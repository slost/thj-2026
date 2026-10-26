extends Resource
class_name FictionEffect
## Something a [FictionReaction] or [FictionAgenda] changes in the world, e.g. a
## state value ([SetStateEffect]) or where an entity is ([MoveEntityEffect]).
## Refer to entities by id, or by who is acting. Override [method apply].


## Which entity an effect acts on.
enum Subject {
	FIXED, ## The entity named by id.
	SELF, ## The entity that owns the reaction or agenda.
	ACTOR, ## Who runs the command.
	OBJECT, ## The command's object (the reacting entity when it is one of them).
	TARGET, ## The command's target.
}


## Applies the effect. [param m] is the command being run (null for an agenda),
## [param actor] who runs it, [param host] the reacting entity or agenda owner.
func apply(m: CommandMatch, actor: Entity, world: FictionWorld, host: Entity = null) -> void:
	pass


## The entity [param subject] names, or null.
static func resolve_entity(subject: Subject, entity_id: StringName, m: CommandMatch, actor: Entity, world: FictionWorld, host: Entity) -> Entity:
	match subject:
		Subject.SELF:
			return host
		Subject.ACTOR:
			return actor
		Subject.OBJECT:
			if m and host and m.objects.has(host):
				return host
			if m and not m.objects.is_empty():
				return m.objects[0]
			return null
		Subject.TARGET:
			return m.target if m else null
	return world.get_entity(entity_id) if world else null
