extends Node2D

const _Overlay := preload("res://systems/battle/unit_debug_overlay.gd")
const _DebugMenu := preload("res://systems/battle/battle_debug_menu.gd")
const _UNIT_SCENE := preload("res://systems/units/unit.tscn")

const _BLOCK_ATTACK_RANGE := "res://data/blocks/enemy_in_attack_range.tres"
const _BLOCK_DETECT_RANGE := "res://data/blocks/enemy_in_detect_range.tres"
const _BLOCK_ATTACK := "res://data/blocks/attack_target.tres"
const _BLOCK_MOVE := "res://data/blocks/move_to_target.tres"
const _BLOCK_AWAY := "res://data/blocks/move_away_from_target.tres"
const _BLOCK_WANDER := "res://data/blocks/wander.tres"
const _BLOCK_STAND := "res://data/blocks/stand_still.tres"

const _MINION_CELLS: Array[Vector2i] = [Vector2i(-4, -2), Vector2i(-4, 0), Vector2i(-4, 2)]
const _MINION_CPU: Array[float] = [0.5, 1.0, 2.0]
const _MINION_NAMES: Array[String] = ["Minion Slow", "Minion Normal", "Minion Fast"]
const _VILLAGER_CELLS: Array[Vector2i] = [Vector2i(2, -2), Vector2i(2, 0), Vector2i(2, 2)]
const _FLEE_CELLS: Array[Vector2i] = [Vector2i(6, -2), Vector2i(6, 0), Vector2i(6, 2)]

var _debug_visible := true
var _hunt_program: UnitProgram
var _stand_program: UnitProgram
var _flee_program: UnitProgram
var _spawn_serial := 0


func _enter_tree() -> void:
	var map := $TileMaps/Map as TileMapLayer
	var template := $Unit as Unit2D
	_hunt_program = _build_demo_program()
	_stand_program = _build_stand_program()
	_flee_program = _build_flee_program()
	var hunt := _hunt_program
	var dummy := _stand_program

	# Duplicate the clean scene instance first. A child added before duplicate()
	# is dropped, and the copy reports a missing node.
	var minions: Array[Unit2D] = [template]
	for index in range(1, _MINION_CELLS.size()):
		minions.append(template.duplicate() as Unit2D)
	var villagers: Array[Unit2D] = []
	for index in _VILLAGER_CELLS.size():
		villagers.append(template.duplicate() as Unit2D)
	var fleers: Array[Unit2D] = []
	for index in _FLEE_CELLS.size():
		fleers.append(template.duplicate() as Unit2D)

	for index in minions.size():
		_setup_unit(minions[index], _MINION_NAMES[index], Unit2D.Team.MINION, hunt, _MINION_CPU[index], map.map_to_local(_MINION_CELLS[index]), Color(0.65, 0.95, 0.65))
		if minions[index] != template:
			add_child.call_deferred(minions[index])
	for index in villagers.size():
		_setup_unit(villagers[index], "Villager %d" % (index + 1), Unit2D.Team.VILLAGER, dummy, 1.0, map.map_to_local(_VILLAGER_CELLS[index]), Color(1.0, 0.82, 0.65))
		add_child.call_deferred(villagers[index])
	for index in fleers.size():
		_setup_unit(fleers[index], "Villager Flee %d" % (index + 1), Unit2D.Team.VILLAGER, _flee_program, 1.0, map.map_to_local(_FLEE_CELLS[index]), Color(0.7, 0.85, 1.0))
		add_child.call_deferred(fleers[index])


func _ready() -> void:
	var menu := _DebugMenu.new()
	menu.name = "BattleDebugMenu"
	$UI.add_child(menu)


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


func delete_selected_unit() -> void:
	var director := $FocusDirector as FocusDirector
	if director == null:
		return
	var unit := director.get_selected_unit()
	if unit == null:
		return
	director.clear_selection()
	unit.queue_free()


func spawn_minion() -> Unit2D:
	_spawn_serial += 1
	return _spawn_unit("Minion %d" % _spawn_serial, Unit2D.Team.MINION, _hunt_program, 1.0, Color(0.65, 0.95, 0.65))


func spawn_villager() -> Unit2D:
	_spawn_serial += 1
	return _spawn_unit("Villager Flee %d" % (3 + _spawn_serial), Unit2D.Team.VILLAGER, _flee_program, 1.0, Color(0.7, 0.85, 1.0))


func toggle_pause() -> bool:
	get_tree().paused = not get_tree().paused
	return get_tree().paused


func _spawn_unit(unit_name: String, team: Unit2D.Team, program: UnitProgram, cpu: float, tint: Color) -> Unit2D:
	var unit := _UNIT_SCENE.instantiate() as Unit2D
	_setup_unit(unit, unit_name, team, program, cpu, _random_walkable_position(), tint)
	add_child(unit)
	return unit


func _random_walkable_position() -> Vector2:
	var map := $TileMaps/Map as TileMapLayer
	var rect := map.get_used_rect()
	var cell := Vector2i(
		randi_range(rect.position.x, rect.position.x + rect.size.x - 1),
		randi_range(rect.position.y, rect.position.y + rect.size.y - 1)
	)
	return map.map_to_local(cell)


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
	return _program_with(brain)


## [EnemyInDetectRange] <MoveAwayFromTarget>
## otherwise <Wander>
func _build_flee_program() -> UnitProgram:
	var flee_rule := ProgramRule.new()
	var flee_conditions: Array[ConditionBlock] = []
	flee_conditions.append(_condition(_BLOCK_DETECT_RANGE))
	flee_rule.conditions = flee_conditions
	flee_rule.action = _action(_BLOCK_AWAY)

	var wander_rule := ProgramRule.new()
	wander_rule.action = _action(_BLOCK_WANDER)

	var brain := UnitFunction.new()
	brain.function_name = "Flee"
	var rules: Array[ProgramRule] = []
	rules.append(flee_rule)
	rules.append(wander_rule)
	brain.rules = rules
	return _program_with(brain)


func _build_stand_program() -> UnitProgram:
	var stand_rule := ProgramRule.new()
	stand_rule.action = _action(_BLOCK_STAND)

	var brain := UnitFunction.new()
	brain.function_name = "Dummy"
	var rules: Array[ProgramRule] = []
	rules.append(stand_rule)
	brain.rules = rules
	return _program_with(brain)


func _program_with(brain: UnitFunction) -> UnitProgram:
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
