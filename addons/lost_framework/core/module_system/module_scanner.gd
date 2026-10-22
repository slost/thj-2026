## A service to scan for modules in given paths and load their metadata.
@tool
extends RefCounted
class_name ModuleScannerService


func scan(paths: Array[String]) -> Array:
	var results: Array = []
	for path in paths:
		results.append_array(_scan_modules(path))
	return results


func _scan_modules(path: String) -> Array:
	var found: Array = []

	var dir := DirAccess.open(path)
	if not dir:
		push_error("Cannot open module path: %s" % path)
		return found

	dir.list_dir_begin()
	var folder_name := dir.get_next()

	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var module := _load_module_from_folder(path + "/" + folder_name) as Object
			if module:
				found.append(module)
		folder_name = dir.get_next()

	dir.list_dir_end()
	return found


func _load_module_from_folder(folder_path: String):
	var folder_name := folder_path.get_file()
	var script_path := folder_path + "/" + folder_name + ".module.gd"
	var has_script := ResourceLoader.exists(script_path)

	var metadata := _load_metadata(folder_path, has_script)
	if metadata and metadata.type == ModuleMetadata.Type.PASSIVE:
		return metadata

	if not has_script:
		if metadata:
			push_warning("Missing module script for runtime module: %s" % folder_path)
		return null

	var script := ResourceLoader.load(script_path)
	if not script:
		push_error("Failed to load module script: %s" % script_path)
		return null

	var module = script.new()
	if not module:
		push_error("Failed to instantiate module script: %s" % script_path)
		return null

	if not module.has_method("get_id"):
		push_error("Module missing get_id(): %s" % module)
		module.queue_free()
		return null

	if metadata:
		if not module.has_method("bind_metadata"):
			push_error("Module missing bind_metadata(): %s" % module)
			module.queue_free()
			return null
		module.bind_metadata(metadata)

	return module


func _load_metadata(folder_path: String, has_script: bool) -> ModuleMetadata:
	var metadata_path := folder_path + "/metadata.tres"
	if ResourceLoader.exists(metadata_path):
		var resource := ResourceLoader.load(metadata_path)
		if resource:
			return resource

	var metadata := _make_default_metadata(folder_path, has_script)

	if not Engine.is_editor_hint():
		push_warning("Missing or invalid metadata.tres, using runtime default: %s" % folder_path)
		return metadata

	var save_err := ResourceSaver.save(metadata, metadata_path)
	if save_err != OK:
		push_warning("Failed to save metadata.tres (%s), using default: %s" % [save_err, folder_path])
	else:
		print_rich("[color=YELLOW]⚠️ Created metadata.tres for: %s[/color]" % folder_path)
	return metadata


func _make_default_metadata(folder_path: String, has_script: bool) -> ModuleMetadata:
	var metadata := ModuleMetadata.new()
	var folder_name := folder_path.get_file()
	metadata.id = folder_name
	metadata.name = folder_name.capitalize()
	metadata.type = ModuleMetadata.Type.RUNTIME if has_script else ModuleMetadata.Type.PASSIVE
	return metadata
