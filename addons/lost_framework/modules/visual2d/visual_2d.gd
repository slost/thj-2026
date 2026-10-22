@tool
extends Node2D
class_name Visual2D

## Presents a main sprite, its outline, and an [AnimationPlayer] as one visual.
##
## Art states come from [VisualDef]. A state can replace the texture, sheet,
## region, offset, flip, modulate, outline, and animation. Fields left unused
## keep the current sprite. Clips stored on the definition are installed with it.
## The outline stays aligned with the main sprite. Scale, rotation, and position
## are inherited because the outline is a child of the main sprite.
## Runtime shader edits use a unique material copy.

signal texture_changed(texture: Texture2D)
signal state_changed(state_name: StringName)
signal animation_finished(anim_name: StringName)

enum MaterialTarget {
	MAIN,
	OUTLINE,
	BOTH,
}

## Result of [method set_state] and [method set_definition].
## [code]NOT_FOUND[/code] is [code]0[/code], so a bare [code]if set_state()[/code] is false only when nothing was applied.
enum StateApplyResult {
	NOT_FOUND,
	APPLIED,
	FELL_BACK,
}

const OUTLINE_COLOR := &"clr"
const OUTLINE_THICKNESS := &"thickness"
const OUTLINE_TYPE := &"type"
const DEF_LIBRARY := &"visual_def"


@export_group("Nodes")
@export var main_sprite: Sprite2D
@export var outline_sprite: Sprite2D
@export var animation_player: AnimationPlayer:
	set(value):
		if animation_player == value:
			_bind_animation_player()
			return
		_unbind_animation_player()
		animation_player = value
		_bind_animation_player()

@export_group("Visual")
@export var def: VisualDef:
	set(value):
		set_definition(value)
	get:
		return _definition

@export var state: StringName = &"default":
	set(value):
		set_state(value)
	get:
		return _state

@export_group("Outline")
@export var outline_enabled := true:
	set(value):
		outline_enabled = value
		_apply_outline_visibility()

## Copies frame, flip, region, and related sprite settings from the main sprite onto the outline.
@export var outline_follows_main := true:
	set(value):
		outline_follows_main = value
		set_process(value and not Engine.is_editor_hint())

var _definition: VisualDef
var _state: StringName = &"default"
var _pending_state: StringName = &""
var _texture: Texture2D
var _bound_animation_player: AnimationPlayer
var _animation_waits: Array = []
var _advance_from_state: StringName = &""
var _advance_clip: StringName = &""


func _ready() -> void:
	if not tree_exiting.is_connected(_on_tree_exiting):
		tree_exiting.connect(_on_tree_exiting)
	_duplicate_runtime_materials()
	_bind_animation_player()
	_apply_outline_visibility()
	set_process(outline_follows_main and not Engine.is_editor_hint())
	if _texture == null and main_sprite != null:
		_texture = main_sprite.texture
	if _definition != null:
		var startup_state := _pending_state if _pending_state != &"" else _state
		set_state(startup_state)
	elif _texture != null:
		_update_sprites()
	_sync_outline_from_main()


func _process(_delta: float) -> void:
	# Sprite edits outside AnimationPlayer (offset, flip, frame, region) have no signal.
	# Playback is synced again from mixer_applied, after the mixer writes the main sprite.
	_sync_outline_from_main()


func _exit_tree() -> void:
	_settle_animation_waits(&"", false, false)


func _on_tree_exiting() -> void:
	_settle_animation_waits(&"", false, false)


func get_sprite() -> Sprite2D:
	return main_sprite

#region Texture
func set_texture(texture: Texture2D) -> void:
	_texture = texture
	_update_sprites()
	texture_changed.emit(_texture)


func get_texture() -> Texture2D:
	return _texture


func set_flip(flip_h: bool, flip_v: bool) -> void:
	if main_sprite == null:
		return
	main_sprite.flip_h = flip_h
	main_sprite.flip_v = flip_v
	_sync_outline_from_main()


func set_frame(frame: int) -> void:
	if main_sprite == null:
		return
	main_sprite.frame = frame
	_sync_outline_from_main()


func set_sprite_sheet(hframes: int, vframes: int, frame := 0) -> void:
	if main_sprite == null:
		return
	main_sprite.hframes = maxi(hframes, 1)
	main_sprite.vframes = maxi(vframes, 1)
	main_sprite.frame = frame
	_sync_outline_from_main()


func set_region(enabled: bool, rect := Rect2()) -> void:
	if main_sprite == null:
		return
	main_sprite.region_enabled = enabled
	if enabled:
		main_sprite.region_rect = rect
	_sync_outline_from_main()

