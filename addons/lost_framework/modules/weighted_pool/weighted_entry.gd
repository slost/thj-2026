## This class represents an entry in a weighted pool. It can either have a direct value or reference another weighted pool. When resolved, it will return an item definition based on its value or by picking from the referenced pool.
@tool
extends Resource
class_name WeightedEntry


@export var value: Variant ## The value of the entry
@export var pool: WeightedPool

@export var weight: int = 1


## Returns the expected type of the entry's value. Override this to lock the value field in the inspector.
## Return null to keep a Variant, a Script or class name for a custom Resource, or a TYPE_* constant for a builtin value.
## TYPE_OBJECT locks the field to any Resource.
func expected_type() -> Variant:
    return null


func _validate_property(property: Dictionary) -> void:
    if property.name != "value":
        return

    var expected: Variant = expected_type()
    if expected == null:
        return

    var resource_type := resource_type_name(expected)
    if not resource_type.is_empty():
        _lock_resource_property(property, resource_type)
        return

    if typeof(expected) != TYPE_INT or expected == TYPE_NIL:
        return

    if expected == TYPE_OBJECT:
        _lock_resource_property(property, "Resource")
        return

    property.type = expected
    property.hint = PROPERTY_HINT_NONE
    property.hint_string = ""
    property.usage = PROPERTY_USAGE_DEFAULT


## Resolves a custom resource class from a Script or class name. Builtin TYPE_* values return an empty string.
static func resource_type_name(expected: Variant) -> String:
    if expected is Script:
        var global_name := String(expected.get_global_name())
        if not global_name.is_empty():
            return global_name
        return expected.resource_path
    if typeof(expected) == TYPE_STRING or typeof(expected) == TYPE_STRING_NAME:
        return String(expected)
    return ""


func _lock_resource_property(property: Dictionary, resource_type: String) -> void:
    property.type = TYPE_OBJECT
    property.hint = PROPERTY_HINT_RESOURCE_TYPE
    property.hint_string = resource_type
    property.usage = PROPERTY_USAGE_DEFAULT


## Resolves the entry to an actual item definition. If the entry has a direct value, it returns that. If it has a pool, it picks one from the pool and resolves it recursively. If neither is set, it returns null.
func resolve(rng) -> Variant:
    if value:
        return value
    if pool:
        return pool.pick_one(rng).resolve(rng)
    return null
