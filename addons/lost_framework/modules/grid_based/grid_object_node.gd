extends Node2D
class_name GridObjectNode


@export var sprite: Sprite2D

var runtime_id: int = -1


func set_texture(texture: Texture2D) -> void:
	if sprite == null:
		return

	sprite.texture = texture


func sync_to_world_position(world_position: Vector2) -> void:
	global_position = world_position