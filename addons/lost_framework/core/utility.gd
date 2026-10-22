class_name Utils


#region Controls
static func is_anything_pressed_except_mouse() -> bool:
	if Input.is_anything_pressed() and not (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP) or Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN)):
		return true
	return false


static func is_any_action_pressed() -> bool:
	var InputMapList:Array = InputMap.get_actions()
	for actions in InputMapList:
		if Input.is_action_pressed(actions):
			print("The Input is pressed: ", actions)
			return true
	return false
#endregion

#region Utility Functions
static func generate_uid() -> String:
	return "%s_%d" % [Time.get_ticks_usec(), randi()]


static func sanitize_filename(text: String) -> String:
	var name := text.strip_edges()

	# Replace forbidden characters with underscore
	var forbidden := [
		"/", "\\", ":", "*", "?", "\"", "<", ">", "|"
	]

	for c in forbidden:
		name = name.replace(c, "_")

	# Collapse whitespace
	name = name.replace("  ", " ")

	# Avoid empty or dot-only names
	if name == "" or name == "." or name == "..":
		name = "unnamed"

	# Windows-specific: no trailing dot or space
	while name.ends_with(" ") or name.ends_with("."):
		name = name.substr(0, name.length() - 1)

	return name


# Returns the path to a file in the same directory as the script.
static func local_path(script: Script, file_name: String) -> String:
	return script.resource_path.get_base_dir().path_join(file_name)
#endregion

#region Component Helpers
## Returns the first component of the given script attached to the host.
## Example: `Utils.get_component(self, TargetingComponent)`
static func get_component(host: Node, component_script: Script) -> Component:
	if not host:
		return null
	
	for child in host.get_children():
		if child.get_script() == component_script:
			return child

		if child is ComponentContainer:
			return get_component(child, component_script)

	return null


## Returns all components of the given script attached to the host.
## Useful for stacking modifiers or multiple behaviors.
static func get_component_list(host: Node, component_script: Script) -> Array[Component]:
	var result: Array[Component] = []

	if not host:
		return result

	for child in host.get_children():
		if child.get_script() == component_script:
			result.append(child)

	return result
#endregion

#region Sorting
static func sort_nodes_by_name_ascending(parent: Node) -> void:
	var children = parent.get_children()
	
	children.sort_custom(func(a, b): return a.name.to_lower() < b.name.to_lower())
	
	for i in range(children.size()):
		parent.move_child(children[i], i)
#endregion

#region Info Strings
static func get_version_info() -> String:
	return "Build: %s" % ProjectSettings.get_setting("application/config/version")


static func get_memory_usage_mb_info() -> String:
	return "Memory Usage: %.2f MB\n" % (OS.get_static_memory_usage() / (1024.0 * 1024.0))
#endregion

#region Framework things
static func framework_version() -> String:
	var cfg := ConfigFile.new()
	var config_path = "res://addons/lost_framework/plugin.cfg"
	var err := cfg.load(config_path)

	if err != OK:
		push_error("Failed to load plugin.cfg")
		return ""

	var version := str(cfg.get_value("plugin", "version", "unknown"))
	return version


static func framework_model() -> String:
	var cfg := ConfigFile.new()
	var name := str(cfg.get_value("plugin", "name", "LOST Framework"))
	var version := framework_version()
	return "%s v%s" % [name, version]


# Return the centralized Lost Framework theme resource
static func get_main_theme() -> Theme:
	return load(Paths.MAIN_THEME)


## Apply Lost Framework theme
static func set_to_main_theme(control: Control) -> void:
	var theme := get_main_theme()
	if theme != null:
		control.theme = theme
#endregion