#endregion


#region State
## Stores [param visual_definition] and applies [param next_state], or the current state when the name is empty.
## See [enum StateApplyResult]. The stored state changes only when a state actually resolves.
func set_definition(visual_definition: VisualDef, next_state: StringName = &"") -> StateApplyResult:
	_definition = visual_definition
	_install_animation_library()
	var target := _state
	if next_state != &"":
		target = next_state
	elif _pending_state != &"":
		target = _pending_state
	var result := set_state(target)
	notify_property_list_changed()
	return result


## Applies [param next_state] from [member definition].
## [enum StateApplyResult.APPLIED] means that state exists and is now current.
## [enum StateApplyResult.FELL_BACK] means it was missing and [code]default[/code] was applied instead.
## [enum StateApplyResult.NOT_FOUND] means neither exists. The previous state is kept and [signal state_changed] is not emitted.
## With no definition yet, the name is remembered and applied when a definition arrives. [method get_state] stays unchanged.
func set_state(next_state: StringName) -> StateApplyResult:
	if _definition == null:
		_pending_state = next_state
		return StateApplyResult.NOT_FOUND

	_pending_state = &""
	var visual_state := _find_state(next_state)
	var resolved_name := next_state
	var result := StateApplyResult.APPLIED
	if visual_state == null:
		if next_state != &"default":
			visual_state = _find_state(&"default")
			resolved_name = &"default"
		if visual_state == null:
			push_warning("Visual2D: state '%s' not found." % next_state)
			return StateApplyResult.NOT_FOUND
		push_warning("Visual2D: state '%s' not found, using 'default'." % next_state)
		result = StateApplyResult.FELL_BACK

	_state = resolved_name
	apply_visual_state(visual_state)
	state_changed.emit(_state)
	return result


func get_state() -> StringName:
	return _state


## Names stored on [member definition], sorted. Used by the Inspector state list.
func get_state_names() -> PackedStringArray:
	var names := PackedStringArray()
	if _definition == null:
		return names
	for key: Variant in _definition.states.keys():
		names.append(String(key))
	names.sort()
	return names


func has_state(state_name: StringName) -> bool:
	return _find_state(state_name) != null


## Applies one visual state without changing the stored state name.
## Sprite fields apply only when that state opts in. An empty animation keeps the current clip.
## [member VisualState.next_state] runs when the clip started here finishes. Looping clips do not advance.
func apply_visual_state(visual_state: VisualState) -> void:
	if visual_state == null:
		push_warning("Visual2D: cannot apply a null visual state.")
		return
	_advance_from_state = &""
	_advance_clip = &""
	if visual_state.texture != null:
		set_texture(visual_state.texture)
	_apply_state_sprite(visual_state)
	if visual_state.outline_style != null:
		set_outline_style(visual_state.outline_style)
	if visual_state.animation == &"" or animation_player == null or Engine.is_editor_hint():
		return
	if not play(visual_state.animation) or visual_state.next_state == &"":
		return
	_advance_from_state = _state
	_advance_clip = get_current_animation()

#endregion


#region Animation
func play(anim_name: StringName = &"", custom_blend := -1.0, custom_speed := 1.0, from_end := false) -> bool:
	var resolved := _resolve_animation_name(anim_name)
	if not _can_play(resolved):
		return false
	animation_player.play(resolved, custom_blend, custom_speed, from_end)
	return true


func play_backwards(anim_name: StringName = &"", custom_blend := -1.0) -> bool:
	var resolved := _resolve_animation_name(anim_name)
	if not _can_play(resolved):
		return false
	animation_player.play_backwards(resolved, custom_blend)
	return true


## Plays [param anim_name] and waits until it finishes.
## Returns [code]true[/code] when a non-looping clip finishes or playback is stopped.
## Returns [code]false[/code] when playback cannot start, the clip loops (it is left playing),
## or this node is freed or leaves the tree before the clip finishes.
## Looping clips never emit [signal AnimationMixer.animation_finished], so this does not wait for them.
func play_and_wait(anim_name: StringName = &"", custom_blend := -1.0, custom_speed := 1.0, from_end := false) -> bool:
	if not play(anim_name, custom_blend, custom_speed, from_end):
		return false
	if animation_player == null or not is_inside_tree():
		return false

	var target := get_current_animation()
	if target == &"" or not animation_player.has_animation(target):
		return false

	var clip := animation_player.get_animation(target)
	if clip != null and clip.loop_mode != Animation.LOOP_NONE:
		return false
	if not is_playing(target):
		return true

	var gate := _AnimationWait.new()
	gate.target = target
	_animation_waits.append(gate)
	var success: bool = await gate.settled
	if not is_instance_valid(self) or not is_inside_tree():
		return false
	_animation_waits.erase(gate)
	if animation_player == null or not is_instance_valid(animation_player) or not animation_player.is_inside_tree():
		return false
	return success


