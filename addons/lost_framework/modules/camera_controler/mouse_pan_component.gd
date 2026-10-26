## Offsets a camera toward the mouse, clamped to a maximum distance from its rest offset.
## Parallax layers read [member offset] and shift by a fraction of it.
## @tags: camera, pan, mouse, parallax
extends Component
class_name MousePanComponent


signal pan_changed(offset: Vector2)

@export var camera: Camera2D ## Defaults to the parent when it is a Camera2D
@export var max_offset: Vector2 = Vector2(64, 40) ## Furthest pan from the rest offset, in pixels
@export var smooth_speed: float = 6.0 ## How quickly the pan catches the mouse

var offset: Vector2 ## Smoothed pan currently applied on top of the camera's rest offset

var _base_offset: Vector2
var _has_base_offset := false


func _setup() -> void:
	if not is_in_group(&"mouse_pan"):
		add_to_group(&"mouse_pan")
	process_priority = -10
	_resolve_camera()


func _process(delta: float) -> void:
	if not _resolve_camera():
		return

	var target := Vector2.ZERO
	if is_enabled():
		target = _target_offset()

	var blend := 1.0 - exp(-smooth_speed * delta)
	var next := offset.lerp(target, blend)
	if next.is_equal_approx(offset) and camera.offset.is_equal_approx(_base_offset + offset):
		return

	offset = next
	camera.offset = _base_offset + offset
	pan_changed.emit(offset)


func _resolve_camera() -> bool:
	if not is_instance_valid(camera):
		camera = get_parent() as Camera2D
	if camera == null:
		return false
	if not _has_base_offset:
		_base_offset = camera.offset
		_has_base_offset = true
	return true


func _target_offset() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2.ZERO

	var size := viewport.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO

	var from_center := (viewport.get_mouse_position() - size * 0.5) / (size * 0.5)
	from_center = from_center.clamp(Vector2(-1.0, -1.0), Vector2.ONE)
	return Vector2(from_center.x * max_offset.x, from_center.y * max_offset.y)


## Turns mouse panning on or off. Turning it off snaps the camera back to its rest offset.
func set_active(active: bool) -> void:
	set_enabled(active)
	if active or not _resolve_camera():
		return

	offset = Vector2.ZERO
	camera.offset = _base_offset


func _teardown() -> void:
	if is_in_group(&"mouse_pan"):
		remove_from_group(&"mouse_pan")
	if is_instance_valid(camera) and _has_base_offset:
		camera.offset = _base_offset
		offset = Vector2.ZERO
