extends Component
class_name TriggerIntervalComponent

#region EXPORTS

## Interval between triggers (seconds)
@export var interval: float = 1.0

## Trigger immediately on start
@export var trigger_on_start: bool = false

#endregion


#region STATE

var _time_left: float = 0.0
var _time_scale_comp: TimeScaleComponent

#endregion


#region SIGNALS

signal triggered

#endregion


#region SETUP

func _setup() -> void:
	super._setup()
	_time_scale_comp = Utils.get_component(get_host(), TimeScaleComponent)

	if not trigger_on_start:
		_time_left = interval
		return
	if _time_scale_comp.time_scale > 0:
		_time_left = 0.0
	elif _time_scale_comp.time_scale <= 0:
		_time_left = 0.0001

#endregion


#region PROCESS

func _physics_process(delta: float) -> void:
	var dt := delta
	if _time_scale_comp:
		dt *= _time_scale_comp.time_scale

	_time_left -= dt

	if _time_left <= 0.0:
		_time_left += interval
		triggered.emit()

#endregion


#region API

func reset() -> void:
	_time_left = interval


func can_trigger() -> bool:
	return _time_left <= 0.0

#endregion
