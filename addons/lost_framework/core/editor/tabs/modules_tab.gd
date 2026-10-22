@tool
extends VBoxContainer


# Configuration for visual spacing and layout.
const CARD_MARGIN := 6
const CONTENT_MARGIN := 12
const CORNER_RADIUS := 6

var editor_interface = null
var _core: Node = null
var _toggle_service := ModuleToggleService.new()
var _module_cards: Dictionary = {}
var _prefer_card_refresh_on_scan := false


func _ready() -> void:
	# Ensure the UI rebuilds when the node enters the scene tree.
	_connect_core_signals()
	_build()


func _exit_tree() -> void:
	_disconnect_core_signals()


func _connect_core_signals() -> void:
	_core = _get_core()
	if not _core:
		return
	if not _core.has_signal("modules_scanned"):
		return

	var callback := Callable(self, "_on_modules_scanned")
	if not _core.is_connected("modules_scanned", callback):
		_core.connect("modules_scanned", callback)


func _disconnect_core_signals() -> void:
	if not _core:
		return
	if not _core.has_signal("modules_scanned"):
		return

	var callback := Callable(self, "_on_modules_scanned")
	if _core.is_connected("modules_scanned", callback):
		_core.disconnect("modules_scanned", callback)
	_core = null


func _on_modules_scanned(_total_modules: int) -> void:
	if _prefer_card_refresh_on_scan:
		_prefer_card_refresh_on_scan = false
		call_deferred("_refresh_module_cards_from_core")
		return
	call_deferred("_build")


func _build() -> void:
	_clear_children()
	_module_cards.clear()
	
	# Add a main header for the list.
	var main_header := Label.new()
	main_header.text = "INSTALLED MODULES"
	main_header.add_theme_font_override("font", get_theme_font("title", "EditorFonts"))
	main_header.add_theme_color_override("font_color", get_theme_color("accent_color", "Editor"))
	main_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(main_header)
	
	# Add a spacer.
	add_child(HSeparator.new())

	# Create a ScrollContainer to handle many modules.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	
	# Container for the list items inside the scroll view.
	var list_container := VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 8)
	scroll.add_child(list_container)

	# --- Core Logic Retrieval ---
	var core := _get_core()
	if not core:
		_add_empty(list_container, "LostCore not found. Ensure autoload 'Lost' is enabled.")
		return

	var modules_dict: Dictionary = core.modules
	if modules_dict.is_empty():
		_add_empty(list_container, "No modules loaded.")
		return

	var ids := modules_dict.keys()
	ids.sort()

	# --- Module Rendering Loop ---
	var core_items: Array = []
	var extension_items: Array = []
	var tooling_items: Array = []
	var uncategorized_items: Array = []
	for id in ids:
		var module_entry = modules_dict[id]
		var meta := _get_module_metadata(module_entry)
		if not meta:
			uncategorized_items.append(id)
			continue
		match meta.role:
			ModuleMetadata.Role.CORE:
				core_items.append(id)
			ModuleMetadata.Role.EXTENSION:
				extension_items.append(id)
			ModuleMetadata.Role.TOOLING:
				tooling_items.append(id)
			_:
				uncategorized_items.append(id)

	if core_items.is_empty() and extension_items.is_empty() and tooling_items.is_empty() and uncategorized_items.is_empty():
		_add_empty(list_container, "No modules loaded.")
		return

	if not core_items.is_empty():
		_add_section_header(list_container, "CORE MODULES")
		for id in core_items:
			_create_module_card(list_container, id, modules_dict[id])

	if not extension_items.is_empty():
		_add_section_header(list_container, "EXTENSION MODULES")
		for id in extension_items:
			_create_module_card(list_container, id, modules_dict[id])

	if not tooling_items.is_empty():
		_add_section_header(list_container, "TOOLING MODULES")
		for id in tooling_items:
			_create_module_card(list_container, id, modules_dict[id])

	if not uncategorized_items.is_empty():
		_add_section_header(list_container, "UNCATEGORIZED MODULES")
		for id in uncategorized_items:
			_create_module_card(list_container, id, modules_dict[id])


