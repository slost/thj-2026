extends CommandDef
class_name UnlockCommandDef
## "unlock door with key": unlocks a [LockableComponent]. The key is the
## target; without one, a carried entity whose id is
## [member LockableComponent.key_id] is used. A lockable with no key_id
## needs no key.


func _default_messages() -> Dictionary:
	var result := super()
	result.merge({
		&"unlocked": "You unlock the {object}.",
		&"unlocked_with": "You unlock the {object} with the {target}.",
		&"not_lockable": "You can't unlock the {object}.",
		&"already_unlocked": "The {object} isn't locked.",
		&"need_key": "You need a key to unlock the {object}.",
		&"key_not_carried": "You don't have the {target}.",
		&"wrong_key": "The {target} doesn't fit the {object}.",
	}, true)
	return result


func _seen_messages() -> Dictionary:
	return {
		&"unlocked_seen": "{actor} unlocks the {object}.",
		&"unlocked_with_seen": "{actor} unlocks the {object} with the {target}.",
	}


func execute(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	return _execute_each_object(m, actor, world)


func _execute_object(object: Entity, m: CommandMatch, actor: Entity, world: FictionWorld) -> FictionEvent:
	var lockable := object.get_component(LockableComponent) as LockableComponent
	if lockable == null:
		return _event(&"not_lockable", m, actor, false, object)
	if not lockable.is_locked:
		return _event(&"already_unlocked", m, actor, false, object)
	var key := m.target
	if key:
		var problem := UnlockCommandDef.check_key(lockable, key, actor)
		if problem != &"":
			return _event(problem, m, actor, false, object)
	elif lockable.key_id != &"":
		key = find_carried_key(lockable, actor, world)
		if key == null:
			return _event(&"need_key", m, actor, false, object)
	lockable.unlock(key)
	if key:
		return _event(&"unlocked_with", m, actor, true, object, {"target": key.get_display_name(_locale_of(m))})
	return _event(&"unlocked", m, actor, true, object)


## Why [param key] cannot be used on [param lockable] by [param actor]:
## &"key_not_carried", &"wrong_key", or &"" when it can. Shared by
## unlock, lock and "open X with key" ([OpenCommandDef]).
static func check_key(lockable: LockableComponent, key: Entity, actor: Entity) -> StringName:
	if not CommandMatcher.is_carried(key, actor):
		return &"key_not_carried"
	if not lockable.can_unlock_with(key):
		return &"wrong_key"
	return &""


## A key for [param lockable] that [param actor] carries and can reach
## (not inside something closed), or null.
static func find_carried_key(lockable: LockableComponent, actor: Entity, world: FictionWorld) -> Entity:
	if lockable.key_id == &"" or actor == null:
		return null
	var reachable: Array[Entity] = world.get_scope(actor) if world else actor.get_contents()
	for entity in reachable:
		if entity.get_id() == lockable.key_id and CommandMatcher.is_carried(entity, actor):
			return entity
	return null
