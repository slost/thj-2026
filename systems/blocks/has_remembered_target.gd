extends ConditionBlock
class_name HasRememberedTarget


func _init() -> void:
	name = "HasRememberedTarget"


func evaluate(unit: Unit2D, _ctx: ExecContext) -> bool:
	return not unit.targets.is_empty()
