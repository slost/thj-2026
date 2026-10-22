extends Node


func _ready():
	SignalBus.request_scene_change.connect(_on_scene_change_requested)
	SignalBus.request_quit_game.connect(quit_game)


func _on_scene_change_requested(scene_path: String):
	var scene_paths = Refs.scene_paths
	if scene_paths.has(scene_path):
		change_scene(scene_paths[scene_path])
		return

	# If the scene name is not found in the dictionary, assume it's a direct path
	change_scene(scene_path)


func change_scene(scene_path: String) -> void:
	if ResourceLoader.exists(scene_path):
		print("Changed scene to: %s" % scene_path)
		get_tree().change_scene_to_file(scene_path)
		
	else:
		push_error("Scene not found: %s" % scene_path)


func quit_game():
	get_tree().quit()
