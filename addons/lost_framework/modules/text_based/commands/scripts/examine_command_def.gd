extends CommandDef
class_name ExamineCommandDef
## "examine box", "look box": the object's description, what is visible
## inside it, and for the actor itself ("look me") what it carries.


func _default_messages() -> Dictionary:
	var result := super()
	result.merge({
		&"no_description": "You see nothing special about the {object}.",
		&"contents": "The {object} contains: {list}.",
		&"is_closed": "The {object} is closed.",
		&"carrying": "You are carrying: {list}.",
		&"empty_handed": "You are empty-handed.",
	}, true)
	return result


func execute(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	var result: Array[FictionEvent] = []
	for object in m.objects:
		var events := _describe(object, m, actor)
		if m.objects.size() > 1 and not events.is_empty():
			events[0].text = "%s: %s" % [object.get_display_name(_locale_of(m)), events[0].text]
		result.append_array(events)
	return result


func _describe(object: Entity, m: CommandMatch, actor: Entity) -> Array[FictionEvent]:
	var result: Array[FictionEvent] = []
	var text := object.get_description()
	if not text.is_empty():
		result.append(FictionEvent.new(text, actor, true, &"description", id))
	elif object != actor:
		result.append(_event(&"no_description", m, actor, true, object))

	if object == actor:
		result.append(InventoryCommandDef.carried_event(self, m, actor))
		return result
	if object.get_component(LocationComponent):
		return result # A place: "look" describes it

	var openable := object.get_component(OpenableComponent) as OpenableComponent
	var inside := object.get_contents()
	if openable and not openable.is_open:
		result.append(_event(&"is_closed", m, actor, true, object))
	elif not inside.is_empty():
		result.append(_event(&"contents", m, actor, true, object, {"list": _list_names(inside, _locale_of(m))}))
	return result
