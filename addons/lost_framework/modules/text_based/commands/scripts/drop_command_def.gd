extends CommandDef
class_name DropCommandDef
## "drop sword": moves a carried entity to the actor's location.


func _default_messages() -> Dictionary:
	var result := super()
	result.merge({
		&"dropped": "Dropped.",
		&"not_carried": "You don't have the {object}.",
	}, true)
	return result


func _seen_messages() -> Dictionary:
	return {&"dropped_seen": "{actor} drops the {object}."}


func execute(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	return _execute_each_object(m, actor, world)


func _execute_object(object: Entity, m: CommandMatch, actor: Entity, world: FictionWorld) -> FictionEvent:
	if object == actor or not CommandMatcher.is_carried(object, actor):
		return _event(&"not_carried", m, actor, false, object)
	var place := actor.get_location()
	if place == null:
		place = actor.get_parent_entity()
	if place == null:
		return _event(&"cant_do", m, actor, false, object)
	object.reparent(place)
	return _event(&"dropped", m, actor, true, object)
