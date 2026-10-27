extends ConditionBlock
class_name EnemyNearbyCondition


func _init() -> void:
	name = "enemy nearby"


## Writes the nearest enemy within detect_range into ctx.target.
func check(unit: Unit2D, ctx: ExecContext) -> bool:
	if unit.stats == null:
		return false
	var enemy := unit.find_nearest_enemy(unit.stats.detect_range)
	if enemy == null:
		return false
	ctx.target = enemy
	return true
