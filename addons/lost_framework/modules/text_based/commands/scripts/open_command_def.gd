extends CommandDef
class_name OpenCommandDef
## "open box": opens an [OpenableComponent] that is not locked.
## "open door with key": a locked [LockableComponent] is unlocked with the
## key first (same key rules as [UnlockCommandDef]). Without a key a locked
## thing stays shut; a carried key is not used on its own.


func _default_messages() -> Dictionary:
	var result := super()
	result.merge({
		&"opened": "You open the {object}.",
		&"opened_revealing": "You open the {object}, revealing: {list}.", # {list}: what is inside
		&"unlock_and_open": "You unlock the {object} with the {target} and open it.",
		&"not_openable": "You can't open the {object}.",
		&"already_open": "The {object} is already open.",
		&"locked": "The {object} is locked.",
		&"cant_open_with": "You can't open the {object} with the {target}.",
		&"key_not_carried": "You don't have the {target}.",
		&"wrong_key": "The {target} doesn't fit the {object}.",
	}, true)
	return result


func _seen_messages() -> Dictionary:
	return {
		&"opened_seen": "{actor} opens the {object}.",
		&"opened_revealing_seen": "{actor} opens the {object}, revealing: {list}.",
		&"unlock_and_open_seen": "{actor} unlocks the {object} with the {target} and opens it.",
	}


func execute(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	return _execute_each_object(m, actor, world)


func _execute_object(object: Entity, m: CommandMatch, actor: Entity, world: FictionWorld) -> FictionEvent:
	var openable := object.get_component(OpenableComponent) as OpenableComponent
	if openable == null:
		return _event(&"not_openable", m, actor, false, object)
	if openable.is_open:
		return _event(&"already_open", m, actor, false, object)
	var unlocked := false
	if m.target:
		var lockable := object.get_component(LockableComponent) as LockableComponent
		if lockable == null:
			return _event(&"cant_open_with", m, actor, false, object)
		var problem := UnlockCommandDef.check_key(lockable, m.target, actor)
		if problem == &"wrong_key" and not lockable.is_locked:
			problem = &"cant_open_with" # Not a key for it, and no lock to try it on
		if problem != &"":
			return _event(problem, m, actor, false, object)
		if lockable.is_locked:
			lockable.unlock(m.target)
			unlocked = true
	if not openable.open():
		return _event(&"locked", m, actor, false, object)
	if unlocked:
		return _event(&"unlock_and_open", m, actor, true, object)
	var inside := object.get_contents()
	if not inside.is_empty() and object.get_component(LocationComponent) == null:
		return _event(&"opened_revealing", m, actor, true, object, {"list": _list_names(inside, _locale_of(m))})
	return _event(&"opened", m, actor, true, object)
