extends Component
class_name LockableComponent
## Something that can be locked. Reports the value "locked".
## If [member key_id] is set, only the entity with that id unlocks it.


signal locked
signal unlocked

@export var is_locked := true
@export var key_id := &"" ## Entity id of the key. Empty means no key is needed.


func can_unlock_with(key: Entity) -> bool:
	if key_id == &"":
		return true
	return key != null and key.get_id() == key_id


## Returns true if it is unlocked afterwards.
func unlock(key: Entity = null) -> bool:
	if not is_locked:
		return true
	if not can_unlock_with(key):
		return false
	is_locked = false
	unlocked.emit()
	return true


func lock(key: Entity = null) -> bool:
	if is_locked:
		return true
	if not can_unlock_with(key):
		return false
	is_locked = true
	locked.emit()
	return true


func _state_values() -> Dictionary:
	return {&"locked": is_locked}


func _set_state_value(key: StringName, value: Variant) -> bool:
	if key != &"locked":
		return false
	if bool(value) != is_locked:
		is_locked = bool(value)
		(locked if is_locked else unlocked).emit()
	return true
