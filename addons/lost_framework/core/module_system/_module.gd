## Base class for all modules in the Lost Framework.
@tool
extends Node

var metadata: ModuleMetadata

var _active_in_editor := false
var _active_in_runtime := false


func _ready() -> void:
	if is_autoload() or _is_project_autoload():
		activate()


#region Identity & Configuration
func bind_metadata(m: ModuleMetadata) -> void:
	assert(metadata == null, "Metadata already bound")
	metadata = m


func get_metadata() -> ModuleMetadata:
	assert(metadata != null, "Metadata not bound yet")
	return metadata

func get_id() -> String:
	return metadata.id if metadata else "undefined_module"

func is_autoload() -> bool:
	return metadata.is_autoload if metadata else false
#endregion

#region Public API
func activate() -> void:
	if _is_active():
		return

	if _is_editor():
		_activate_editor()
	else:
		_activate_runtime()


func deactivate() -> void:
	if not _is_active():
		return

	_on_deactivate()


func is_active() -> bool:
	return _is_active()
#endregion

#region Internal State Helpers
func _is_editor() -> bool:
	return Engine.is_editor_hint()

func _is_active() -> bool:
	return _active_in_editor if _is_editor() else _active_in_runtime


func _is_project_autoload() -> bool:
	var script := get_script() as Script
	if script == null or script.resource_path == "":
		return false

	for property in ProjectSettings.get_property_list():
		var property_name := property.get("name", "") as String
		if not property_name.begins_with("autoload/"):
			continue

		var autoload_value := ProjectSettings.get_setting(property_name, "") as String
		if _autoload_value_matches_script(autoload_value, script):
			return true

	return false


func _autoload_value_matches_script(autoload_value: String, script: Script) -> bool:
	var resource_ref := autoload_value.trim_prefix("*")
	if resource_ref == script.resource_path:
		return true

	var uid := ResourceLoader.get_resource_uid(script.resource_path)
	if uid == ResourceUID.INVALID_ID:
		return false

	return resource_ref == ResourceUID.id_to_text(uid)
#endregion

#region Activation Flow
func _activate_editor() -> void:
	_active_in_editor = true
	_on_editor_activate()


func _activate_runtime() -> void:
	_active_in_runtime = true
	_on_runtime_activate()
#endregion

#region Overridable Hooks
func _on_editor_activate() -> void:
	pass


func _on_runtime_activate() -> void:
	pass


func _on_deactivate() -> void:
	pass
#endregion
