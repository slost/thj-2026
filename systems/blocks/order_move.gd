## Player order: walk to one cell, any distance, using the unit's existing pathing.
extends ActionBlock


@export var goal := Vector2i.ZERO
var _sent := false


func _init() -> void:
	name = "OrderMove"


## Cell the player clicked. The pin overlay draws a mark there.
func order_marker() -> Variant:
	return goal


func step(unit: Unit2D, _ctx: ExecContext) -> StepResult:
	if unit == null or unit.state == Unit2D.State.DEAD:
		return StepResult.CANCELLED
	if unit.state == Unit2D.State.SPAWNING:
		return StepResult.RUNNING
	var nav := _nav()
	if nav != null and nav.world_to_cell(unit.global_position) == goal and unit.state != Unit2D.State.MOVING:
		return StepResult.DONE
	if not _sent:
		_sent = true
		if not unit.try_move_to_cell(goal):
			return StepResult.CANCELLED
		return StepResult.RUNNING
	if unit.path_failed():
		return StepResult.CANCELLED
	if unit.state != Unit2D.State.MOVING and (nav == null or nav.world_to_cell(unit.global_position) != goal):
		return StepResult.CANCELLED
	return StepResult.RUNNING


func _nav() -> GridNav:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(GridNav.GROUP) as GridNav
