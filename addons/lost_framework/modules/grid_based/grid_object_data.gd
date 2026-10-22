extends Resource
class_name GridObjectData


@export var object_id: StringName
@export var cell: Vector2i
@export var layer: StringName = &"main"
@export var rotation_steps: int = 0
@export var metadata: Dictionary = {}