## This component is specifically for UI elements.
extends Component
class_name UIComponent


func _handle_host() -> void:
	if _is_parent_control():
		set_host(get_parent())
		return
	assert(_is_parent_control(), "UIComponent can only be attached to Control nodes.")


## Returns whether the host node is a Control.
func _is_parent_control() -> bool:
	return get_parent() is Control
