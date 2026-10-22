extends Camera2D
class_name CameraController2D


@export var max_shake_intensity: float = 12.0
@export var noise_interval: float = 0.02

@export_category("Zoom Config")
@export var zoom_target: Node2D
@export var zoom_group: String = "zoom_affect"
@export var base_zoom: float = 1.0
@export var max_zoom_out: float = 0.6
@export var object_per_step: int = 10
@export var zoom_lerp_speed: float = 5.0


var _original_position: Vector2
var _shakes: Array[Dictionary] = []
var _noise_timer: float = 0.0
var _target_zoom: float = 1.0


func _ready() -> void:
	_original_position = position


func _process(delta: float) -> void:
	_update_shake(delta)
	_update_zoom(delta)


#region Public API
func shake(intensity: float = 5.0, duration: float = 0.5) -> void:
	if intensity <= 0.0 or duration <= 0.0:
		return

	_shakes.append({
		"intensity": intensity,
		"time_left": duration
	})
#endregion


#region Interal Logic
func _update_zoom(delta: float) -> void:
	if not zoom_target or zoom_group.is_empty():
		return

	var object_count: int = 0

	for child in zoom_target.get_children():
		if child.is_in_group(zoom_group):
			object_count += 1

	var steps: float = float(object_count) / float(object_per_step)
	var zoom_factor: float = 1.0 / (1.0 + steps)

	_target_zoom = clamp(
		base_zoom * zoom_factor,
		max_zoom_out,
		base_zoom
	)

	var current: float = zoom.x
	var next: float = lerp(current, _target_zoom, zoom_lerp_speed * delta)
	zoom = Vector2(next, next)


func _update_shake(delta: float) -> void:
	if _shakes.is_empty():
		position = _original_position
		return

	var raw_intensity: float = 0.0

	for i in range(_shakes.size() - 1, -1, -1):
		var entry := _shakes[i]
		entry.time_left -= delta

		if entry.time_left <= 0.0:
			_shakes.remove_at(i)
		else:
			raw_intensity += entry.intensity

	var intensity := _soft_cap(raw_intensity, max_shake_intensity)

	_noise_timer -= delta
	if _noise_timer <= 0.0:
		_noise_timer = noise_interval
		var offset := Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		position = _original_position + offset
#endregion


#region Math
func _soft_cap(value: float, max_value: float) -> float:
	if value <= 0.0:
		return 0.0

	return max_value * (1.0 - exp(-value / max_value))
#endregion
