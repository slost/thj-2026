extends CommandDef
class_name UndoCommandDef
## Restores the world to the state before the last change.


func _default_messages() -> Dictionary:
	var result := super()
	result.merge({
		&"undone": "Undone.",
		&"nothing_to_undo": "Nothing to undo.",
	}, true)
	return result


func execute(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	if world and world.undo_last():
		return _events([_event(&"undone", m, actor, true)])
	return _events([_event(&"nothing_to_undo", m, actor, false)])
