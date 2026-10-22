extends Node2D

@export var scene_to_load: String = "res://UI/title.tscn"

func _ready():
  # change scene to scene_to_load
    get_tree().change_scene_to_file(scene_to_load)