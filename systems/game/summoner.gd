## Shared summon rules for camp and battle.
## A summoned unit keeps its own definition and a deep copy of the spell's program.
extends RefCounted


const _UNIT_SCENE := preload("res://systems/units/unit.tscn")
const _BLOCK_DIR := "res://data/blocks/%s.tres"


static func can_afford(spell: SummonSpell) -> bool:
	if spell == null:
		return false
	for entry in spell.get_costs():
		if entry == null:
			continue
		if _held(entry.resource_type) < maxi(entry.amount, 0):
			return false
	return true


static func deny_reason(spell: SummonSpell) -> String:
	var missing := _missing_cost(spell)
	if missing == null or missing.resource_type == int(Game.ResourceType.CORPSE):
		return LocaleText.resolve("ui.summon.not_enough_corpses", "Not enough corpses")
	var names := PackedStringArray(Game.ResourceType.keys())
	var label := names[missing.resource_type].to_lower()
	var pattern := LocaleText.resolve("ui.summon.not_enough", "Not enough {resource}")
	return pattern.format({"resource": label})


## Rows of {type: Game.ResourceType, amount: int}.
static func cost_entries(spell: SummonSpell) -> Array:
	var rows: Array = []
	if spell == null:
		return rows
	for entry in spell.get_costs():
		if entry == null or entry.amount <= 0:
			continue
		rows.append({"type": entry.resource_type, "amount": entry.amount})
	return rows


static func summon(spell: SummonSpell, scene_root: Node, world_pos: Vector2) -> Unit2D:
	if spell == null or scene_root == null or not can_afford(spell):
		return null
	_spend(spell)
	var member := ArmyMember.new()
	member.def = copy_def(spell)
	member.hp = maxi(member.def.max_hp, 1)
	member.paid = _copy_paid(cost_entries(spell))
	member.spell_slot = Game.spells.find(spell)
	Game.army.append(member)
	var unit := spawn_member(member, scene_root, world_pos)
	if unit != null:
		Sfx.play("general.magic_cast")
		Sfx.play_summon_laugh()
	return unit


## Stats copied off the spell, plus a program the spell can no longer edit.
static func copy_def(spell: SummonSpell) -> UnitDef:
	var def := UnitDef.new()
	var source := spell.def
	if source != null:
		def.id = source.id
		def.name = source.name
		def.description = source.description
		def.team = source.team
		def.race = source.race
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
	def.starting_program = _owned_program(spell.get_program())
	return def


static func spawn_member(member: ArmyMember, scene_root: Node, world_pos: Vector2) -> Unit2D:
	if member == null or scene_root == null or member.def == null:
		return null
	if member.unit != null and is_instance_valid(member.unit):
		return member.unit
	var unit := spawn_def(member.def, scene_root, world_pos, member.hp)
	member.unit = unit
	if unit != null:
		unit.summon_paid = _copy_paid(member.paid)
		unit.spell_slot = member.spell_slot
	return unit


## Drops the dead and remembers survivor HP. Scene changes free the bodies.
static func stash_army() -> void:
	var kept: Array[ArmyMember] = []
	for member in Game.army:
		if member == null:
			continue
		var unit := member.unit
		if unit != null and is_instance_valid(unit):
			if _is_dead(unit):
				member.unit = null
				continue
			member.hp = _read_hp(unit)
		member.unit = null
		kept.append(member)
	Game.army = kept


static func spawn_army_at(camp: Node) -> void:
	if camp == null:
		return
	var pending: Array[ArmyMember] = []
	for member in Game.army:
		if member == null:
			continue
		if member.unit != null and is_instance_valid(member.unit) and not _is_dead(member.unit):
			continue
		if member.unit != null and is_instance_valid(member.unit) and _is_dead(member.unit):
			continue
		pending.append(member)
	var points: Array = []
	if camp.has_method("muster_points"):
		var mustered: Variant = camp.call("muster_points", pending.size())
		if mustered is Array:
			points = mustered
	for index in pending.size():
		var pos := Vector2.ZERO
		if index < points.size():
			pos = points[index]
		spawn_member(pending[index], camp, pos)


static func army_to_data(members: Array) -> Array:
	var rows: Array = []
	for entry in members:
		var member := entry as ArmyMember
		if member == null or member.def == null:
			continue
		rows.append({
			"hp": member.hp,
			"def": _def_to_data(member.def),
			"paid": _copy_paid(member.paid),
			"spell_slot": member.spell_slot,
		})
	return rows


