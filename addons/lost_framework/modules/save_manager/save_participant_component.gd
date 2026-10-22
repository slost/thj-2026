extends Component
class_name SaveParticipantComponent


enum Mode {
	PROPERTIES,
	ADAPTER
}


@export var save_key: String = ""
@export var mode: Mode = Mode.PROPERTIES
@export var properties: Array[StringName] = []
@export var adapter: SaveAdapter


func _setup() -> void:
	if SaveManager.registry == null:
		push_error("SaveParticipantComponent: SaveManager registry is null")
		return

	SaveManager.registry.register_participant(self)


func _teardown() -> void:
	if SaveManager.registry == null:
		return

	SaveManager.registry.unregister_participant(self)


func get_save_key() -> String:
	return save_key.strip_edges()


func capture_save_data() -> Dictionary:
	var target := get_host()
	if target == null:
		push_warning("SaveParticipantComponent: host is null while capturing save data")
		return {}

	match mode:
		Mode.PROPERTIES:
			return _capture_properties(target)
		Mode.ADAPTER:
			if adapter == null:
				push_warning("SaveParticipantComponent: adapter mode selected but adapter is null")
				return {}
			return adapter.capture(target)

	return {}


func apply_save_data(data: Dictionary) -> void:
	var target := get_host()
	if target == null:
		push_warning("SaveParticipantComponent: host is null while applying save data")
		return

	match mode:
		Mode.PROPERTIES:
			_apply_properties(target, data)
		Mode.ADAPTER:
			if adapter == null:
				push_warning("SaveParticipantComponent: adapter mode selected but adapter is null")
				return
			adapter.apply(target, data)


func _capture_properties(target: Node) -> Dictionary:
	var result := {}

	for property_name in properties:
		if property_name.is_empty():
			continue

		if not _has_property(target, property_name):
			push_warning(
				"SaveParticipantComponent: host '%s' does not have property '%s'"
				% [target.name, String(property_name)]
			)
			continue

		result[String(property_name)] = target.get(property_name)

	return result


func _apply_properties(target: Node, data: Dictionary) -> void:
	for property_name in properties:
		if property_name.is_empty():
			continue

		var key := String(property_name)
		if not data.has(key):
			continue

		if not _has_property(target, property_name):
			push_warning(
				"SaveParticipantComponent: host '%s' does not have property '%s'"
				% [target.name, key]
			)
			continue

		target.set(property_name, data[key])


func _has_property(target: Node, property_name: StringName) -> bool:
	for property_data in target.get_property_list():
		if property_data.get("name", &"") == property_name:
			return true

	return false
