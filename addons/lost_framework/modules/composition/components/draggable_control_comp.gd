extends UIComponent
class_name DraggableControlComponent


signal drag_started(component: DraggableControlComponent)
signal drag_moved(component: DraggableControlComponent, delta: Vector2)
signal drag_ended(component: DraggableControlComponent)

@export_category("Configures")
@export var auto_drag: bool = true
@export var size_to_host: bool = true
@export var drag_button_size: Vector2 = Vector2(96, 96)
@export var drag_button_z_index: int = 0
@export var hide_drag_button: bool = true
var drag_button_hidden_alpha: float = 0.0
var drag_button_visible_alpha: float = 1.0


var drag_button: BaseButton
var _previous_mouse_position: Vector2 = Vector2.ZERO
var _button_pressed: bool = false


#region Public API
func apply_drag(delta: Vector2) -> void:
	if not host_node:
		return
	host_node.position += delta
#endregion


func _setup() -> void:
	if not enabled:
		return

	if size_to_host:
		drag_button_size = host_node.size

	call_deferred("_post_setup")


func _post_setup() -> void:
	_resolve_drag_button()


func _input(event: InputEvent) -> void:
	if not enabled or drag_button == null or host_node == null:
		return
	if get_viewport().is_input_handled():
		return

	var mouse_button := event as InputEventMouseButton
	if mouse_button == null or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_button.pressed:
		if _button_pressed or not _can_start_drag():
			return
		_button_pressed = true
		_previous_mouse_position = host_node.get_viewport().get_mouse_position()
		emit_signal("drag_started", self)
		get_viewport().set_input_as_handled()
		return

	if not _button_pressed:
		return

	_button_pressed = false
	emit_signal("drag_ended", self)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not enabled:
		return

	if not _button_pressed:
		return

	_process_drag()


func _exit_tree() -> void:
	_button_pressed = false
	super._exit_tree()


#region  Internal Setup
func _create_drag_button(parent: Node) -> BaseButton:
	var button := Button.new()
	button.name = "DragButton"

	button.focus_mode = Control.FOCUS_NONE
	# Picking skips this sensor, so buttons and fields on the host still receive the click.
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- Anchor to center ---
	button.anchor_left = 0.5
	button.anchor_top = 0.5
	button.anchor_right = 0.5
	button.anchor_bottom = 0.5

	# --- Size ---
	button.custom_minimum_size = drag_button_size
	button.size = drag_button_size

	# --- Offset to center ---
	button.offset_left = -drag_button_size.x * 0.5
	button.offset_top = -drag_button_size.y * 0.5
	button.offset_right = drag_button_size.x * 0.5
	button.offset_bottom = drag_button_size.y * 0.5

	# --- Pivot (for scale / rotation) ---
	button.pivot_offset = drag_button_size * 0.5

	# --- Draw order ---
	button.z_index = drag_button_z_index
	button.z_as_relative = false

	parent.add_child(button)

	return button


func _resolve_drag_button() -> void:
	if not drag_button:
		drag_button = _create_drag_button(host_node)

	_update_drag_button_alpha()
#endregion

#region Drag Logic (sensor only)
func _process_drag() -> void:
	var viewport := host_node.get_viewport()
	if not viewport:
		return

	var current_mouse_position := viewport.get_mouse_position()
	var delta := current_mouse_position - _previous_mouse_position
	_previous_mouse_position = current_mouse_position

	if auto_drag:
		apply_drag(delta)

	emit_signal("drag_moved", self, delta)
#endregion

#region Hit testing
func _can_start_drag() -> bool:
	var host := host_node as Control
	if host == null or not host.is_visible_in_tree():
		return false
	if not drag_button.get_global_rect().has_point(drag_button.get_global_mouse_position()):
		return false

	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null or hovered == drag_button or hovered == host:
		return true
	if not host.is_ancestor_of(hovered):
		return false
	return not _control_takes_pointer(hovered)


func _control_takes_pointer(control: Control) -> bool:
	var current := control
	while current != null and current != host_node:
		if current is ScrollContainer or current is SplitContainer:
			return true
		if not current is Container and current.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return true
		current = current.get_parent() as Control
	return false
#endregion

#region Helpers
func _update_drag_button_alpha() -> void:
	if not drag_button:
		return

	var alpha := drag_button_hidden_alpha if hide_drag_button else drag_button_visible_alpha
	drag_button.modulate.a = alpha
#endregion
