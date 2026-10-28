## A block that does one thing.
## Memory commands run the moment their line is read.
## Other actions are copied into the unit's queue and stepped until they finish.
## Actions only call the Unit2D API; animations/timing live in Unit2D.
extends CodeBlock
class_name ActionBlock

enum StepResult { RUNNING, DONE, CANCELLED }


## True when this command needs a remembered target before it can be queued or stepped.
func affects_target() -> bool:
	return false


## True for remember/forget. Those run during the read instead of entering the queue.
func runs_immediately() -> bool:
	return false


## Return false to make a caller skip this action (e.g. no target).
func can_execute(_unit: Unit2D, _ctx: ExecContext) -> bool:
	return true


## Override in subclasses.
func execute(_unit: Unit2D, _ctx: ExecContext) -> void:
	pass


## One frame of a queued action. DONE and CANCELLED remove it from the queue.
func step(unit: Unit2D, ctx: ExecContext) -> StepResult:
	if affects_target() and unit.get_primary_target() == null:
		return StepResult.CANCELLED
	execute(unit, ctx)
	return StepResult.DONE