func queue_animation(anim_name: StringName) -> bool:
	if anim_name == &"":
		push_warning("Visual2D: cannot queue an empty animation name.")
		return false
	var resolved := _resolve_animation_name(anim_name)
	if not _can_play(resolved):
		return false
	animation_player.queue(resolved)
	return true


func stop(keep_state := false) -> void:
	if animation_player == null:
		return
	var current := get_current_animation()
	_advance_from_state = &""
	_advance_clip = &""
	animation_player.stop(keep_state)
	_sync_outline_from_main()
	_settle_animation_waits(current, true)


func pause() -> void:
	if animation_player == null:
		return
	animation_player.pause()
	_sync_outline_from_main()


func resume() -> void:
	if animation_player == null:
		return
	animation_player.play()


func is_playing(anim_name: StringName = &"") -> bool:
	if animation_player == null or not animation_player.is_playing():
		return false
	if anim_name == &"":
		return true
	return _animation_names_match(animation_player.current_animation, anim_name)


func has_animation(anim_name: StringName) -> bool:
	if animation_player == null:
		return false
	if animation_player.has_animation(anim_name):
		return true
	return animation_player.has_animation(_library_animation_name(anim_name))


func get_current_animation() -> StringName:
	if animation_player == null:
		return &""
	return animation_player.current_animation


func set_animation_speed(speed_scale: float) -> void:
	if animation_player == null:
		return
	animation_player.speed_scale = speed_scale

#endregion


#region Shader
func set_shader(shader: Shader, target: MaterialTarget = MaterialTarget.MAIN) -> void:
	if shader == null:
		clear_shader(target)
		return
	if target == MaterialTarget.BOTH:
		set_shader(shader, MaterialTarget.MAIN)
		set_shader(shader, MaterialTarget.OUTLINE)
		return

	var sprite := _sprite_for(target)
	if sprite == null:
		push_warning("Visual2D: missing %s sprite." % _target_label(target))
		return

	var mat := _unique_shader_material(sprite)
	if mat == null:
		mat = ShaderMaterial.new()
		if not Engine.is_editor_hint():
			mat.resource_local_to_scene = true
		sprite.material = mat
	mat.shader = shader


func clear_shader(target: MaterialTarget = MaterialTarget.MAIN) -> void:
	if target == MaterialTarget.BOTH:
		clear_shader(MaterialTarget.MAIN)
		clear_shader(MaterialTarget.OUTLINE)
		return

	var sprite := _sprite_for(target)
	if sprite == null:
		return
	sprite.material = null


func set_shader_parameter(parameter: StringName, value: Variant, target: MaterialTarget = MaterialTarget.MAIN) -> void:
	if target == MaterialTarget.BOTH:
		set_shader_parameter(parameter, value, MaterialTarget.MAIN)
		set_shader_parameter(parameter, value, MaterialTarget.OUTLINE)
		return

	var sprite := _sprite_for(target)
	if sprite == null:
		push_warning("Visual2D: missing %s sprite." % _target_label(target))
		return

	var mat := _unique_shader_material(sprite)
	if mat == null:
		push_warning("Visual2D: %s sprite has no ShaderMaterial." % _target_label(target))
		return
	mat.set_shader_parameter(parameter, value)


func get_shader_parameter(parameter: StringName, target: MaterialTarget = MaterialTarget.MAIN) -> Variant:
	if target == MaterialTarget.BOTH:
		target = MaterialTarget.MAIN
	var sprite := _sprite_for(target)
	if sprite == null:
		return null
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return null
	return mat.get_shader_parameter(parameter)


func reset_shader_parameter(parameter: StringName, target: MaterialTarget = MaterialTarget.MAIN) -> void:
	set_shader_parameter(parameter, null, target)

#endregion


#region Outline
func toggle_outline(enabled: bool) -> void:
	outline_enabled = enabled


func set_outline_color(color: Color) -> void:
	set_shader_parameter(OUTLINE_COLOR, color, MaterialTarget.OUTLINE)


func set_outline_thickness(thickness: float) -> void:
	set_shader_parameter(OUTLINE_THICKNESS, thickness, MaterialTarget.OUTLINE)


