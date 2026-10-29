## Right page script. One row per ScriptLine, indented like ScriptDebugPanel.
## The horizontal mouse position chooses the indent column while dragging.
class_name ScriptView
extends Control

signal place_block(block: CodeBlock, index: int, indent: int)
signal move_line(from_index: int, to_index: int, indent: int)
signal remove_line(index: int)
signal indent_line(index: int, delta: int)

const ROW_H := 34.0
const INDENT_STEP := 32.0
const PAD := 8.0
const _INK := Color(0.15, 0.11, 0.07)
const _SELECT_BG := Color("ffe08a")
const _SELECT_INK := Color("1a1408")
const _EMPTY := Color(0.4, 0.33, 0.24)

var _lines: Array[ScriptLine] = []
var _selected := -1
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _indicator: ColorRect
var _rebuild_queued := false


func _ready() -> void:
	clip_contents = true
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override(&"separation", 0)
	_scroll.add_child(_rows)
	add_child(_scroll)
	_indicator = ColorRect.new()
	_indicator.color = Color(0.42, 0.2, 0.08, 0.95)
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator.visible = false
	_indicator.z_index = 2
	add_child(_indicator)


func set_lines(lines: Array[ScriptLine]) -> void:
	_lines = lines
	_selected = -1
	_queue_rebuild()


func refresh() -> void:
	if _selected >= _lines.size():
		_selected = _lines.size() - 1
	_queue_rebuild()


func select_line(index: int) -> void:
	_selected = index
	for child in _rows.get_children():
		var row := child as _Row
		if row:
			row.set_selected(row.line_index == _selected)


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild")


func _rebuild() -> void:
	_rebuild_queued = false
	if _rows == null:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.free()
	if _lines.is_empty():
		var empty := Label.new()
		empty.text = "(empty)"
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.add_theme_font_size_override(&"font_size", 22)
		empty.add_theme_color_override(&"font_color", _EMPTY)
		_rows.add_child(empty)
		return
	for index in _lines.size():
		var line := _lines[index]
		var row := _Row.new()
		row.setup(self, index, line, index == _selected)
		_rows.add_child(row)


func _can_drop_data(at: Vector2, data: Variant) -> bool:
	var plan := _plan(at, data)
	_show_plan(plan)
	return plan.x >= 0.0


func _drop_data(at: Vector2, data: Variant) -> void:
	var plan := _plan(at, data)
	_indicator.visible = false
	if plan.x < 0.0 or not data is Dictionary:
		return
	var source := str(data.get("source", ""))
	if source == "palette":
		var block := data.get("block") as CodeBlock
		if block:
			place_block.emit(block, int(plan.x), int(plan.y))
	elif source == "script":
		move_line.emit(int(data.get("index", -1)), int(plan.x), int(plan.y))


func _process(_delta: float) -> void:
	if _indicator == null or not _indicator.visible:
		return
	if not get_viewport().gui_is_dragging():
		_indicator.visible = false
		return
	var local := get_local_mouse_position()
	if not Rect2(Vector2.ZERO, size).has_point(local):
		_indicator.visible = false


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.keycode != KEY_TAB and key.keycode != KEY_DELETE and key.keycode != KEY_BACKSPACE:
		return
	get_viewport().set_input_as_handled()
	if not key.pressed or key.echo or _selected < 0:
		return
	if key.keycode == KEY_TAB:
		indent_line.emit(_selected, -1 if key.shift_pressed else 1)
	else:
		remove_line.emit(_selected)


## Vector2(gap, indent). Empty when the drop is not allowed.
func _plan(at: Vector2, data: Variant) -> Vector2:
	if not data is Dictionary:
		return Vector2(-1, -1)
	var source := str(data.get("source", ""))
	var skip_from := -1
	var skip_until := -1
	if source == "script":
		skip_from = int(data.get("index", -1))
		if skip_from < 0 or skip_from >= _lines.size():
			return Vector2(-1, -1)
		skip_until = ScriptEditing.subtree_end(_lines, skip_from)
	elif source == "palette":
		if data.get("block") == null:
			return Vector2(-1, -1)
	else:
		return Vector2(-1, -1)
	var gap := _gap_at(at.y)
	if skip_from >= 0 and gap > skip_from and gap < skip_until:
		return Vector2(-1, -1)
	var raw := int(floor((at.x - PAD) / INDENT_STEP))
	var indent := ScriptEditing.clamped_indent(_lines, gap, raw, skip_from, skip_until)
	return Vector2(gap, indent)


func _gap_at(local_y: float) -> int:
	var scrolled := local_y
	if _scroll:
		scrolled += float(_scroll.scroll_vertical)
	if ROW_H <= 0.0:
		return 0
	return clampi(int(round(scrolled / ROW_H)), 0, _lines.size())


func _show_plan(plan: Vector2) -> void:
	if plan.x < 0.0:
		_indicator.visible = false
		return
	var y := plan.x * ROW_H
	if _scroll:
		y -= float(_scroll.scroll_vertical)
	var x := PAD + plan.y * INDENT_STEP
	_indicator.position = Vector2(x, y - 2.0)
	_indicator.size = Vector2(maxf(size.x - x - 12.0, 24.0), 4.0)
	_indicator.visible = true


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
	label.add_theme_font_size_override(&"font_size", 22)
	label.add_theme_color_override(&"font_color", _INK)
	panel.add_child(label)
	return panel


class _Row extends Control:
	var line_index := -1
	var _view: ScriptView
	var _background: ColorRect
	var _label: Label

	func setup(view: ScriptView, index: int, line: ScriptLine, selected: bool) -> void:
		_view = view
		line_index = index
		custom_minimum_size = Vector2(0, ScriptView.ROW_H)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_MOVE
		_background = ColorRect.new()
		_background.set_anchors_preset(Control.PRESET_FULL_RECT)
		_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_background)
		_label = Label.new()
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.clip_text = true
		_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_label.add_theme_font_size_override(&"font_size", 22)
		var indent := 0
		var text := "..."
		if line:
			indent = maxi(line.indent, 0)
			text = line.get_label()
		_label.offset_left = ScriptView.PAD + float(indent) * ScriptView.INDENT_STEP
		_label.text = text
		add_child(_label)
		set_selected(selected)


	func set_selected(selected: bool) -> void:
		if selected:
			_background.color = ScriptView._SELECT_BG
			_label.add_theme_color_override(&"font_color", ScriptView._SELECT_INK)
		else:
			_background.color = Color(0, 0, 0, 0)
			_label.add_theme_color_override(&"font_color", ScriptView._INK)


	func _gui_input(event: InputEvent) -> void:
		if not event is InputEventMouseButton:
			return
		var mouse := event as InputEventMouseButton
		if not mouse.pressed or _view == null:
			return
		_view.select_line(line_index)
		if mouse.button_index == MOUSE_BUTTON_RIGHT:
			_view.remove_line.emit(line_index)
			accept_event()


	func _get_drag_data(_at: Vector2) -> Variant:
		if _view:
			_view.select_line(line_index)
		var caption := _label.text if _label else "..."
		set_drag_preview(ScriptView._preview(caption))
		return {"source": "script", "index": line_index}
