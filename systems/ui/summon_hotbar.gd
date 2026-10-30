## Eight summon buttons. Shown in camp and in battle, hidden on the map and in the book.
extends Control


const _Summoner := preload("res://systems/game/summoner.gd")
const _GHOST_TEXTURE := preload("res://placeholders/tex_zombie.png")
const _FLASH_TIME := 1.6

@onready var _flash_label: Label = %Flash
@onready var _buttons: Array[Button] = [
	%Spell1, %Spell2, %Spell3, %Spell4, %Spell5, %Spell6, %Spell7, %Spell8,
]

var _spell_index := -1
var _ghost: Node2D
var _ghost_spell := -2
var _flash_left := 0.0
var _selecting := false


func _ready() -> void:
	_flash_label.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in _buttons.size():
		var button := _buttons[index]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_spell_pressed.bind(index))
	if not Game.resource_changed.is_connected(_refresh_buttons):
		Game.resource_changed.connect(_refresh_buttons)
	_refresh_buttons()
	refresh_visibility()


func _process(delta: float) -> void:
	var was_visible := visible
	refresh_visibility()
	if visible and not was_visible:
		_refresh_buttons()
	_tick_flash(delta)
	_follow_ghost()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		_on_key(event as InputEventKey)
		return
	if event is InputEventMouseButton:
		_on_mouse(event as InputEventMouseButton)


func refresh_visibility() -> void:
	var show_bar := _should_show()
	if not show_bar and _spell_index >= 0:
		_cancel_placement()
	visible = show_bar


func _should_show() -> bool:
	var stage := Game.current_stage
	if stage == null or not is_instance_valid(stage):
		return false
	if stage.has_method("allows_summon_bar"):
		return bool(stage.call("allows_summon_bar"))
	if stage is WorldMap:
		return (stage as WorldMap).current_state == WorldMap.State.CAMP
	return stage.has_method("spawn_raid_party")


func _refresh_buttons() -> void:
	for index in _buttons.size():
		var button := _buttons[index]
		if index >= Game.spells.size() or not _stage_shows_spell(index):
			button.visible = false
			continue
		button.visible = true
		var spell := Game.spells[index]
		button.text = spell.display_name()
		button.clip_text = true
		RaceProfiles.mount_slot_icon(button, spell.race)
		var open := _stage_allows_spell(index)
		button.disabled = not open
		var affordable := open and _Summoner.can_afford(spell)
		button.modulate = Color.WHITE if affordable else Game.DISABLED_COLOR
		button.tooltip_text = "" if affordable else _Summoner.deny_reason(spell)
		_fill_costs(button, spell)
		if index != _spell_index:
			button.button_pressed = false


func _fill_costs(button: Button, spell: SummonSpell) -> void:
	var row := button.get_node_or_null("Costs") as HBoxContainer
	if row == null:
		row = HBoxContainer.new()
		row.name = "Costs"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		row.offset_left = 4.0
		row.offset_right = -4.0
		row.offset_top = -30.0
		row.offset_bottom = -4.0
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		button.add_child(row)
	for child in row.get_children():
		child.free()
	for entry in _Summoner.cost_entries(spell):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var icon := HotSwapTextureRect.new()
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var resource_type: Game.ResourceType = int(entry.get("type", 0))
		icon.asset_id = Game.resource_icon_id(resource_type)
		row.add_child(icon)
		var amount := Label.new()
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		amount.text = str(int(entry.get("amount", 0)))
		row.add_child(amount)


func _on_spell_pressed(index: int) -> void:
	if _selecting:
		return
	if _spell_index == index:
		_cancel_placement()
		return
	_select(index)


func _on_key(key: InputEventKey) -> void:
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE and _spell_index >= 0:
		_cancel_placement()
		get_viewport().set_input_as_handled()
		return
	var index := _digit(key.keycode)
	if index < 0:
		return
	_select(index)
	get_viewport().set_input_as_handled()


func _on_mouse(mouse: InputEventMouseButton) -> void:
	if _spell_index < 0 or not mouse.pressed:
		return
	if mouse.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_placement()
		get_viewport().set_input_as_handled()
		return
	if mouse.button_index != MOUSE_BUTTON_LEFT or _pointer_on_bar():
		return
	_confirm()
	get_viewport().set_input_as_handled()


func _stage_shows_spell(index: int) -> bool:
	var stage := Game.current_stage
	if stage != null and stage.has_method("shows_spell"):
		return bool(stage.call("shows_spell", index))
	return _stage_allows_spell(index)


func _stage_allows_spell(index: int) -> bool:
	var stage := Game.current_stage
	if stage != null and stage.has_method("allows_spell"):
		return bool(stage.call("allows_spell", index))
	return true


func _stage_allows_summon(index: int) -> bool:
	var stage := Game.current_stage
	if stage != null and stage.has_method("allows_summon"):
		return bool(stage.call("allows_summon", index))
	return true


func _digit(keycode: Key) -> int:
	if keycode >= KEY_1 and keycode <= KEY_8:
		return keycode - KEY_1
	if keycode >= KEY_KP_1 and keycode <= KEY_KP_8:
		return keycode - KEY_KP_1
	return -1


