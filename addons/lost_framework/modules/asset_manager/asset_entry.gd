@tool
extends Resource
class_name AssetEntry


@export var key: String = "" ## Human-facing identifier
@export var type: String = "" ## e.g. "audio", "scene", "shader"
@export var category: String = "" ## e.g. "ui", "fx", "environment"
@export var tags: Array[String] = []
@export var uid: String = "" ## Immutable unique id
@export var resource: Resource ## The actual asset (Texture2D, PackedScene, AudioStream, etc.)
