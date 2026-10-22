@tool
extends PanelContainer
class_name AssetDatabaseTab


#region Enums
enum FilterScope {
	ALL,
	KEY,
	CATEGORY,
	TAG,
	RESOURCE,
}

enum NewEntryAction {
	EMPTY,
	NEW_RESOURCE,
	EXISTING_RESOURCE,
}
#endregion


#region STATE
const UI_SEPARATION_PX := 4
const FILTER_BAR_SEPARATION_PX := 8
const LIST_SEPARATION_PX := 1
const FOOTER_HEIGHT_PX := 30

const SEARCH_PLACEHOLDER := "Filter Assets..."
const DROP_ACCENT_BG := Color(0.2, 0.7, 1.0, 0.08)
const DROP_ACCENT_BORDER := Color(0.2, 0.7, 1.0, 0.9)
const DROP_ACCENT_BORDER_PX := 2
const DROP_HELP_TEXT := "Drop files or folders to create asset entries"

var search_text: String = ""
var filter_scope: int = FilterScope.ALL

var list_container: VBoxContainer
var count_label: Label
var new_entry_button: Button
var entry_type_popup: PopupMenu
var confirm_dialog: ConfirmationDialog

# Widget refs (handy for future UX tweaks)
var _search_field: LineEdit
var _scope_option: OptionButton
var _drop_scroll: ScrollContainer
var _drop_accent: PanelContainer

var _pending_remove_entry: AssetEntry = null
var _pending_new_resource: Resource = null # Used when saving after "Create Entry with New Resource"
var _save_resource_dialog: FileDialog = null

var _asset_manager: AssetManager = null
var _core: Node = null
#endregion


class DropScrollContainer extends ScrollContainer:
	var _tab: AssetDatabaseTab

	func _init(tab: AssetDatabaseTab) -> void:
		_tab = tab

	func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
		var can := _tab._can_accept_drop_data(data)
		_tab._set_drop_highlight(can)
		return can

	func _drop_data(at_position: Vector2, data: Variant) -> void:
		_tab._handle_drop_data(data)
		_tab._set_drop_highlight(false)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			_tab._set_drop_highlight(false)


func _ready() -> void:
	_connect_core_signal()
	_resolve_asset_manager()
	_build_ui()
	call_deferred("_rebuild_rows")


func _exit_tree() -> void:
	_disconnect_core_signal()


#region UI Construction
func _build_ui() -> void:
	Utils.set_to_main_theme(self)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.theme_type_variation = "RootMarginContainer"
	add_child(margin)

	var bg_panel := PanelContainer.new()
	bg_panel.theme_type_variation = "MainPanel"
	margin.add_child(bg_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UI_SEPARATION_PX)
	bg_panel.add_child(root)

	_build_toolbar_panel(root)
	_build_list_panel(root)
	_build_footer_panel(root)


func _build_toolbar_panel(root: Control) -> void:
	var toolbar_panel := PanelContainer.new()
	toolbar_panel.theme_type_variation = "ToolbarPanel"
	root.add_child(toolbar_panel)

	var filter_bar := HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", FILTER_BAR_SEPARATION_PX)
	toolbar_panel.add_child(filter_bar)

	_search_field = _build_search_field()
	filter_bar.add_child(_search_field)

	_scope_option = _build_scope_option()
	filter_bar.add_child(_scope_option)


func _build_search_field() -> LineEdit:
	var search := LineEdit.new()
	search.placeholder_text = SEARCH_PLACEHOLDER
	search.theme_type_variation = "SearchLineEdit"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(_on_search_text_changed)
	return search


func _build_scope_option() -> OptionButton:
	var scope := OptionButton.new()
	scope.add_item("All", FilterScope.ALL)
	scope.add_item("Key", FilterScope.KEY)
	scope.add_item("Category", FilterScope.CATEGORY)
	scope.add_item("Tag", FilterScope.TAG)
	scope.add_item("Resource", FilterScope.RESOURCE)
	scope.item_selected.connect(_on_scope_selected)
	return scope


