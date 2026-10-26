extends Node2D
class_name WorldMap


enum State {MAP, FOCUS, CAMP, CODE}

@export var indicator: Node2D
@export var debug_label: Label
@export var portrait: HotSwapSprite
@export var map: Node2D
@export var camp: Node2D
@export var book: Node2D
@export var town_info: Control
@export var map_marker: Marker2D

@export_group("Camera")
@export var focus_zoom: float = 1.8 ## Map scale while a location is selected
@export var focus_duration: float = 0.45

@export_group("Buttons")
@export var map_button: Button
@export var camp_button: Button
@export var code_button: Button

var current_state: State = State.MAP
var focus_location: TownLocation ## The location that is currently focused on.
var _dtag := DebugTag.new("WorldMap") ## The debug tag for the world map.
var _is_selected: bool = false
var _map_rest_position: Vector2
var _map_rest_scale: Vector2 = Vector2.ONE
var _map_tween: Tween


func _ready() -> void:
	Game.world_map = self
	if map:
		_map_rest_position = map.position
		_map_rest_scale = map.scale
	unfocus_location()
	set_state()

	# Test resources
	Game.change_resource(Game.ResourceType.CORPSE, 10)
	Game.change_resource(Game.ResourceType.BONE, 5)
	Game.change_resource(Game.ResourceType.WEAPON, -3)


func _unhandled_input(event: InputEvent) -> void:
	if current_state != State.MAP and current_state != State.FOCUS:
		return
	if event is not InputEventMouseButton or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	var town := _town_at_mouse()
	if town != null and not town.is_locked():
		_select_location(town)
		return

	if _is_selected or focus_location != null:
		unfocus_location()


func deal_damage_to(_location: TownLocation, _damage: float) -> void:
	_location.take_damage(_damage)
	refresh_locations()
	if focus_location == _location:
		_update_debug_label()


func find_location(save_key: String) -> TownLocation:
	for town in _towns():
		if town.get_save_key() == save_key:
			return town
	return null


func reset_locations() -> void:
	for town in _towns():
		town.reset_progress()
	refresh_locations()
	if focus_location != null:
		_update_debug_label()


func refresh_locations() -> void:
	var towns := _towns()
	for town in towns:
		town.sync_destroyed_state()
	for town in towns:
		town.refresh_visual()


func _towns() -> Array[TownLocation]:
	var towns: Array[TownLocation] = []
	for child in get_children():
		if child is TownLocation:
			towns.append(child)
	return towns


func is_location_selected() -> bool:
	return _is_selected


func focus_location_on(_location: TownLocation) -> void:
	if _is_selected:
		return
	if current_state != State.MAP and current_state != State.FOCUS:
		return

	focus_location = _location
	indicator.show()
	move_indicator_to(focus_location.global_position)
	_dtag.print("Focused on location: %s" % focus_location.name)
	_update_debug_label()
	set_state(State.FOCUS)


func unfocus_location() -> void:
	var restore_map := _is_selected
	focus_location = null
	_is_selected = false
	indicator.hide()
	if town_info:
		town_info.hide()
	_update_debug_label()
	set_state(State.MAP)
	if restore_map:
		_release_map_frame()


func _on_restart_button_pressed() -> void:
	Game.restart()


func _on_delete_save_button_pressed() -> void:
	Game.delete_save()


func move_indicator_to(_position: Vector2) -> void:
	indicator.global_position = _position


func _update_debug_label() -> void:
	if focus_location == null:
		debug_label.text = "No location focused"
		return

	if focus_location.def == null:
		debug_label.text = "No location def found"
		return

	debug_label.text = "Focusing on: %s" % focus_location.def.get_display_name()
	debug_label.text += "\n" + focus_location.def.get_display_description()
	debug_label.text += "\n" + focus_location.def.id
	debug_label.text += "\n" + "Is locked: %s" % focus_location.is_locked()
	debug_label.text += "\n" + "Has been destroyed: %s" % focus_location.has_been_destroyed
	debug_label.text += "\n" + "Restore points: %s" % focus_location.restore_points
	debug_label.text += "\n" + "Required locations: %s" % str(focus_location.required_locations)


