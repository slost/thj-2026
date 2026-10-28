extends ActionBlock
class_name AttackTarget

var _swung: bool = false


func _init() -> void:
	name = "AttackTarget"


func affects_target() -> bool:
	return true


func can_execute(unit: Unit2D, ctx: ExecContext) -> bool:
	var target := ctx.target as Unit2D
	if target == null or not is_instance_valid(target) or target.state == Unit2D.State.DEAD:
		return false
	return unit.is_in_attack_range(target)


func execute(unit: Unit2D, ctx: ExecContext) -> void:
	unit.stop_moving()
	if unit.can_attack():
		unit.attack(ctx.target as Unit2D)


## Waits out cooldown and the attack pose. Leaves the queue if the hit cannot happen.
func step(unit: Unit2D, ctx: ExecContext) -> StepResult:
	var target := unit.get_primary_target()
	if target == null:
		return StepResult.CANCELLED
	if _swung:
		if unit.state == Unit2D.State.ATTACKING:
			return StepResult.RUNNING
		return StepResult.DONE
	if not unit.is_in_attack_range(target):
		return StepResult.CANCELLED
	if not unit.can_attack():
		return StepResult.RUNNING
	ctx.target = target
	execute(unit, ctx)
	_swung = true
	return StepResult.RUNNING
