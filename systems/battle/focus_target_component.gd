## Marks a host as something a FocusDirector can hover and pin.
## The host must be a CollisionObject2D so the pointer can enter it.
extends Component
class_name FocusTargetComponent

var _body: CollisionObject2D


func _setup() -> void:
	_body = get_host() as CollisionObject2D
	if _body == null:
		push_warning("FocusTargetComponent on %s needs a CollisionObject2D host." % get_parent())
		return
	_body.input_pickable = true
	if not _body.mouse_entered.is_connected(_on_mouse_entered):
		_body.mouse_entered.connect(_on_mouse_entered)
	if not _body.mouse_exited.is_connected(_on_mouse_exited):
		_body.mouse_exited.connect(_on_mouse_exited)
	if not _body.input_event.is_connected(_on_input_event):
		_body.input_event.connect(_on_input_event)


func _teardown() -> void:
	if _body == null or not is_instance_valid(_body):
		_body = null
		return
	if _body.mouse_entered.is_connected(_on_mouse_entered):
		_body.mouse_entered.disconnect(_on_mouse_entered)
	if _body.mouse_exited.is_connected(_on_mouse_exited):
		_body.mouse_exited.disconnect(_on_mouse_exited)
	if _body.input_event.is_connected(_on_input_event):
		_body.input_event.disconnect(_on_input_event)
	_body = null


func can_focus() -> bool:
	return is_enabled() and get_host() is Node2D


func get_focus_position() -> Vector2:
	var host := get_host() as Node2D
	if host == null:
		return Vector2.ZERO
	return host.global_position


func get_debug_text() -> String:
	var host := get_host()
	if host == null:
		return "No host"
	return "Focusing on: %s" % host.name


func _on_mouse_entered() -> void:
	if not can_focus():
		return
	var director := _director()
	if director:
		director.focus_target(self)


func _on_mouse_exited() -> void:
	var director := _director()
	if director:
		director.unfocus_target(self)


func _on_input_event(viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not can_focus():
		return
	if event is not InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed:
		return
	var director := _director()
	if mouse.button_index == MOUSE_BUTTON_RIGHT:
		if director:
			director.order_attack(self)
		if viewport is Viewport:
			(viewport as Viewport).set_input_as_handled()
		return
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if director:
		director.select_target(self)
	if viewport is Viewport:
		(viewport as Viewport).set_input_as_handled()


func _director() -> FocusDirector:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(FocusDirector.GROUP) as FocusDirector
