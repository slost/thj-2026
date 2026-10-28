## Child node of Unit2D. Fires events into the unit's program.
class_name ProgramRunner
extends Node

signal rule_executed(fn: UnitFunction, rule: ProgramRule)  ## for UI highlight / debug

const MIN_CPU := 1

var _think_timer: float = 0.0
var _timer_armed: bool = false

@onready var unit: Unit2D = get_parent() as Unit2D


## Called by Unit2D every physics frame. Thinks only while IDLE or MOVING.
func tick(delta: float) -> void:
	if unit == null:
		return
	if unit.state != Unit2D.State.IDLE and unit.state != Unit2D.State.MOVING:
		return
	if not _timer_armed:
		# Spread the first think so a wave of units does not act on one frame.
		_think_timer = randf() * _think_interval()
		_timer_armed = true
		return
	_think_timer -= delta
	if _think_timer > 0.0:
		return
	fire(EventGraph.Event.ON_UPDATE)
	_think_timer += _think_interval()
	if _think_timer < 0.0:
		_think_timer = 0.0


## Runs linked functions in order; stops at the first one that acts.
## Returns true if any action was executed.
func fire(event: EventGraph.Event, source: Node = null) -> bool:
	if unit == null or unit.def == null:
		return false
	if event not in unit.def.allowed_events:
		return false
	if unit.program == null or unit.program.event_graph == null:
		return false
	var ctx := ExecContext.new(unit, event, source)
	for fn in unit.program.event_graph.get_functions(event):
		var function := fn as UnitFunction
		if function == null:
			continue
		if function.run(unit, ctx):
			rule_executed.emit(function, function.last_executed_rule)
			return true
	return false


## 0 at the start of a wait, 1 the moment the next program loop runs.
func get_think_ratio() -> float:
	if not _timer_armed:
		return 0.0
	var interval := _think_interval()
	if interval <= 0.0:
		return 1.0
	return clampf(1.0 - _think_timer / interval, 0.0, 1.0)


func _think_interval() -> float:
	var cpu := MIN_CPU
	if unit != null and unit.stats != null:
		cpu = maxi(unit.stats.cpu, MIN_CPU)
	return Formular.calculate_think_interval(cpu)
