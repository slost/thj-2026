extends RefCounted
class_name GridObjectRecord

var runtime_id: int = -1
var object_id: StringName

var cell: Vector2i = Vector2i.ZERO
var layer: StringName = &"main"
var rotation_steps: int = 0

var metadata: Dictionary = {}
var tags: Array[StringName] = []

var visual_node: Node2D
var definition: GridObjectDefinition


func setup(
	p_runtime_id: int,
	p_object_id: StringName,
	p_cell: Vector2i,
	p_layer: StringName,
	p_rotation_steps: int = 0,
	p_metadata: Dictionary = {},
	p_tags: Array[StringName] = [],
	p_definition: GridObjectDefinition = null,
	p_visual_node: Node2D = null
) -> void:
	runtime_id = p_runtime_id
	object_id = p_object_id
	cell = p_cell
	layer = p_layer
	rotation_steps = p_rotation_steps
	metadata = p_metadata.duplicate(true)
	tags = p_tags.duplicate()
	definition = p_definition
	visual_node = p_visual_node


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
