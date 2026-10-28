extends ActionBlock
class_name Wander


func _init() -> void:
	name = "Wander"


func can_execute(unit: Unit2D, _ctx: ExecContext) -> bool:
	return unit.state != Unit2D.State.DEAD and unit.state != Unit2D.State.SPAWNING


## Keeps the current goal while the unit is still walking, then picks a new direction.
func execute(unit: Unit2D, _ctx: ExecContext) -> void:
	if unit.state == Unit2D.State.MOVING and unit.velocity.length() > 8.0:
		return
	unit.move_dir(Vector2.from_angle(randf() * TAU))