static func army_from_data(raw: Variant) -> Array:
	var loaded: Array = []
	if raw is not Array:
		return loaded
	for entry in raw:
		if entry is not Dictionary:
			continue
		var def := _def_from_data(entry.get("def", {}))
		if def == null:
			continue
		var member := ArmyMember.new()
		member.def = def
		member.hp = int(entry.get("hp", def.max_hp))
		member.paid = _copy_paid(entry.get("paid", []))
		member.spell_slot = int(entry.get("spell_slot", -1))
		loaded.append(member)
	return loaded


## Units share one y-sorted parent so closer bodies draw in front.
static func unit_container(scene_root: Node) -> Node:
	var holder := scene_root.get_node_or_null("Units") as Node2D
	if holder == null:
		holder = Node2D.new()
		holder.name = "Units"
		holder.y_sort_enabled = true
		scene_root.add_child(holder)
	holder.y_sort_enabled = true
	return holder


static func spawn_def(def: UnitDef, scene_root: Node, world_pos: Vector2, hp: int) -> Unit2D:
	var unit := _UNIT_SCENE.instantiate() as Unit2D
	if unit == null or def == null:
		return null
	unit.def = def
	var holder := unit_container(scene_root)
	holder.add_child(unit)
	if scene_root is Node2D:
		unit.global_position = world_pos
	if hp >= 0:
		_set_hp(unit, hp)
	return unit


static func _spend(spell: SummonSpell) -> void:
	for entry in spell.get_costs():
		if entry == null or entry.amount <= 0:
			continue
		Game.change_resource(_kind(entry.resource_type), -entry.amount)


## Return half the pieces, chosen at random, then forget the bill so it cannot pay twice.
static func refund_unit(unit: Unit2D) -> void:
	if unit == null:
		return
	var member := _member_for(unit)
	var paid: Array = member.paid if member != null else unit.summon_paid
	_grant_half(paid)
	if member != null:
		member.paid = []
	unit.summon_paid = []


static func refund_member(member: ArmyMember) -> void:
	if member == null:
		return
	_grant_half(member.paid)
	member.paid = []
	if member.unit != null and is_instance_valid(member.unit):
		member.unit.summon_paid = []


static func _member_for(unit: Unit2D) -> ArmyMember:
	for member in Game.army:
		if member != null and member.unit == unit:
			return member
	return null


static func _copy_paid(source: Variant) -> Array:
	var copy: Array = []
	if source is not Array:
		return copy
	for entry in source:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var amount := int(entry.get("amount", 0))
		if amount <= 0:
			continue
		copy.append({"type": int(entry.get("type", 0)), "amount": amount})
	return copy


static func _grant_half(paid: Array) -> void:
	var pieces: Array = []
	for entry in paid:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var kind := int(entry.get("type", 0))
		for _piece in int(entry.get("amount", 0)):
			pieces.append(kind)
	var give := pieces.size() / 2
	if give <= 0:
		return
	Rng.shuffle_array(pieces)
	var totals := {}
	for index in give:
		var kind: int = pieces[index]
		totals[kind] = int(totals.get(kind, 0)) + 1
	for kind in totals.keys():
		Game.change_resource(_kind(int(kind)), int(totals[kind]))


static func _missing_cost(spell: SummonSpell) -> SummonCost:
	if spell == null:
		return null
	for entry in spell.get_costs():
		if entry != null and _held(entry.resource_type) < maxi(entry.amount, 0):
			return entry
	return null


static func _held(type_value: int) -> int:
	return Game.get_resource(_kind(type_value))


static func _kind(type_value: int) -> Game.ResourceType:
	var kind: Game.ResourceType = type_value
	return kind


static func _owned_program(source: UnitProgram) -> UnitProgram:
	if source == null:
		return SummonSpell.blank_program()
	var copy := source.clone()
	_detach_blocks(copy)
	return copy


## duplicate() can keep a .tres subresource. Each unit needs its own block instance.
static func _detach_blocks(program: UnitProgram) -> void:
	if program == null:
		return
	for fn in program.functions:
		if fn == null:
			continue
		for line in fn.lines:
			if line == null or line.block == null:
				continue
			line.block = line.block.duplicate(true) as CodeBlock


static func _set_hp(unit: Unit2D, hp: int) -> void:
	var maximum := hp
	if unit.stats:
		maximum = maxi(unit.stats.max_hp, 1)
	var clamped := clampi(hp, 1, maximum)
	if unit.health:
		unit.health.current_health = float(clamped)
	if unit.stats:
		unit.stats.hp = clamped


