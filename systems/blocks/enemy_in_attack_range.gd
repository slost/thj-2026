extends ConditionBlock
class_name EnemyInAttackRange


func _init() -> void:
	name = "EnemyInAttackRange"


## Nearest enemy inside attack_range. Writes that unit into ctx.target.
func check(unit: Unit2D, ctx: ExecContext) -> bool:
	if unit.stats == null:
		return false
	var enemy := unit.find_nearest_enemy(unit.stats.attack_range)
	if enemy == null or not unit.is_in_attack_range(enemy):
		return false
	ctx.target = enemy
	return true
