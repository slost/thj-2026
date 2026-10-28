extends Node2D


func _ready() -> void:
	Game.change_stage(self)


func _on_button_pressed() -> void:
	Game.back_to_map()
