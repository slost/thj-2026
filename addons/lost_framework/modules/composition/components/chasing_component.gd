extends Component
class_name ChasingComponent


var time_scale_comp: TimeScaleComponent
var targeting_comp: TargetingComponent
var speed_comp: SpeedComponent


func _setup() -> void:
	super._setup()
	time_scale_comp = get_host_component(TimeScaleComponent)
	targeting_comp = get_host_component(TargetingComponent)
	speed_comp = get_host_component(SpeedComponent)


func _physics_process(delta: float) -> void:
	if not targeting_comp:
		return

	var target: Node2D = targeting_comp.get_target()
	if not target:
		return

	var direction: Vector2 = (target.global_position - get_host().global_position).normalized()

	var speed: float = 100.0
	if speed_comp:
		speed = speed_comp.get_speed()

	var time_scale: float = 1.0
	if time_scale_comp:
		time_scale = time_scale_comp.time_scale

	get_host().velocity = direction * speed * time_scale
	get_host().move_and_slide()