## Outline sample count from [code]outline.gdshader[/code]. [code]1[/code] uses 4 directions and [code]2[/code] uses 8.
## [code]0[/code] samples nothing, so values below [code]1[/code] are raised to [code]1[/code].
func set_outline_type(type: int) -> void:
	set_shader_parameter(OUTLINE_TYPE, clampi(type, 1, 2), MaterialTarget.OUTLINE)


## Applies [param style] color, thickness, and type together.
func set_outline_style(style: OutlineStyle) -> void:
	if style == null:
		push_warning("Visual2D: cannot apply a null outline style.")
		return
	set_outline_color(style.color)
	set_outline_thickness(style.thickness)
	set_outline_type(style.type)


func sync_outline() -> void:
	_sync_outline_from_main()

#endregion


func _find_state(state_name: StringName) -> VisualState:
	if _definition == null:
		return null
	return _definition.get_visual_state(state_name)


func _update_sprites() -> void:
	if main_sprite != null:
		main_sprite.texture = _texture
	if outline_sprite != null:
		outline_sprite.texture = _texture
	_sync_outline_from_main()


func _sync_outline_from_main() -> void:
	if not outline_follows_main or main_sprite == null or outline_sprite == null:
		return

	if outline_sprite.texture != main_sprite.texture:
		outline_sprite.texture = main_sprite.texture
	if outline_sprite.hframes != main_sprite.hframes:
		outline_sprite.hframes = main_sprite.hframes
	if outline_sprite.vframes != main_sprite.vframes:
		outline_sprite.vframes = main_sprite.vframes
	if outline_sprite.frame != main_sprite.frame:
		outline_sprite.frame = main_sprite.frame
	if outline_sprite.flip_h != main_sprite.flip_h:
		outline_sprite.flip_h = main_sprite.flip_h
	if outline_sprite.flip_v != main_sprite.flip_v:
		outline_sprite.flip_v = main_sprite.flip_v
	if outline_sprite.region_enabled != main_sprite.region_enabled:
		outline_sprite.region_enabled = main_sprite.region_enabled
	if outline_sprite.region_rect != main_sprite.region_rect:
		outline_sprite.region_rect = main_sprite.region_rect
	if outline_sprite.centered != main_sprite.centered:
		outline_sprite.centered = main_sprite.centered
	if outline_sprite.offset != main_sprite.offset:
		outline_sprite.offset = main_sprite.offset
	# Scale is a transform. A child outline already inherits it, so copying it would apply the scale twice.
	if outline_sprite.get_parent() != main_sprite and outline_sprite.scale != main_sprite.scale:
		outline_sprite.scale = main_sprite.scale


func _apply_outline_visibility() -> void:
	if outline_sprite != null:
		outline_sprite.visible = outline_enabled


func _duplicate_runtime_materials() -> void:
	_unique_shader_material(main_sprite)
	_unique_shader_material(outline_sprite)


func _unique_shader_material(sprite: Sprite2D) -> ShaderMaterial:
	if sprite == null:
		return null
	var mat := sprite.material as ShaderMaterial
	if mat == null or Engine.is_editor_hint() or mat.resource_local_to_scene:
		return mat

	var unique := mat.duplicate() as ShaderMaterial
	unique.resource_local_to_scene = true
	sprite.material = unique
	return unique


func _can_play(anim_name: StringName) -> bool:
	if animation_player == null:
		push_warning("Visual2D: AnimationPlayer is not assigned.")
		return false
	if anim_name != &"" and not animation_player.has_animation(anim_name):
		push_warning("Visual2D: animation '%s' not found." % anim_name)
		return false
	return true


func _bind_animation_player() -> void:
	if animation_player == null or animation_player == _bound_animation_player:
		return
	_unbind_animation_player()
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	if not animation_player.mixer_applied.is_connected(_sync_outline_from_main):
		animation_player.mixer_applied.connect(_sync_outline_from_main)
	if not animation_player.current_animation_changed.is_connected(_on_current_animation_changed):
		animation_player.current_animation_changed.connect(_on_current_animation_changed)
	_bound_animation_player = animation_player
	_install_animation_library()


func _unbind_animation_player() -> void:
	if _bound_animation_player == null:
		return
	if is_instance_valid(_bound_animation_player):
		if _bound_animation_player.animation_finished.is_connected(_on_animation_finished):
			_bound_animation_player.animation_finished.disconnect(_on_animation_finished)
		if _bound_animation_player.mixer_applied.is_connected(_sync_outline_from_main):
			_bound_animation_player.mixer_applied.disconnect(_sync_outline_from_main)
		if _bound_animation_player.current_animation_changed.is_connected(_on_current_animation_changed):
			_bound_animation_player.current_animation_changed.disconnect(_on_current_animation_changed)
	_bound_animation_player = null


