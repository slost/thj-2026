## Detect and attack circles for the unit currently shown in the focus label.
extends Node2D

var detect_radius: float = 0.0
var attack_radius: float = 0.0


func _draw() -> void:
	if detect_radius > 1.0:
		draw_arc(Vector2.ZERO, detect_radius, 0.0, TAU, 72, Color(0.35, 0.78, 1.0, 0.9), 3.0)
	if attack_radius > 1.0:
		draw_arc(Vector2.ZERO, attack_radius, 0.0, TAU, 48, Color(1.0, 0.38, 0.32, 0.95), 3.0)
