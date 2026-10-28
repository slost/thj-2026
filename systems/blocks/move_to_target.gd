extends ActionBlock
class_name MoveToTarget


func _init() -> void:
	name = "MoveToTarget"


func can_execute(_unit: Unit2D, ctx: ExecContext) -> bool:
	return ctx.target is Node2D and is_instance_valid(ctx.target)


func execute(unit: Unit2D, ctx: ExecContext) -> void:
	unit.move_toward_target(ctx.target as Node2D)
