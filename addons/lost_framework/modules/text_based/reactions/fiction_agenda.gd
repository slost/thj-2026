extends Resource
class_name FictionAgenda
## Something that happens after one or more actions in the world (a candle
## burning down, a guard walking in). Held by a [FictionAgendaComponent].
## The wait is stored on the host entity, so it is saved with the world.


@export var key := &"" ## Stable name for the saved wait. Empty uses the list index.
## Fire every this many actions after the first. 0 fires once, after [member delay].
@export var every := 1
## Actions to wait before the first fire. 0 waits [member every] (or 1 when that is 0).
@export var delay := 0
## Shown when it fires. Placeholders: {actor}. Passed through translation like a reaction.
@export_multiline var text := ""
@export var effects: Array[FictionEffect] = []
@export var conditions: Array[ValueCondition] = []
@export var once := false
@export var visibility := FictionEvent.Visibility.ROOM


func wait_key(index: int) -> StringName:
	return StringName("agenda_wait.%s" % (key if key != &"" else str(index)))


func done_key(index: int) -> StringName:
	return StringName("agenda_done.%s" % (key if key != &"" else str(index)))
