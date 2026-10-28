## Child node of Unit2D. Reads the ON_UPDATE script one line at a time.
class_name ProgramRunner
extends Node

const MIN_CPU := 1

## Line the reader is on. The debug script highlights this index.
var read_index: int = 0

var _read_timer: float = 0.0
var _timer_armed: bool = false

@onready var unit: Unit2D = get_parent() as Unit2D


## Called by Unit2D every physics frame while the unit can act.
func tick(delta: float) -> void:
	if not _can_read():
		return
	if not _timer_armed:
		# Spread the first read so a wave of units does not act on one frame.
		_read_timer = randf() * _read_interval()
		_timer_armed = true
		return
	_read_timer -= delta
	if _read_timer > 0.0:
		return
	read_current_line()
	_read_timer += _read_interval()
	if _read_timer < 0.0:
		_read_timer = 0.0


## Runs linked functions for events other than the line-by-line update script.
func fire(event: EventGraph.Event, source: Node = null) -> bool:
	if event == EventGraph.Event.ON_UPDATE:
		return false
	if unit == null or unit.def == null:
		return false
	if event not in unit.def.allowed_events:
		return false
	if unit.program == null or unit.program.event_graph == null:
		return false
	var acted := false
	for fn in unit.program.event_graph.get_functions(event):
		var function := fn as UnitFunction
		if function == null:
			continue
		if _run_instant(function, event, source):
			acted = true
	return acted


## 0 at the start of a read, 1 the moment the current line is applied.
func get_think_ratio() -> float:
	if not _timer_armed:
		return 0.0
	var interval := _read_interval()
	if interval <= 0.0:
		return 1.0
	return clampf(1.0 - _read_timer / interval, 0.0, 1.0)


func get_update_script() -> UnitFunction:
	if unit == null or unit.program == null or unit.program.event_graph == null:
		return null
	var list := unit.program.event_graph.get_functions(EventGraph.Event.ON_UPDATE)
	if list.is_empty():
		return null
	return list[0] as UnitFunction


func read_current_line() -> void:
	if unit == null:
		return
	var function := get_update_script()
	if function == null or function.lines.is_empty():
		return
	if read_index < 0 or read_index >= function.lines.size():
		read_index = 0
	var line := function.lines[read_index]
	var enter_body := _apply_line(line, EventGraph.Event.ON_UPDATE, null)
	var next := next_line_index(function.lines, read_index, enter_body)
	read_index = 0 if next >= function.lines.size() else next


## The line after index. A failed condition jumps past every deeper line.
static func next_line_index(lines: Array[ScriptLine], index: int, enter_body: bool) -> int:
	if lines.is_empty() or index < 0 or index >= lines.size():
		return 0
	if enter_body:
		return index + 1
	var indent := 0
	if lines[index]:
		indent = lines[index].indent
	var cursor := index + 1
	while cursor < lines.size():
		var line := lines[cursor]
		if line == null or line.indent <= indent:
			break
		cursor += 1
	return cursor


func _can_read() -> bool:
	return (
		unit != null
		and (
			unit.state == Unit2D.State.IDLE
			or unit.state == Unit2D.State.MOVING
			or unit.state == Unit2D.State.ATTACKING
		)
	)


func _read_interval() -> float:
	var cpu := MIN_CPU
	if unit != null and unit.stats != null:
		cpu = maxi(unit.stats.cpu, MIN_CPU)
	return Formular.calculate_think_interval(cpu)


func _run_instant(function: UnitFunction, event: EventGraph.Event, source: Node) -> bool:
	var acted := false
	var index := 0
	var guard := 0
	while index < function.lines.size() and guard <= function.lines.size():
		var line := function.lines[index]
		var enter_body := _apply_line(line, event, source)
		if line and line.block is ActionBlock:
			acted = true
		var next := next_line_index(function.lines, index, enter_body)
		if next <= index:
			break
		index = next
		guard += 1
	return acted


## A passing condition enters the indented body. A failing one does not.
func _apply_line(line: ScriptLine, event: EventGraph.Event, source: Node) -> bool:
	if line == null or line.block == null or unit == null:
		return true
	var ctx := ExecContext.new(unit, event, source)
	ctx.target = unit.get_primary_target()
	if line.block is ConditionBlock:
		return (line.block as ConditionBlock).evaluate(unit, ctx)
	if line.block is ActionBlock:
		var action := line.block as ActionBlock
		if action.runs_immediately():
			action.execute(unit, ctx)
		elif not action.affects_target() or unit.get_primary_target() != null:
			unit.enqueue_action(action)
		return true
	return true
