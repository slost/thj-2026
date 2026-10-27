extends Node2D

const _EnemyNearby := preload("res://systems/program/blocks/enemy_nearby_condition.gd")
const _InAttackRange := preload("res://systems/program/blocks/in_attack_range_condition.gd")
const _Attack := preload("res://systems/program/blocks/attack_action.gd")
const _MoveTo := preload("res://systems/program/blocks/move_to_target_action.gd")


func _enter_tree() -> void:
	var map := $TileMaps/Map as TileMapLayer
	var program := _build_hunt_program()
	var minion := $Unit as Unit2D
	var villager := minion.duplicate() as Unit2D

	minion.def = _build_def(Unit2D.Team.MINION, program)
	minion.position = map.map_to_local(Vector2i(-3, 0))
	minion.modulate = Color(0.65, 0.95, 0.65)

	villager.name = "Villager"
	villager.def = _build_def(Unit2D.Team.VILLAGER, program)
	villager.position = map.map_to_local(Vector2i(3, 0))
	villager.modulate = Color(1.0, 0.82, 0.65)
	add_child.call_deferred(villager)


func _build_def(team: Unit2D.Team, program: UnitProgram) -> UnitDef:
	var def := UnitDef.new()
	def.team = team
	def.speed = 160.0
	def.detect_range = 8
	def.starting_program = program
	var events: Array[EventGraph.Event] = []
	events.append(EventGraph.Event.ON_SPAWN)
	events.append(EventGraph.Event.ON_UPDATE)
	events.append(EventGraph.Event.ON_HIT)
	events.append(EventGraph.Event.ON_ALLY_DIED)
	events.append(EventGraph.Event.ON_DEATH)
	def.allowed_events = events
	return def


## [enemy nearby] [in attack range] <attack>
## [enemy nearby] <move to target>
func _build_hunt_program() -> UnitProgram:
	var nearby: ConditionBlock = _EnemyNearby.new()
	var in_range: ConditionBlock = _InAttackRange.new()
	var attack: ActionBlock = _Attack.new()
	var move: ActionBlock = _MoveTo.new()

	var attack_rule := Rule.new()
	var attack_conditions: Array[ConditionBlock] = []
	attack_conditions.append(nearby)
	attack_conditions.append(in_range)
	attack_rule.conditions = attack_conditions
	attack_rule.action = attack

	var move_rule := Rule.new()
	var move_conditions: Array[ConditionBlock] = []
	move_conditions.append(nearby)
	move_rule.conditions = move_conditions
	move_rule.action = move

	var hunt := UnitFunction.new()
	hunt.function_name = "Hunt"
	var rules: Array[Rule] = []
	rules.append(attack_rule)
	rules.append(move_rule)
	hunt.rules = rules

	var graph := EventGraph.new()
	graph.connect_function(EventGraph.Event.ON_UPDATE, hunt)

	var program := UnitProgram.new()
	program.event_graph = graph
	var functions: Array[UnitFunction] = []
	functions.append(hunt)
	program.functions = functions
	return program
