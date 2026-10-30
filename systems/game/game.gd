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
## Sandbox writes here so a test battle cannot replace the campaign save.
const SANDBOX_SAVE_SLOT := 1
const BATTLE_TEST_SCENE := "res://systems/battle/battle_test.tscn"
const DISABLED_COLOR: Color = Color.DIM_GRAY
const RESOURCE_CAP := 99
const BGM_TITLE := "bgm.title"
const BGM_MAP := "bgm.map"
const BGM_BATTLE := "bgm.battle"
const BGM_BATTLE_WIN := "bgm.battle.win"
const BGM_BATTLE_RETREAT := "bgm.battle.retreat"
const _BATTLE_SCRIPT := "res://systems/battle/battle.gd"
const _TITLE_SCENE := "res://systems/debug/debug_rooms.tscn"
const TUTORIAL_SCENE := "res://systems/tutorial/tutorial.tscn"

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
## Race values the player may put on a spell. Zombie is always included.
var unlocked_races: Array[int] = []
## Minions summoned in camp or battle. Snapshots, not the live spells.
var army: Array[ArmyMember] = []
## False until the map save has been read once this session.
var _army_loaded := false
## The boot cutscene plays once, before the title menu.
var opening_played := false
## Slot used by load_map_state and save_map_state. The campaign stays on slot 0.
var save_slot := MAP_SAVE_SLOT
var _sandbox_open := false
var _campaign_hold: Dictionary = {}
## Set when the guided battle is finished or skipped, and stored on the map save.
var tutorial_done := false
## True while a win or retreat sting should hand back to the battle bed.
var _resume_battle_bed := false

const _Summoner := preload("res://systems/game/summoner.gd")

const _SPELL_COUNT := 8
const _SEED_RAM: Array[int] = [8, 12, 16, 10, 8, 14, 12, 9]


func _ready() -> void:
	block_inventory = BlockInventory.new()
	block_inventory.seed_if_empty()
	_seed_spells_if_empty()
	_seed_unlocked_races()
	get_tree().scene_changed.connect(_on_scene_changed)
	Audio.music_finished.connect(_on_music_finished)
	play_bgm(BGM_TITLE)


## Looping bed for a stage. One-shot stingers pass [param loop] as false and return the clip length.
func play_bgm(key: String, loop: bool = true) -> float:
	var stream := Assets.fetch(key) as AudioStream
	if stream == null:
		push_warning("Game: missing bgm '%s'" % key)
		return 0.0
	Audio.play_music(stream, loop)
	return stream.get_length()


## One-shot win or retreat clip. When it ends, the battle bed plays until the stage changes.
func play_battle_sting(key: String) -> void:
	_resume_battle_bed = true
	if play_bgm(key, false) <= 0.0:
		_resume_battle_bed = false
		if _is_battle_stage(current_stage):
			play_bgm(BGM_BATTLE)


func _on_music_finished() -> void:
	if not _resume_battle_bed:
		return
	_resume_battle_bed = false
	if _is_battle_stage(current_stage):
		play_bgm(BGM_BATTLE)


func change_stage(stage: Node) -> void:
	current_stage = stage
	_resume_battle_bed = false
	if stage is WorldMap:
		play_bgm(BGM_MAP)
	elif _is_battle_stage(stage):
		play_bgm(BGM_BATTLE)


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == _TITLE_SCENE:
		play_bgm(BGM_TITLE)


func _is_battle_stage(stage: Node) -> bool:
	var script := stage.get_script() as Script
	return script != null and script.resource_path == _BATTLE_SCRIPT


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
	if SaveManager.has_slot(save_slot):
		SaveManager.load_slot(save_slot)

	if is_instance_valid(world_map):
		world_map.refresh_locations()

	if not _army_loaded:
		var meta := SaveManager.get_slot_metadata(save_slot)
		_replace_army(_Summoner.army_from_data(meta.get("army", [])))
		if SaveManager.has_slot(save_slot):
			apply_saved_progress(meta)
			if save_slot == SANDBOX_SAVE_SLOT:
				_apply_wallet(meta.get("wallet", []))
		_army_loaded = true
	else:
		_write_army()

	_apply_pending_raid_damage()


