extends UIComponent
class_name PickableControlComponent


#region Signals

signal pick_started(component: PickableControlComponent)
signal pick_moved(component: PickableControlComponent, position: Vector2)
signal pick_ended(component: PickableControlComponent)
signal pick_canceled(component: PickableControlComponent)

#endregion


#region Config

@export var auto_pick: bool = true

@export var pick_button_size: Vector2 = Vector2(96, 96)
@export var pick_button_z_index: int = 4096

@export var hide_pick_button: bool = true
@export var pick_button_hidden_alpha: float = 0.0
@export var pick_button_visible_alpha: float = 1.0

@export var follow_speed: float = 20.0

#endregion


#region State
var pick_button: BaseButton
var _picking: bool = false
var _start_rect: Rect2
var _hovering := false
#endregion



#region Public API

func apply_pick(target_global_position: Vector2) -> void:
	if not host_node:
		return

	var current_pos: Vector2 = host_node.global_position
	var t: float = 1.0 - exp(-follow_speed * get_process_delta_time())

	host_node.global_position = current_pos.lerp(target_global_position, t)

#endregion


#region Lifecycle

func _setup() -> void:
	super._setup()

	if get_host():
		pick_button_size = get_host().size

	call_deferred("_post_setup")


func _post_setup() -> void:
	_resolve_pick_button()
	_connect_signals()


func _process(_delta: float) -> void:
	if not enabled:
		return

	if not _picking:
		return

	_process_pick()


func _exit_tree() -> void:
	_disconnect_signals()
	super._exit_tree()

#endregion


#region Internal Setup

func _create_pick_button(parent: Control) -> BaseButton:
	var button := Button.new()
	button.name = "PickButton"

	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS

	button.anchor_left = 0.5
	button.anchor_top = 0.5
	button.anchor_right = 0.5
	button.anchor_bottom = 0.5

	button.custom_minimum_size = pick_button_size
	button.size = pick_button_size

	button.offset_left = -pick_button_size.x * 0.5
	button.offset_top = -pick_button_size.y * 0.5
	button.offset_right = pick_button_size.x * 0.5
	button.offset_bottom = pick_button_size.y * 0.5

	button.pivot_offset = pick_button_size * 0.5

	button.z_index = pick_button_z_index
	button.z_as_relative = false

	parent.add_child(button)
	return button


func _resolve_pick_button() -> void:
	if not pick_button:
		pick_button = _create_pick_button(host_node)

	_update_pick_button_alpha()


func _connect_signals() -> void:
	if not pick_button:
		return

	pick_button.button_down.connect(_on_pick_button_down)
	pick_button.button_up.connect(_on_pick_button_up)
	pick_button.mouse_entered.connect(_on_pick_button_mouse_entered)
	pick_button.mouse_exited.connect(_on_pick_button_mouse_exited)


func _disconnect_signals() -> void:
	if not pick_button:
		return

	if pick_button.button_down.is_connected(_on_pick_button_down):
		pick_button.button_down.disconnect(_on_pick_button_down)
	if pick_button.button_up.is_connected(_on_pick_button_up):
		pick_button.button_up.disconnect(_on_pick_button_up)
	if pick_button.mouse_entered.is_connected(_on_pick_button_mouse_entered):
		pick_button.mouse_entered.disconnect(_on_pick_button_mouse_entered)
	if pick_button.mouse_exited.is_connected(_on_pick_button_mouse_exited):
		pick_button.mouse_exited.disconnect(_on_pick_button_mouse_exited)

#endregion


#region Pick Logic

func _process_pick() -> void:
	var mouse_pos: Vector2 = host_node.get_global_mouse_position()
	var target_pos: Vector2 = mouse_pos - host_node.size * 0.5

	if auto_pick:
		apply_pick(target_pos)

	emit_signal("pick_moved", self, target_pos)

#endregion


#region Signal Handlers

func _on_pick_button_down() -> void:
	if not enabled:
		return

	_picking = true

	# Save original screen rect for cancel detection
	_start_rect = pick_button.get_global_rect()

	# Force absolute positioning
	host_node.anchor_left = 0.0
	host_node.anchor_top = 0.0
	host_node.anchor_right = 0.0
	host_node.anchor_bottom = 0.0

	emit_signal("pick_started", self)


func _on_pick_button_up() -> void:
	if not enabled:
		return

	_picking = false

	var mouse_pos: Vector2 = host_node.get_global_mouse_position()

	if _start_rect.has_point(mouse_pos):
		emit_signal("pick_canceled", self)
	else:
		emit_signal("pick_ended", self)



func _on_pick_button_mouse_entered() -> void:
	if not enabled:
		return

	_hovering = true


func _on_pick_button_mouse_exited() -> void:
	_hovering = false

#endregion


#region Helper

func _update_pick_button_alpha() -> void:
	if not pick_button:
		return

	var alpha: float = pick_button_hidden_alpha if hide_pick_button else pick_button_visible_alpha
	pick_button.modulate.a = alpha

#endregion
