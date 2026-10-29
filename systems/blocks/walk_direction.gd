## One queued step onto the neighboring grid cell.
## direction is one tile: left (-1, 0), right (1, 0), up (0, -1), down (0, 1).
extends ActionBlock
class_name WalkDirection


@export var direction: Vector2i = Vector2i.ZERO

var _goal: Vector2i = Vector2i.ZERO
var _started: bool = false


func _init() -> void:
	name = "WalkDirection"


func can_execute(unit: Unit2D, _ctx: ExecContext) -> bool:
	return unit.state != Unit2D.State.DEAD and unit.state != Unit2D.State.SPAWNING


func step(unit: Unit2D, _ctx: ExecContext) -> StepResult:
	if unit.state == Unit2D.State.DEAD or unit.state == Unit2D.State.SPAWNING:
		return StepResult.CANCELLED
	if not _started:
		if direction == Vector2i.ZERO:
			return StepResult.CANCELLED
		var nav := _nav(unit)
		if nav == null:
			return StepResult.CANCELLED
		_goal = nav.world_to_cell(unit.global_position) + direction
		if not unit.try_move_to_cell(_goal):
			return StepResult.CANCELLED
		_started = true
		return StepResult.RUNNING
	if unit.path_failed():
		unit.stop_moving()
		return StepResult.CANCELLED
	var nav := _nav(unit)
	if nav != null and nav.world_to_cell(unit.global_position) == _goal and unit.state != Unit2D.State.MOVING:
		return StepResult.DONE
	if unit.state == Unit2D.State.MOVING:
		return StepResult.RUNNING
	return StepResult.CANCELLED


func _nav(unit: Unit2D) -> GridNav:
	var tree := unit.get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(GridNav.GROUP) as GridNav
