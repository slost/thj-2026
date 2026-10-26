extends CommandDef
class_name PutCommandDef
## "put sword in box": moves a carried entity into the target, which needs a
## [ContainerComponent] and must not be closed.


func _default_messages() -> Dictionary:
	var result := super()
	result.merge({
		&"put": "You put the {object} in the {target}.",
		&"not_carried": "You don't have the {object}.",
		&"not_container": "You can't put things in the {target}.",
		&"container_closed": "The {target} is closed.",
		&"put_in_itself": "You can't put the {object} inside itself.",
		&"put_on": "You put the {object} on the {target}.",
		&"not_supporter": "You can't put things on the {target}.",
	}, true)
	return result


func _seen_messages() -> Dictionary:
	return {
		&"put_seen": "{actor} puts the {object} in the {target}.",
		&"put_on_seen": "{actor} puts the {object} on the {target}.",
	}


func execute(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	return _execute_each_object(m, actor, world)


func _execute_object(object: Entity, m: CommandMatch, actor: Entity, world: FictionWorld) -> FictionEvent:
	var target := m.target
	if target == null:
		return _event(&"cant_do", m, actor, false, object)
	if object == target or object.is_ancestor_of(target):
		return _event(&"put_in_itself", m, actor, false, object)
	if object == actor or not CommandMatcher.is_carried(object, actor):
		return _event(&"not_carried", m, actor, false, object)
	if m.preposition == &"on":
		var supporter := target.get_component(SupporterComponent) as SupporterComponent
		if supporter == null:
			return _event(&"not_supporter", m, actor, false, object)
		if not supporter.is_accessible():
			return _event(&"container_closed", m, actor, false, object)
		object.reparent(target)
		return _event(&"put_on", m, actor, true, object)
	var container := target.get_component(ContainerComponent) as ContainerComponent
	if container == null:
		return _event(&"not_container", m, actor, false, object)
	if not container.is_accessible():
		return _event(&"container_closed", m, actor, false, object)
	object.reparent(target)
	return _event(&"put", m, actor, true, object)
