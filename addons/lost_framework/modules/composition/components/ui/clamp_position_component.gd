extends UIComponent
class_name ClampPositionComponent


signal position_clamped(component: ClampPositionComponent, from_position: Vector2, to_position: Vector2)

enum AvoidPlacement {
	RIGHT,
	LEFT,
	BOTTOM,
	TOP
}

@export_category("Bounds")
@export var margin: Vector2 = Vector2(8, 8)
@export var clamp_x: bool = true
@export var clamp_y: bool = true

@export_category("Behavior")
@export var auto_clamp: bool = true
@export var clamp_only_when_visible: bool = true
@export var clamp_on_process: bool = true

@export_category("Avoidance")
@export var avoid_enabled: bool = true
@export var avoid_gap: float = 8.0
@export var preferred_placement: AvoidPlacement = AvoidPlacement.RIGHT


var _avoid_control: Control
var _avoid_rect: Rect2
var _has_avoid_rect: bool = false


func _setup() -> void:
	set_process(enabled and auto_clamp and clamp_on_process)
	call_deferred("clamp_to_viewport")

	if host_node:
		if not host_node.resized.is_connected(_on_host_resized):
			host_node.resized.connect(_on_host_resized)
		if not host_node.visibility_changed.is_connected(_on_host_visibility_changed):
			host_node.visibility_changed.connect(_on_host_visibility_changed)


func _tear_down() -> void:
	if host_node:
		if host_node.resized.is_connected(_on_host_resized):
			host_node.resized.disconnect(_on_host_resized)
		if host_node.visibility_changed.is_connected(_on_host_visibility_changed):
			host_node.visibility_changed.disconnect(_on_host_visibility_changed)


func _process(_delta: float) -> void:
	clamp_to_viewport()


func set_enabled(value: bool) -> void:
	super.set_enabled(value)
	set_process(enabled and auto_clamp and clamp_on_process)


func clamp_to_viewport() -> void:
	if not enabled:
		return

	if not host_node:
		return

	if clamp_only_when_visible and not host_node.visible:
		return

	var viewport := host_node.get_viewport()
	if not viewport:
		return

	var viewport_rect := viewport.get_visible_rect()
	var host_rect: Rect2 = host_node.get_global_rect()
	var target_position: Vector2 = host_node.global_position

	_update_avoid_rect_from_control()

	if avoid_enabled and _has_avoid_rect:
		target_position = _find_position_around_avoid_rect(viewport_rect, host_rect)
		host_rect.position += target_position - host_node.global_position

	if clamp_x:
		target_position.x = _clamp_axis(
			target_position.x,
			host_rect.position.x,
			host_rect.size.x,
			viewport_rect.position.x + margin.x,
			viewport_rect.end.x - margin.x
		)

	if clamp_y:
		target_position.y = _clamp_axis(
			target_position.y,
			host_rect.position.y,
			host_rect.size.y,
			viewport_rect.position.y + margin.y,
			viewport_rect.end.y - margin.y
		)

	if target_position.distance_squared_to(host_node.global_position) <= 0.001:
		return

	var previous_position: Vector2 = host_node.global_position
	host_node.global_position = target_position
	position_clamped.emit(self, previous_position, target_position)


func set_avoid_control(control: Control) -> void:
	_avoid_control = control
	_has_avoid_rect = is_instance_valid(_avoid_control)
	if _has_avoid_rect:
		_avoid_rect = _avoid_control.get_global_rect()
	clamp_to_viewport()


func set_avoid_rect(rect: Rect2) -> void:
	_avoid_control = null
	_avoid_rect = rect
	_has_avoid_rect = true
	clamp_to_viewport()


func clear_avoid_target() -> void:
	_avoid_control = null
	_has_avoid_rect = false


func _clamp_axis(current_position: float, rect_start: float, rect_size: float, bound_start: float, bound_end: float) -> float:
	var min_position := current_position + bound_start - rect_start
	var max_position := current_position + bound_end - (rect_start + rect_size)

	if min_position > max_position:
		return min_position

	return clamp(current_position, min_position, max_position)


func _update_avoid_rect_from_control() -> void:
	if not _avoid_control:
		return

	if not is_instance_valid(_avoid_control):
		clear_avoid_target()
		return

	_avoid_rect = _avoid_control.get_global_rect()
	_has_avoid_rect = true


func _find_position_around_avoid_rect(viewport_rect: Rect2, host_rect: Rect2) -> Vector2:
	var rect_offset: Vector2 = host_rect.position - host_node.global_position
	var candidate_positions := _get_avoid_candidate_positions(host_rect.size, rect_offset)
	var bounds := Rect2(
		viewport_rect.position + margin,
		viewport_rect.size - margin * 2.0
	)

	var best_position: Vector2 = host_node.global_position
	var best_score := INF

	for candidate_position in candidate_positions:
		var clamped_position := _clamp_position_to_bounds(candidate_position, host_rect, bounds)
		var candidate_rect := Rect2(clamped_position + (host_rect.position - host_node.global_position), host_rect.size)
		var overlap_penalty := 1000000.0 if candidate_rect.intersects(_avoid_rect, true) else 0.0
		var movement_penalty := clamped_position.distance_squared_to(host_node.global_position)
		var score: float = overlap_penalty + movement_penalty

		if score < best_score:
			best_score = score
			best_position = clamped_position

	return best_position


func _get_avoid_candidate_positions(host_size: Vector2, rect_offset: Vector2) -> Array[Vector2]:
	var positions: Array[Vector2] = [
		Vector2(_avoid_rect.end.x + avoid_gap, _avoid_rect.position.y + (_avoid_rect.size.y - host_size.y) * 0.5) - rect_offset,
		Vector2(_avoid_rect.position.x - host_size.x - avoid_gap, _avoid_rect.position.y + (_avoid_rect.size.y - host_size.y) * 0.5) - rect_offset,
		Vector2(_avoid_rect.position.x + (_avoid_rect.size.x - host_size.x) * 0.5, _avoid_rect.end.y + avoid_gap) - rect_offset,
		Vector2(_avoid_rect.position.x + (_avoid_rect.size.x - host_size.x) * 0.5, _avoid_rect.position.y - host_size.y - avoid_gap) - rect_offset
	]

	var preferred_position: Vector2 = positions.pop_at(preferred_placement)
	positions.push_front(preferred_position)

	return positions


func _clamp_position_to_bounds(position: Vector2, host_rect: Rect2, bounds: Rect2) -> Vector2:
	var rect_offset: Vector2 = host_rect.position - host_node.global_position
	var target_position: Vector2 = position
	var rect_start: Vector2 = target_position + rect_offset
	var rect_end: Vector2 = rect_start + host_rect.size

	if clamp_x:
		if rect_start.x < bounds.position.x:
			target_position.x += bounds.position.x - rect_start.x
		elif rect_end.x > bounds.end.x:
			target_position.x -= rect_end.x - bounds.end.x

	if clamp_y:
		if rect_start.y < bounds.position.y:
			target_position.y += bounds.position.y - rect_start.y
		elif rect_end.y > bounds.end.y:
			target_position.y -= rect_end.y - bounds.end.y

	return target_position


func _on_host_resized() -> void:
	if auto_clamp:
		call_deferred("clamp_to_viewport")


func _on_host_visibility_changed() -> void:
	if auto_clamp and host_node.visible:
		call_deferred("clamp_to_viewport")