func _on_search_text_changed(t: String) -> void:
	search_text = t.strip_edges()
	_rebuild_rows()


func _on_scope_selected(i: int) -> void:
	filter_scope = i
	_rebuild_rows()


func _build_list_panel(root: Control) -> void:
	var list_panel := PanelContainer.new()
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(list_panel)

	_drop_scroll = DropScrollContainer.new(self)
	_drop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(_drop_scroll)

	list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", LIST_SEPARATION_PX)
	_drop_scroll.add_child(list_container)

	_drop_accent = _build_drop_accent_overlay()
	list_panel.add_child(_drop_accent)


func _build_footer_panel(root: Control) -> void:
	var footer := HBoxContainer.new()
	footer.custom_minimum_size = Vector2(0, FOOTER_HEIGHT_PX)
	root.add_child(footer)

	count_label = Label.new()
	count_label.text = "Total: 0"
	count_label.modulate = Color("#888888")
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(count_label)

	new_entry_button = _build_new_entry_button()
	footer.add_child(new_entry_button)

	entry_type_popup = _build_entry_type_popup()
	footer.add_child(entry_type_popup)

	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Confirm Removal"
	confirm_dialog.dialog_text = "Remove this asset entry?"
	confirm_dialog.confirmed.connect(_confirm_remove)
	add_child(confirm_dialog)


func _build_new_entry_button() -> Button:
	var button := Button.new()
	button.text = " New Entry"
	button.icon = get_theme_icon("Add", "EditorIcons")
	button.pressed.connect(_on_NewEntry_button_pressed)
	return button


func _build_entry_type_popup() -> PopupMenu:
	var popup := PopupMenu.new()
	popup.add_item("Create Empty Entry", NewEntryAction.EMPTY)
	popup.add_item("Create Entry with New Resource…", NewEntryAction.NEW_RESOURCE)
	popup.add_item("Create Entry from Existing Resource…", NewEntryAction.EXISTING_RESOURCE)
	popup.id_pressed.connect(_on_new_entry_action)
	return popup
#endregion


#region ROW BUILDING & FILTERING
func _rebuild_rows() -> void:
	_clear_list()
	var manager := _require_asset_manager()
	if manager == null:
		_set_count(0)
		return

	var entries: Array = manager.get_all_assets()
	var shown_entries: Array[AssetEntry] = []

	for entry in entries:
		if not _passes_filter(entry):
			continue

		shown_entries.append(entry)

	shown_entries.sort_custom(_sort_entries)

	var shown := 0
	var last_group := ""

	for entry in shown_entries:
		var group := _group_label(entry)
		if group != last_group:
			list_container.add_child(_build_group_header(group))
			last_group = group

		var row := AssetDatabaseRow.new(self, entry)
		# Add synchronously to preserve header -> row ordering.
		# Using call_deferred() would append all rows after the last header.
		list_container.add_child(row)
		shown += 1

	_set_count(shown)


func _clear_list() -> void:
	for c in list_container.get_children():
		c.queue_free()


func _set_count(shown: int) -> void:
	count_label.text = "Total: %d" % shown


func _sort_entries(a: AssetEntry, b: AssetEntry) -> bool:
	# Sort by group label then by key.
	var ag := _group_label(a).to_lower()
	var bg := _group_label(b).to_lower()
	if ag != bg:
		return ag < bg

	return a.key.to_lower() < b.key.to_lower()


func _group_label(entry: AssetEntry) -> String:
	# List section header: group by resource class (PackedScene, Texture2D, ...) or "Asset" if empty.
	var res := entry.resource as Resource
	if res:
		return res.get_class()
	return "Asset"


func _build_group_header(text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", FILTER_BAR_SEPARATION_PX)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = text
	label.modulate = Color("#AAAAAA")
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	var sep := HSeparator.new()
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sep.modulate.a = 0.25
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sep)

	return row


