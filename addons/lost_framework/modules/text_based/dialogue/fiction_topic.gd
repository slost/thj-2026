extends Resource
class_name FictionTopic
## One thing an entity can be asked, told or talked to about. Held by a
## [FictionDialogueComponent]. Keywords are matched in any language; an empty
## list is the greeting, used when the player names no subject.


@export var id := &""
## Command ids it answers, e.g. [&"ask"]. Empty answers ask, tell and talk.
@export var command_ids: Array[StringName] = []
## Words that select it ("moth", "ผีเสื้อ"). Any one match is enough.
@export var keywords: PackedStringArray = []
## Shown when it is chosen. Placeholders: {actor}, {object}. Passed through translation.
@export_multiline var text := ""
@export var conditions: Array[ValueCondition] = []
@export var effects: Array[FictionEffect] = []
@export var once := false
## Stable name for the "once" state key. Empty uses [member id], then the list index.
@export var key := &""


func answers(command_id: StringName) -> bool:
	return command_ids.is_empty() or command_ids.has(command_id)


## True if [param topic_text] (already normalized, may be empty) selects this topic.
func matches_text(topic_text: String) -> bool:
	if keywords.is_empty():
		return topic_text.is_empty()
	if topic_text.is_empty():
		return false
	for word in keywords:
		var keyword := TextNormalizer.normalize(word)
		if keyword.is_empty():
			continue
		if topic_text == keyword or topic_text.contains(keyword):
			return true
	return false


func done_key(index: int) -> StringName:
	var name := key if key != &"" else id
	return StringName("topic_done.%s" % (name if name != &"" else str(index)))
