extends CommandDef
class_name DialogueCommandDef
## ask, tell and talk: the object's [FictionDialogueComponent] picks a
## [FictionTopic] from the words after the person (see [member CommandMatch.topic]).


func _default_messages() -> Dictionary:
	var result := super()
	result.merge({
		&"no_dialogue": "You can't talk to the {object}.",
		&"no_topic": "The {object} has nothing to say about that.",
		&"need_topic": "What do you want to talk to the {object} about?",
	}, true)
	return result


func execute(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	return _execute_each_object(m, actor, world)


func _execute_object(object: Entity, m: CommandMatch, actor: Entity, world: FictionWorld) -> FictionEvent:
	var dialogue := object.get_component(FictionDialogueComponent) as FictionDialogueComponent
	if dialogue == null:
		return _event(&"no_dialogue", m, actor, false, object)
	var topic_text := TextNormalizer.normalize(m.topic)
	var topic := dialogue.find_topic(id, topic_text, actor, world)
	if topic == null:
		var key := &"need_topic" if topic_text.is_empty() else &"no_topic"
		return _event(key, m, actor, false, object)
	var index := dialogue.topics.find(topic)
	if topic.once:
		object.set_value(topic.done_key(index), true)
	for effect in topic.effects:
		if effect:
			effect.apply(m, actor, world, object)
	if topic.text.is_empty():
		return null
	var locale := _locale_of(m)
	var values := _message_values(m, actor, object)
	var source := LocaleText.translate(topic.text, locale)
	if source.is_empty():
		source = topic.text
	var event := FictionEvent.new(source.format(values), actor, true, &"topic", id)
	event.object = object
	event.template = topic.text
	event.values = values
	event.locale = locale
	event.visibility = FictionEvent.Visibility.ROOM
	var here := actor.get_location() if actor else null
	event.location_id = here.get_id() if here else &""
	return event