func _passes_filter(entry: AssetEntry) -> bool:
	if search_text == "":
		return true

	var query := _normalize_query(search_text)
	if query == "":
		return true

	var terms := _tokenize_query(query)
	if terms.is_empty():
		return true

	for term in terms:
		if not _matches_term(entry, term):
			return false
	return true


func _normalize_query(text: String) -> String:
	return text.strip_edges().to_lower()

func _tokenize_query(query_lower: String) -> PackedStringArray:
	# Split on whitespace and discard empties.
	# Example: "aa   bb" -> ["aa","bb"]
	var out := PackedStringArray()
	for part in query_lower.split(" ", false):
		var t := part.strip_edges()
		if t != "":
			out.append(t)
	return out


func _matches_term(entry: AssetEntry, term_lower: String) -> bool:
	# Supports prefixes like:
	# - key:foo
	# - cat:ui / category:ui
	# - tag:fx
	# - type:audio
	# - res:PackedScene / resource:texture2d
	# - path:.tscn
	var idx := term_lower.find(":")
	if idx > 0:
		var prefix := term_lower.substr(0, idx)
		var value := term_lower.substr(idx + 1).strip_edges()
		if value == "":
			return true
		return _matches_prefixed(entry, prefix, value)

	# No prefix: interpret based on current scope.
	match filter_scope:
		FilterScope.KEY:
			return _contains(entry.key, term_lower)
		FilterScope.CATEGORY:
			return _contains(entry.category, term_lower)
		FilterScope.TAG:
			return _matches_any_tag(entry, term_lower)
		FilterScope.RESOURCE:
			return _matches_resource(entry, term_lower)
		FilterScope.ALL, _:
			return _matches_any_field(entry, term_lower)


func _matches_prefixed(entry: AssetEntry, prefix_lower: String, value_lower: String) -> bool:
	match prefix_lower:
		"key":
			return _contains(entry.key, value_lower)
		"cat", "category":
			return _contains(entry.category, value_lower)
		"tag", "tags":
			return _matches_any_tag(entry, value_lower)
		"type":
			return _contains(entry.type, value_lower)
		"res", "resource":
			# resource class name + path + entry.type fallback
			return _matches_resource(entry, value_lower)
		"path":
			return _matches_resource_path(entry, value_lower)
		_:
			# Unknown prefix -> treat as free term (don't "break" search)
			return _matches_any_field(entry, value_lower)


func _matches_any_field(entry: AssetEntry, term_lower: String) -> bool:
	return (
		_contains(entry.key, term_lower)
		or _contains(entry.category, term_lower)
		or _contains(entry.type, term_lower)
		or _matches_any_tag(entry, term_lower)
		or _matches_resource(entry, term_lower)
	)


func _contains(haystack: String, needle_lower: String) -> bool:
	if needle_lower == "":
		return true
	return haystack.to_lower().find(needle_lower) != -1


func _matches_any_tag(entry: AssetEntry, query_lower: String) -> bool:
	for tag in entry.tags:
		if _contains(tag, query_lower):
			return true
	return false


func _matches_resource(entry: AssetEntry, query_lower: String) -> bool:
	var res := entry.resource as Resource
	if not res:
		return _contains(entry.type, query_lower)

	if _contains(res.get_class(), query_lower):
		return true

	var path := res.resource_path
	if path != "" and _contains(path, query_lower):
		return true

	return false


func _matches_resource_path(entry: AssetEntry, query_lower: String) -> bool:
	var res := entry.resource as Resource
	if not res:
		return false
	var path := res.resource_path
	return path != "" and _contains(path, query_lower)
#endregion


#region ACTIONS
func _on_NewEntry_button_pressed() -> void:
	_popup_menu_below(new_entry_button, entry_type_popup)


func _popup_menu_below(anchor: Control, menu: PopupMenu) -> void:
	# Popup menu near the button instead of centered.
	var r := anchor.get_global_rect()
	var pos := Vector2i(int(r.position.x), int(r.position.y + r.size.y))
	var size := Vector2i(int(r.size.x), int(r.size.y))
	menu.popup(Rect2i(pos, size))


