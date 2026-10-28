extends ConditionBlock
class_name NoRememberedTarget


func _init() -> void:
	name = "NoRememberedTarget"


func evaluate(unit: Unit2D, _ctx: ExecContext) -> bool:
	return unit.targets.is_empty()
