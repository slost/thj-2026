extends CanvasLayer


func _on_restart_button_pressed() -> void:
	Game.restart()


func _on_delete_save_button_pressed() -> void:
	Game.delete_save()
	

func _on_rooms_button_pressed() -> void:
	get_tree().change_scene_to_file("res://systems/debug/debug_rooms.tscn")


func _on_unlock_capital_pressed() -> void:
	Game.unlock_capital_for_debug()
