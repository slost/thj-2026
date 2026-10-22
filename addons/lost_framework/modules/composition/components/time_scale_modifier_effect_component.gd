extends AuraEffectComponent
class_name TimeScaleModifierEffectComponent

#region EXPORTS
@export var mode: TimeModifierComponent.Mode = TimeModifierComponent.Mode.MULTIPLY
@export var value: float = 1.0
#endregion

#region STATE
## target -> applied TimeModifierComponent
var _applied: Dictionary = {}
#endregion

#region HOOKS
func _on_first_stack_applied(target: Node) -> void:
	var time_scale: TimeScaleComponent = Utils.get_component(target, TimeScaleComponent)
	if not time_scale:
		return

	var modifier: TimeModifierComponent = TimeModifierComponent.new()
	modifier.mode = mode
	modifier.value = value

	# Apply modifier using existing API
	modifier.apply_to(time_scale)

	_applied[target] = modifier


func _on_stack_changed(target: Node, stacks: int) -> void:
	if not _applied.has(target):
		return

	var modifier: TimeModifierComponent = _applied[target]

	match mode:
		TimeModifierComponent.Mode.MULTIPLY:
			modifier.value = pow(value, stacks)
		TimeModifierComponent.Mode.ADD:
			modifier.value = value * stacks
		_:
			modifier.value = value

	modifier.apply_to(Utils.get_component(target, TimeScaleComponent))


func _on_last_stack_removed(target: Node) -> void:
	if not _applied.has(target):
		return

	var modifier: TimeModifierComponent = _applied[target]
	var time_scale: TimeScaleComponent = Utils.get_component(target, TimeScaleComponent)

	if time_scale:
		modifier.remove_from(time_scale)

	_applied.erase(target)
#endregion
