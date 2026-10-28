extends ConditionBlock
class_name RandomChance


## Probability from 0 to 1 that this condition passes.
@export_range(0.0, 1.0, 0.05) var chance: float = 0.5


func _init() -> void:
	name = "RandomChance"


func check(_unit: Unit2D, _ctx: ExecContext) -> bool:
	return randf() < chance
