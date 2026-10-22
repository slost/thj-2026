extends Node2D


@export var game_scene_path: String = "res://scenes/game/game.tscn"


func _on_play_button_pressed() -> void:
	SignalBus.request_scene_change.emit(game_scene_path)


func _on_quit_button_pressed() -> void:
	SignalBus.request_quit_game.emit()
