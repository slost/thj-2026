extends ConditionBlock
class_name RememberedTargetInAttackRange


func _init() -> void:
	name = "RememberedTargetInAttackRange"


## The first living remembered target is close enough to hit.
func evaluate(unit: Unit2D, _ctx: ExecContext) -> bool:
	var target := unit.get_primary_target()
	return target != null and unit.is_in_attack_range(target)
