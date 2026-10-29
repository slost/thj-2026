## Shared summon rules for camp and battle.
## A summoned unit keeps its own definition and a deep copy of the spell's program.
extends RefCounted


const _UNIT_SCENE := preload("res://systems/units/unit.tscn")


static func can_afford(_spell: SummonSpell) -> bool:
	return _spell != null


static func deny_reason(_spell: SummonSpell) -> String:
	return LocaleText.resolve("ui.summon.not_enough_corpses", "Not enough corpses")


## Rows of {type: Game.ResourceType, amount: int}. Empty until a spell has a cost.
static func cost_entries(_spell: SummonSpell) -> Array:
	return []


static func summon(spell: SummonSpell, scene_root: Node, world_pos: Vector2) -> Unit2D:
	if spell == null or scene_root == null or not can_afford(spell):
		return null
	return spawn_def(copy_def(spell), scene_root, world_pos, -1)


## Stats copied off the spell, plus a program the spell can no longer edit.
static func copy_def(spell: SummonSpell) -> UnitDef:
	var def := UnitDef.new()
	var source := spell.def
	if source != null:
		def.id = source.id
		def.name = source.name
		def.description = source.description
		def.team = source.team
		def.max_hp = source.max_hp
		def.speed = source.speed
		def.damage = source.damage
		def.detect_range = source.detect_range
		def.attack_range = source.attack_range
		def.attack_cooldown = source.attack_cooldown
		def.cpu = source.cpu
		def.gpu = source.gpu
		def.ram = source.ram
		def.mb = source.mb
		var events: Array[EventGraph.Event] = []
		for event in source.allowed_events:
			events.append(event)
		def.allowed_events = events
	else:
		def.team = Unit2D.Team.MINION
		def.name = spell.display_name()
	def.starting_program = spell.get_program().clone()
	return def


static func spawn_def(def: UnitDef, scene_root: Node, world_pos: Vector2, hp: int) -> Unit2D:
	var unit := _UNIT_SCENE.instantiate() as Unit2D
	if unit == null or def == null:
		return null
	unit.def = def
	unit.position = scene_root.to_local(world_pos) if scene_root is Node2D else world_pos
	scene_root.add_child(unit)
	if hp >= 0:
		_set_hp(unit, hp)
	return unit


static func _set_hp(unit: Unit2D, hp: int) -> void:
	var maximum := hp
	if unit.stats:
		maximum = maxi(unit.stats.max_hp, 1)
	var clamped := clampi(hp, 1, maximum)
	if unit.health:
		unit.health.current_health = float(clamped)
	if unit.stats:
		unit.stats.hp = clamped
