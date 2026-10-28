extends ActionBlock
class_name StandStill


func _init() -> void:
	name = "StandStill"


func execute(unit: Unit2D, _ctx: ExecContext) -> void:
	unit.stop_moving()
