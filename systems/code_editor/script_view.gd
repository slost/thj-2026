## Right page script. One card per ScriptLine, indented like a nested list.
## The horizontal mouse position chooses the indent column while dragging.
## Row slots stay still; only the card visual inside them floats.
class_name ScriptView
extends Control

signal place_block(block: CodeBlock, index: int, indent: int)
signal move_line(from_index: int, to_index: int, indent: int)
signal remove_line(index: int)
signal indent_line(index: int, delta: int)

@export var row_height: float = 44.0
@export var indent_step: float = 32.0
@export var indent_pad: float = 8.0

var _lines: Array[ScriptLine] = []
var _selected := -1
var _rebuild_queued := false

@onready var _scroll: ScrollContainer = %ScriptScroll
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
		card.set_selected(index == _selected)
		_rows.add_child(card)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var plan := _plan(at_position, data)
	_show_plan(plan)
	return plan.x >= 0.0


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var plan := _plan(at_position, data)
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
	var raw := int(floor((at.x - indent_pad) / indent_step))
	var indent := ScriptEditing.clamped_indent(_lines, gap, raw, skip_from, skip_until)
	return Vector2(gap, indent)


func _gap_at(local_y: float) -> int:
	var scrolled := local_y
	if _scroll:
		scrolled += float(_scroll.scroll_vertical)
	if row_height <= 0.0:
		return 0
	return clampi(int(round(scrolled / row_height)), 0, _lines.size())


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


func _on_card_remove(index: int) -> void:
	remove_line.emit(index)
