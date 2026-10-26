extends CommandDef
class_name CloseCommandDef
## "close box": closes an [OpenableComponent].


func _default_messages() -> Dictionary:
	var result := super()
	result.merge({
		&"closed": "You close the {object}.",
		&"not_openable": "You can't close the {object}.",
		&"already_closed": "The {object} is already closed.",
	}, true)
	return result


func _seen_messages() -> Dictionary:
	return {&"closed_seen": "{actor} closes the {object}."}


func execute(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	return _execute_each_object(m, actor, world)


func _execute_object(object: Entity, m: CommandMatch, actor: Entity, world: FictionWorld) -> FictionEvent:
	var openable := object.get_component(OpenableComponent) as OpenableComponent
	if openable == null:
		return _event(&"not_openable", m, actor, false, object)
	if not openable.is_open:
		return _event(&"already_closed", m, actor, false, object)
	openable.close()
	return _event(&"closed", m, actor, true, object)