func _build_drop_accent_overlay() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = DROP_ACCENT_BG
	style.border_color = DROP_ACCENT_BORDER
	style.set_border_width_all(DROP_ACCENT_BORDER_PX)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)

	# Help text (centered)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)

	var label := Label.new()
	label.text = DROP_HELP_TEXT
	label.modulate = DROP_ACCENT_BORDER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(label)

	return panel


func _set_drop_highlight(is_on: bool) -> void:
	if _drop_accent:
		_drop_accent.visible = is_on


func _can_accept_drop_data(data: Variant) -> bool:
	# Accept dragging files from the FileSystem dock ("type": "files").
	return not _extract_res_paths_from_drop_data(data).is_empty()


func _handle_drop_data(data: Variant) -> void:
	var manager := _require_asset_manager()
	if manager == null:
		return

	var root_paths := _extract_res_paths_from_drop_data(data)
	if root_paths.is_empty():
		return

	var res_paths := _expand_res_paths(root_paths)
	if res_paths.is_empty():
		return

	var used_keys := _build_existing_key_set()
	var created := 0

	for path in res_paths:
		if _create_resource_entry_from_res_path(path, used_keys):
			created += 1

	if created > 0:
		# Ensure the dock view is refreshed with the canonical saved instances.
		manager.rebuild_index()
		_rebuild_rows()


func _extract_res_paths_from_drop_data(data: Variant) -> PackedStringArray:
	if typeof(data) != TYPE_DICTIONARY:
		return PackedStringArray()

	var d := data as Dictionary
	if d.get("type") != "files":
		return PackedStringArray()

	var files_variant := d.get("files")
	var files: PackedStringArray = files_variant if files_variant is PackedStringArray else PackedStringArray()
	if files.is_empty():
		return PackedStringArray()

	var out := PackedStringArray()
	for f in files:
		var res_path := _to_res_path(str(f))
		if res_path == "":
			continue
		# Keep both files and folders; we'll expand folders later.
		if ResourceLoader.exists(res_path) or _is_res_dir(res_path):
			out.append(res_path)
	return out


func _to_res_path(path: String) -> String:
	# Convert absolute path to res:// when possible, otherwise keep res:// paths.
	if path.begins_with("res://"):
		return path

	# Some drags may provide absolute paths; localize them if they are inside the project.
	var localized := ProjectSettings.localize_path(path)
	if localized.begins_with("res://"):
		return localized

	return ""


func _create_resource_entry_from_res_path(res_path: String, used_keys: Dictionary) -> bool:
	var manager := _require_asset_manager()
	if manager == null:
		return false

	var res := load(res_path) as Resource
	if not res:
		return false

	var entry := manager.create_new_asset()
	if not entry:
		return false

	entry.resource = res
	entry.category = _derive_category_from_res_path(res_path)

	var base_key := _derive_key_from_file_path(res_path)
	var final_key := _generate_unique_key(base_key, used_keys)
	entry.key = final_key

	manager.save_asset(entry)
	return true


func _build_existing_key_set() -> Dictionary:
	var manager := _require_asset_manager()
	var set := {}
	if manager == null:
		return set
	for e in manager.get_all_assets():
		if e.key != "":
			set[e.key] = true
	return set


func _generate_unique_key(base_key: String, used_keys: Dictionary) -> String:
	var key := base_key.strip_edges()
	if key == "":
		key = "unnamed"

	var candidate := key
	var i := 1
	while used_keys.has(candidate):
		i += 1
		candidate = "%s_%d" % [key, i]

	used_keys[candidate] = true
	return candidate


func _derive_key_from_file_path(res_path: String) -> String:
	# Example: "res://.../sfx_attack.mp3" -> "sfx.attack"
	var base := res_path.get_file().get_basename().to_lower()
	base = base.replace("-", "_").replace(" ", "_").replace(".", "_")

	var parts := base.split("_", false)
	var out_parts: Array[String] = []

	for p in parts:
		var token := p.strip_edges()
		if token == "":
			continue
		out_parts.append(token)

	return ".".join(out_parts)


