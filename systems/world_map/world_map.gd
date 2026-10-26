extends Node2D
class_name WorldMap


enum State {MAP, FOCUS, CAMP, CODE}

@export var indicator: Node2D
@export var debug_label: Label
@export var portrait: HotSwapSprite
@export var map: Node2D
@export var camp: Node2D
@export var book: Node2D

@export_group("Buttons")
@export var map_button: Button
@export var camp_button: Button
@export var code_button: Button

var current_state: State = State.MAP
var focus_location: TownLocation ## The location that is currently focused on.
var _dtag := DebugTag.new("WorldMap") ## The debug tag for the world map.


func _ready() -> void:
	Game.world_map = self
	unfocus_location()
	set_state()

	# Test resources
	Game.change_resource(Game.ResourceType.CORPSE, 10)
	Game.change_resource(Game.ResourceType.BONE, 5)
	Game.change_resource(Game.ResourceType.WEAPON, -3)


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
	if current_state != State.MAP:
		return

	focus_location = _location
	indicator.show()
	move_indicator_to(focus_location.global_position)
	_dtag.print("Focused on location: %s" % focus_location.name)
	_update_debug_label()
	set_state(State.FOCUS)


func unfocus_location() -> void:
	focus_location = null
	indicator.hide()
	_update_debug_label()
	set_state(State.MAP)


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
	current_state = new_state
	_update_portrait()
	_update_buttons()
	_update_state()


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
