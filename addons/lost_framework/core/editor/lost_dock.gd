@tool
extends Control

const MARGIN_SIZE: int = 8
const COLOR_BG_DARK := Color("#141414")
const COLOR_TAB_BG := Color("#1a1a1a")

var _tabs: TabContainer
var editor_interface = null


func _enter_tree() -> void:
	_build_layout()
	_register_tabs()


func _build_layout() -> void:
	_clear_children()

	var main_bg := PanelContainer.new()
	main_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = COLOR_BG_DARK
	main_bg.add_theme_stylebox_override("panel", bg_style)
	add_child(main_bg)

	var margin := MarginContainer.new()
	_set_margins(margin, MARGIN_SIZE)
	main_bg.add_child(margin)

	_create_tab_container(margin)


func _create_tab_container(parent: Control) -> void:
	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.all_tabs_in_front = true
	_tabs.drag_to_rearrange_enabled = true
	
	var content_style := StyleBoxFlat.new()
	content_style.bg_color = COLOR_TAB_BG
	content_style.set_border_width_all(0)
	content_style.set_content_margin_all(4)
	_tabs.add_theme_stylebox_override("panel", content_style)
	
	var tab_unselected := StyleBoxFlat.new()
	tab_unselected.bg_color = Color("#1a1a1a")
	tab_unselected.set_content_margin_all(8)
	tab_unselected.border_width_bottom = 2
	tab_unselected.border_color = Color("#141414")

	var tab_selected := StyleBoxFlat.new()
	tab_selected.bg_color = Color("#242424")
	tab_selected.set_content_margin_all(8)
	tab_selected.border_width_bottom = 2
	tab_selected.border_color = Color("#4a90e2")

	_tabs.add_theme_stylebox_override("tab_unselected", tab_unselected)
	_tabs.add_theme_stylebox_override("tab_selected", tab_selected)
	_tabs.add_theme_stylebox_override("tab_hovered", tab_selected)

	var tab_bar := _tabs.get_tab_bar()
	tab_bar.clip_tabs = false
	tab_bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	parent.add_child(_tabs)


## Central place for registering framework tabs
func _register_tabs() -> void:

	_add_tab("Asset Database", "res://addons/lost_framework/core/editor/asset_tab/asset_database_tab.gd")
	_add_tab("Modules", "res://addons/lost_framework/core/editor/tabs/modules_tab.gd")
	_add_tab("Core Autoloads", "res://addons/lost_framework/core/editor/tabs/core_autoload_tab.gd")


func _add_tab(title: String, script_path: String) -> void:
	if not FileAccess.file_exists(script_path):
		push_error("Tab script not found: " + script_path)
		return

	var script: Script = load(script_path)
	if not script:
		push_error("Invalid tab script: " + script_path)
		return

	var tab: Control = script.new()
	tab.name = title
	if editor_interface and tab.has_method("set_editor_interface"):
		tab.set_editor_interface(editor_interface)

	_tabs.add_child(tab)
	_tabs.set_tab_title(_tabs.get_child_count() - 1, title)


func set_editor_interface(value) -> void:
	editor_interface = value


func _clear_children() -> void:
	for child in get_children():
		child.queue_free()


func _set_margins(container: MarginContainer, value: int) -> void:
	container.add_theme_constant_override("margin_top", value)
	container.add_theme_constant_override("margin_left", value)
	container.add_theme_constant_override("margin_bottom", value)
	container.add_theme_constant_override("margin_right", value)