func _create_module_card(parent: Control, id: String, module_entry) -> void:
	var module = _get_module_instance(module_entry)
	# Extract metadata.
	var meta := _get_module_metadata(module_entry)

	var display_name := id
	if meta and meta.name != "":
		display_name = meta.name
	elif module is Node and module.has_method("get_id"):
		display_name = module.get_id()
	elif meta and meta.id != "":
		display_name = meta.id

	var version := meta.version if meta else "1.0"
	var description := meta.description if meta else "No description available."
	var is_enabled := _get_module_enabled_state(id, module_entry)

	# 1. Main Card Container (PanelContainer for background styling).
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Create a dynamic stylebox based on editor theme.
	var style := StyleBoxFlat.new()
	style.bg_color = get_theme_color("base_color", "Editor") * Color(1.1, 1.1, 1.1, 1.0) # Slightly lighter than base
	style.border_color = get_theme_color("box_selection_fill_color", "Editor") # Subtle accent border
	style.border_width_left = 4 # Accent strip on the left
	style.content_margin_top = CONTENT_MARGIN
	style.content_margin_bottom = CONTENT_MARGIN
	style.content_margin_left = CONTENT_MARGIN
	style.content_margin_right = CONTENT_MARGIN
	style.set_corner_radius_all(CORNER_RADIUS)
	
	card.add_theme_stylebox_override("panel", style)
	parent.add_child(card)

	# 2. Layout inside the card.
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)

	# 3. Header Row split into sections:
	# Front: Name | Version | Type badge
	# Mid: compact action buttons (script/folder/doc)
	# Right: large toggle slider
	var header := HBoxContainer.new()
	row.add_child(header)

	var front_section := HBoxContainer.new()
	front_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	front_section.add_theme_constant_override("separation", 6)
	header.add_child(front_section)

	var actions_section := HBoxContainer.new()
	actions_section.add_theme_constant_override("separation", 2)
	header.add_child(actions_section)

	var section_divider := Label.new()
	section_divider.text = "|"
	section_divider.modulate = Color(0.7, 0.7, 0.7)
	section_divider.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(section_divider)

	var title_lbl := Label.new()
	title_lbl.text = display_name
	title_lbl.add_theme_font_override("font", get_theme_font("bold", "EditorFonts"))
	front_section.add_child(title_lbl)

	# Version Badge.
	var version_panel: PanelContainer = null
	var ver_lbl: Label = null
	if version != "":
		version_panel = PanelContainer.new()
		var ver_style := StyleBoxFlat.new()
		ver_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
		ver_style.set_corner_radius_all(4)
		ver_style.content_margin_left = 6
		ver_style.content_margin_right = 6
		version_panel.add_theme_stylebox_override("panel", ver_style)
		
		ver_lbl = Label.new()
		ver_lbl.text = "v" + version
		ver_lbl.add_theme_font_override("font", get_theme_font("main", "EditorFonts"))
		ver_lbl.modulate = Color(0.7, 0.7, 0.7) # Dimmed color
		version_panel.add_child(ver_lbl)
		front_section.add_child(version_panel)

	# Type Badge.
	var type_panel: PanelContainer = null
	var type_lbl: Label = null
	if meta and meta.type == ModuleMetadata.Type.PASSIVE:
		type_panel = PanelContainer.new()
		var passive_style := StyleBoxFlat.new()
		passive_style.bg_color = Color(0.15, 0.3, 0.2, 0.6)
		passive_style.set_corner_radius_all(4)
		passive_style.content_margin_left = 6
		passive_style.content_margin_right = 6
		type_panel.add_theme_stylebox_override("panel", passive_style)

		type_lbl = Label.new()
		type_lbl.text = "PASSIVE"
		type_lbl.add_theme_font_override("font", get_theme_font("main", "EditorFonts"))
		type_lbl.modulate = Color(0.7, 0.9, 0.8)
		type_panel.add_child(type_lbl)
		front_section.add_child(type_panel)
	elif meta and meta.type == ModuleMetadata.Type.RUNTIME:
		type_panel = PanelContainer.new()
		var runtime_style := StyleBoxFlat.new()
		runtime_style.bg_color = Color(0.35, 0.15, 0.15, 0.6)
		runtime_style.set_corner_radius_all(4)
		runtime_style.content_margin_left = 6
		runtime_style.content_margin_right = 6
		type_panel.add_theme_stylebox_override("panel", runtime_style)

		type_lbl = Label.new()
		type_lbl.text = "RUNTIME"
		type_lbl.add_theme_font_override("font", get_theme_font("main", "EditorFonts"))
		type_lbl.modulate = Color(0.95, 0.7, 0.7)
		type_panel.add_child(type_lbl)
		front_section.add_child(type_panel)

	# Module Toggle Slider (large right-side control).
	var toggle_btn := CheckButton.new()
	toggle_btn.custom_minimum_size = Vector2(92, 34)
	toggle_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle_btn.button_pressed = is_enabled
	_update_toggle_button_visual(toggle_btn, is_enabled)
	if meta and meta.role == ModuleMetadata.Role.CORE:
		toggle_btn.disabled = true
		toggle_btn.tooltip_text = "Core modules cannot be toggled"
	else:
		toggle_btn.toggled.connect(_on_module_toggled.bind(id, meta, card, toggle_btn))
	header.add_child(toggle_btn)

	# Script Button.
	var script_btn := Button.new()
	script_btn.tooltip_text = "Open module script"
	script_btn.flat = true
	
	# Try to get the specific script icon, fallback to generic File.
	if has_theme_icon("Script", "EditorIcons"):
		script_btn.icon = get_theme_icon("Script", "EditorIcons")
	else:
		script_btn.text = "< >"
		
	if module is Node:
		script_btn.pressed.connect(_open_module_script.bind(module))
	else:
		script_btn.disabled = true
		script_btn.tooltip_text = "No core script for passive module"
	script_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	actions_section.add_child(script_btn)

	# Folder Button.
	var folder_btn := Button.new()
	folder_btn.tooltip_text = "Show in FileSystem"
	folder_btn.flat = true
	if has_theme_icon("Folder", "EditorIcons"):
		folder_btn.icon = get_theme_icon("Folder", "EditorIcons")
	else:
		folder_btn.text = "Dir"
	folder_btn.pressed.connect(_open_module_folder.bind(module, meta))
	folder_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	actions_section.add_child(folder_btn)

	# Document Button (placeholder).
	var doc_btn := Button.new()
	doc_btn.tooltip_text = "Not implemented yet"
	doc_btn.flat = true
	if has_theme_icon("Help", "EditorIcons"):
		doc_btn.icon = get_theme_icon("Help", "EditorIcons")
	else:
		doc_btn.text = "?"
	doc_btn.pressed.connect(_show_not_implemented)
	doc_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	actions_section.add_child(doc_btn)

	# 4. Description Row.
	var desc_lbl := Label.new()
	desc_lbl.text = description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.modulate = Color(0.8, 0.8, 0.8) # Slightly dimmed text
	desc_lbl.add_theme_font_override("font", get_theme_font("doc_italic", "EditorFonts")) # Italic if available
	row.add_child(desc_lbl)

	_apply_module_enabled_visual(card, is_enabled)
	_module_cards[id] = {
		"card": card,
		"toggle_btn": toggle_btn,
		"title_lbl": title_lbl,
		"desc_lbl": desc_lbl,
		"version_panel": version_panel,
		"version_lbl": ver_lbl,
		"type_panel": type_panel,
		"type_lbl": type_lbl
	}


