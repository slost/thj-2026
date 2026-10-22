extends Resource
class_name LevelData


@export var level_id: StringName
@export var display_name: String
@export var grid_config: GridConfig
@export var map_size: Vector2i
@export var walkable_cells: Array[Vector2i] = []
@export var objects: Array[GridObjectData] = []
@export_multiline var notes: String
