extends ActionBlock
class_name MoveToTarget


func _init() -> void:
	name = "MoveToTarget"


func affects_target() -> bool:
	return true


func can_execute(_unit: Unit2D, ctx: ExecContext) -> bool:
	return ctx.target is Node2D and is_instance_valid(ctx.target)


func execute(unit: Unit2D, ctx: ExecContext) -> void:
	unit.move_toward_target(ctx.target as Node2D)


func step(unit: Unit2D, ctx: ExecContext) -> StepResult:
	var target := unit.get_primary_target()
	if target == null or unit.path_failed():
		unit.stop_moving()
		return StepResult.CANCELLED
	var cells := unit.chebyshev_cells_to(target.global_position)
	if unit.keeps_distance():
		if cells <= Formular.garrison_kite_tiles():
			unit.move_away_from(target)
			return StepResult.RUNNING
		var hold := 1
		if unit.stats != null:
			hold = maxi(unit.stats.attack_range, 1)
		if cells <= hold:
			unit.stop_moving()
			return StepResult.DONE
	elif cells <= 1:
		unit.stop_moving()
		return StepResult.DONE
	ctx.target = target
	execute(unit, ctx)
	return StepResult.RUNNING
