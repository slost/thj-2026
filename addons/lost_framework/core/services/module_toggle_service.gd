@tool
extends RefCounted
class_name ModuleToggleService

const GDIGNORE_NAME := ".gdignore"


func set_module_ignored(folder_path: String, enabled: bool) -> bool:
	if folder_path == "":
		push_warning("[ModuleToggleService] Missing module folder")
		return false
	return _set_gdignore(folder_path, enabled)


func _set_gdignore(folder_path: String, enabled: bool) -> bool:
	var ignore_path := folder_path.path_join(GDIGNORE_NAME)

	if enabled:
		if not FileAccess.file_exists(ignore_path):
			return true
		var dir := DirAccess.open(folder_path)
		if not dir:
			push_warning("[ModuleToggleService] Cannot open module directory: %s" % folder_path)
			return false
		var err := dir.remove(GDIGNORE_NAME)
		if err != OK:
			push_warning("[ModuleToggleService] Cannot remove .gdignore at: %s (%s)" % [ignore_path, err])
			return false
		return true

	var file := FileAccess.open(ignore_path, FileAccess.WRITE)
	if not file:
		push_warning("[ModuleToggleService] Cannot create .gdignore at: %s" % ignore_path)
		return false
	file.store_line("# Disabled by Lost ModuleToggleService")
	return true
