extends ConditionBlock
class_name InAttackRangeCondition


func _init() -> void:
	name = "in attack range"


func check(unit: Unit2D, ctx: ExecContext) -> bool:
	var enemy := ctx.target as Unit2D
	if enemy == null or not is_instance_valid(enemy) or enemy.state == Unit2D.State.DEAD:
		if unit.stats == null:
			return false
		enemy = unit.find_nearest_enemy(unit.stats.attack_range)
	if enemy == null:
		return false
	ctx.target = enemy
	return unit.is_in_attack_range(enemy)