func _select(index: int) -> void:
	if index < 0 or index >= Game.spells.size():
		return
	if not _stage_allows_spell(index) or not _stage_allows_summon(index):
		return
	var spell := Game.spells[index]
	if not _Summoner.can_afford(spell):
		_flash(_Summoner.deny_reason(spell))
		_buttons[index].button_pressed = false
		return
	_spell_index = index
	_selecting = true
	_buttons[index].button_pressed = true
	_selecting = false
	_ensure_ghost()


func _confirm() -> void:
	if _spell_index < 0 or _spell_index >= Game.spells.size():
		return
	var spot := _spot(_mouse_world())
	if not bool(spot.get("ok", false)):
		return
	if not _stage_allows_summon(_spell_index):
		return
	var spell := Game.spells[_spell_index]
	var host := _summon_root()
	if host == null or _Summoner.summon(spell, host, spot.get("pos", Vector2.ZERO)) == null:
		_flash(_Summoner.deny_reason(spell))
		return
	if host.has_method("note_summon"):
		host.note_summon()
	_cancel_placement()
	_refresh_buttons()


func _cancel_placement() -> void:
	_spell_index = -1
	_free_ghost()
	_set_summon_preview(false)
	_selecting = true
	for button in _buttons:
		button.button_pressed = false
	_selecting = false


func _ensure_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost) and _ghost_spell == _spell_index:
		_set_summon_preview(true)
		return
	_free_ghost()
	var stage := Game.current_stage
	if stage == null:
		return
	var spell: SummonSpell = null
	if _spell_index >= 0 and _spell_index < Game.spells.size():
		spell = Game.spells[_spell_index]
	var ghost := Node2D.new()
	ghost.name = "SummonGhost"
	ghost.z_index = 40
	ghost.modulate = Color(1, 1, 1, 0.55)
	_mount_preview(ghost, spell)
	stage.add_child(ghost)
	_ghost = ghost
	_ghost_spell = _spell_index
	_set_summon_preview(true)


func _free_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_ghost_spell = -2


func _mount_preview(host: Node2D, spell: SummonSpell) -> void:
	var race := Unit2D.Race.ZOMBIE
	if spell != null:
		spell.build_def()
		race = spell.race
	var path := Unit2D.scene_path_for_race(race)
	var scene: PackedScene = null
	if path != "":
		scene = load(path) as PackedScene
	var visual: Node2D = null
	if scene != null:
		visual = scene.instantiate() as Node2D
	if visual == null:
		var sprite := Sprite2D.new()
		sprite.texture = _GHOST_TEXTURE
		host.add_child(sprite)
		return
	visual.name = "Visual"
	host.add_child(visual)
	if Unit2D.is_villager_race(race):
		Unit2D.randomize_villager_sprites(visual)
	_loop_spawn(visual.get_node_or_null("AnimationPlayer") as AnimationPlayer)


## Plays a copy of spawn on loop. The shared clip on the animation scene stays unchanged.
func _loop_spawn(player: AnimationPlayer) -> void:
	if player == null or not player.has_animation(&"spawn"):
		return
	var source := player.get_animation(&"spawn")
	if source == null:
		return
	var clip := source.duplicate(true) as Animation
	if clip == null:
		return
	clip.loop_mode = Animation.LOOP_LINEAR
	var library := AnimationLibrary.new()
	library.add_animation(&"spawn", clip)
	var library_name := &"ghost"
	if player.has_animation_library(library_name):
		player.remove_animation_library(library_name)
	player.add_animation_library(library_name, library)
	player.play(&"ghost/spawn")


func _set_summon_preview(active: bool) -> void:
	var stage := Game.current_stage
	if stage != null and stage.has_method("set_summon_preview"):
		stage.call("set_summon_preview", active)
	if GUI != null and GUI.has_method("set_summoning"):
		GUI.set_summoning(active)


func _follow_ghost() -> void:
	if _ghost == null or not is_instance_valid(_ghost) or _spell_index < 0:
		return
	var spot := _spot(_mouse_world())
	_ghost.global_position = spot.get("pos", _mouse_world())
	if bool(spot.get("ok", false)):
		_ghost.modulate = Color(0.55, 1.0, 0.6, 0.55)
	else:
		_ghost.modulate = Color(1.0, 0.35, 0.32, 0.78)


func _spot(world_pos: Vector2) -> Dictionary:
	var stage := Game.current_stage
	if stage != null and stage.has_method("summon_spot"):
		var result: Variant = stage.call("summon_spot", world_pos)
		if result is Dictionary:
			return result
	return {"ok": false, "pos": world_pos}


func _summon_root() -> Node:
	var stage := Game.current_stage
	if stage is WorldMap:
		var camp: Node = (stage as WorldMap).camp
		if camp != null:
			return camp
	return stage


func _mouse_world() -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera:
		return camera.get_global_mouse_position()
	return get_global_mouse_position()


func _pointer_on_bar() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and (hovered == self or is_ancestor_of(hovered))


func _flash(text: String) -> void:
	_flash_label.text = text
	_flash_label.visible = true
	_flash_left = _FLASH_TIME


func _tick_flash(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	if _flash_left <= 0.0:
		_flash_label.visible = false
