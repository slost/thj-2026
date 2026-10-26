extends CommandDef
class_name LockCommandDef
## "lock door with key": locks a [LockableComponent]. Works like
## [UnlockCommandDef]. Something open must be closed first; it is not
## closed for the player.


func _default_messages() -> Dictionary:
	var result := super()
	result.merge({
		&"locked": "You lock the {object}.",
		&"locked_with": "You lock the {object} with the {target}.",
		&"not_lockable": "You can't lock the {object}.",
		&"already_locked": "The {object} is already locked.",
		&"close_first": "You need to close the {object} first.",
		&"need_key": "You need a key to lock the {object}.",
		&"key_not_carried": "You don't have the {target}.",
		&"wrong_key": "The {target} doesn't fit the {object}.",
	}, true)
	return result


func _seen_messages() -> Dictionary:
	return {
		&"locked_seen": "{actor} locks the {object}.",
		&"locked_with_seen": "{actor} locks the {object} with the {target}.",
	}


func execute(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	return _execute_each_object(m, actor, world)


func _execute_object(object: Entity, m: CommandMatch, actor: Entity, world: FictionWorld) -> FictionEvent:
	var lockable := object.get_component(LockableComponent) as LockableComponent
	if lockable == null:
		return _event(&"not_lockable", m, actor, false, object)
	if lockable.is_locked:
		return _event(&"already_locked", m, actor, false, object)
	var openable := object.get_component(OpenableComponent) as OpenableComponent
	if openable and openable.is_open:
		return _event(&"close_first", m, actor, false, object)
	var key := m.target
	if key:
		var problem := UnlockCommandDef.check_key(lockable, key, actor)
		if problem != &"":
			return _event(problem, m, actor, false, object)
	elif lockable.key_id != &"":
		key = UnlockCommandDef.find_carried_key(lockable, actor, world)
		if key == null:
			return _event(&"need_key", m, actor, false, object)
	lockable.lock(key)
	if key:
		return _event(&"locked_with", m, actor, true, object, {"target": key.get_display_name(_locale_of(m))})
	return _event(&"locked", m, actor, true, object)
