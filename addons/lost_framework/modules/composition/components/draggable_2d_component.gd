extends Component
class_name Dragable2DComponent


signal drag_started(component: Dragable2DComponent)
signal drag_moved(component: Dragable2DComponent, delta: Vector2)
signal drag_ended(component: Dragable2DComponent)


@export var auto_drag: bool = true
@export var can_drag: bool = true
@export var sensor: Area2D
@export var drag_button: MouseButton = MOUSE_BUTTON_LEFT
@export var block_by_physics_collision: bool = true
@export_enum("None", "All Directions", "Downward Only") var collision_block_mode: int = 1
@export_range(1, 16, 1) var collision_sweep_iterations: int = 8
@export var drag_gravity_scale: float = 0.0
@export var bring_to_front_while_dragging: bool = true
@export var drag_front_z_index: int = 4096
@export var normalize_rotation_on_drag_start: bool = true
@export var normalize_rotation_after_drag: bool = true
@export var normal_rotation_degrees: float = 0.0
@export_range(0.0, 720.0, 1.0) var rotation_recover_speed_degrees: float = 240.0
@export var snap_rotation_threshold_degrees: float = 1.0
@export var enable_throw_on_release: bool = true
@export_range(0.0, 5000.0, 1.0) var min_throw_speed: float = 80.0
@export_range(0.0, 5.0, 0.01) var throw_linear_multiplier: float = 1.0
@export_range(0.0, 5000.0, 1.0) var max_throw_speed: float = 1800.0
@export_range(0.0, 1.0, 0.01) var throw_velocity_smoothing: float = 0.35

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _previous_host_position: Vector2 = Vector2.ZERO
var _host_was_frozen_before_drag: bool = false
var _host_freeze_mode_before_drag: RigidBody2D.FreezeMode = RigidBody2D.FREEZE_MODE_STATIC
var _host_gravity_scale_before_drag: float = 1.0
var _host_z_index_before_drag: int = 0
var _host_z_as_relative_before_drag: bool = true
var _recovering_rotation: bool = false
var _drag_linear_velocity: Vector2 = Vector2.ZERO


func set_can_drag(value: bool) -> void:
	can_drag = value
	if not can_drag and _dragging:
		stop_drag()


func apply_drag(target_global_position: Vector2) -> void:
	var host_2d := get_host()  as Node2D
	if not host_2d:
		return

	var current_global_position := host_2d.global_position
	var motion := target_global_position - current_global_position
	if motion == Vector2.ZERO:
		return

	var should_block_by_collision := block_by_physics_collision and collision_block_mode != 0
	if should_block_by_collision and collision_block_mode == 2 and motion.y <= 0.0:
		should_block_by_collision = false

	if not should_block_by_collision:
		host_2d.global_position = target_global_position
		return

	var host_body := host_2d as PhysicsBody2D
	if not host_body:
		host_2d.global_position = target_global_position
		return

	# Sweep in small steps to get the farthest safe movement without tunneling through masked bodies.
	if not host_body.test_move(host_body.global_transform, motion):
		host_2d.global_position = target_global_position
		return

	var steps := maxi(collision_sweep_iterations, 1)
	var step_motion := motion / float(steps)
	for _i in range(steps):
		if host_body.test_move(host_body.global_transform, step_motion):
			break
		host_2d.global_position += step_motion


func _setup() -> void:
	if not enabled:
		return

	_resolve_sensor()
	_connect_signals()


