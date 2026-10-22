## A component that listens to MouseSensor (Area2D) and emits position-based interaction requests.
## Universal for any system that needs a world position from pointer interaction.
extends Component
class_name AreaPointerInputComponent


signal position_entered(global_pos: Vector2)
signal position_exited(global_pos: Vector2)
signal position_pressed(global_pos: Vector2)
signal position_released(global_pos: Vector2)
signal position_clicked(global_pos: Vector2)
signal position_long_pressed(global_pos: Vector2)

@export var sensor: Area2D
@export var button: MouseButton = MOUSE_BUTTON_LEFT
@export var long_press_duration: float = 0.5

var _is_entered: bool = false
var _is_pressed: bool = false
var _long_press_active: bool = false
var _press_position: Vector2

var _long_press_timer: Timer


#region Setup
func _setup() -> void:
	if not sensor:
		sensor = get_host() as Area2D

	if not sensor:
		return

	_long_press_timer = Timer.new()
	_long_press_timer.one_shot = true
	_long_press_timer.wait_time = long_press_duration
	add_child(_long_press_timer)

	_long_press_timer.timeout.connect(_on_long_press_timeout)

	sensor.input_event.connect(_on_input_event)
	sensor.mouse_entered.connect(_on_mouse_entered)
	sensor.mouse_exited.connect(_on_mouse_exited)

#endregion


#region Input
func _on_mouse_entered() -> void:
	if not is_enabled():
		return

	_is_entered = true
	position_entered.emit(sensor.get_global_mouse_position())


func _on_mouse_exited() -> void:
	if not is_enabled():
		return

	_is_entered = false
	position_exited.emit(sensor.get_global_mouse_position())


func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not is_enabled():
		return

	if not event is InputEventMouseButton:
		return

	var mb := event as InputEventMouseButton

	if mb.button_index != button or mb.is_echo():
		return

	if mb.pressed:
		_is_pressed = true
		_long_press_active = false
		_press_position = mb.global_position

		position_pressed.emit(mb.global_position)
		_long_press_timer.start()
	else:
		_is_pressed = false
		_long_press_timer.stop()

		position_released.emit(mb.global_position)

		if not _long_press_active:
			position_clicked.emit(mb.global_position)

#endregion


#region Long Press
func _on_long_press_timeout() -> void:
	if not _is_pressed:
		return

	_long_press_active = true
	position_long_pressed.emit(_press_position)

#endregion
