extends ActionBlock
class_name AttackAction


func _init() -> void:
	name = "attack"


## True while a living target is already in range, even if the swing is on cooldown.
## Returning true ends the think so a later rule does not walk closer.
func can_execute(unit: Unit2D, ctx: ExecContext) -> bool:
	var target := ctx.target as Unit2D
	if target == null or not is_instance_valid(target) or target.state == Unit2D.State.DEAD:
		return false
	return unit.is_in_attack_range(target)


func execute(unit: Unit2D, ctx: ExecContext) -> void:
	unit.stop_moving()
	if unit.can_attack():
		unit.attack(ctx.target as Unit2D)
