extends Resource
class_name FictionReaction
## A scripted response of an entity to a command, held by a
## [FictionReactionComponent]. BEFORE reactions run before the command (and
## may [member stop] it); AFTER reactions run only if the command succeeded.
## Example: a sign with a BEFORE reaction to &"read" that shows its text and stops.


## Which part the reacting entity must play in the command.
enum Role {
	OBJECT, ## It is one of the objects: "open [b]box[/b]".
	TARGET, ## It is the target: "put sword in [b]box[/b]".
	ANY, ## Object, target, or the actor's location (a room reacting to anything done in it).
	ACTOR, ## The actor: a reaction on the one who runs the command.
}

enum Timing {
	BEFORE, ## Before the command runs.
	AFTER, ## After the command ran and succeeded.
}

## Command ids it reacts to, e.g. [&"read"]. Use the id the command runs as
## (examine for "look box"). Empty reacts to every command.
@export var command_ids: Array[StringName] = []
@export var role := Role.OBJECT
## Value name -> required value, read from the reacting entity with
## [method Entity.get_value] (like [member DescriptionVariant.when]). Empty always matches.
@export var when: Dictionary = {}
## Every condition must hold too: SELF is the reacting entity, ACTOR who
## runs the command, ENTITY any entity by id, WORLD [member FictionWorld.state].
@export var conditions: Array[ValueCondition] = []
@export var timing := Timing.BEFORE
## Shown when it fires. Placeholders: {actor}, {object}, {target},
## {direction}, {verb}. Passed through [method Object.tr]. Empty shows nothing.
@export_multiline var text := ""
@export var effects: Array[FictionEffect] = []
@export var stop := false ## BEFORE only: the command itself does not run.
## Fires only the first time. Remembered in the reacting entity's
## [member Entity.state] (see [method get_done_key]), so it is saved with it.
@export var once := false
## Optional stable name used in the "once" state key. Empty uses the
## reaction's index in its component, which changes if reactions are reordered.
@export var key := &""


## True if it reacts to [param command_id] when the entity plays [param p_role]
## (OBJECT, TARGET, or ANY for the actor's location).
func reacts_to(command_id: StringName, p_role: Role) -> bool:
	if not command_ids.is_empty() and not command_ids.has(command_id):
		return false
	if role == Role.ANY:
		return p_role != Role.ACTOR
	return role == p_role


## True if [member when] and every one of [member conditions] hold for
## [param entity]. [param context] resolves subjects other than SELF.
func conditions_met(entity: Entity, context: Object = null) -> bool:
	var values := entity.get_values()
	return ValueCondition.when_matches(when, values) and ValueCondition.all_hold(conditions, values, context)


## The [member Entity.state] key that remembers a [member once] reaction
## fired, e.g. &"reaction_done.moth" or &"reaction_done.0".
func get_done_key(index: int) -> StringName:
	return StringName("reaction_done.%s" % (key if key != &"" else str(index)))


## [member text] translated, with placeholders filled from [param values].
func get_text(values: Dictionary) -> String:
	return tr(text).format(values) if not text.is_empty() else ""
