extends ConditionBlock
class_name EnemyInDetectRange


func _init() -> void:
	name = "EnemyInDetectRange"


## Nearest enemy inside detect_range. Writes that unit into ctx.target.
func evaluate(unit: Unit2D, ctx: ExecContext) -> bool:
	if unit.stats == null:
		return false
	var enemy := unit.find_nearest_enemy(unit.stats.detect_range)
	if enemy == null:
		return false
	ctx.target = enemy
	return true
