extends Node


signal resource_changed()

enum ResourceType {
	CORPSE,
	BONE,
	WEAPON,
	COLLAR,
}

const BATTLE_SCENE: String = "res://systems/battle/battle.tscn"
const MAP_SCENE: String = "res://systems/world_map/world_map.tscn"
const DESTROYED_RATIO: float = 0.5 # The ratio of the town's restore points to be destroyed.
const MAP_SAVE_SLOT := 0
const DISABLED_COLOR: Color = Color.DIM_GRAY

# States
var raid_target_id := "" ## Save key of the town that was raided.
var pending_raid_damage := 0.0 ## Applied after the map reloads its saved restore points.
var current_stage: Node

# Hard-coded resources
var corpse := 0
var bone := 0
var weapon := 0
var collar := 0

# Refs
var world_map: WorldMap

## Blocks the player owns. Empty on startup, then seeded from data/blocks.
var block_inventory: BlockInventory
## Minion slots. Each keeps its own program, cloned from the def on first use.
var roster: Array[MinionSlot] = []

const _ROSTER_SIZE := 4
const _SEED_RAM: Array[int] = [8, 12, 16, 10]


func change_stage(stage: Node) -> void:
	current_stage = stage


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
	get_tree().reload_current_scene()
	# get_tree().change_scene_to_file(MAP_SCENE)


func delete_save() -> void:
	_clear_raid_request()
	SaveManager.delete_slot(MAP_SAVE_SLOT)
	if world_map != null:
		world_map.reset_locations()


func _clear_raid_request() -> void:
	raid_target_id = ""
	pending_raid_damage = 0.0


func resource_icon_id(resource_type: ResourceType) -> String:
	match resource_type:
		ResourceType.CORPSE:
			return "tex_resource_corpse"
		ResourceType.BONE:
			return "tex_resource_bone"
		ResourceType.WEAPON:
			return "tex_resource_weapon"
		ResourceType.COLLAR:
			return "tex_resource_collar"
		_:
			return ""


func get_resource(resource_type: ResourceType) -> int:
	match resource_type:
		ResourceType.CORPSE:
			return corpse
		ResourceType.BONE:
			return bone
		ResourceType.WEAPON:
			return weapon
		ResourceType.COLLAR:
			return collar
		_:
			return 0


func change_resource(resource_type: ResourceType, amount: int) -> void:
	match resource_type:
		ResourceType.CORPSE:
			corpse = max(0, corpse + amount)
		ResourceType.BONE:
			bone = max(0, bone + amount)
		ResourceType.WEAPON:
			weapon = max(0, weapon + amount)
		ResourceType.COLLAR:
			collar = max(0, collar + amount)
			
	resource_changed.emit()


func _ready() -> void:
	block_inventory = BlockInventory.new()
	block_inventory.seed_if_empty()
	_seed_roster_if_empty()


func _seed_roster_if_empty() -> void:
	if not roster.is_empty():
		return
	for index in _ROSTER_SIZE:
		var def := UnitDef.new()
		def.id = StringName("minion_%d" % (index + 1))
		def.name = "Minion %d" % (index + 1)
		def.team = Unit2D.Team.MINION
		def.ram = _SEED_RAM[index]
		var events: Array[EventGraph.Event] = []
		events.append(EventGraph.Event.ON_UPDATE)
		def.allowed_events = events
		def.starting_program = MinionSlot.blank_program()
		var slot := MinionSlot.new()
		slot.def = def
		roster.append(slot)