extends Component
class_name LookAtTargetComponent

## Rotation speed (radians per second)
@export var rotation_speed: float = 8.0

## Optional sprite or node to rotate.
## If empty, rotate host.
@export var rotate_node_path: NodePath

var time_scale_comp: TimeScaleComponent
var targeting_comp: TargetingComponent
var rotate_node: Node2D



func _setup() -> void:
	super._setup()
	
	time_scale_comp = get_host_component(TimeScaleComponent)
	targeting_comp = get_host_component(TargetingComponent)

	if rotate_node_path != NodePath():
		rotate_node = get_host().get_node_or_null(rotate_node_path)
	else:
		rotate_node = get_host()

	if not targeting_comp or not rotate_node:
		set_enabled(false)


func _physics_process(delta: float) -> void:
	if not is_enabled():
		return

	var target: Node2D = targeting_comp.get_target()
	if not target:
		return

	var to_target: Vector2 = target.global_position - rotate_node.global_position
	if to_target == Vector2.ZERO:
		return

	var desired_angle: float = to_target.angle()

	var time_scale: float = 1.0
	if time_scale_comp:
		time_scale = time_scale_comp.time_scale

	rotate_node.rotation = lerp_angle(
		rotate_node.rotation,
		desired_angle,
		rotation_speed * time_scale * delta
	)


func supports_preview() -> bool:
	return true
