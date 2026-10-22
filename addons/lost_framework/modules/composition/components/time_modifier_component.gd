extends Component
class_name TimeModifierComponent

#region ENUMS

enum Mode {
	ADD,
	MULTIPLY,
}

#endregion


#region EXPORTS

@export var mode: Mode = Mode.MULTIPLY
@export var value: float = 1.0

#endregion


#region STATE

## TimeScaleComponent -> true
var _applied_to: Dictionary = {}

#endregion


#region PUBLIC API

func apply_to(time_scale: TimeScaleComponent) -> void:
	if not time_scale:
		return

	if _applied_to.has(time_scale):
		return

	_applied_to[time_scale] = true
	_apply_effect(time_scale)


func remove_from(time_scale: TimeScaleComponent) -> void:
	if not _applied_to.has(time_scale):
		return

	_remove_effect(time_scale)
	_applied_to.erase(time_scale)


func remove_all() -> void:
	for time_scale in _applied_to.keys():
		_remove_effect(time_scale)

	_applied_to.clear()

#endregion


#region INTERNAL LOGIC

func _apply_effect(time_scale: TimeScaleComponent) -> void:
	match mode:
		Mode.ADD:
			time_scale.time_scale += value
		Mode.MULTIPLY:
			time_scale.time_scale *= value


func _remove_effect(time_scale: TimeScaleComponent) -> void:
	match mode:
		Mode.MULTIPLY:
			if value != 0.0:
				time_scale.time_scale /= value
		Mode.ADD:
			time_scale.time_scale -= value

#endregion


#region LIFECYCLE SAFETY

func _exit_tree() -> void:
	remove_all()
	super._exit_tree()

#endregion
