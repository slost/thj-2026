extends Node


const BATTLE_SCENE: String = "res://systems/battle/battle.tscn"
const MAP_SCENE: String = "res://systems/world_map/world_map.tscn"
const DESTROYED_RATIO: float = 0.5 # The ratio of the town's restore points to be destroyed.
const MAP_SAVE_SLOT := 0
const DISABLED_COLOR: Color = Color.DIM_GRAY


# States
var raid_target_id := "" ## Save key of the town that was raided.
var pending_raid_damage := 0.0 ## Applied after the map reloads its saved restore points.

# Refs
var world_map: WorldMap


func raid_to(_location: TownLocation) -> void:
	raid_target_id = _location.get_save_key()
	save_map_state()
	get_tree().change_scene_to_file(BATTLE_SCENE)


func back_to_map() -> void:
	pending_raid_damage = 50.0 # test only, remove this later
	get_tree().change_scene_to_file(MAP_SCENE)


func load_map_state() -> void:
	if SaveManager.has_slot(MAP_SAVE_SLOT):
		SaveManager.load_slot(MAP_SAVE_SLOT)

	if world_map != null:
		world_map.refresh_locations()

	_apply_pending_raid_damage()


func save_map_state() -> void:
	SaveManager.save_slot(MAP_SAVE_SLOT)


func _apply_pending_raid_damage() -> void:
	if pending_raid_damage <= 0.0:
		return

	var damage := pending_raid_damage
	pending_raid_damage = 0.0
	if world_map == null or raid_target_id.is_empty():
		return

	var location := world_map.find_location(raid_target_id)
	if location == null:
		push_warning("Game: saved raid target '%s' is not on the world map" % raid_target_id)
		return

	world_map.deal_damage_to(location, damage)
	save_map_state()


func restart() -> void:
	_clear_raid_request()
	SaveManager.delete_slot(MAP_SAVE_SLOT)
	get_tree().change_scene_to_file(MAP_SCENE)


func delete_save() -> void:
	_clear_raid_request()
	SaveManager.delete_slot(MAP_SAVE_SLOT)
	if world_map != null:
		world_map.reset_locations()


func _clear_raid_request() -> void:
	raid_target_id = ""
	pending_raid_damage = 0.0
