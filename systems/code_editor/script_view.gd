## Right page script. One card per ScriptLine, indented like a nested list.
## Dropping on a block inserts below it, or into it when the pointer sits further right.
## Row slots stay still; only the card visual inside them floats.
class_name ScriptView
extends Control

signal place_block(block: CodeBlock, index: int, indent: int)
signal move_line(from_index: int, to_index: int, indent: int)
signal remove_line(index: int)
signal remove_group(index: int)
signal remove_rows(indexes: Array)
signal indent_line(index: int, delta: int)

@export var row_height: float = 64.0
@export var indent_step: float = 32.0
@export var indent_pad: float = 8.0

var _lines: Array[ScriptLine] = []
var _selected := -1
var _rebuild_queued := false
var _stroke_open := false
var _stroke_started_msec := 0
var _stroke: Array[int] = []
const _GROUP_HOLD_MSEC := 420

@onready var _scroll: ScrollContainer = %ScriptScroll
@onready var _body: Control = %ScriptBody
@onready var _links: ScriptLinks = %ScriptLinks
@onready var _rows: VBoxContainer = %ScriptRows
@onready var _empty: Label = %EmptyLabel
@onready var _indicator: ColorRect = %DropIndicator


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
	if _rows == null:
		return
	for child in _rows.get_children():
		var card := child as BlockCard
		if card:
			card.set_selected(card.line_index == _selected)


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
		var node := child as Node
		if node == null:
			continue
		_rows.remove_child(node)
		node.free()
	var empty := _lines.is_empty()
	if _empty:
		_empty.visible = empty
		_empty.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_empty.text = LocaleText.resolve("ui.code_editor.empty", "(empty)", "en")
	_sync_body()
	if empty:
		return
	for index in _lines.size():
		var line := _lines[index]
		var card := (load("res://systems/code_editor/block_card.tscn") as PackedScene).instantiate() as BlockCard
		var indent := 0
		var block: CodeBlock = null
		if line:
			indent = maxi(line.indent, 0)
			block = line.block
		card.indent_pad = indent_pad
		card.indent_step = indent_step
		card.custom_minimum_size = Vector2(0, row_height)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		card.setup(block, 0, false, indent)
		card.line_index = index
		card.allow_drag = block != null
		card.drag_data = {"source": "script", "index": index}
		card.line_pressed.connect(select_line)
		card.line_remove_requested.connect(_on_card_remove)
		card.group_remove_requested.connect(_on_card_remove_group)
		card.right_gesture_started.connect(_on_right_started)
		card.right_gesture_finished.connect(_on_right_gesture)
		card.row_touched.connect(_note_row)
		card.focus_left.connect(_on_focus_left)
		card.block_drop_requested.connect(_on_card_drop.bind(card))
		card.set_selected(index == _selected)
		_rows.add_child(card)
	_sync_body()


func _sync_body() -> void:
	var height := float(_lines.size()) * row_height
	if not _lines.is_empty():
		height += row_height
	if _body:
		_body.custom_minimum_size = Vector2(0, height)
	if _rows:
		_rows.custom_minimum_size = Vector2(0, height)
		_rows.size = Vector2(maxf(_body.size.x if _body else 0.0, _rows.size.x), height)
	if _links:
		_links.show_script(_lines, row_height, indent_step, indent_pad)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if _is_remove_drag(data):
		if _indicator:
			_indicator.visible = false
		return true
	var plan := _plan(at_position, data)
	_show_plan(plan)
	return plan.x >= 0.0


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _is_remove_drag(data):
		if data is Dictionary:
			data["handled"] = true
		_indicator.visible = false
		var index := int(data.get("index", -1))
		if bool(data.get("group", false)):
			remove_group.emit(index)
		else:
			remove_line.emit(index)
		return
	var plan := _plan(at_position, data)
	_indicator.visible = false
	if plan.x < 0.0 or not data is Dictionary:
		return
	data["handled"] = true
	var source := str(data.get("source", ""))
	if source == "palette":
		var block := data.get("block") as CodeBlock
		if block:
			place_block.emit(block, int(plan.x), int(plan.y))
	elif source == "script":
		move_line.emit(int(data.get("index", -1)), int(plan.x), int(plan.y))


