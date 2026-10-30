## Player order: chase one enemy and keep attacking until that enemy is down.
extends ActionBlock


var target: Unit2D
var _swung := false


func _init() -> void:
	name = "OrderAttack"


## Where the chosen enemy stands. Empty once that enemy is gone.
func order_marker() -> Variant:
	if target == null or not is_instance_valid(target) or target.state == Unit2D.State.DEAD:
		return null
	return target.global_position


func step(unit: Unit2D, _ctx: ExecContext) -> StepResult:
	if unit == null or unit.state == Unit2D.State.DEAD:
		return StepResult.CANCELLED
	if unit.state == Unit2D.State.SPAWNING:
		return StepResult.RUNNING
	if target == null or not is_instance_valid(target) or target.state == Unit2D.State.DEAD:
		unit.stop_moving()
		return StepResult.DONE if target != null else StepResult.CANCELLED
	if not unit.is_in_attack_range(target):
		_swung = false
		unit.move_toward_target(target)
		return StepResult.RUNNING
	if _swung:
		if unit.state == Unit2D.State.ATTACKING:
			return StepResult.RUNNING
		_swung = false
	if not unit.can_attack():
		return StepResult.RUNNING
	unit.stop_moving()
	unit.attack(target)
	_swung = true
	return StepResult.RUNNING