func save_map_state() -> void:
	_write_army()
	SaveManager.save_slot(save_slot)


func _write_army() -> void:
	SaveManager.set_metadata_value("army", _Summoner.army_to_data(army))
	SaveManager.set_metadata_value("unlocked_races", unlocked_races.duplicate())
	SaveManager.set_metadata_value("spells", _spell_specs_to_data())
	SaveManager.set_metadata_value("tutorial_done", tutorial_done)
	if save_slot == SANDBOX_SAVE_SLOT:
		SaveManager.set_metadata_value("wallet", [corpse, bone, weapon, collar, gore])


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
	_seed_unlocked_races()
	_reset_spell_specs()
	SaveManager.delete_slot(MAP_SAVE_SLOT)
	get_tree().reload_current_scene()
	# get_tree().change_scene_to_file(MAP_SCENE)


func delete_save() -> void:
	_clear_raid_request()
	army.clear()
	_army_loaded = true
	_seed_unlocked_races()
	_reset_spell_specs()
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


func is_race_unlocked(race: Unit2D.Race) -> bool:
	return unlocked_races.has(int(race))


func can_afford(costs: Array) -> bool:
	for entry in costs:
		var cost := entry as SummonCost
		if cost == null:
			continue
		var kind: ResourceType = int(cost.resource_type)
		if get_resource(kind) < maxi(cost.amount, 0):
			return false
	return true


## Pays every line, or pays nothing. Each spent line emits resource_changed.
func spend(costs: Array) -> bool:
	if not can_afford(costs):
		return false
	for entry in costs:
		var cost := entry as SummonCost
		if cost == null or cost.amount <= 0:
			continue
		var kind: ResourceType = int(cost.resource_type)
		change_resource(kind, -cost.amount)
	return true


## Unlocks one race for every spell. A price that cannot be paid leaves the wallet alone.
func try_unlock_race(race: Unit2D.Race) -> bool:
	if is_race_unlocked(race):
		return true
	var profile := RaceProfiles.get_profile(race)
	if profile == null:
		return false
	if not spend(profile.unlock_costs):
		return false
	unlocked_races.append(int(race))
	Sfx.play("general.magic_cast")
	resource_changed.emit()
	_write_army()
	if is_instance_valid(world_map):
		save_map_state()
	return true


## Spell specs and unlocks, in the same shape stored on the map save.
func capture_progress() -> Dictionary:
	return {
		"unlocked_races": unlocked_races.duplicate(),
		"spells": _spell_specs_to_data(),
	}


## Missing keys are an old save: only zombie is unlocked, and every spec returns to zombie.
func apply_saved_progress(meta: Dictionary) -> void:
	if meta.has("unlocked_races"):
		_set_unlocked(meta.get("unlocked_races"))
	else:
		_seed_unlocked_races()
	if meta.has("spells"):
		_apply_spell_specs(meta.get("spells"))
	else:
		_reset_spell_specs()
	tutorial_done = bool(meta.get("tutorial_done", false))


func change_resource(resource_type: ResourceType, amount: int) -> void:
	match resource_type:
		ResourceType.CORPSE:
			corpse = _capped(corpse + amount)
		ResourceType.BONE:
			bone = _capped(bone + amount)
		ResourceType.WEAPON:
			weapon = _capped(weapon + amount)
		ResourceType.COLLAR:
			collar = _capped(collar + amount)
		ResourceType.GORE:
			gore = _capped(gore + amount)
	resource_changed.emit()


func _capped(value: int) -> int:
	return clampi(value, 0, RESOURCE_CAP)


## Keeps the campaign in memory, then loads or starts the sandbox slot.
func enter_sandbox() -> void:
	if not _sandbox_open:
		_campaign_hold = _capture_session()
		_sandbox_open = true
	save_slot = SANDBOX_SAVE_SLOT
	_army_loaded = false
	if SaveManager.has_slot(SANDBOX_SAVE_SLOT):
		load_map_state()
	else:
		_seed_new_game_state()
		tutorial_done = true
		_army_loaded = true
	if block_inventory:
		block_inventory.fill_starter()
	get_tree().change_scene_to_file(BATTLE_TEST_SCENE)


