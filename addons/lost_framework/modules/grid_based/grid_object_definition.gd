extends Resource
class_name GridObjectDefinition


@export_category("Identity")
@export var object_id: StringName
@export var display_name: String = ""

@export_category("Visuals")
@export var visual_scene: PackedScene
@export var default_texture: Texture2D

@export_category("Setup")
@export var default_layer: StringName = &"main"
@export var tags: Array[StringName] = []
@export var default_metadata: Dictionary = {}