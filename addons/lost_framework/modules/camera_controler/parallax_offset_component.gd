## Shifts a visual by a fraction of [MousePanComponent] offset.
## factor 0 stays in the world with the map. factor 1 follows the pan and sticks to the screen.
## A positive factor lags behind the map. A negative factor moves farther than the map, for art in front of it.
## A [CanvasLayer] visual uses the same factor, converted into a screen-space shift.
## @tags: camera, parallax, background
extends Component
class_name ParallaxOffsetComponent


@export var pan: MousePanComponent ## Defaults to the first MousePanComponent in the mouse_pan group
@export var visual: Node2D ## Defaults to the parent when it is a Node2D
@export var factor: Vector2 = Vector2(0.45, 0.45) ## Share of the camera pan added to the visual

var _base_position: Vector2
var _has_base_position := false


func _setup() -> void:
	process_priority = 10
	_resolve_pan()
	_resolve_visual()


func _process(_delta: float) -> void:
	if not is_enabled() or not _resolve_visual():
		return
	if not _resolve_pan():
		if _is_screen_space(visual):
			visual.position = _base_position
		return

	var parallax := _parallax_offset()
	var parent_node := visual.get_parent() as Node2D
	if parent_node:
		var parent_scale := parent_node.global_scale
		if not is_zero_approx(parent_scale.x):
			parallax.x /= parent_scale.x
		if not is_zero_approx(parent_scale.y):
			parallax.y /= parent_scale.y
	visual.position = _base_position + parallax


func _parallax_offset() -> Vector2:
	var shift := pan.offset
	if _is_screen_space(visual):
		if is_instance_valid(pan.camera):
			var zoom := pan.camera.zoom
			shift.x *= zoom.x
			shift.y *= zoom.y
		return Vector2(shift.x * (factor.x - 1.0), shift.y * (factor.y - 1.0))

	return Vector2(shift.x * factor.x, shift.y * factor.y)


func _is_screen_space(node: Node) -> bool:
	var current := node.get_parent()
	while current:
		if current is CanvasLayer:
			return not current.follow_viewport_enabled
		current = current.get_parent()
	return false


func _resolve_pan() -> bool:
	if is_instance_valid(pan):
		return true

	pan = get_tree().get_first_node_in_group(&"mouse_pan") as MousePanComponent
	return pan != null


func _resolve_visual() -> bool:
	if is_instance_valid(visual):
		_capture_base_position()
		return true

	visual = get_parent() as Node2D
	if visual == null:
		return false

	_capture_base_position()
	return true


func _capture_base_position() -> void:
	if _has_base_position or visual == null:
		return

	_base_position = visual.position
	_has_base_position = true


func _teardown() -> void:
	if is_instance_valid(visual) and _has_base_position:
		visual.position = _base_position
