## Base class for objects that can be interacted with.
extends Node
class_name Interactable


signal interacted(context: InteractionContext)

var is_interactable: bool = true # Whether interaction is currently enabled.


## The first gate for interaction, by checking if the can_interact() function returns true.
## If the interaction is successful, calls the _on_interact() function and emits the interacted signal.
func try_interact(context: InteractionContext) -> bool:
	if not is_interactable:
		return false

	if not can_interact(context):
		return false

	_on_interact(context)
	interacted.emit(context)
	return true


## The condition for interaction, override to define interaction conditions.
func can_interact(context: InteractionContext) -> bool:
	return true


## The interaction behavior, override to define the interaction behavior.
func _on_interact(context: InteractionContext) -> void:
	pass