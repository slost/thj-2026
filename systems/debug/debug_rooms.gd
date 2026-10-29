extends Control


func _on_world_map_button_button_down():
	get_tree().change_scene_to_file("res://systems/world_map/world_map.tscn")


func _on_battle_button_pressed():
	get_tree().change_scene_to_file("res://systems/battle/battle_test.tscn")
	

func _on_battle_button_2_pressed() -> void:
	pass # Replace with function body.


func _on_code_button_pressed() -> void:
	get_tree().change_scene_to_file("res://systems/code_editor/editor_standalone.tscn")
