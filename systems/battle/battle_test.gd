extends Node2D

const _Overlay := preload("res://systems/battle/unit_debug_overlay.gd")

const _BLOCK_ATTACK_RANGE := "res://data/blocks/enemy_in_attack_range.tres"
const _BLOCK_DETECT_RANGE := "res://data/blocks/enemy_in_detect_range.tres"
const _BLOCK_ATTACK := "res://data/blocks/attack_target.tres"
const _BLOCK_MOVE := "res://data/blocks/move_to_target.tres"
const _BLOCK_WANDER := "res://data/blocks/wander.tres"
const _BLOCK_STAND := "res://data/blocks/stand_still.tres"

const _MINION_CELLS: Array[Vector2i] = [Vector2i(-4, -2), Vector2i(-4, 0), Vector2i(-4, 2)]
const _MINION_CPU: Array[float] = [0.5, 1.0, 2.0]
const _MINION_NAMES: Array[String] = ["Minion Slow", "Minion Normal", "Minion Fast"]
const _VILLAGER_CELLS: Array[Vector2i] = [Vector2i(2, -2), Vector2i(2, 0), Vector2i(2, 2)]

var _debug_visible := true


func _enter_tree() -> void:
	var map := $TileMaps/Map as TileMapLayer
	var template := $Unit as Unit2D
	var hunt := _build_demo_program()
	var dummy := _build_stand_program()

	# Duplicate the clean scene instance first. A child added before duplicate()
	# is dropped, and the copy reports a missing node.
	var minions: Array[Unit2D] = [template]
	for index in range(1, _MINION_CELLS.size()):
		minions.append(template.duplicate() as Unit2D)
	var villagers: Array[Unit2D] = []
	for index in _VILLAGER_CELLS.size():
		villagers.append(template.duplicate() as Unit2D)

	for index in minions.size():
		_setup_unit(minions[index], _MINION_NAMES[index], Unit2D.Team.MINION, hunt, _MINION_CPU[index], map.map_to_local(_MINION_CELLS[index]), Color(0.65, 0.95, 0.65))
		if minions[index] != template:
			add_child.call_deferred(minions[index])
	for index in villagers.size():
		_setup_unit(villagers[index], "Villager %d" % (index + 1), Unit2D.Team.VILLAGER, dummy, 1.0, map.map_to_local(_VILLAGER_CELLS[index]), Color(1.0, 0.82, 0.65))
		add_child.call_deferred(villagers[index])


func _setup_unit(unit: Unit2D, unit_name: String, team: Unit2D.Team, program: UnitProgram, cpu: float, pos: Vector2, tint: Color) -> void:
	unit.name = unit_name
	unit.def = _build_def(team, program, cpu)
	unit.position = pos
	unit.modulate = tint
	var overlay := _Overlay.new()
	overlay.name = "DebugOverlay"
	unit.add_child(overlay)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_F1:
			set_debug_overlay_visible(not _debug_visible)
			get_viewport().set_input_as_handled()


func set_debug_overlay_visible(shown: bool) -> void:
	_debug_visible = shown
	get_tree().call_group(UnitDebugOverlay.GROUP, &"set_overlay_visible", shown)


func _build_def(team: Unit2D.Team, program: UnitProgram, cpu: float) -> UnitDef:
	var def := UnitDef.new()
	def.team = team
	def.speed = 160.0
	def.detect_range = 8
	def.cpu = cpu
	def.starting_program = program
	var events: Array[EventGraph.Event] = []
	events.append(EventGraph.Event.ON_SPAWN)
	events.append(EventGraph.Event.ON_UPDATE)
	events.append(EventGraph.Event.ON_HIT)
	events.append(EventGraph.Event.ON_ALLY_DIED)
	events.append(EventGraph.Event.ON_DEATH)
	def.allowed_events = events
	return def


## [EnemyInAttackRange] <AttackTarget>
## [EnemyInDetectRange] <MoveToTarget>
## otherwise <Wander>
func _build_demo_program() -> UnitProgram:
	var attack_rule := ProgramRule.new()
	var attack_conditions: Array[ConditionBlock] = []
	attack_conditions.append(_condition(_BLOCK_ATTACK_RANGE))
	attack_rule.conditions = attack_conditions
	attack_rule.action = _action(_BLOCK_ATTACK)

	var move_rule := ProgramRule.new()
	var move_conditions: Array[ConditionBlock] = []
	move_conditions.append(_condition(_BLOCK_DETECT_RANGE))
	move_rule.conditions = move_conditions
	move_rule.action = _action(_BLOCK_MOVE)

	var wander_rule := ProgramRule.new()
	wander_rule.action = _action(_BLOCK_WANDER)

	var brain := UnitFunction.new()
	brain.function_name = "Hunt"
	var rules: Array[ProgramRule] = []
	rules.append(attack_rule)
	rules.append(move_rule)
	rules.append(wander_rule)
	brain.rules = rules

	var graph := EventGraph.new()
	graph.connect_function(EventGraph.Event.ON_UPDATE, brain)

	var program := UnitProgram.new()
	program.event_graph = graph
	var functions: Array[UnitFunction] = []
	functions.append(brain)
	program.functions = functions
	return program


func _build_stand_program() -> UnitProgram:
	var stand_rule := ProgramRule.new()
	stand_rule.action = _action(_BLOCK_STAND)

	var brain := UnitFunction.new()
	brain.function_name = "Dummy"
	var rules: Array[ProgramRule] = []
	rules.append(stand_rule)
	brain.rules = rules

	var graph := EventGraph.new()
	graph.connect_function(EventGraph.Event.ON_UPDATE, brain)

	var program := UnitProgram.new()
	program.event_graph = graph
	var functions: Array[UnitFunction] = []
	functions.append(brain)
	program.functions = functions
	return program


func _condition(path: String) -> ConditionBlock:
	var block := load(path) as ConditionBlock
	if block == null:
		push_error("Missing condition block: %s" % path)
	return block


func _action(path: String) -> ActionBlock:
	var block := load(path) as ActionBlock
	if block == null:
		push_error("Missing action block: %s" % path)
	return block
