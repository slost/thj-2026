## Hit the enemy standing along the way this unit just walked.
extends ActionBlock
class_name AttackFacing


var _swung := false


func _init() -> void:
	name = "AttackFacing"


func step(unit: Unit2D, _ctx: ExecContext) -> StepResult:
	if unit == null or unit.state == Unit2D.State.DEAD:
		return StepResult.CANCELLED
	if unit.state == Unit2D.State.SPAWNING:
		return StepResult.RUNNING
	if _swung:
		if unit.state == Unit2D.State.ATTACKING:
			return StepResult.RUNNING
		return StepResult.DONE
	var foe := unit.enemy_along_facing()
	if foe == null or not unit.is_in_attack_range(foe):
		return StepResult.CANCELLED
	if not unit.can_attack():
		return StepResult.RUNNING
	unit.stop_moving()
	unit.attack(foe)
	_swung = true
	return StepResult.RUNNING
