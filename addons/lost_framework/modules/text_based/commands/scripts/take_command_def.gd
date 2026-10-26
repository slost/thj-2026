extends CommandDef
class_name TakeCommandDef
## "take sword": moves a [PortableComponent] entity into the actor. Taking
## something from a bag the actor carries moves it to the actor's hands.


func _default_messages() -> Dictionary:
	var result := super()
	result.merge({
		&"taken": "Taken.",
		&"already_have": "You already have the {object}.",
		&"not_portable": "You can't take the {object}.",
	}, true)
	return result


func _seen_messages() -> Dictionary:
	return {&"taken_seen": "{actor} takes the {object}."}


func execute(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	return _execute_each_object(m, actor, world)


func _execute_object(object: Entity, m: CommandMatch, actor: Entity, world: FictionWorld) -> FictionEvent:
	if object == actor or object.is_ancestor_of(actor):
		return _event(&"cant_do", m, actor, false, object)
	if object.get_parent_entity() == actor:
		return _event(&"already_have", m, actor, false, object)
	if object.get_component(PortableComponent) == null:
		return _event(&"not_portable", m, actor, false, object)
	object.reparent(actor)
	return _event(&"taken", m, actor, true, object)
