extends ActionBlock
class_name Wander

var _sent: bool = false


func _init() -> void:
	name = "Wander"


func can_execute(unit: Unit2D, _ctx: ExecContext) -> bool:
	return unit.state != Unit2D.State.DEAD and unit.state != Unit2D.State.SPAWNING


func execute(unit: Unit2D, _ctx: ExecContext) -> void:
	unit.move_dir(Vector2.from_angle(randf() * TAU))


func step(unit: Unit2D, ctx: ExecContext) -> StepResult:
	if unit.state == Unit2D.State.DEAD or unit.state == Unit2D.State.SPAWNING:
		return StepResult.CANCELLED
	if not _sent:
		execute(unit, ctx)
		_sent = true
		return StepResult.RUNNING
	if unit.state == Unit2D.State.MOVING:
		return StepResult.RUNNING
	return StepResult.DONE
