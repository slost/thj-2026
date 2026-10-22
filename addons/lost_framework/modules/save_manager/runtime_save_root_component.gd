extends Component
class_name RuntimeSaveRootComponent


@export_file("*.tscn") var scene_path: String = ""


func _setup() -> void:
	if SaveManager.registry == null:
		push_error("RuntimeSaveRootComponent: SaveManager registry is null")
		return

	SaveManager.registry.register_runtime_root(self)


func _teardown() -> void:
	if SaveManager.registry == null:
		return

	SaveManager.registry.unregister_runtime_root(self)


func get_scene_path() -> String:
	return scene_path.strip_edges()


func capture_instance_data() -> Dictionary:
	var target := get_host()
	if target == null:
		push_warning("RuntimeSaveRootComponent: host is null while capturing instance data")
		return {}

	var participant_payload := {}
	for participant in _collect_save_participants(target):
		var participant_key := _get_participant_key(target, participant)
		if participant_key.is_empty():
			continue

		participant_payload[participant_key] = participant.capture_save_data()

	return {
		"scene_path": get_scene_path(),
		"parent_path": _get_parent_path(target),
		"participants": participant_payload
	}


func apply_instance_data(data: Dictionary) -> void:
	var target := get_host()
	if target == null:
		push_warning("RuntimeSaveRootComponent: host is null while applying instance data")
		return

	var participant_payload := data.get("participants", {})
	if typeof(participant_payload) != TYPE_DICTIONARY:
		return

	for participant in _collect_save_participants(target):
		var participant_key := _get_participant_key(target, participant)
		if participant_key.is_empty():
			continue

		var participant_data := participant_payload.get(participant_key, {}) as Dictionary
		if typeof(participant_data) != TYPE_DICTIONARY:
			continue

		participant.apply_save_data(participant_data)


func _collect_save_participants(root: Node) -> Array[SaveParticipantComponent]:
	var result: Array[SaveParticipantComponent] = []
	_collect_save_participants_recursive(root, result)
	return result


func _collect_save_participants_recursive(
	current: Node,
	result: Array[SaveParticipantComponent]
) -> void:
	for child in current.get_children():
		if child is RuntimeSaveRootComponent:
			continue

		if child is SaveParticipantComponent:
			result.append(child)
			continue

		_collect_save_participants_recursive(child, result)


func _get_participant_key(root: Node, participant: SaveParticipantComponent) -> String:
	return String(root.get_path_to(participant))


func _get_parent_path(target: Node) -> String:
	var parent := target.get_parent()
	if parent == null:
		return ""

	return String(parent.get_path())
