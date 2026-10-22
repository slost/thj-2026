@tool
extends Node
class_name LostCore

signal modules_scanned(total_modules: int)

const MODULE_LIST_DIR := Paths.DEFAULT_DATA_ROOT
const MODULE_LIST_PATH := MODULE_LIST_DIR + "/assigned_modules.json"
const MODULE_LIST_VERSION := 1

## Modules registry schema:
## modules[module_id] = {
## 	"id": String,                 # Stable module id
## 	"module": Object,             # Runtime module instance (Node) or ModuleMetadata for passive modules
## 	"metadata": ModuleMetadata,   # Metadata if available, else null
## 	"activated": bool             # Last known lifecycle state in LostCore
## }
var modules: Dictionary = {}
var scanner := ModuleScannerService.new()
var _is_applying := false
var _dtag := DebugTag.new("LOST")

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	load_assigned_modules()


#region Module discovery & registry
## Loads the assigned module list. Does not scan disk and does not rewrite the list.
func load_assigned_modules() -> void:
	var listed := _read_assigned_file()
	if listed.is_empty():
		if Engine.is_editor_hint():
			assign_modules()
		else:
			push_warning("LostCore skipped module assign: module list not found.")
		return
	if listed.get("version", -1) != MODULE_LIST_VERSION:
		push_warning("LostCore skipped module assign: unsupported module list version.")
		return

	var manifest = listed.get("manifest", [])
	if not (manifest is Array) or manifest.is_empty():
		push_warning("LostCore skipped module assign: empty module list.")
		return

	_apply_modules(_load_from_manifest(manifest), _activation_map_from_manifest(manifest))
	print_rich("[color=LIME]Assigned modules loaded: %d[/color]" % modules.size())
	_dtag.print(modules.keys())
	emit_signal("modules_scanned", modules.size())


## Editor-only. Discovers modules and writes the assigned list.
## Call this after module settings change in the plugin, not on startup.
func assign_modules() -> void:
	if not Engine.is_editor_hint():
		_dtag.push_warning("LostCore.assign_modules() is editor-only. Runtime loads the assigned module list.")
		return

	var previous := _read_manifest()
	var activation := _activation_map_from_manifest(previous)
	for id in modules.keys():
		var entry = modules[id]
		if entry is Dictionary:
			activation[id] = entry.get("activated", activation.get(id, true))

	_apply_modules(scanner.scan([Paths.MODULES]), activation)
	_save_assigned_list(_build_assigned_manifest(previous))

	print_rich("[color=LIME]Module list assigned. Total modules loaded: %d[/color]" % modules.size())
	_dtag.print(modules.keys())
	emit_signal("modules_scanned", modules.size())


## Kept for existing callers. Startup loads the assigned list instead of scanning.
func scan() -> void:
	assign_modules()


func _apply_modules(found: Array, activation: Dictionary) -> void:
	_reset_modules_for_rescan()
	_is_applying = true
	for module in found:
		var id := _resolve_module_id(module)
		var should_activate := bool(activation.get(id, true))
		_on_load_module(module, should_activate)
	_is_applying = false


func _reset_modules_for_rescan() -> void:
	for entry in modules.values():
		if not (entry is Dictionary):
			continue
		var module = entry.get("module")
		var was_activated := entry.get("activated", false) as bool

		if was_activated and module and module.has_method("deactivate"):
			module.deactivate()

		if module is Node and is_instance_valid(module):
			var parent := module.get_parent() as Node
			if parent == self:
				remove_child(module)
				module.queue_free()
			elif parent == null:
				module.queue_free()

	modules.clear()


func _on_load_module(module, should_activate: bool = true) -> void:
	module = _resolve_autoload_singleton(module)

	if _should_attach(module):
		module.name = _resolve_module_id(module)
		add_child(module)

	_register_module(module)
	if should_activate:
		activate_module(module)
	else:
		set_module_activated_state(module, false)
	# print_rich("[color=SEA_GREEN]--- ✅ Module loaded: %s ---" % module.get_id())


func _should_attach(module) -> bool:
	if module is ModuleMetadata:
		return false
	if module.is_autoload():
		return false
	return true


func _resolve_autoload_singleton(module):
	if module is ModuleMetadata:
		return module
	if not module or not module.is_autoload():
		return module

	var autoload_name := _find_autoload_name_for_script(module.get_script())
	if autoload_name == "":
		return module

	var singleton := get_node_or_null("/root/" + autoload_name)
	if singleton == null:
		return module

	if (
		singleton != module
		and singleton.has_method("bind_metadata")
		and "metadata" in singleton
		and singleton.metadata == null
		and module.metadata is ModuleMetadata
	):
		singleton.bind_metadata(module.metadata)
		if module is Node:
			module.queue_free()

	return singleton


