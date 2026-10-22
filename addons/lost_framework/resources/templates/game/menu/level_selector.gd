extends Control


func _on_back_button_pressed() -> void:
	SignalBus.request_scene_change.emit("Main Menu")
