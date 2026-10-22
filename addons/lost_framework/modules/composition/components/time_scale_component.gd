extends Component
class_name TimeScaleComponent


## Multiplier applied to time-dependent logic
@export var time_scale: float = 1.0


func get_scaled_delta(delta: float) -> float:
	return delta * time_scale


# func supports_preview() -> bool:
# 	return true
