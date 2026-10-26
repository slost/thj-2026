extends CommandDef
class_name SaveCommandDef
## Saves the world's plain state to [member FictionWorld.save_path].


func _default_messages() -> Dictionary:
	var result := super()
	result.merge({
		&"saved": "Saved.",
		&"save_failed": "Could not save.",
	}, true)
	return result


func execute(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	if world and world.save_to_file():
		return _events([_event(&"saved", m, actor, true)])
	return _events([_event(&"save_failed", m, actor, false)])
