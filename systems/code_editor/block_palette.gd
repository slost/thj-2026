## Left page. Conditions and actions the player still owns.
## Dropping a script row here returns that block to the inventory.
class_name BlockPalette
extends Control

signal return_line(index: int)

const _INK := Color(0.16, 0.12, 0.08)
const _MUTED := Color(0.38, 0.3, 0.22)
const _EMPTY := Color(0.58, 0.52, 0.46)

var _condition_tab: Button
var _action_tab: Button
var _list: VBoxContainer
var _showing_conditions := true
var _rebuild_queued := false


func _ready() -> void:
	clip_contents = true
	_build()
	if Game.block_inventory == null:
		push_error("BlockPalette: Game.block_inventory is missing")
		return
	Game.block_inventory.changed.connect(_queue_rebuild)
	_queue_rebuild()


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return _line_index(data) >= 0


func _drop_data(_at: Vector2, data: Variant) -> void:
	var index := _line_index(data)
	if index >= 0:
		return_line.emit(index)


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild")


func _build() -> void:
	var tabs := HBoxContainer.new()
	tabs.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tabs.offset_bottom = 44.0
	tabs.add_theme_constant_override(&"separation", 8)
	_condition_tab = _tab("[ Conditions ]")
	_action_tab = _tab("< Actions >")
	_condition_tab.pressed.connect(_show_conditions)
	_action_tab.pressed.connect(_show_actions)
	tabs.add_child(_condition_tab)
	tabs.add_child(_action_tab)
	add_child(tabs)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 52.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 4)
	scroll.add_child(_list)
	add_child(scroll)
	_show_conditions()


func _tab(title: String) -> Button:
	var button := Button.new()
	button.text = title
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override(&"font_size", 20)
	button.add_theme_color_override(&"font_color", _INK)
	return button


func _show_conditions() -> void:
	_showing_conditions = true
	_condition_tab.set_pressed_no_signal(true)
	_action_tab.set_pressed_no_signal(false)
	_queue_rebuild()


func _show_actions() -> void:
	_showing_conditions = false
	_condition_tab.set_pressed_no_signal(false)
	_action_tab.set_pressed_no_signal(true)
	_queue_rebuild()


func _rebuild() -> void:
	_rebuild_queued = false
	if _list == null or Game.block_inventory == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()
	for block in Game.block_inventory.get_all():
		var is_condition := block is ConditionBlock
		if is_condition != _showing_conditions:
			continue
		_list.add_child(_Entry.new(block, Game.block_inventory.get_count(block)))


func _line_index(data: Variant) -> int:
	if not data is Dictionary:
		return -1
	if str(data.get("source", "")) != "script":
		return -1
	return int(data.get("index", -1))


class _Entry extends Control:
	var block: CodeBlock

	func _init(found: CodeBlock, count: int) -> void:
		block = found
		custom_minimum_size = Vector2(0, 40)
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = found.get_display_description() if found else ""
		var owned := count > 0
		modulate = Color.WHITE if owned else BlockPalette._EMPTY
		mouse_default_cursor_shape = Control.CURSOR_MOVE if owned else Control.CURSOR_ARROW

		var row := HBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override(&"separation", 8)
		var title := _label(BlockInventory.block_title(found), HORIZONTAL_ALIGNMENT_LEFT)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var copies := _label("x%d" % count, HORIZONTAL_ALIGNMENT_RIGHT)
		copies.custom_minimum_size = Vector2(48, 0)
		var cost := 0
		if found:
			cost = found.get_ram_cost()
		var ram := _label("%d RAM" % cost, HORIZONTAL_ALIGNMENT_RIGHT)
		ram.custom_minimum_size = Vector2(78, 0)
		row.add_child(title)
		row.add_child(copies)
		row.add_child(ram)
		add_child(row)

		var rule := ColorRect.new()
		rule.color = Color(0.35, 0.26, 0.14, 0.16)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rule.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		rule.offset_top = -1.0
		add_child(rule)


	func _get_drag_data(_at: Vector2) -> Variant:
		if block == null or Game.block_inventory == null:
			return null
		if Game.block_inventory.get_count(block) <= 0:
			return null
		set_drag_preview(_preview(BlockInventory.block_title(block)))
		return {"source": "palette", "block": block}


	func _label(text: String, alignment: HorizontalAlignment) -> Label:
		var label := Label.new()
		label.text = text
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = alignment
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override(&"font_size", 20)
		label.add_theme_color_override(&"font_color", BlockPalette._INK)
		return label


	static func _preview(text: String) -> Control:
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.97, 0.94, 0.84)
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		style.content_margin_top = 4.0
		style.content_margin_bottom = 4.0
		panel.add_theme_stylebox_override(&"panel", style)
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override(&"font_size", 20)
		label.add_theme_color_override(&"font_color", BlockPalette._INK)
		panel.add_child(label)
		return panel
