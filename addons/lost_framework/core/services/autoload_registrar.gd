extends RefCounted
class_name AutoloadRegistrar

#region Constants
const CORE_NAME := "Lost"
const CORE_PATH := "res://addons/lost_framework/core/lost_core.gd"

# Core (non-module) autoloads
const CORE_AUTOLOADS_PATH := "res://addons/lost_framework/core/autoloads/"

# Legacy (temporary)
const LEGACY_AUTOLOADS := {
	"Audio": "res://addons/lost_framework/modules/audio_manager/audio_manager.module.gd",
	"SaveManager": "res://addons/lost_framework/modules/save_manager/save_manager.module.gd",
	"Settings": "res://addons/lost_framework/modules/settings/settings.module.gd",
}

# Future: module metadata
const MODULES_PATH := "res://addons/lost_framework/modules/"
#endregion


#region Public API

static func register_all(plugin: EditorPlugin) -> void:
	if not plugin:
		return

	_register_core_autoloads_from_folder(plugin)
	_register_core(plugin)
	# _register_module_autoloads_from_metadata(plugin) # future
	# register_legacy(plugin) # transitional only

	ProjectSettings.save()


static func unregister_all(plugin: EditorPlugin) -> void:
	if not plugin:
		return

	for prop in ProjectSettings.get_property_list():
		var key: String = prop.name
		if not key.begins_with("autoload/"):
			continue

		var name := key.replace("autoload/", "")
		if _is_framework_autoload(name):
			plugin.remove_autoload_singleton(name)

	ProjectSettings.save()
#endregion


#region Core Autoloads (Folder-based, NOT modules)
static func _register_core(plugin: EditorPlugin) -> void:
	if ProjectSettings.has_setting("autoload/" + CORE_NAME):
		return

	plugin.add_autoload_singleton(CORE_NAME, CORE_PATH)


static func _register_core_autoloads_from_folder(plugin: EditorPlugin) -> void:
	var dir := DirAccess.open(CORE_AUTOLOADS_PATH)
	if not dir:
		push_warning("Autoload folder not found: %s" % CORE_AUTOLOADS_PATH)
		return

	dir.list_dir_begin()
	var file := dir.get_next()

	while file != "":
		if file.ends_with(".gd") or file.ends_with(".tscn"):
			_try_register_core_autoload(plugin, file)
		file = dir.get_next()

	dir.list_dir_end()
#endregion


#region Legacy Support (Temporary)
static func register_legacy(plugin: EditorPlugin) -> void:
	for name in LEGACY_AUTOLOADS.keys():
		if ProjectSettings.has_setting("autoload/" + name):
			continue

		plugin.add_autoload_singleton(name, LEGACY_AUTOLOADS[name])
#endregion


#region Helpers (STATELESS & SAFE)
static func _try_register_core_autoload(plugin: EditorPlugin, file_name: String) -> void:
	var name := _to_autoload_name(file_name)

	if not name.is_valid_identifier():
		push_warning(
			"[LostFramework] Skipping invalid autoload name '%s' from file '%s'"
			% [name, file_name]
		)
		return

	if ProjectSettings.has_setting("autoload/" + name):
		return

	plugin.add_autoload_singleton(name, CORE_AUTOLOADS_PATH + file_name)


static func _to_autoload_name(file_name: String) -> String:
	# NOTE: No static state. Safe for editor reloads.

	var invalid_char_regex := RegEx.new()
	invalid_char_regex.compile("[^A-Za-z0-9_]")

	var starts_with_digit_regex := RegEx.new()
	starts_with_digit_regex.compile("^[0-9]")

	var base := file_name.get_basename()
	var parts := base.replace("-", "_").split("_", false)

	var result := ""
	for part in parts:
		if part.length() > 0:
			result += part.capitalize()

	result = invalid_char_regex.sub(result, "", true)

	if result.is_empty():
		return ""

	if starts_with_digit_regex.search(result):
		result = "_" + result

	return result


static func _is_framework_autoload(name: String) -> bool:
	if name == CORE_NAME:
		return true

	# Core folder autoloads (derived from filenames)
	var snake := name.to_snake_case()
	if FileAccess.file_exists(CORE_AUTOLOADS_PATH + snake + ".gd"):
		return true
	if FileAccess.file_exists(CORE_AUTOLOADS_PATH + snake + ".tscn"):
		return true

	# Legacy
	return LEGACY_AUTOLOADS.has(name)
#endregion