func _derive_category_from_res_path(res_path: String) -> String:
	# Use the immediate parent folder name as category (e.g. res://sfx/attack.ogg -> "sfx").
	var dir := res_path.get_base_dir()
	var folder := dir.get_file()
	return folder


func _expand_res_paths(paths: PackedStringArray) -> PackedStringArray:
	# Expand folders into file paths (non-recursive).
	var out := PackedStringArray()
	for p in paths:
		if _is_res_dir(p):
			for f in _list_res_files_in_dir(p):
				out.append(f)
		else:
			# Only accept loadable resources.
			if ResourceLoader.exists(p):
				out.append(p)
	return out


func _is_res_dir(res_path: String) -> bool:
	# DirAccess.open() succeeds for directories and fails for files.
	if not res_path.begins_with("res://"):
		return false
	return DirAccess.open(res_path) != null


func _list_res_files_in_dir(res_dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(res_dir)
	if not dir:
		return out

	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and not name.begins_with("."):
			if name.ends_with(".import") or name.ends_with(".uid"):
				name = dir.get_next()
				continue

			var path := res_dir.rstrip("/") + "/" + name
			if ResourceLoader.exists(path):
				out.append(path)
		name = dir.get_next()
	dir.list_dir_end()

	return out


func _on_new_entry_action(id: int) -> void:
	match id:
		NewEntryAction.EMPTY:
			_create_empty_entry()
		NewEntryAction.NEW_RESOURCE:
			_open_create_new_resource_dialog()
		NewEntryAction.EXISTING_RESOURCE:
			_open_existing_resource_picker()


func _create_empty_entry() -> void:
	var manager := _require_asset_manager()
	if manager == null:
		return
	manager.create_new_asset()
	_rebuild_rows()


func _open_create_new_resource_dialog() -> void:
	# Same flow as FileSystem "Create New Resource": pick type, then save as file.
	if not Engine.is_editor_hint():
		return
	EditorInterface.popup_create_dialog(
		_on_new_resource_type_selected,
		&"Resource",
		"",
		"Create New Resource"
	)


func _on_new_resource_type_selected(type_name: StringName) -> void:
	if type_name.is_empty():
		return
	var res: Resource = ClassDB.instantiate(type_name) as Resource
	if not res:
		return
	_pending_new_resource = res
	_ensure_save_resource_dialog()
	_save_resource_dialog.current_dir = Paths.data_assets()
	_save_resource_dialog.current_file = "new_resource.tres"
	_save_resource_dialog.popup_centered()


func _ensure_save_resource_dialog() -> void:
	if _save_resource_dialog:
		return
	_save_resource_dialog = FileDialog.new()
	_save_resource_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_resource_dialog.access = FileDialog.ACCESS_RESOURCES
	_save_resource_dialog.title = "Save New Resource"
	_save_resource_dialog.add_filter("*.tres ; Resource files")
	_save_resource_dialog.file_selected.connect(_on_save_new_resource_path_selected)
	add_child(_save_resource_dialog)


func _on_save_new_resource_path_selected(path: String) -> void:
	var manager := _require_asset_manager()
	if manager == null:
		return

	var res: Resource = _pending_new_resource
	_pending_new_resource = null
	if not res:
		return
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save resource: %s" % path)
		return
	# Create asset entry pointing to the new resource (use res:// path for loading)
	var res_path := path
	if not res_path.begins_with("res://"):
		res_path = ProjectSettings.localize_path(path)
	var loaded := load(res_path) as Resource
	if not loaded:
		return
	var used_keys := _build_existing_key_set()
	var entry := manager.create_new_asset()
	if not entry:
		return
	entry.resource = loaded
	entry.key = _generate_unique_key(_derive_key_from_file_path(res_path), used_keys)
	entry.category = _derive_category_from_res_path(res_path)
	manager.save_asset(entry)
	manager.rebuild_index()
	_rebuild_rows()


func _open_existing_resource_picker() -> void:
	# Quick-open dialog to pick an existing resource file (like FileSystem).
	if not Engine.is_editor_hint():
		return
	EditorInterface.popup_quick_open(_on_existing_resource_selected)


func _on_existing_resource_selected(path: String) -> void:
	var manager := _require_asset_manager()
	if manager == null:
		return

	if path.is_empty():
		return
	if not ResourceLoader.exists(path):
		return
	var res := load(path) as Resource
	if not res:
		return
	var used_keys := _build_existing_key_set()
	var entry := manager.create_new_asset()
	if not entry:
		return
	entry.resource = res
	entry.key = _generate_unique_key(_derive_key_from_file_path(path), used_keys)
	entry.category = _derive_category_from_res_path(path)
	manager.save_asset(entry)
	manager.rebuild_index()
	_rebuild_rows()


func _on_asset_renamed(entry: AssetEntry, new_key: String) -> void:
	var manager := _require_asset_manager()
	if manager == null:
		return
	manager.rename_asset(entry, new_key)
	_rebuild_rows()


func _on_asset_updated(entry: AssetEntry) -> void:
	var manager := _require_asset_manager()
	if manager == null:
		return
	manager.save_asset(entry)


func _request_remove(entry: AssetEntry) -> void:
	_pending_remove_entry = entry
	
	if _is_empty_asset(entry):
		_on_remove()
		return

	
	confirm_dialog.popup_centered()



func _confirm_remove() -> void:
	if _pending_remove_entry == null:
		return

	_on_remove()


func _on_remove() -> void:
	var manager := _require_asset_manager()
	if manager == null:
		return
	manager.delete_asset(_pending_remove_entry)
	_pending_remove_entry = null
	_rebuild_rows()
#endregion


func _is_empty_asset(entry: AssetEntry) -> bool:
	if entry.key.strip_edges() != "":
		return false

	if entry.category.strip_edges() != "":
		return false

	if entry.tags.size() > 0:
		return false

	if entry.resource:
		return false

	return true


func _connect_core_signal() -> void:
	_core = get_node_or_null("/root/Lost")
	if _core == null:
		return
	if not _core.has_signal("modules_scanned"):
		return

	var callback := Callable(self, "_on_modules_scanned")
	if not _core.is_connected("modules_scanned", callback):
		_core.connect("modules_scanned", callback)


func _disconnect_core_signal() -> void:
	if _core == null:
		return
	if not _core.has_signal("modules_scanned"):
		_core = null
		return

	var callback := Callable(self, "_on_modules_scanned")
	if _core.is_connected("modules_scanned", callback):
		_core.disconnect("modules_scanned", callback)
	_core = null


func _on_modules_scanned(_total_modules: int) -> void:
	# Re-resolve in case AssetManager is instantiated after this tab's _ready().
	_asset_manager = null
	_resolve_asset_manager()
	call_deferred("_rebuild_rows")


func _require_asset_manager() -> AssetManager:
	if _asset_manager:
		return _asset_manager
	return _resolve_asset_manager()


func _resolve_asset_manager() -> AssetManager:
	var core := get_node_or_null("/root/Lost")
	if core == null:
		return _build_fallback_asset_manager()

	if core.has_method("get_module"):
		var module = core.get_module("asset_manager")
		if module is AssetManager:
			_asset_manager = module
			return _asset_manager

	var by_name := core.get_node_or_null("AssetManager")
	if by_name is AssetManager:
		_asset_manager = by_name
		return _asset_manager

	return _build_fallback_asset_manager()


func _build_fallback_asset_manager() -> AssetManager:
	if _asset_manager:
		return _asset_manager

	var script := load("res://addons/lost_framework/modules/asset_manager/asset_manager.module.gd") as Script
	if not script:
		push_warning("Asset Database fallback could not load AssetManager script.")
		return null

	var manager := script.new() as AssetManager
	if manager == null:
		push_warning("Asset Database fallback could not instantiate AssetManager.")
		return null

	# Keep the editor tool usable even when LostCore's module cache misses asset_manager.
	manager.rebuild_index()
	_asset_manager = manager
	return _asset_manager