func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
	_module_cards.clear()


func _get_core() -> Node:
	return get_node_or_null("/root/Lost")


func _add_empty(parent: Node, message: String) -> void:
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(0.6, 0.6, 0.6)
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(label)


func _add_section_header(parent: Node, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_override("font", get_theme_font("bold", "EditorFonts"))
	label.modulate = Color(0.8, 0.8, 0.8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	parent.add_child(HSeparator.new())


func _get_module_instance(module_entry):
	if module_entry is Dictionary:
		return module_entry.get("module")
	return module_entry


func _get_module_metadata(module_entry) -> ModuleMetadata:
	if module_entry is Dictionary:
		var metadata = module_entry.get("metadata")
		if metadata is ModuleMetadata:
			return metadata
		var wrapped_module = module_entry.get("module")
		if wrapped_module is ModuleMetadata:
			return wrapped_module
		if wrapped_module and "metadata" in wrapped_module and wrapped_module.metadata is ModuleMetadata:
			return wrapped_module.metadata
		return null

	if module_entry is ModuleMetadata:
		return module_entry
	if module_entry and "metadata" in module_entry and module_entry.metadata is ModuleMetadata:
		return module_entry.metadata
	return null


func _get_module_enabled_state(id: String, module_entry) -> bool:
	if module_entry is Dictionary and module_entry.has("activated"):
		return module_entry.get("activated", true)
	var core := _get_core()
	if core and core.has_method("is_module_activated"):
		return core.is_module_activated(id)
	return true


func _on_module_toggled(enabled: bool, id: String, meta: ModuleMetadata, card: PanelContainer, toggle_btn: Button) -> void:
	if meta and meta.role == ModuleMetadata.Role.CORE:
		toggle_btn.set_pressed_no_signal(true)
		return

	var core := _get_core()
	var folder_path := ""
	if core and core.has_method("get_assigned_folder_path"):
		folder_path = core.get_assigned_folder_path(id)

	var toggle_ok := _toggle_service.set_module_ignored(folder_path, enabled)
	if not toggle_ok:
		var fallback_enabled := not enabled
		toggle_btn.set_pressed_no_signal(fallback_enabled)
		_apply_module_enabled_visual(card, fallback_enabled)
		_update_toggle_button_visual(toggle_btn, fallback_enabled)
		OS.alert("Failed to toggle module '%s'. Check the assigned module list and folder permissions." % id)
		return

	call_deferred("_refresh_after_module_toggle")

	if core:
		if core.modules.has(id):
			if enabled and core.has_method("activate_module"):
				core.activate_module(id)
			elif not enabled and core.has_method("deactivate_module"):
				core.deactivate_module(id)
		elif core.has_method("set_assigned_activation"):
			core.set_assigned_activation(id, enabled)

	var synced_enabled := enabled
	if core and core.modules.has(id) and core.has_method("is_module_activated"):
		synced_enabled = core.is_module_activated(id)
	toggle_btn.set_pressed_no_signal(synced_enabled)
	_apply_module_enabled_visual(card, synced_enabled)
	_update_toggle_button_visual(toggle_btn, synced_enabled)


func _refresh_after_module_toggle() -> void:
	if not Engine.is_editor_hint():
		return
	if not editor_interface:
		return

	# Let file operations (.gdignore create/remove) settle before rescanning.
	await get_tree().process_frame

	# Ensure editor FileSystem picks up .gdignore changes immediately.
	if editor_interface.has_method("get_resource_filesystem"):
		var filesystem = editor_interface.get_resource_filesystem()
		if filesystem:
			if filesystem.has_method("scan"):
				filesystem.scan()
			elif filesystem.has_method("scan_sources"):
				filesystem.scan_sources()

			# Wait for async editor filesystem scan to finish before refreshing module registry.
			if filesystem.has_method("is_scanning"):
				var guard := 0
				while filesystem.is_scanning() and guard < 240:
					guard += 1
					await get_tree().process_frame

	# Assign the module list from disk after module settings change.
	var core := _get_core()
	if core and core.has_method("assign_modules"):
		_prefer_card_refresh_on_scan = true
		core.assign_modules()


func _refresh_module_cards_from_core() -> void:
	if _module_cards.is_empty():
		call_deferred("_build")
		return

	var core := _get_core()
	if not core:
		call_deferred("_build")
		return

	var modules_dict: Dictionary = core.modules
	for id in _module_cards.keys():
		var refs = _module_cards.get(id)
		if not (refs is Dictionary):
			continue
		if modules_dict.has(id):
			_update_module_card(refs, id, modules_dict[id])
		else:
			_mark_module_card_missing(refs)


func _update_module_card(refs: Dictionary, id: String, module_entry) -> void:
	var module = _get_module_instance(module_entry)
	var meta := _get_module_metadata(module_entry)
	var display_name := id
	if meta and meta.name != "":
		display_name = meta.name
	elif module is Node and module.has_method("get_id"):
		display_name = module.get_id()
	elif meta and meta.id != "":
		display_name = meta.id

	var description := meta.description if meta else "No description available."
	var version := meta.version if meta else ""
	var is_enabled := _get_module_enabled_state(id, module_entry)

	var title_lbl = refs.get("title_lbl")
	if title_lbl is Label:
		title_lbl.text = display_name

	var desc_lbl = refs.get("desc_lbl")
	if desc_lbl is Label:
		desc_lbl.text = description

	var version_panel = refs.get("version_panel")
	var version_lbl = refs.get("version_lbl")
	if version_panel is CanvasItem:
		version_panel.visible = version != ""
	if version_lbl is Label:
		version_lbl.text = "v" + version if version != "" else ""

	var type_panel = refs.get("type_panel")
	var type_lbl = refs.get("type_lbl")
	_update_type_badge(type_panel, type_lbl, meta)

	var toggle_btn = refs.get("toggle_btn")
	if toggle_btn is CheckButton:
		toggle_btn.set_pressed_no_signal(is_enabled)
		_update_toggle_button_visual(toggle_btn, is_enabled)
		toggle_btn.disabled = meta != null and meta.role == ModuleMetadata.Role.CORE
		if toggle_btn.disabled:
			toggle_btn.tooltip_text = "Core modules cannot be toggled"

	var card = refs.get("card")
	if card is PanelContainer:
		_apply_module_enabled_visual(card, is_enabled)


func _mark_module_card_missing(refs: Dictionary) -> void:
	var title_lbl = refs.get("title_lbl")
	if title_lbl is Label and not title_lbl.text.ends_with(" (missing)"):
		title_lbl.text = title_lbl.text + " (missing)"

	var desc_lbl = refs.get("desc_lbl")
	if desc_lbl is Label:
		desc_lbl.text = "Module is currently excluded by .gdignore."

	var toggle_btn = refs.get("toggle_btn")
	if toggle_btn is CheckButton:
		toggle_btn.disabled = false
		toggle_btn.set_pressed_no_signal(false)
		toggle_btn.tooltip_text = "Enable module"
		_update_toggle_button_visual(toggle_btn, false)

	var card = refs.get("card")
	if card is PanelContainer:
		_apply_module_enabled_visual(card, false)


func _update_type_badge(type_panel, type_lbl, meta: ModuleMetadata) -> void:
	if not (type_panel is PanelContainer):
		return
	if not (type_lbl is Label):
		return
	if not meta:
		type_panel.visible = false
		return

	type_panel.visible = true
	var style := type_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if not (style is StyleBoxFlat):
		return

	if meta.type == ModuleMetadata.Type.PASSIVE:
		type_lbl.text = "PASSIVE"
		type_lbl.modulate = Color(0.7, 0.9, 0.8)
		style.bg_color = Color(0.15, 0.3, 0.2, 0.6)
	elif meta.type == ModuleMetadata.Type.RUNTIME:
		type_lbl.text = "RUNTIME"
		type_lbl.modulate = Color(0.95, 0.7, 0.7)
		style.bg_color = Color(0.35, 0.15, 0.15, 0.6)
	else:
		type_panel.visible = false


func _apply_module_enabled_visual(card: PanelContainer, enabled: bool) -> void:
	card.modulate = Color(1, 1, 1, 1) if enabled else Color(0.55, 0.55, 0.55, 0.8)


func _update_toggle_button_visual(toggle_btn: Button, enabled: bool) -> void:
	toggle_btn.text = "ON" if enabled else "OFF"
	toggle_btn.tooltip_text = "Disable module" if enabled else "Enable module"


func _open_module_script(module) -> void:
	if not module or not (module is Node):
		return
	var script = module.get_script()
	if not script: return
	
	var path := script.resource_path as String
	if path == "": return

	# Prefer editor script view when available; fall back to external editor.
	if Engine.is_editor_hint() and editor_interface:
		if editor_interface.has_method("edit_script"):
			editor_interface.edit_script(script)
			return
		# Fallback for older Godot versions or different interface structures
		var editor = editor_interface.get_script_editor() as Object
		if editor and editor.has_method("open_script"):
			editor.open_script(script)
			return
			
	OS.shell_open(ProjectSettings.globalize_path(path))


func _open_module_folder(module, meta: ModuleMetadata) -> void:
	var path := ""
	if module and (module is Node):
		var script = module.get_script()
		if script:
			path = script.resource_path.get_base_dir()
	if path == "" and meta and meta.id != "":
		path = "res://addons/lost_framework/modules/%s" % meta.id
	if path == "":
		_show_not_implemented()
		return
	if not _reveal_in_filesystem(path):
		OS.shell_open(ProjectSettings.globalize_path(path))


func _show_not_implemented() -> void:
	OS.alert("Not implemented yet")


func _reveal_in_filesystem(path: String) -> bool:
	if not Engine.is_editor_hint():
		return false
	if not editor_interface:
		return false
	if not editor_interface.has_method("get_file_system_dock"):
		return false
	var dock = editor_interface.get_file_system_dock()
	if not dock:
		return false

	if dock.has_method("navigate_to_path"):
		dock.navigate_to_path(path)
		return true
	if dock.has_method("select_path"):
		dock.select_path(path)
		return true
	if dock.has_method("select_file"):
		dock.select_file(path)
		return true
	return false


func set_editor_interface(value) -> void:
	editor_interface = value
