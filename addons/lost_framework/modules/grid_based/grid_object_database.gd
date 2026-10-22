extends Resource
class_name GridObjectDatabase

#region Data
@export var definitions: Array[GridObjectDefinition] = []
#endregion


func get_definition(object_id: StringName) -> GridObjectDefinition:
	for definition in definitions:
		if definition == null:
			continue

		if definition.object_id == object_id:
			return definition

	return null


func has_definition(object_id: StringName) -> bool:
	return get_definition(object_id) != null