static func _read_hp(unit: Unit2D) -> int:
	if unit.health:
		return int(round(unit.health.get_health()))
	if unit.stats:
		return unit.stats.hp
	return 1


static func _is_dead(unit: Unit2D) -> bool:
	if unit.state == Unit2D.State.DEAD:
		return true
	if unit.health and unit.health.get_health() <= 0.0:
		return true
	return false


static func _def_to_data(def: UnitDef) -> Dictionary:
	var events: Array = []
	for event in def.allowed_events:
		events.append(int(event))
	return {
		"id": String(def.id),
		"name": def.name,
		"description": def.description,
		"team": int(def.team),
		"race": int(def.race),
		"max_hp": def.max_hp,
		"speed": def.speed,
		"damage": def.damage,
		"detect_range": def.detect_range,
		"attack_range": def.attack_range,
		"attack_cooldown": def.attack_cooldown,
		"cpu": def.cpu,
		"gpu": def.gpu,
		"ram": def.ram,
		"mb": def.mb,
		"allowed_events": events,
		"functions": _functions_to_data(def.starting_program),
	}


static func _functions_to_data(program: UnitProgram) -> Array:
	var rows: Array = []
	if program == null:
		return rows
	for fn in program.functions:
		if fn == null:
			continue
		var lines: Array = []
		for line in fn.lines:
			if line == null or line.block == null:
				continue
			lines.append({
				"indent": line.indent,
				"block": String(line.block.id),
			})
		var linked: Array = []
		if program.event_graph:
			for event in EventGraph.Event.values():
				if program.event_graph.get_functions(event).has(fn):
					linked.append(int(event))
		rows.append({
			"name": fn.function_name,
			"lines": lines,
			"events": linked,
		})
	return rows


static func _def_from_data(raw: Variant) -> UnitDef:
	if raw is not Dictionary:
		return null
	var data: Dictionary = raw
	var def := UnitDef.new()
	def.id = StringName(str(data.get("id", "")))
	def.name = str(data.get("name", ""))
	def.description = str(data.get("description", ""))
	var team: Unit2D.Team = int(data.get("team", int(Unit2D.Team.MINION)))
	def.team = team
	var race: Unit2D.Race = int(data.get("race", int(Unit2D.Race.ZOMBIE)))
	def.race = race
	def.max_hp = int(data.get("max_hp", 30))
	def.speed = float(data.get("speed", 60.0))
	def.damage = int(data.get("damage", 5))
	def.detect_range = int(data.get("detect_range", 4))
	def.attack_range = int(data.get("attack_range", 2))
	def.attack_cooldown = float(data.get("attack_cooldown", 1.0))
	def.cpu = int(data.get("cpu", 1))
	def.gpu = int(data.get("gpu", 1))
	def.ram = int(data.get("ram", 8))
	def.mb = int(data.get("mb", 1))
	var events: Array[EventGraph.Event] = []
	var stored: Variant = data.get("allowed_events", [])
	if stored is Array:
		for event in stored:
			var kind: EventGraph.Event = int(event)
			events.append(kind)
	if events.is_empty():
		events.append(EventGraph.Event.ON_UPDATE)
	def.allowed_events = events
	def.starting_program = _program_from_data(data.get("functions", []))
	return def


static func _program_from_data(raw: Variant) -> UnitProgram:
	var program := UnitProgram.new()
	var functions: Array[UnitFunction] = []
	var graph := EventGraph.new()
	graph.links = {}
	program.event_graph = graph
	if raw is Array:
		for entry in raw:
			if entry is not Dictionary:
				continue
			var fn := UnitFunction.new()
			fn.function_name = str(entry.get("name", "ON_UPDATE"))
			var lines: Array[ScriptLine] = []
			var stored_lines: Variant = entry.get("lines", [])
			if stored_lines is Array:
				for line_data in stored_lines:
					if line_data is not Dictionary:
						continue
					var block := _block_by_id(str(line_data.get("block", "")))
					if block == null:
						continue
					var line := ScriptLine.new()
					line.indent = int(line_data.get("indent", 0))
					line.block = block
					lines.append(line)
			fn.lines = lines
			functions.append(fn)
			var stored_events: Variant = entry.get("events", [])
			if stored_events is Array:
				for event in stored_events:
					var kind: EventGraph.Event = int(event)
					graph.connect_function(kind, fn)
	if functions.is_empty():
		return SummonSpell.blank_program()
	program.functions = functions
	return _owned_program(program)


static func _block_by_id(id: String) -> CodeBlock:
	if id.is_empty():
		return null
	var path := _BLOCK_DIR % id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as CodeBlock