func _on_animation_finished(anim_name: StringName) -> void:
	_sync_outline_from_main()
	animation_finished.emit(anim_name)
	_settle_animation_waits(anim_name, true)
	_advance_after_animation(anim_name)


func _on_current_animation_changed(_anim_name: StringName) -> void:
	# AnimationPlayer also emits this with an empty name while the new clip is still playing.
	# Only end a wait when its clip has actually stopped, and fail the wait if playback is torn down with the tree.
	if not is_inside_tree() or animation_player == null or not is_instance_valid(animation_player) or not animation_player.is_inside_tree():
		_settle_animation_waits(&"", false, false)
		return
	var pending := _animation_waits.duplicate()
	for gate in pending:
		if is_playing(gate.target):
			continue
		gate.settle(true)


func _settle_animation_waits(anim_name: StringName, success: bool, only_target := true) -> void:
	var pending := _animation_waits.duplicate()
	for gate in pending:
		if only_target and gate.target != anim_name:
			continue
		gate.settle(success)


func _sprite_for(target: MaterialTarget) -> Sprite2D:
	match target:
		MaterialTarget.MAIN:
			return main_sprite
		MaterialTarget.OUTLINE:
			return outline_sprite
		_:
			return null


func _validate_property(property: Dictionary) -> void:
	if property.name != "state":
		return
	var names := get_state_names()
	if names.is_empty():
		return
	var cleaned := PackedStringArray()
	for state_name in names:
		cleaned.append(state_name.replace(",", ""))
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(cleaned)


func _apply_state_sprite(visual_state: VisualState) -> void:
	if main_sprite == null:
		return
	if visual_state.apply_frames:
		set_sprite_sheet(visual_state.hframes, visual_state.vframes, visual_state.frame)
	if visual_state.apply_region:
		set_region(visual_state.region_enabled, visual_state.region_rect)
	if visual_state.apply_offset:
		main_sprite.offset = visual_state.offset
		_sync_outline_from_main()
	if visual_state.apply_flip:
		set_flip(visual_state.flip_h, visual_state.flip_v)
	if visual_state.apply_modulate:
		main_sprite.modulate = visual_state.modulate


func _advance_after_animation(anim_name: StringName) -> void:
	if _advance_from_state == &"" or _advance_clip != anim_name or _state != _advance_from_state:
		return
	var visual_state := _find_state(_state)
	if visual_state == null or visual_state.next_state == &"":
		return
	var next := visual_state.next_state
	_advance_from_state = &""
	_advance_clip = &""
	set_state(next)


func _install_animation_library() -> void:
	if Engine.is_editor_hint():
		return
	if animation_player == null:
		return
	if animation_player.has_animation_library(DEF_LIBRARY):
		animation_player.remove_animation_library(DEF_LIBRARY)
	if _definition == null or _definition.animation_library == null:
		return
	var copy := _definition.animation_library.duplicate(true) as AnimationLibrary
	if copy == null:
		push_warning("Visual2D: could not copy the definition animation library.")
		return
	var err := animation_player.add_animation_library(DEF_LIBRARY, copy)
	if err != OK:
		push_warning("Visual2D: could not install the definition animation library (%s)." % error_string(err))


func _resolve_animation_name(anim_name: StringName) -> StringName:
	if anim_name == &"" or animation_player == null or animation_player.has_animation(anim_name):
		return anim_name
	var prefixed := _library_animation_name(anim_name)
	if animation_player.has_animation(prefixed):
		return prefixed
	return anim_name


func _library_animation_name(anim_name: StringName) -> StringName:
	return StringName("%s/%s" % [DEF_LIBRARY, String(anim_name)])


func _animation_names_match(current: StringName, requested: StringName) -> bool:
	if current == requested:
		return true
	return current == _library_animation_name(requested) or requested == _library_animation_name(current)


func _target_label(target: MaterialTarget) -> String:
	match target:
		MaterialTarget.MAIN:
			return "main"
		MaterialTarget.OUTLINE:
			return "outline"
		_:
			return "both"


class _AnimationWait extends RefCounted:
	signal settled(success: bool)

	var target: StringName
	var _done := false


	func settle(success: bool) -> void:
		if _done:
			return
		_done = true
		settled.emit(success)
