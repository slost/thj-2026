extends Refs.MODULE


const SAVE_ROOT: String = "user://saves/"
const FILE_EXTENSION: String = ".json"
const RUNTIME_INSTANCES_KEY := "runtime_instances"


var registry: SaveRegistry
var serializer: JsonSaveSerializer
var _metadata: Dictionary = {}


func _enter_tree() -> void:
	if registry == null:
		registry = SaveRegistry.new()

	if serializer == null:
		serializer = JsonSaveSerializer.new()


func _ready() -> void:
	_ensure_save_root()


#region Public API
func save_slot(slot_id: int) -> bool:
	var payload: Dictionary = _build_payload(slot_id)

	if payload.is_empty():
		push_error("SaveManager: payload is empty")
		return false

	return _write_payload(slot_id, payload)


func load_slot(slot_id: int) -> bool:
	if not has_slot(slot_id):
		push_error("SaveManager: slot does not exist: %d" % slot_id)
		return false

	var payload: Dictionary = _read_payload(slot_id)

	if payload.is_empty():
		push_error("SaveManager: failed to read payload")
		return false

	var data: Dictionary = payload.get("data", {})
	var metadata: Dictionary = payload.get("meta", {})
	var runtime_instances: Variant = payload.get(RUNTIME_INSTANCES_KEY, [])
	_metadata = metadata.duplicate(true)

	if runtime_instances is Array:
		_restore_runtime_instances(runtime_instances)

	var participants: Array[SaveParticipantComponent] = registry.get_participants()

	for participant in participants:
		if _is_runtime_managed_participant(participant):
			continue

		var key: String = participant.get_save_key()

		if key.is_empty():
			continue

		if not data.has(key):
			continue

		var participant_data: Variant = data.get(key)

		if typeof(participant_data) != TYPE_DICTIONARY:
			continue

		participant.apply_save_data(participant_data)

	return true


func has_slot(slot_id: int) -> bool:
	return FileAccess.file_exists(_get_slot_path(slot_id))


func get_slot_metadata(slot_id: int) -> Dictionary:
	if not has_slot(slot_id):
		return {}

	var payload: Dictionary = _read_payload(slot_id)
	var metadata: Dictionary = payload.get("meta", {})

	if typeof(metadata) != TYPE_DICTIONARY:
		return {}

	return metadata.duplicate(true)


func set_metadata_value(key: String, value: Variant) -> void:
	if key.strip_edges().is_empty():
		return

	_metadata[key] = value


func clear_runtime_instances() -> void:
	if registry == null:
		return

	for runtime_root in registry.get_runtime_roots():
		if runtime_root == null or not is_instance_valid(runtime_root):
			continue

		var host := runtime_root.get_host()
		if host == null or host.is_queued_for_deletion():
			continue

		var parent := host.get_parent()
		if parent:
			parent.remove_child(host)

		host.queue_free()


func delete_slot(slot_id: int) -> bool:
	var path: String = _get_slot_path(slot_id)

	if not FileAccess.file_exists(path):
		return false

	return DirAccess.remove_absolute(path) == OK
#endregion


#region Build Payload
func _build_payload(slot_id: int) -> Dictionary:
	var data := {}
	var metadata := _metadata.duplicate(true)
	metadata["slot_id"] = slot_id
	metadata["saved_at_unix"] = Time.get_unix_time_from_system()

	var participants: Array[SaveParticipantComponent] = registry.get_participants()

	for participant in participants:
		if _is_runtime_managed_participant(participant):
			continue

		var key: String = participant.get_save_key()

		if key.is_empty():
			continue

		var value: Dictionary = participant.capture_save_data()

		data[key] = value

	return {
		"meta": metadata,
		"data": data,
		RUNTIME_INSTANCES_KEY: _capture_runtime_instances()
	}
#endregion

#region File IO
func _write_payload(slot_id: int, payload: Dictionary) -> bool:
	var path: String = _get_slot_path(slot_id)

	var raw: String = serializer.serialize(payload)

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		push_error("SaveManager: failed to open file for writing: %s" % path)
		return false

	file.store_string(raw)
	file.flush()
	return true


func _read_payload(slot_id: int) -> Dictionary:
	var path: String = _get_slot_path(slot_id)

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("SaveManager: failed to open file for reading: %s" % path)
		return {}

	var raw: String = file.get_as_text()

	return serializer.deserialize(raw)
#endregion


#region Internal
func _get_slot_path(slot_id: int) -> String:
	return "%sslot_%d%s" % [SAVE_ROOT, slot_id, FILE_EXTENSION]


func _ensure_save_root() -> void:
	var absolute_save_root := ProjectSettings.globalize_path(SAVE_ROOT)
	if DirAccess.dir_exists_absolute(absolute_save_root):
		return

	var error: Error = DirAccess.make_dir_recursive_absolute(absolute_save_root)

	if error != OK:
		push_error("SaveManager: failed to create save directory: %s" % SAVE_ROOT)


func _capture_runtime_instances() -> Array[Dictionary]:
	var instances: Array[Dictionary] = []

	for runtime_root in registry.get_runtime_roots():
		if runtime_root == null or not is_instance_valid(runtime_root):
			continue

		var host := runtime_root.get_host()

		if host == null or host.is_queued_for_deletion():
			continue

		var instance_data := runtime_root.capture_instance_data()
		var scene_path := runtime_root.get_scene_path()

		if scene_path.is_empty():
			push_warning("SaveManager: runtime save root is missing scene_path")
			continue

		if instance_data.is_empty():
			continue

		instances.append(instance_data)

	return instances


func _restore_runtime_instances(instances: Array) -> void:
	clear_runtime_instances()

	for instance_data in instances:
		if typeof(instance_data) != TYPE_DICTIONARY:
			continue

		var scene_path := String(instance_data.get("scene_path", "")).strip_edges()
		if scene_path.is_empty():
			continue

		var scene := ResourceLoader.load(scene_path) as PackedScene
		if scene == null:
			push_warning("SaveManager: failed to load runtime scene '%s'" % scene_path)
			continue

		var parent := _resolve_runtime_parent(instance_data)
		var instance := scene.instantiate()
		parent.add_child(instance)

		var runtime_root := _find_runtime_save_root(instance)
		if runtime_root == null:
			push_warning("SaveManager: runtime scene '%s' is missing RuntimeSaveRootComponent" % scene_path)
			continue

		runtime_root.apply_instance_data(instance_data)


func _resolve_runtime_parent(instance_data: Dictionary) -> Node:
	var parent_path := String(instance_data.get("parent_path", "")).strip_edges()
	if parent_path.is_empty():
		return self

	var tree := get_tree()
	if tree == null:
		return self

	var parent := tree.root.get_node_or_null(parent_path)
	if parent == null:
		push_warning("SaveManager: runtime parent '%s' not found, falling back to SaveManager" % parent_path)
		return self

	return parent


func _find_runtime_save_root(node: Node) -> RuntimeSaveRootComponent:
	for child in node.get_children():
		if child is RuntimeSaveRootComponent:
			return child

	return null


func _is_runtime_managed_participant(participant: SaveParticipantComponent) -> bool:
	var host := participant.get_host()
	while host:
		if _find_runtime_save_root(host) != null:
			return true
		host = host.get_parent()

	return false
#endregion
