## Shifts a visual by a fraction of [MousePanComponent] offset.
## factor 0 stays in the world with the map. factor 1 follows the pan and sticks to the screen.
## A positive factor lags behind the map. A negative factor moves farther than the map, for art in front of it.
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
		return

	var shift := pan.offset
	var parallax := Vector2(shift.x * factor.x, shift.y * factor.y)
	var parent_node := visual.get_parent() as Node2D
	if parent_node:
		var parent_scale := parent_node.global_scale
		if not is_zero_approx(parent_scale.x):
			parallax.x /= parent_scale.x
		if not is_zero_approx(parent_scale.y):
			parallax.y /= parent_scale.y
	visual.position = _base_position + parallax


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
