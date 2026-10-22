@tool
extends PanelContainer
class_name AssetDatabaseRow

#region VARIABLES
const OUTER_MARGIN_PX := 6 # Increased for better spacing
const ROOT_SEPARATION_PX := 10
const COLUMN_SEPARATION_PX := 4
const DRAG_HANDLE_WIDTH_PX := 40 # Increased width for easier grabbing
const ICON_PREVIEW_SIZE := Vector2(40, 40) # Slightly larger preview

const COPY_ALPHA_IDLE := 0.5
const PREVIEW_DIM_ALPHA := 0.5

var _tab: AssetDatabaseTab
var _entry: AssetEntry

var _icon_preview: TextureRect
var _content_root: HBoxContainer
var _main_column: VBoxContainer
var _header_row: HBoxContainer
var _details_row: HBoxContainer

# UI field references
var _key_field: LineEdit
var _category_field: LineEdit

# Style variables
var _style_normal: StyleBox
var _style_hover: StyleBox
#endregion

func _init(tab: AssetDatabaseTab, entry: AssetEntry) -> void:
	_tab = tab
	_entry = entry

func _ready() -> void:
	_apply_theme()
	
	# Connect signals for hover effects
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	_build_ui()
	_update_style()

#region UI BUILDING
func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Use a separate container for margins
	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", OUTER_MARGIN_PX)
	margin_container.add_theme_constant_override("margin_right", 0) # Handle takes care of right padding
	margin_container.add_theme_constant_override("margin_top", OUTER_MARGIN_PX)
	margin_container.add_theme_constant_override("margin_bottom", OUTER_MARGIN_PX)
	margin_container.mouse_filter = Control.MOUSE_FILTER_PASS # Allow drag pass-through
	add_child(margin_container)

	# Main horizontal layout: [Preview] | [Content] | [DragHandle]
	_content_root = HBoxContainer.new()
	_content_root.add_theme_constant_override("separation", ROOT_SEPARATION_PX)
	_content_root.mouse_filter = Control.MOUSE_FILTER_PASS
	margin_container.add_child(_content_root)

	# 1. Left: Preview
	_build_icon_preview(_content_root)

	# 2. Middle: Main Content Column
	_main_column = VBoxContainer.new()
	_main_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_column.alignment = BoxContainer.ALIGNMENT_CENTER # Center content vertically
	_main_column.add_theme_constant_override("separation", COLUMN_SEPARATION_PX)
	_main_column.mouse_filter = Control.MOUSE_FILTER_PASS
	_content_root.add_child(_main_column)

	# 2.1 Header Row
	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", ROOT_SEPARATION_PX)
	_header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_header_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_main_column.add_child(_header_row)

	# 2.2 Details Row
	_details_row = HBoxContainer.new()
	_details_row.add_theme_constant_override("separation", ROOT_SEPARATION_PX)
	_details_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_details_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_main_column.add_child(_details_row)

	_build_header_content()
	_build_details_content()

	# 3. Right: Drag Handle (Distinct Area)
	_build_drag_handle(_content_root)

func _apply_theme() -> void:
	var lost_theme := Utils.get_main_theme()
	if lost_theme:
		self.theme = lost_theme
		_style_normal = lost_theme.get_stylebox("panel", "AssetDatabaseRow")
		_style_hover = lost_theme.get_stylebox("hover", "AssetDatabaseRow")
		
		if not _style_normal:
			_style_normal = lost_theme.get_stylebox("panel", "PanelContainer")
		if not _style_hover:
			_style_hover = _style_normal.duplicate() if _style_normal else null

func _update_style() -> void:
	if _style_normal:
		add_theme_stylebox_override("panel", _style_normal)
#endregion

#region INTERACTION HANDLERS
func _on_mouse_entered() -> void:
	_set_hovered(true)

func _on_mouse_exited() -> void:
	_set_hovered(false)

func _set_hovered(is_hovered: bool) -> void:
	var style := _style_hover if is_hovered else _style_normal
	if style:
		add_theme_stylebox_override("panel", style)
#endregion

#region Components Builders
func _build_drag_handle(parent: Control) -> void:
	# Create a visual container for the handle
	var handle_bg := PanelContainer.new()
	handle_bg.custom_minimum_size = Vector2(DRAG_HANDLE_WIDTH_PX, 0)
	handle_bg.mouse_filter = Control.MOUSE_FILTER_PASS # Critical: Allows drag to bubble up to root
	handle_bg.mouse_default_cursor_shape = Control.CURSOR_MOVE # Explicit move cursor
	
	# Subtle background for the handle area
	var style_flat := StyleBoxFlat.new()
	style_flat.bg_color = Color(0, 0, 0, 0.2)
	style_flat.set_corner_radius_all(0)
	# Only round right corners to match the row
	style_flat.corner_radius_top_right = 4
	style_flat.corner_radius_bottom_right = 4
	handle_bg.add_theme_stylebox_override("panel", style_flat)
	
	var center_layout := CenterContainer.new()
	center_layout.mouse_filter = Control.MOUSE_FILTER_PASS
	handle_bg.add_child(center_layout)
	
	var handle_icon := TextureRect.new()
	handle_icon.texture = get_theme_icon("GuiResizer", "EditorIcons")
	handle_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	handle_icon.modulate = Color(1, 1, 1, 0.5)
	handle_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	center_layout.add_child(handle_icon)
	
	parent.add_child(handle_bg)

