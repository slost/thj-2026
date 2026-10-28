extends ActionBlock
class_name AttackTarget


func _init() -> void:
	name = "AttackTarget"


## Stays true while the target is in range, including during the cooldown,
## so a later rule does not walk the unit out of melee.
func can_execute(unit: Unit2D, ctx: ExecContext) -> bool:
	var target := ctx.target as Unit2D
	if target == null or not is_instance_valid(target) or target.state == Unit2D.State.DEAD:
		return false
	return unit.is_in_attack_range(target)


func execute(unit: Unit2D, ctx: ExecContext) -> void:
	unit.stop_moving()
	if unit.can_attack():
		unit.attack(ctx.target as Unit2D)