func _physics_process(delta: float) -> void:
	if not enabled:
		return

	if _dragging:
		_process_drag(delta)
		if _recovering_rotation:
			_recover_rotation(delta)
		return

	if not _recovering_rotation:
		return

	_recover_rotation(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if not _dragging:
		return


	if event is InputEventMouseButton and event.button_index == drag_button and not event.pressed:
		stop_drag()


func _exit_tree() -> void:
	_disconnect_signals()
	super._exit_tree()


func _resolve_sensor() -> void:
	if sensor:
		return

	if get_host() is Area2D:
		sensor = get_host() 
		return

	for child: Node in get_host().get_children():
		if child is Area2D:
			sensor = child
			return


func _connect_signals() -> void:
	if not sensor:
		push_warning("Dragable2DComponent requires an Area2D sensor to detect drag input.")
		return

	if not sensor.input_event.is_connected(_on_sensor_input_event):
		sensor.input_event.connect(_on_sensor_input_event)

	sensor.input_pickable = true


func _disconnect_signals() -> void:
	if not sensor:
		return

	if sensor.input_event.is_connected(_on_sensor_input_event):
		sensor.input_event.disconnect(_on_sensor_input_event)


func _process_drag(delta_time: float) -> void:
	var host_2d := get_host()  as Node2D
	if not host_2d:
		return

	var mouse_global_position := host_2d.get_global_mouse_position()
	var target_global_position := mouse_global_position + _drag_offset

	if auto_drag:
		apply_drag(target_global_position)

	var current_position := host_2d.global_position if auto_drag else target_global_position
	var delta := current_position - _previous_host_position
	_previous_host_position = current_position
	var safe_delta := maxf(delta_time, 0.0001)
	var instant_velocity := delta / safe_delta
	var smooth_weight := clampf(throw_velocity_smoothing, 0.0, 1.0)
	_drag_linear_velocity = _drag_linear_velocity.lerp(instant_velocity, smooth_weight)

	emit_signal("drag_moved", self, delta)


func _on_sensor_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not enabled:
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index != drag_button:
		return

	if event.pressed:
		if not can_drag:
			return
		_start_drag()
	else:
		stop_drag()


func _start_drag() -> void:
	var host_2d := get_host()  as Node2D
	if not host_2d:
		push_warning("Dragable2DComponent host must be Node2D.")
		return
	_recovering_rotation = normalize_rotation_on_drag_start

	_host_z_index_before_drag = host_2d.z_index
	_host_z_as_relative_before_drag = host_2d.z_as_relative

	if bring_to_front_while_dragging:
		host_2d.z_as_relative = false
		host_2d.z_index = drag_front_z_index

	var host_body := host_2d as RigidBody2D
	if host_body:
		_host_was_frozen_before_drag = host_body.freeze
		_host_freeze_mode_before_drag = host_body.freeze_mode
		_host_gravity_scale_before_drag = host_body.gravity_scale
		host_body.freeze = true
		host_body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		host_body.gravity_scale = drag_gravity_scale
		host_body.sleeping = false
		host_body.linear_velocity = Vector2.ZERO
		host_body.angular_velocity = 0.0

	_dragging = true
	_drag_offset = host_2d.global_position - host_2d.get_global_mouse_position()
	_previous_host_position = host_2d.global_position
	_drag_linear_velocity = Vector2.ZERO
	emit_signal("drag_started", self)


func stop_drag(recover_rotation := false) -> void:
	if not _dragging:
		return

	var host_2d := get_host() as Node2D
	if host_2d:
		host_2d.z_index = _host_z_index_before_drag
		host_2d.z_as_relative = _host_z_as_relative_before_drag

	var host_body := get_host() as RigidBody2D
	var applied_throw := false
	if host_body:
		host_body.gravity_scale = _host_gravity_scale_before_drag
		host_body.freeze_mode = _host_freeze_mode_before_drag
		host_body.freeze = _host_was_frozen_before_drag
		host_body.sleeping = false
		if enable_throw_on_release and not _host_was_frozen_before_drag:
			var throw_velocity := _drag_linear_velocity * throw_linear_multiplier
			var throw_speed := throw_velocity.length()
			if throw_speed > max_throw_speed and max_throw_speed > 0.0:
				throw_velocity = throw_velocity.normalized() * max_throw_speed
				throw_speed = max_throw_speed

			if throw_speed >= min_throw_speed:
				host_body.linear_velocity = throw_velocity
				host_body.angular_velocity = 0.0
				applied_throw = true

		if not applied_throw:
			host_body.linear_velocity = Vector2.ZERO
			host_body.angular_velocity = 0.0

	_dragging = false
	_recovering_rotation = recover_rotation and (not applied_throw) and (_recovering_rotation or normalize_rotation_after_drag)
	emit_signal("drag_ended", self)


func _recover_rotation(delta: float) -> void:
	var host_2d := get_host()  as Node2D
	if not host_2d:
		_recovering_rotation = false
		return

	var target_angle := deg_to_rad(normal_rotation_degrees)
	var current_angle := host_2d.global_rotation
	var max_step := deg_to_rad(rotation_recover_speed_degrees) * maxf(delta, 0.0)
	var next_angle := rotate_toward(current_angle, target_angle, max_step)

	var angle_error := absf(wrapf(target_angle - current_angle, -PI, PI))
	var snap_threshold := deg_to_rad(maxf(snap_rotation_threshold_degrees, 0.0))
	var should_snap := angle_error <= snap_threshold

	var host_body := get_host()  as RigidBody2D
	if host_body:
		var safe_delta := maxf(delta, 0.0001)
		var angle_velocity := wrapf(next_angle - current_angle, -PI, PI) / safe_delta
		host_body.angular_velocity = angle_velocity
		host_body.global_rotation = next_angle
		if should_snap:
			host_body.global_rotation = target_angle
			host_body.angular_velocity = 0.0
			_recovering_rotation = false
		return

	host_2d.global_rotation = next_angle
	if should_snap:
		host_2d.global_rotation = target_angle
		_recovering_rotation = false
