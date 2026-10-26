extends FictionEffect
class_name MoveEntityEffect
## Moves an entity into another one (a room, a box, an actor).
## [member subject] and [member destination_subject] pick them;
## [constant Subject.FIXED] uses the ids.


@export var subject := Subject.FIXED
@export var entity_id := &"" ## The entity to move when [member subject] is [constant Subject.FIXED].
@export var destination_subject := Subject.FIXED
@export var destination_id := &"" ## Where it goes when [member destination_subject] is [constant Subject.FIXED].


func apply(m: CommandMatch, actor: Entity, world: FictionWorld, host: Entity = null) -> void:
	var entity := resolve_entity(subject, entity_id, m, actor, world, host)
	var destination := resolve_entity(destination_subject, destination_id, m, actor, world, host)
	if entity == null or destination == null:
		push_warning("MoveEntityEffect: unknown entity '%s' or destination '%s'" % [entity_id, destination_id])
		return
	if entity == destination or entity.is_ancestor_of(destination):
		push_warning("MoveEntityEffect: cannot move '%s' into itself" % entity.get_id())
		return
	entity.reparent(destination)
