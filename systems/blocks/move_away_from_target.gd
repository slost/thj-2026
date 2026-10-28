extends ActionBlock
class_name MoveAwayFromTarget

var _sent: bool = false


func _init() -> void:
	name = "MoveAwayFromTarget"


func affects_target() -> bool:
	return true


func can_execute(_unit: Unit2D, ctx: ExecContext) -> bool:
	return ctx.target is Node2D and is_instance_valid(ctx.target)


func execute(unit: Unit2D, ctx: ExecContext) -> void:
	unit.move_away_from(ctx.target as Node2D)


func step(unit: Unit2D, ctx: ExecContext) -> StepResult:
	var target := unit.get_primary_target()
	if target == null:
		unit.stop_moving()
		return StepResult.CANCELLED
	if not _sent:
		ctx.target = target
		execute(unit, ctx)
		_sent = true
		return StepResult.RUNNING
	if unit.state == Unit2D.State.MOVING:
		return StepResult.RUNNING
	return StepResult.DONE
