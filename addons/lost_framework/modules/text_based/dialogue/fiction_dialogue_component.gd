extends Component
class_name FictionDialogueComponent
## Topics the host entity can discuss (see [FictionTopic]). ask, tell and talk
## look here.


@export var topics: Array[FictionTopic] = []


## The first topic that answers [param command_id], matches [param topic_text]
## and whose conditions hold. [param topic_text] is normalized by the caller
## when it is not empty; pass "" for a greeting.
func find_topic(command_id: StringName, topic_text: String, actor: Entity, world: FictionWorld) -> FictionTopic:
	var host := get_host() as Entity
	var context: Object = world.make_condition_context_for(host, actor) if world and host else null
	var values: Dictionary = host.get_values() if host else {}
	for i in topics.size():
		var topic := topics[i]
		if topic == null or not topic.answers(command_id) or not topic.matches_text(topic_text):
			continue
		if topic.once and host and host.get_value(topic.done_key(i), false):
			continue
		if not ValueCondition.all_hold(topic.conditions, values, context):
			continue
		return topic
	return null