func _find_autoload_name_for_script(script: Script) -> String:
	if script == null or script.resource_path == "":
		return ""

	var autoloads := ProjectSettings.get_property_list()
	for property in autoloads:
		var property_name := property.get("name", "") as String
		if not property_name.begins_with("autoload/"):
			continue

		var autoload_value := ProjectSettings.get_setting(property_name, "") as String
		if _autoload_value_matches_script(autoload_value, script):
			return property_name.get_file()

	return ""


func _autoload_value_matches_script(autoload_value: String, script: Script) -> bool:
	var resource_ref := autoload_value.trim_prefix("*")
	if resource_ref == script.resource_path:
		return true

	var uid := ResourceLoader.get_resource_uid(script.resource_path)
	if uid == ResourceUID.INVALID_ID:
		return false

	return resource_ref == ResourceUID.id_to_text(uid)


func _register_module(module) -> void:
	var id := ""
	if module is ModuleMetadata:
		id = module.id
	elif module.has_method("get_id"):
		id = module.get_id()
	else:
		push_error("Module missing get_id(): %s" % module)
		module.queue_free()
		return

	if id == "":
		push_error("Module missing id: %s" % module)
		if module is Node:
			module.queue_free()
		return

	if modules.has(id):
		push_error("Duplicate module id: %s" % id)
		if module is Node:
			module.queue_free()
		return

	modules[id] = _make_module_entry(id, module)


func get_module(id: String):
	var entry = modules.get(id)
	if entry is Dictionary:
		return entry.get("module")
	return entry


func get_module_entry(id: String) -> Dictionary:
	var entry = modules.get(id)
	if entry is Dictionary:
		return entry
	return {}


func is_module_activated(id: String) -> bool:
	var entry := get_module_entry(id)
	return entry.get("activated", false)


func set_module_activated_state(module_or_id, activated: bool) -> bool:
	var id := _resolve_module_id(module_or_id)
	if id == "" or not modules.has(id):
		return false

	var entry: Dictionary = modules[id]
	entry["activated"] = activated
	modules[id] = entry
	if not _is_applying and Engine.is_editor_hint():
		_save_assigned_list(_build_assigned_manifest(_read_manifest()))
	return true


func get_assigned_folder_path(id: String) -> String:
	if modules.has(id):
		var entry = modules[id]
		if entry is Dictionary:
			return _resolve_module_folder_path(entry.get("module"), id)

	for listed in _read_manifest():
		if listed is Dictionary and str(listed.get("id", "")) == id:
			return str(listed.get("folder_path", ""))
	return ""


func set_assigned_activation(id: String, activated: bool) -> bool:
	if id == "":
		return false
	if modules.has(id):
		return set_module_activated_state(id, activated)

	var manifest := _read_manifest()
	var found := false
	for i in manifest.size():
		var entry = manifest[i]
		if entry is Dictionary and str(entry.get("id", "")) == id:
			entry["activated"] = activated
			manifest[i] = entry
			found = true
			break
	if not found:
		return false
	_save_assigned_list(manifest)
	return true
#endregion

#region Lifecycle control
func activate_module(module_or_id) -> void:
	var id := _resolve_module_id(module_or_id)
	if id == "" or not modules.has(id):
		return

	var entry: Dictionary = modules[id]
	var module = entry.get("module")
	if module and module.has_method("activate"):
		module.activate()
	set_module_activated_state(id, true)
	# print("Activated module: %s" % module.get_id())


func deactivate_module(module_or_id) -> void:
	var id := _resolve_module_id(module_or_id)
	if id == "" or not modules.has(id):
		return

	var entry: Dictionary = modules[id]
	var module = entry.get("module")
	if module and module.has_method("deactivate"):
		module.deactivate()
	set_module_activated_state(id, false)
#endregion


func _make_module_entry(id: String, module) -> Dictionary:
	var metadata: ModuleMetadata = null
	if module is ModuleMetadata:
		metadata = module
	elif "metadata" in module and module.metadata is ModuleMetadata:
		metadata = module.metadata

	return {
		"id": id,
		"module": module,
		"metadata": metadata,
		"activated": false
	}


