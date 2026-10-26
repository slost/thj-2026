extends Node2D
class_name WorldMap


@export var indicator: Node2D
@export var debug_label: Label

var focus_location: TownLocation ## The location that is currently focused on.
var _dtag := DebugTag.new("WorldMap") ## The debug tag for the world map.


func _ready() -> void:
	Game.world_map = self
	unfocus_location()


func _input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return

	if focus_location == null:
		return

	if focus_location.is_locked():
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			Game.raid_to(focus_location)


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


func focus_location_on(_location: TownLocation) -> void:
	focus_location = _location
	indicator.show()
	move_indicator_to(focus_location.global_position)
	_dtag.print("Focused on location: %s" % focus_location.name)
	_update_debug_label()


func unfocus_location() -> void:
	focus_location = null
	indicator.hide()
	_update_debug_label()


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