func _build_icon_preview(parent: Control) -> void:
	var frame := PanelContainer.new()
	# Use a darker background for the preview to make it pop
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.5)
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	frame.add_theme_stylebox_override("panel", style)
	
	frame.mouse_filter = Control.MOUSE_FILTER_PASS # Critical: Allows dragging from the icon
	parent.add_child(frame)
	
	_icon_preview = TextureRect.new()
	_icon_preview.custom_minimum_size = ICON_PREVIEW_SIZE
	_icon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_preview.mouse_filter = Control.MOUSE_FILTER_PASS # Critical
	
	frame.add_child(_icon_preview)
	_update_preview_image()

func _update_preview_image() -> void:
	if not _icon_preview: return

	var res := _entry.resource as Resource
	if res is Texture2D:
		_icon_preview.texture = res
		_icon_preview.tooltip_text = res.resource_path
		_icon_preview.modulate = Color(1, 1, 1, 1)
		return

	var icon_name := "Object"
	if res:
		icon_name = res.get_class()
		if not has_theme_icon(icon_name, "EditorIcons"):
			icon_name = "Object"

	_icon_preview.texture = get_theme_icon(icon_name, "EditorIcons")
	_icon_preview.tooltip_text = "No Preview Available"
	_icon_preview.modulate = Color(1, 1, 1, PREVIEW_DIM_ALPHA)

func _build_header_content() -> void:
	_build_key_field(_header_row)
	_build_category_field(_header_row)
	_build_action_buttons(_header_row)

func _build_details_content() -> void:
	_build_resource_fields(_details_row)
#endregion

#region DRAG & DROP LOGIC
func _get_drag_data(_at_position: Vector2) -> Variant:
	# This function is called by Godot engine when a drag starts on this control.
	# Because we set child controls (Preview, Handle) to MOUSE_FILTER_PASS,
	# the event propagates up to here.
	var res := _entry.resource as Resource
	if not res or res.resource_path == "":
		return null

	set_drag_preview(_make_drag_preview())
	return {
		"type": "files",
		"files": PackedStringArray([res.resource_path]),
	}

func _make_drag_preview() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _icon_preview.texture if _icon_preview else null
	root.add_child(icon)

	var label := Label.new()
	label.text = _entry.key if _entry and _entry.key != "" else "Asset"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(label)

	return panel
#endregion

#region FIELD IMPLEMENTATIONS
func _build_key_field(parent: Control) -> void:
	_key_field = LineEdit.new()
	_key_field.text = _entry.key
	_key_field.placeholder_text = "Key"
	_key_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key_field.size_flags_stretch_ratio = 1.5
	_key_field.flat = false
	
	# UX: Cleaner look
	_key_field.right_icon = get_theme_icon("Token", "EditorIcons") 
	
	_key_field.text_submitted.connect(_commit_rename)
	_key_field.focus_exited.connect(func(): _commit_rename(_key_field.text))
	parent.add_child(_key_field)

func _commit_rename(text: String) -> void:
	var new_key := text.strip_edges()
	if new_key == _entry.key:
		_sync_key_field()
		return
	_tab._on_asset_renamed(_entry, new_key)

func _build_category_field(parent: Control) -> void:
	_category_field = LineEdit.new()
	_category_field.text = _entry.category
	_category_field.placeholder_text = "Category"
	_category_field.custom_minimum_size = Vector2(80, 0)
	_category_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_field.size_flags_stretch_ratio = 1.0
	
	_category_field.text_submitted.connect(_commit_category)
	_category_field.focus_exited.connect(func(): _commit_category(_category_field.text))
	parent.add_child(_category_field)

func _commit_category(text: String) -> void:
	var new_cat := text.strip_edges()
	if new_cat == _entry.category:
		_sync_category_field()
		return
	_entry.category = new_cat
	_tab._on_asset_updated(_entry)
	_sync_category_field()

func _sync_key_field() -> void:
	if _key_field: _key_field.text = _entry.key

func _sync_category_field() -> void:
	if _category_field: _category_field.text = _entry.category

func _build_resource_fields(parent: Control) -> void:
	var resource_picker := EditorResourcePicker.new()
	resource_picker.edited_resource = _entry.resource
	resource_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER # Center vertically
	resource_picker.resource_changed.connect(func(r):
		_entry.resource = r
		_update_preview_image()
		_tab._on_asset_updated(_entry)
	)
	parent.add_child(resource_picker)

func _build_action_buttons(parent: Control) -> void:
	var copy := Button.new()
	copy.icon = get_theme_icon("ActionCopy", "EditorIcons")
	copy.flat = true
	copy.tooltip_text = "Copy Code"
	copy.focus_mode = Control.FOCUS_NONE
	copy.modulate.a = COPY_ALPHA_IDLE
	
	copy.mouse_entered.connect(func(): copy.modulate.a = 1.0)
	copy.mouse_exited.connect(func(): copy.modulate.a = COPY_ALPHA_IDLE)
	
	copy.pressed.connect(func():
		DisplayServer.clipboard_set('Asset.use("%s")' % _entry.key)
	)
	parent.add_child(copy)

	var remove := Button.new()
	remove.icon = get_theme_icon("Remove", "EditorIcons")
	remove.flat = true
	remove.modulate = Color(1, 0.4, 0.4, 0.7)
	remove.tooltip_text = "Remove"
	remove.focus_mode = Control.FOCUS_NONE
	
	remove.mouse_entered.connect(func(): remove.modulate = Color(1, 0.2, 0.2, 1.0))
	remove.mouse_exited.connect(func(): remove.modulate = Color(1, 0.4, 0.4, 0.7))
	
	remove.pressed.connect(func():
		_tab._request_remove(_entry)
	)
	parent.add_child(remove)
#endregion