## Writes the sandbox slot, puts the campaign back, and returns to the title.
func leave_sandbox() -> void:
	if get_tree().paused:
		get_tree().paused = false
	if _sandbox_open:
		save_map_state()
		save_slot = MAP_SAVE_SLOT
		_restore_session(_campaign_hold)
		_campaign_hold = {}
		_sandbox_open = false
	get_tree().change_scene_to_file(_TITLE_SCENE)


func _capture_session() -> Dictionary:
	return {
		"specs": _spell_specs_to_data(),
		"army": _Summoner.army_to_data(army),
		"races": unlocked_races.duplicate(),
		"tutorial_done": tutorial_done,
		"army_loaded": _army_loaded,
		"wallet": [corpse, bone, weapon, collar, gore],
		"blocks": _block_counts(),
	}


func _restore_session(hold: Dictionary) -> void:
	if hold.is_empty():
		return
	var wallet: Variant = hold.get("wallet", [])
	_apply_wallet(wallet)
	_set_unlocked(hold.get("races", []))
	tutorial_done = bool(hold.get("tutorial_done", false))
	_apply_spell_specs(hold.get("specs", []))
	_replace_army(_Summoner.army_from_data(hold.get("army", [])))
	_apply_block_counts(hold.get("blocks", {}))
	_army_loaded = bool(hold.get("army_loaded", false))


func _apply_wallet(raw: Variant) -> void:
	if raw is not Array or raw.size() < 5:
		return
	set_wallet(int(raw[0]), int(raw[1]), int(raw[2]), int(raw[3]), int(raw[4]))


func _block_counts() -> Dictionary:
	var counts := {}
	if block_inventory == null:
		return counts
	for block in block_inventory.get_all():
		if block == null or block.resource_path.is_empty():
			continue
		counts[block.resource_path] = block_inventory.get_count(block)
	return counts


func _apply_block_counts(counts: Variant) -> void:
	if block_inventory == null or counts is not Dictionary:
		return
	block_inventory.clear_counts()
	for path in counts.keys():
		var amount := int(counts[path])
		if amount <= 0:
			continue
		var block := load(str(path)) as CodeBlock
		if block:
			block_inventory.add(block, amount)


## Opens the tutorial until it has been finished or skipped, then the world map.
func begin_play() -> void:
	var meta := SaveManager.get_slot_metadata(MAP_SAVE_SLOT)
	tutorial_done = bool(meta.get("tutorial_done", tutorial_done))
	var next := MAP_SCENE if tutorial_done else TUTORIAL_SCENE
	get_tree().change_scene_to_file(next)


## Skip and the tutorial's Back button both come through here.
## [param travel] stays false in tests that only need the saved starting state.
func finish_tutorial(travel: bool = true) -> void:
	tutorial_done = true
	_seed_new_game_state()
	_army_loaded = true
	if get_tree().paused:
		get_tree().paused = false
	_write_army()
	_save_tutorial_result()
	if travel:
		get_tree().change_scene_to_file(MAP_SCENE)


func skip_tutorial(travel: bool = true) -> void:
	finish_tutorial(travel)


func set_wallet(next_corpse: int, next_bone: int, next_weapon: int, next_collar: int, next_gore: int) -> void:
	corpse = _capped(next_corpse)
	bone = _capped(next_bone)
	weapon = _capped(next_weapon)
	collar = _capped(next_collar)
	gore = _capped(next_gore)
	resource_changed.emit()


## Writes the seeded army and tutorial flag without replacing town data.
## The battle scene has no town participants, so a normal save would blank the map.
func _save_tutorial_result() -> void:
	var path := "user://saves/slot_%d.json" % MAP_SAVE_SLOT
	var payload := {
		"meta": {},
		"data": {},
		"runtime_instances": [],
	}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			payload = parsed
	var meta: Dictionary = payload.get("meta", {})
	meta["tutorial_done"] = tutorial_done
	meta["army"] = _Summoner.army_to_data(army)
	meta["unlocked_races"] = unlocked_races.duplicate()
	meta["spells"] = _spell_specs_to_data()
	meta["slot_id"] = MAP_SAVE_SLOT
	meta["saved_at_unix"] = Time.get_unix_time_from_system()
	payload["meta"] = meta
	if not payload.has("data"):
		payload["data"] = {}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Game: could not write the tutorial result")
		return
	file.store_string(JSON.stringify(payload, "\t"))


