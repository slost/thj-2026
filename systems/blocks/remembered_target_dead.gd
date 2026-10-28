extends ConditionBlock
class_name RememberedTargetDead


func _init() -> void:
	name = "RememberedTargetDead"


func evaluate(unit: Unit2D, _ctx: ExecContext) -> bool:
	if unit.targets.is_empty():
		return false
	var target := unit.targets[0]
	return target == null or not is_instance_valid(target) or target.state == Unit2D.State.DEAD
