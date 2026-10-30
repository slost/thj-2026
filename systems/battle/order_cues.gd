## Marks for click orders, plus the path the pinned unit is already walking.
extends Node2D


var path := PackedVector2Array()
var move_points := PackedVector2Array()
var attack_points := PackedVector2Array()


func set_marks(next_path: PackedVector2Array, moves: PackedVector2Array, attacks: PackedVector2Array) -> void:
	path = next_path
	move_points = moves
	attack_points = attacks
	visible = path.size() >= 2 or move_points.size() > 0 or attack_points.size() > 0
	queue_redraw()


func _draw() -> void:
	if path.size() >= 2:
		var line := PackedVector2Array()
		for point in path:
			line.append(to_local(point))
		draw_polyline(line, Color(1.0, 0.86, 0.45, 0.95), 12.0, true)
	for point in move_points:
		_mark(to_local(point), Color(0.45, 0.95, 1.0, 0.95))
	for point in attack_points:
		_mark(to_local(point), Color(1.0, 0.38, 0.28, 0.95))


func _mark(point: Vector2, color: Color) -> void:
	draw_arc(point, 16.0, 0.0, TAU, 16, color, 3.0)
	draw_line(point + Vector2(-12.0, 0.0), point + Vector2(12.0, 0.0), color, 3.0)
	draw_line(point + Vector2(0.0, -12.0), point + Vector2(0.0, 12.0), color, 3.0)
