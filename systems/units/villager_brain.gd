## Fight and flee scripts used by town defenders. Each call returns its own program.
extends RefCounted


const _DETECT := "res://data/blocks/enemy_in_detect_range.tres"
const _REMEMBER := "res://data/blocks/remember_hostile.tres"
const _HAS_TARGET := "res://data/blocks/has_remembered_target.tres"
const _IN_RANGE := "res://data/blocks/remembered_target_in_attack_range.tres"
const _DEAD := "res://data/blocks/remembered_target_dead.tres"
const _NO_TARGET := "res://data/blocks/no_remembered_target.tres"
const _FORGET := "res://data/blocks/forget_first_target.tres"
const _ATTACK := "res://data/blocks/attack_target.tres"
const _MOVE := "res://data/blocks/move_to_target.tres"
const _AWAY := "res://data/blocks/move_away_from_target.tres"
const _WANDER := "res://data/blocks/wander.tres"


static func program(flees: bool) -> UnitProgram:
	var lines: Array[ScriptLine] = []
	lines.append(_line(_condition(_DEAD), 0))
	lines.append(_line(_action(_FORGET), 1))
	lines.append(_line(_condition(_DETECT), 0))
	lines.append(_line(_action(_REMEMBER), 1))
	if flees:
		lines.append(_line(_action(_AWAY), 1))
	else:
		lines.append(_line(_condition(_HAS_TARGET), 0))
		lines.append(_line(_condition(_IN_RANGE), 1))
		lines.append(_line(_action(_ATTACK), 2))
		lines.append(_line(_action(_MOVE), 1))
	lines.append(_line(_condition(_NO_TARGET), 0))
	lines.append(_line(_action(_WANDER), 1))
	return _program_with("Flee" if flees else "Fight", lines)


static func _program_with(function_name: String, lines: Array[ScriptLine]) -> UnitProgram:
	var brain := UnitFunction.new()
	brain.function_name = function_name
	brain.lines = lines
	var graph := EventGraph.new()
	graph.connect_function(EventGraph.Event.ON_UPDATE, brain)
	var created := UnitProgram.new()
	created.event_graph = graph
	var functions: Array[UnitFunction] = []
	functions.append(brain)
	created.functions = functions
	return created


static func _line(block: CodeBlock, indent: int) -> ScriptLine:
	var line := ScriptLine.new()
	line.indent = indent
	line.block = block
	return line


static func _condition(path: String) -> ConditionBlock:
	var block := load(path) as ConditionBlock
	if block == null:
		push_error("Missing condition block: %s" % path)
		return null
	return block.duplicate() as ConditionBlock


static func _action(path: String) -> ActionBlock:
	var block := load(path) as ActionBlock
	if block == null:
		push_error("Missing action block: %s" % path)
		return null
	return block.duplicate() as ActionBlock
