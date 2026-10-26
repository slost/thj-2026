extends Component
class_name OpenableComponent
## Something that can be opened and closed (door, box, book).
## Reports the value "open". If the host also has a [LockableComponent],
## it cannot be opened while locked.


signal opened
signal closed

@export var is_open := false


func can_open() -> bool:
	var lockable := _get_lockable()
	return lockable == null or not lockable.is_locked


## Returns true if it is open afterwards.
func open() -> bool:
	if is_open:
		return true
	if not can_open():
		return false
	is_open = true
	opened.emit()
	return true


func close() -> void:
	if not is_open:
		return
	is_open = false
	closed.emit()


func _state_values() -> Dictionary:
	return {&"open": is_open}


func _set_state_value(key: StringName, value: Variant) -> bool:
	if key != &"open":
		return false
	# Direct state changes (story effects) skip the lock rule on purpose.
	if bool(value) != is_open:
		is_open = bool(value)
		(opened if is_open else closed).emit()
	return true


func _get_lockable() -> LockableComponent:
	var host := get_host()
	if host is Entity:
		return host.get_component(LockableComponent) as LockableComponent
	return null
