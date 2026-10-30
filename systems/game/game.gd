extends Node


signal resource_changed()

enum ResourceType {
	CORPSE,
	BONE,
	WEAPON,
	COLLAR,
	GORE,
}

const BATTLE_SCENE: String = "res://systems/battle/battle.tscn"
const MAP_SCENE: String = "res://systems/world_map/world_map.tscn"
const DESTROYED_RATIO: float = 0.5 # The ratio of the town's restore points to be destroyed.
const MAP_SAVE_SLOT := 0
const DISABLED_COLOR: Color = Color.DIM_GRAY

# States
var raid_target_id := "" ## Save key of the town that was raided.
## Max restore points of the raided town, copied in raid_to before the map unloads.
var raid_target_max_points := 0.0
## Roster indexes brought into the current raid. Empty until raid_to().
var raid_slots: Array[int] = []
var pending_raid_damage := 0.0 ## Applied after the map reloads its saved restore points.
## True from raid_to until the map applies that battle's outcome, even when damage is 0.
var raid_outcome_pending := false
## Villager groups copied from the town before the map unloads. Each row is a dictionary.
var raid_garrison: Array = []
## Full reward lines copied from the town. Paid by lost_ratio when the map applies the outcome.
var raid_rewards: Array = []
## Share of the town's villagers lost, stored with the outcome so rewards can be paid on the map.
var pending_raid_lost_ratio := 0.0
var current_stage: Node

# Hard-coded resources
var corpse := 0
var bone := 0
var weapon := 0
var collar := 0
var gore := 0

# Refs
var world_map: WorldMap

## Blocks the player owns. Empty on startup, then seeded from data/blocks.
var block_inventory: BlockInventory
## Summon spells. Each keeps its own program, cloned from the def on first use.
var spells: Array[SummonSpell] = []
## Minions summoned in camp or battle. Snapshots, not the live spells.
var army: Array[ArmyMember] = []
## False until the map save has been read once this session.
var _army_loaded := false

const _Summoner := preload("res://systems/game/summoner.gd")

const _SPELL_COUNT := 8
const _SEED_RAM: Array[int] = [8, 12, 16, 10, 8, 14, 12, 9]


func _ready() -> void:
	block_inventory = BlockInventory.new()
	block_inventory.seed_if_empty()
	_seed_spells_if_empty()



func change_stage(stage: Node) -> void:
	current_stage = stage


func raid_to(location: TownLocation, slots: Array[int] = []) -> void:
	raid_target_id = location.get_save_key()
	raid_target_max_points = location.def.max_restore_points if location.def != null else 0.0
	raid_garrison = location.def.garrison_snapshot() if location.def != null else []
	raid_rewards = location.def.reward_snapshot() if location.def != null else []
	pending_raid_lost_ratio = 0.0
	raid_outcome_pending = true
	raid_slots = _normalize_raid_slots(slots)
	_Summoner.stash_army()
	save_map_state()
	get_tree().change_scene_to_file(BATTLE_SCENE)


## Empty means every slot, so a caller that omits the list still brings the roster.
func _normalize_raid_slots(slots: Array[int]) -> Array[int]:
	var chosen: Array[int] = []
	var source: Array[int] = []
	if slots.is_empty():
		for index in spells.size():
			source.append(index)
	else:
		source = slots.duplicate()
	for index in source:
		if index < 0 or index >= spells.size():
			continue
		if chosen.has(index):
			continue
		chosen.append(index)
	return chosen


func back_to_map() -> void:
	_Summoner.stash_army()
	get_tree().change_scene_to_file(MAP_SCENE)


## Retreat throws the whole army away. Survivors are not kept.
func abandon_army() -> void:
	for member in army:
		if member == null:
			continue
		_Summoner.refund_member(member)
		member.unit = null
	army.clear()


func load_map_state() -> void:
	if SaveManager.has_slot(MAP_SAVE_SLOT):
		SaveManager.load_slot(MAP_SAVE_SLOT)

	if world_map != null:
		world_map.refresh_locations()

	if not _army_loaded:
		var meta := SaveManager.get_slot_metadata(MAP_SAVE_SLOT)
		_replace_army(_Summoner.army_from_data(meta.get("army", [])))
		_army_loaded = true
	else:
		_write_army()

	_apply_pending_raid_damage()


