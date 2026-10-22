extends Component
class_name SpeedComponent

#region EXPORTS

## Base speed in units per second
@export var base_speed: float = 100.0

#endregion


#region STATE

var time_scale_comp: TimeScaleComponent

#endregion


#region SETUP

func _setup() -> void:
	super._setup()
	time_scale_comp = Utils.get_component(get_host(), TimeScaleComponent)

#endregion


#region API

func get_speed() -> float:
	var speed := base_speed

	if time_scale_comp:
		speed *= time_scale_comp.time_scale

	return speed

#endregion