func _process(delta: float) -> void:
	_autoscroll(delta)
	if _stroke_open:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_finish_stroke(Time.get_ticks_msec() - _stroke_started_msec)
		else:
			_note_row(_row_at_mouse())
	if _indicator == null or not _indicator.visible:
		return
	if not get_viewport().gui_is_dragging():
		_indicator.visible = false
		return
	var local := get_local_mouse_position()
	if not Rect2(Vector2.ZERO, size).has_point(local):
		_indicator.visible = false
		return
	var drag: Variant = get_viewport().gui_get_drag_data()
	if _is_remove_drag(drag):
		_indicator.visible = false
		return
	_show_plan(_plan(local, drag))


func _autoscroll(delta: float) -> void:
	if _scroll == null or delta <= 0.0:
		return
	var viewport := get_viewport()
	if viewport == null or not viewport.gui_is_dragging():
		return
	var local := get_local_mouse_position()
	if local.x < -8.0 or local.x > size.x + 8.0:
		return
	if local.y < -8.0 or local.y > size.y + 8.0:
		return
	var edge := clampf(size.y * 0.18, 28.0, 72.0)
	var speed := 640.0
	if local.y < edge:
		_scroll.scroll_vertical = maxi(_scroll.scroll_vertical - int(speed * delta), 0)
	elif local.y > size.y - edge:
		_scroll.scroll_vertical += int(speed * delta)


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
	var raw := int(floor((at.x - indent_pad) / indent_step))
	var indent := ScriptEditing.clamped_indent(_lines, gap, raw, skip_from, skip_until)
	return Vector2(gap, indent)


func _gap_at(local_y: float) -> int:
	var scrolled := local_y
	if _scroll:
		scrolled += float(_scroll.scroll_vertical)
	if row_height <= 0.0 or _lines.is_empty():
		return 0
	var row := int(floor(scrolled / row_height))
	if row < 0:
		return 0
	if row >= _lines.size():
		return _lines.size()
	# The pointer is on this block. Insert after it instead of taking its slot.
	return row + 1


func _show_plan(plan: Vector2) -> void:
	if _indicator == null or plan.x < 0.0:
		if _indicator:
			_indicator.visible = false
		return
	var y := plan.x * row_height
	if _scroll:
		y -= float(_scroll.scroll_vertical)
	var x := indent_pad + plan.y * indent_step
	_indicator.position = Vector2(x, y - 2.0)
	_indicator.size = Vector2(maxf(size.x - x - 12.0, 24.0), 4.0)
	_indicator.visible = true


func _on_card_drop(at_position: Vector2, data: Variant, card: BlockCard) -> void:
	var global_point := card.get_global_transform_with_canvas() * at_position
	var local := get_global_transform_with_canvas().affine_inverse() * global_point
	_drop_data(local, data)


func _on_card_remove(index: int) -> void:
	remove_line.emit(index)


func _on_card_remove_group(index: int) -> void:
	remove_group.emit(index)


func _on_right_started(index: int) -> void:
	_stroke_open = true
	_stroke_started_msec = Time.get_ticks_msec()
	_stroke = [index]
	_paint_stroke()


func _on_right_gesture(index: int, held_msec: int) -> void:
	if _stroke.is_empty():
		_stroke = [index]
		_stroke_open = true
	_finish_stroke(held_msec)


func _on_focus_left(index: int) -> void:
	if _selected == index:
		select_line(-1)


func _note_row(index: int) -> void:
	if not _stroke_open or index < 0 or index >= _lines.size():
		return
	if _stroke.has(index):
		return
	_stroke.append(index)
	_paint_stroke()


func _finish_stroke(held_msec: int) -> void:
	if not _stroke_open and _stroke.is_empty():
		return
	_stroke_open = false
	var rows: Array[int] = []
	for index in _stroke:
		rows.append(int(index))
	_stroke.clear()
	_paint_stroke()
	if rows.is_empty():
		return
	if rows.size() > 1:
		remove_rows.emit(rows)
	elif held_msec >= _GROUP_HOLD_MSEC:
		remove_group.emit(rows[0])
	else:
		remove_line.emit(rows[0])


func _paint_stroke() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		var card := child as BlockCard
		if card:
			card.set_marked(_stroke.has(card.line_index))


func _row_at_mouse() -> int:
	var local := get_local_mouse_position()
	if not Rect2(Vector2.ZERO, size).has_point(local):
		return -1
	var scrolled := local.y
	if _scroll:
		scrolled += float(_scroll.scroll_vertical)
	if row_height <= 0.0:
		return -1
	var row := int(floor(scrolled / row_height))
	if row < 0 or row >= _lines.size():
		return -1
	return row


func _is_remove_drag(data: Variant) -> bool:
	return data is Dictionary and str(data.get("source", "")) == "script" and bool(data.get("remove", false))