func save_map_state() -> void:
	_write_army()
	SaveManager.save_slot(MAP_SAVE_SLOT)


func _write_army() -> void:
	SaveManager.set_metadata_value("army", _Summoner.army_to_data(army))


func _replace_army(loaded: Array) -> void:
	army.clear()
	for entry in loaded:
		var member := entry as ArmyMember
		if member:
			army.append(member)


func _apply_pending_raid_damage() -> void:
	if not raid_outcome_pending and pending_raid_damage <= 0.0:
		return

	var damage := pending_raid_damage
	var finished := raid_outcome_pending
	var lost_ratio := pending_raid_lost_ratio
	var rewards: Array = raid_rewards.duplicate()
	pending_raid_damage = 0.0
	pending_raid_lost_ratio = 0.0
	raid_outcome_pending = false
	raid_garrison.clear()
	raid_rewards.clear()
	if world_map == null or raid_target_id.is_empty():
		return

	var location := world_map.find_location(raid_target_id)
	if location == null:
		push_warning("Game: saved raid target '%s' is not on the world map" % raid_target_id)
		return

	if damage > 0.0:
		world_map.deal_damage_to(location, damage)
	if finished:
		_grant_raid_rewards(rewards, lost_ratio)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		world_map.recover_other_towns(location, rng)
	save_map_state()


func restart() -> void:
	_clear_raid_request()
	army.clear()
	_army_loaded = true
	SaveManager.delete_slot(MAP_SAVE_SLOT)
	get_tree().reload_current_scene()
	# get_tree().change_scene_to_file(MAP_SCENE)


func delete_save() -> void:
	_clear_raid_request()
	army.clear()
	_army_loaded = true
	SaveManager.delete_slot(MAP_SAVE_SLOT)
	if world_map != null:
		world_map.reset_locations()


func _clear_raid_request() -> void:
	raid_target_id = ""
	raid_target_max_points = 0.0
	raid_slots.clear()
	raid_garrison.clear()
	raid_rewards.clear()
	pending_raid_damage = 0.0
	pending_raid_lost_ratio = 0.0
	raid_outcome_pending = false


func _grant_raid_rewards(rows: Array, lost_ratio: float) -> void:
	for entry in rows:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var amount := Formular.raid_reward_payout(int(entry.get("amount", 0)), lost_ratio)
		if amount <= 0:
			continue
		var kind: ResourceType = int(entry.get("resource_type", 0))
		change_resource(kind, amount)


func resource_icon_id(resource_type: ResourceType) -> String:
	match resource_type:
		ResourceType.CORPSE:
			return "tex_res_corpse"
		ResourceType.BONE:
			return "tex_res_bone"
		ResourceType.WEAPON:
			return "tex_res_weapon"
		ResourceType.COLLAR:
			return "tex_res_collar"
		ResourceType.GORE:
			return "tex_res_gore"
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
		ResourceType.GORE:
			return gore
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
		ResourceType.GORE:
			gore = max(0, gore + amount)
			
	resource_changed.emit()


func _seed_spells_if_empty() -> void:
	if not spells.is_empty():
		return
	for index in _SPELL_COUNT:
		var def := UnitDef.new()
		def.id = StringName("spell_%d" % (index + 1))
		def.name = "Spell %d" % (index + 1)
		def.team = Unit2D.Team.MINION
		def.ram = _SEED_RAM[index]
		var events: Array[EventGraph.Event] = []
		events.append(EventGraph.Event.ON_UPDATE)
		def.allowed_events = events
		def.starting_program = SummonSpell.blank_program()
		var spell := SummonSpell.new()
		spell.def = def
		var price := SummonCost.new()
		price.resource_type = ResourceType.CORPSE
		price.amount = 1
		spell.costs.append(price)
		var gore := SummonCost.new()
		gore.resource_type = ResourceType.GORE
		gore.amount = 1
		spell.costs.append(gore)
		spells.append(spell)