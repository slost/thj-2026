extends FictionEffect
class_name SetStateEffect
## Sets a value on an entity with [method Entity.set_value], so a component
## value (e.g. "open", "locked") or a free-form story flag can be set.
## [member subject] picks the entity; [constant Subject.FIXED] uses [member entity_id].


@export var subject := Subject.FIXED
@export var entity_id := &"" ## The entity to change when [member subject] is [constant Subject.FIXED].
@export var key := &"" ## The value name, e.g. &"open" or &"lever_pulled".
@export var value: Variant = true


func apply(m: CommandMatch, actor: Entity, world: FictionWorld, host: Entity = null) -> void:
	var entity := resolve_entity(subject, entity_id, m, actor, world, host)
	if entity == null:
		push_warning("SetStateEffect: unknown entity '%s'" % entity_id)
		return
	entity.set_value(key, value)