func _resolve_module_id(module_or_id) -> String:
	if module_or_id is String:
		return module_or_id
	if module_or_id is ModuleMetadata:
		return module_or_id.id
	if module_or_id and module_or_id.has_method("get_id"):
		return module_or_id.get_id()
	return ""


func _read_assigned_file() -> Dictionary:
	if not FileAccess.file_exists(MODULE_LIST_PATH):
		return {}

	var file := FileAccess.open(MODULE_LIST_PATH, FileAccess.READ)
	if not file:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _read_manifest() -> Array:
	var manifest = _read_assigned_file().get("manifest", [])
	if manifest is Array:
		return manifest
	return []


func _save_assigned_list(manifest: Array) -> void:
	var payload := {
		"manifest": manifest,
		"version": MODULE_LIST_VERSION,
	}
	var existing := _read_assigned_file()
	var existing_manifest = existing.get("manifest", [])
	if (
		int(existing.get("version", -1)) == MODULE_LIST_VERSION
		and existing_manifest is Array
		and _same_manifest(existing_manifest, manifest)
	):
		return

	var absolute_dir := ProjectSettings.globalize_path(MODULE_LIST_DIR)
	if not DirAccess.dir_exists_absolute(absolute_dir):
		var mkdir_err := DirAccess.make_dir_absolute(absolute_dir)
		if mkdir_err != OK:
			push_warning("Unable to create module list directory: %s (%s)" % [MODULE_LIST_DIR, mkdir_err])
			return

	var file := FileAccess.open(MODULE_LIST_PATH, FileAccess.WRITE)
	if not file:
		push_warning("Unable to write assigned module list: %s" % MODULE_LIST_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))


func _build_assigned_manifest(previous: Array) -> Array:
	var previous_by_id := {}
	for entry in previous:
		if entry is Dictionary:
			var previous_id := str(entry.get("id", ""))
			if previous_id != "":
				previous_by_id[previous_id] = entry

	var manifest: Array = []
	var seen := {}
	for id in modules.keys():
		var entry: Dictionary = modules[id]
		var module = entry.get("module")
		var module_id := str(entry.get("id", id))
		if module_id == "":
			continue

		var folder_path := ""
		if previous_by_id.has(module_id):
			folder_path = str(previous_by_id[module_id].get("folder_path", ""))
		if folder_path == "":
			folder_path = _resolve_module_folder_path(module, module_id)
		if folder_path == "":
			continue

		manifest.append({
			"activated": bool(entry.get("activated", false)),
			"folder_path": folder_path,
			"id": module_id,
		})
		seen[module_id] = true

	for entry in previous:
		if not (entry is Dictionary):
			continue
		var listed_id := str(entry.get("id", ""))
		if listed_id == "" or seen.has(listed_id):
			continue
		var folder_path := str(entry.get("folder_path", ""))
		if folder_path == "" or DirAccess.open(folder_path) == null:
			continue
		manifest.append({
			"activated": bool(entry.get("activated", false)),
			"folder_path": folder_path,
			"id": listed_id,
		})

	manifest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	return manifest


func _same_manifest(a: Array, b: Array) -> bool:
	return _canonical_manifest(a) == _canonical_manifest(b)


func _canonical_manifest(manifest: Array) -> String:
	var rows: Array[String] = []
	for entry in manifest:
		if not (entry is Dictionary):
			continue
		rows.append("%s\n%s\n%s" % [
			str(entry.get("id", "")),
			str(entry.get("folder_path", "")),
			"1" if bool(entry.get("activated", false)) else "0",
		])
	rows.sort()
	return "\n".join(rows)


func _resolve_module_folder_path(module, id: String) -> String:
	if module is ModuleMetadata and module.resource_path != "":
		return module.resource_path.get_base_dir()
	if "metadata" in module and module.metadata is ModuleMetadata and module.metadata.resource_path != "":
		return module.metadata.resource_path.get_base_dir()
	return Paths.MODULES + id


func _load_from_manifest(manifest: Array) -> Array:
	var loaded: Array = []
	for entry in manifest:
		if not (entry is Dictionary):
			continue
		var folder_path := entry.get("folder_path", "") as String
		if folder_path == "":
			continue

		var module = scanner._load_module_from_folder(folder_path)
		if module:
			loaded.append(module)
	return loaded


func _activation_map_from_manifest(manifest: Array) -> Dictionary:
	var states := {}
	for entry in manifest:
		if not (entry is Dictionary):
			continue
		var id := entry.get("id", "") as String
		if id == "":
			continue
		states[id] = entry.get("activated", true)
	return states
