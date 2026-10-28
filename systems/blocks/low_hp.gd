extends ConditionBlock
class_name LowHp


## Fraction of max HP. 0.35 means 35% or below.
@export_range(0.0, 1.0, 0.05) var threshold: float = 0.35


func _init() -> void:
	name = "LowHp"


func check(unit: Unit2D, _ctx: ExecContext) -> bool:
	if unit.stats == null or unit.stats.max_hp <= 0:
		return false
	return float(unit.stats.hp) / float(unit.stats.max_hp) <= threshold
