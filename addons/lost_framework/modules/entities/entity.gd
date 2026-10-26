@icon("res://addons/lost_framework/resources/assets/icons/entity.svg")
extends Node
class_name Entity
## A game object. Template data comes from [member def]; rules live in child
## [Component]s; values that change during play live either in a component
## (typed, with rules, e.g. OpenableComponent.is_open) or in [member state]
## (free-form story flags, e.g. "lever_pulled").
## Read both the same way with [method get_value].


signal state_changed(key: StringName, value: Variant)

@export var id := &"" ## Unique per instance. Falls back to [member DataDef.id] when empty.
@export var def: EntityDef
@export var state: Dictionary = {} ## Free-form flags. Use plain values only, never Nodes.


func _ready() -> void:
	# Do not share the dictionary with other instances of the same scene.
	state = state.duplicate(true)


#region Identity
func get_id() -> StringName:
	if id != &"":
		return id
	if def and def.id != &"":
		return def.id
	return StringName(name)


## The name in [param locale] (empty: the output language), see [method DataDef.get_display_name].
func get_display_name(locale := "") -> String:
	return def.get_display_name(locale) if def else String(name)


## The description from [member def], with its variants picked by this
## entity's values. [param context] resolves [ValueCondition]s about other
## subjects; null uses [method make_condition_context].
func get_description(context: Object = null) -> String:
	if def == null:
		return ""
	return def.get_display_description(get_values(), context if context else make_condition_context())


## A context for conditions about this entity. The nearest ancestor with a
## [code]make_condition_context_for(entity)[/code] method (a world, e.g.
## FictionWorld) makes it; otherwise it only knows this entity.
func make_condition_context() -> Object:
	var node := get_parent()
	while node:
		if node.has_method("make_condition_context_for"):
			return node.make_condition_context_for(self)
		node = node.get_parent()
	return EntityConditionContext.new(self)

#endregion


#region Values
## Returns [param key] from [member state], or from the first component that
## reports it in [code]_state_values()[/code], or [param default].
func get_value(key: StringName, default: Variant = null) -> Variant:
	if state.has(key):
		return state[key]
	for component in get_components():
		if component.has_method("_state_values"):
			var values: Dictionary = component._state_values()
			if values.has(key):
				return values[key]
	return default


func has_value(key: StringName) -> bool:
	return not is_same(get_value(key, self), self) # is_same: != errors for e.g. bool vs Object


## Sets [param key]. A component that owns the key (its
## [code]_set_state_value(key, value)[/code] returns true) handles it;
## otherwise it is stored in [member state].
func set_value(key: StringName, value: Variant) -> void:
	for component in get_components():
		if component.has_method("_set_state_value") and component._set_state_value(key, value):
			state_changed.emit(key, value)
			return
	state[key] = value
	state_changed.emit(key, value)


## All values: every component's [code]_state_values()[/code], then [member state] on top.
func get_values() -> Dictionary:
	var result := {}
	for component in get_components():
		if component.has_method("_state_values"):
			result.merge(component._state_values(), true)
	result.merge(state, true)
	return result

#endregion


#region Place
## Nearest ancestor Entity, or null. Whatever an entity is a child of is
## what it is in (a room, a box, a player's inventory).
func get_parent_entity() -> Entity:
	var node := get_parent()
	while node:
		if node is Entity:
			return node
		node = node.get_parent()
	return null


## Nearest ancestor Entity with a [LocationComponent] (the room it is in), or null.
func get_location() -> Entity:
	var entity := get_parent_entity()
	while entity:
		if entity.get_component(LocationComponent):
			return entity
		entity = entity.get_parent_entity()
	return null


## Entities directly inside this one. Looks through plain grouping nodes,
## skips components.
func get_contents() -> Array[Entity]:
	var result: Array[Entity] = []
	_collect_contents(self, result)
	return result


static func _collect_contents(node: Node, result: Array[Entity]) -> void:
	for child in node.get_children():
		if child is Entity:
			result.append(child)
		elif not (child is Component or child is ComponentContainer):
			_collect_contents(child, result)

#endregion


#region Components
## Direct child components, including those inside a direct ComponentContainer.
func get_components() -> Array[Component]:
	var result: Array[Component] = []
	for child in get_children():
		if child is Component:
			result.append(child)
		elif child is ComponentContainer:
			for inner in child.get_children():
				if inner is Component:
					result.append(inner)
	return result


func get_component(script: Script) -> Component:
	for component in get_components():
		if is_instance_of(component, script):
			return component
	return null

#endregion
