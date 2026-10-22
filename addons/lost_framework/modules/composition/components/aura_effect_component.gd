extends Component
class_name AuraEffectComponent

#region EXPORTS
## Maximum number of stacks allowed (0 = infinite)
@export var max_stacks: int = 0
#endregion

#region STATE
## target -> stack count
var _stacks: Dictionary = {}
#endregion

#region PUBLIC API
## Called by AuraEmitter when a target enters the aura
func apply_to(target: Node) -> void:
	if not target:
		return

	var current: int = _stacks.get(target, 0)

	if max_stacks > 0 and current >= max_stacks:
		return

	current += 1
	_stacks[target] = current

	if current == 1:
		_on_first_stack_applied(target)

	_on_stack_changed(target, current)


## Called by AuraEmitter when a target exits the aura
func remove_from(target: Node) -> void:
	if not target:
		return

	if not _stacks.has(target):
		return

	var current: int = _stacks[target]
	current -= 1

	if current <= 0:
		_stacks.erase(target)
		_on_last_stack_removed(target)
	else:
		_stacks[target] = current
		_on_stack_changed(target, current)
#endregion


#region HOOKS (OVERRIDE IN CHILD)
## Called when first stack is applied to a target
func _on_first_stack_applied(_target: Node) -> void:
	pass


## Called when stack count changes (including first apply)
func _on_stack_changed(_target: Node, _stacks: int) -> void:
	pass


## Called when last stack is removed from a target
func _on_last_stack_removed(_target: Node) -> void:
	pass
#endregion