func _seed_new_game_state() -> void:
	_clear_raid_request()
	army.clear()
	set_wallet(0, 0, 0, 0, 0)
	if block_inventory == null:
		block_inventory = BlockInventory.new()
	block_inventory.fill_starter()
	_seed_unlocked_races()
	for index in spells.size():
		var spell := spells[index]
		spell.base_ram = _SEED_RAM[index] if index < _SEED_RAM.size() else 8
		spell.race = Unit2D.Race.ZOMBIE
		spell.corpse_amount = 1
		spell.gore_amount = 1
		spell.program = SummonSpell.blank_program()
		if spell.def != null:
			spell.def.starting_program = spell.program
		spell.build_def()


func _seed_spells_if_empty() -> void:
	if not spells.is_empty():
		return
	for index in _SPELL_COUNT:
		var def := UnitDef.new()
		def.id = StringName("spell_%d" % (index + 1))
		def.team = Unit2D.Team.MINION
		var events: Array[EventGraph.Event] = []
		events.append(EventGraph.Event.ON_UPDATE)
		def.allowed_events = events
		def.starting_program = SummonSpell.blank_program()
		var spell := SummonSpell.new()
		spell.def = def
		spell.base_ram = _SEED_RAM[index]
		spell.race = Unit2D.Race.ZOMBIE
		spell.corpse_amount = 1
		spell.gore_amount = 1
		spell.build_def()
		spells.append(spell)


func _seed_unlocked_races() -> void:
	unlocked_races.clear()
	for profile in RaceProfiles.all():
		if profile.starts_unlocked:
			unlocked_races.append(int(profile.race))
	if not is_race_unlocked(Unit2D.Race.ZOMBIE):
		unlocked_races.append(int(Unit2D.Race.ZOMBIE))


func _reset_spell_specs() -> void:
	for spell in spells:
		spell.race = Unit2D.Race.ZOMBIE
		spell.corpse_amount = 1
		spell.gore_amount = 1
		spell.build_def()


func _spell_specs_to_data() -> Array:
	var rows: Array = []
	for spell in spells:
		rows.append({
			"race": int(spell.race),
			"corpse_amount": spell.corpse_amount,
			"gore_amount": spell.gore_amount,
			"functions": _Summoner._functions_to_data(spell.get_program()),
		})
	return rows


func _set_unlocked(raw: Variant) -> void:
	unlocked_races.clear()
	if raw is Array:
		for entry in raw:
			var race_value := int(entry)
			if race_value < 0 or race_value >= Unit2D.Race.size():
				continue
			if not unlocked_races.has(race_value):
				unlocked_races.append(race_value)
	if not is_race_unlocked(Unit2D.Race.ZOMBIE):
		unlocked_races.append(int(Unit2D.Race.ZOMBIE))


func _apply_spell_specs(raw: Variant) -> void:
	if raw is not Array:
		_reset_spell_specs()
		return
	for index in spells.size():
		var spell := spells[index]
		if index >= raw.size() or raw[index] is not Dictionary:
			spell.race = Unit2D.Race.ZOMBIE
			spell.corpse_amount = 1
			spell.gore_amount = 1
			spell.build_def()
			continue
		var row: Dictionary = raw[index]
		var race_value := int(row.get("race", int(Unit2D.Race.ZOMBIE)))
		var race := Unit2D.Race.ZOMBIE
		if race_value >= 0 and race_value < Unit2D.Race.size():
			var picked: Unit2D.Race = race_value
			race = picked
		if not is_race_unlocked(race):
			race = Unit2D.Race.ZOMBIE
		spell.race = race
		spell.corpse_amount = int(row.get("corpse_amount", 1))
		spell.gore_amount = int(row.get("gore_amount", 1))
		if row.has("functions"):
			spell.program = _Summoner._program_from_data(row.get("functions"))
		spell.build_def()