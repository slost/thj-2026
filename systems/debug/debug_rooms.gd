extends Control


func _on_world_map_button_button_down():
	get_tree().change_scene_to_file("res://systems/world_map/world_map.tscn")


func _on_battle_button_pressed():
	get_tree().change_scene_to_file("res://systems/battle/battle_test.tscn")
	