func set_state(new_state: State = State.MAP) -> void:
	if new_state != State.FOCUS and _is_selected:
		_is_selected = false
		focus_location = null
		indicator.hide()
		if town_info:
			town_info.hide()
		_release_map_frame()

	current_state = new_state
	_update_portrait()
	_update_buttons()
	_update_state()


func _select_location(location: TownLocation) -> void:
	focus_location = location
	_is_selected = true
	indicator.show()
	move_indicator_to(location.global_position)
	if town_info:
		town_info.show()
	_update_debug_label()
	set_state(State.FOCUS)
	_frame_map_on(location)


func _frame_map_on(location: TownLocation) -> void:
	if map == null or map_marker == null:
		return

	var target_scale := Vector2(focus_zoom, focus_zoom)
	var town_local := _town_local(location)
	var screen_delta := _marker_screen_position() - _viewport_size() * 0.5
	var target_position := screen_delta - Vector2(target_scale.x * town_local.x, target_scale.y * town_local.y)
	_tween_map(target_position, target_scale)


func _release_map_frame() -> void:
	if map == null:
		return

	_tween_map(_map_rest_position, _map_rest_scale)


func _tween_map(target_position: Vector2, target_scale: Vector2) -> void:
	if _map_tween and _map_tween.is_valid():
		_map_tween.kill()

	_map_tween = create_tween()
	_map_tween.set_parallel(true)
	_map_tween.tween_property(map, "position", target_position, focus_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_map_tween.tween_property(map, "scale", target_scale, focus_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _town_local(location: TownLocation) -> Vector2:
	if location.get_parent() == map:
		return location.position

	return map.get_global_transform().affine_inverse() * location.global_position


func _marker_screen_position() -> Vector2:
	return map_marker.get_global_transform_with_canvas().origin


func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _town_at_mouse() -> TownLocation:
	var space := get_world_2d().direct_space_state
	if space == null:
		return null

	var params := PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	params.collide_with_bodies = false
	for hit in space.intersect_point(params, 8):
		var town := hit.collider as TownLocation
		if town != null:
			return town
	return null


func _update_state() -> void:
	if current_state == State.MAP or  current_state == State.FOCUS:
		map.set_process(true)
	else:
		map.set_process(false)

	set_camp_visible(current_state == State.CAMP)
	set_book_visible(current_state == State.CODE)


func set_camp_visible(value: bool = true) -> void:
	map.set_visible(!value)
	if camp:
		for child in camp.get_children():
			if child.has_method("set_visible"):
				child.set_visible(value)
		camp.visible = value


func set_book_visible(value: bool = true) -> void:
	if book:
		for child in book.get_children():
			if child.has_method("set_visible"):
				child.set_visible(value)
		book.visible = value
	

func _update_portrait() -> void:
	var texture_id := ""
	
	match current_state:
		State.MAP:
			texture_id = "tex_portrait_idle"
		State.FOCUS:
			texture_id = "tex_portrait_point"
		State.CAMP:
			texture_id = "tex_portrait_evil"
		State.CODE:
			texture_id = "tex_portrait_write"

	if portrait:
		portrait.set("asset_id", texture_id)


func _update_buttons() -> void:
	for btn in [map_button, camp_button, code_button]:
		btn.modulate = Game.DISABLED_COLOR

	match current_state:
		State.MAP, State.FOCUS:
			map_button.modulate = Color.WHITE
		State.CAMP:
			camp_button.modulate = Color.WHITE
		State.CODE:
			code_button.modulate = Color.WHITE


func _on_raid_button_pressed() -> void:
	Game.raid_to(focus_location)