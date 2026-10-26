class_name EntityConditionContext
extends RefCounted
## Resolves [ValueCondition] subjects for entities: SELF is [member self_entity],
## ENTITY is looked up by id in [member registry], ACTOR is [member actor],
## WORLD is [member world_values]. CARRIES means the holder is an ancestor
## of the item (holds it directly or inside something it holds).
## A world (e.g. FictionWorld) makes one with its own values; an Entity
## outside any world gets one that only knows itself.


var self_entity: Entity
var actor: Entity
## Any Object with [code]get_entity(id: StringName) -> Entity[/code], or null.
var registry: Object
var world_values: Variant = null ## Dictionary of world values, or null when there is no world.


func _init(p_self: Entity = null, p_actor: Entity = null, p_registry: Object = null, p_world_values: Variant = null) -> void:
	self_entity = p_self
	actor = p_actor
	registry = p_registry
	world_values = p_world_values


func get_condition_values(subject: ValueCondition.Subject, entity_id: StringName) -> Variant:
	if subject == ValueCondition.Subject.WORLD:
		return world_values
	var entity := get_subject_entity(subject, entity_id)
	return entity.get_values() if entity else null


func condition_carries(subject: ValueCondition.Subject, entity_id: StringName, item_id: StringName) -> bool:
	var holder := get_subject_entity(subject, entity_id)
	var item := _find(item_id)
	return holder != null and item != null and holder.is_ancestor_of(item)


## The entity a subject refers to, or null (always null for WORLD).
func get_subject_entity(subject: ValueCondition.Subject, entity_id: StringName) -> Entity:
	match subject:
		ValueCondition.Subject.SELF:
			return self_entity
		ValueCondition.Subject.ACTOR:
			return actor
		ValueCondition.Subject.ENTITY:
			return _find(entity_id)
	return null


func _find(entity_id: StringName) -> Entity:
	if registry and registry.has_method("get_entity"):
		return registry.get_entity(entity_id)
	if self_entity and self_entity.get_id() == entity_id:
		return self_entity
	return null
