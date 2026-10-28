extends ActionBlock
class_name MoveAwayFromTarget


func _init() -> void:
	name = "MoveAwayFromTarget"


func can_execute(_unit: Unit2D, ctx: ExecContext) -> bool:
	return ctx.target is Node2D and is_instance_valid(ctx.target)


func execute(unit: Unit2D, ctx: ExecContext) -> void:
	unit.move_away_from(ctx.target as Node2D)
