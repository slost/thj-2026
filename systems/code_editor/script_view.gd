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
## False while the editor is closed, so shortcuts and drag scrolling stay off the map.
var _input_enabled := true
const _GROUP_HOLD_MSEC := 420

@onready var _scroll: ScrollContainer = %ScriptScroll
@onready var _body: Control = %ScriptBody
@onready var _links: ScriptLinks = %ScriptLinks
@onready var _rows: VBoxContainer = %ScriptRows
@onready var _empty: Label = %EmptyLabel
@onready var _indicator: ColorRect = %DropIndicator

const _GAP_SECONDS := 0.12
var _mb_used := 0
var _mb_max := 0
var _ghost: BlockCard
var _ghost_reason: Label
var _spacer: Control
var _gap_tween: Tween
var _preview_gap := -1
var _preview_indent := -1
var _preview_block: CodeBlock
var _preview_reason := ""


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


func set_mb_budget(used: int, maximum: int) -> void:
	_mb_used = maxi(used, 0)
	_mb_max = maxi(maximum, 0)


func preview_drop(at: Vector2, data: Variant) -> void:
	_show_drop(at, data, _plan(at, data))


func clear_drop_preview() -> void:
	_clear_drop_preview()


func _rebuild() -> void:
	_rebuild_queued = false
	_dismiss_drop_nodes()
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
		_clear_drop_preview()
		return true
	var plan := _plan(at_position, data)
	_show_drop(at_position, data, plan)
	return plan.x >= 0.0 and _reject_reason(data, plan).is_empty()


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _is_remove_drag(data):
		if data is Dictionary:
			data["handled"] = true
		_clear_drop_preview()
		var index := int(data.get("index", -1))
		if bool(data.get("group", false)):
			remove_group.emit(index)
		else:
			remove_line.emit(index)
		return
	var plan := _plan(at_position, data)
	_clear_drop_preview()
	if plan.x < 0.0 or not data is Dictionary or not _reject_reason(data, plan).is_empty():
		return
	data["handled"] = true
	var source := str(data.get("source", ""))
	if source == "palette":
		var block := data.get("block") as CodeBlock
		if block:
			place_block.emit(block, int(plan.x), int(plan.y))
	elif source == "script":
		move_line.emit(int(data.get("index", -1)), int(plan.x), int(plan.y))


## Keyboard shortcuts, drag scrolling, and the delete stroke. Closed editors must not see them.
func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	set_process(enabled)
	set_process_input(enabled)
	if enabled:
		return
	_stroke_open = false
	_stroke.clear()
	_clear_drop_preview()
	_paint_stroke()


func _process(delta: float) -> void:
	if not _input_enabled:
		return
	_autoscroll(delta)
	if _stroke_open:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_finish_stroke(Time.get_ticks_msec() - _stroke_started_msec)
		else:
			_note_row(_row_at_mouse())
	if not get_viewport().gui_is_dragging():
		if _preview_gap >= 0:
			_clear_drop_preview()
		return
	var local := get_local_mouse_position()
	if not Rect2(Vector2.ZERO, size).has_point(local):
		if _preview_gap >= 0:
			_clear_drop_preview()
		return
	var drag: Variant = get_viewport().gui_get_drag_data()
	if _is_remove_drag(drag):
		_clear_drop_preview()
		return
	_show_drop(local, drag, _plan(local, drag))
	_follow_drop_ghost()


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
	if not _input_enabled:
		return
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


func _show_drop(at: Vector2, data: Variant, plan: Vector2) -> void:
	if _indicator:
		_indicator.visible = false
	if _rows == null:
		return
	var gap := int(plan.x) if plan.x >= 0.0 else _gap_at(at.y)
	var indent := int(plan.y) if plan.x >= 0.0 else _raw_indent(at.x, gap, data)
	var reason := _reject_reason(data, plan)
	var block := _drag_block(data)
	var changed := _ghost == null or _preview_block != block or _preview_indent != indent
	_open_gap(gap)
	_preview_indent = indent
	if changed:
		_ensure_ghost(block, indent)
	_preview_block = block
	_preview_reason = reason
	var rejected := not reason.is_empty()
	if _ghost:
		_ghost.modulate = UiPalette.tint(UiPalette.DANGER, 0.78) if rejected else Color(1, 1, 1, 0.55)
		_ghost.visible = true
	if _ghost_reason:
		_ghost_reason.visible = rejected
		_ghost_reason.text = reason
	_follow_drop_ghost()


func _reject_reason(data: Variant, plan: Vector2) -> String:
	if plan.x < 0.0:
		return LocaleText.resolve("ui.code_editor.drop_indent", "Can't indent here", "en")
	if str(data.get("source", "")) != "palette":
		return ""
	var block := _drag_block(data)
	if block == null or ScriptEditing.fits_ram(_mb_used, block, _mb_max):
		return ""
	return LocaleText.resolve("ui.code_editor.drop_mb", "Not enough MB", "en")


func _raw_indent(local_x: float, gap: int, data: Variant) -> int:
	var skip_from := -1
	var skip_until := -1
	if data is Dictionary and str(data.get("source", "")) == "script":
		skip_from = int(data.get("index", -1))
		if skip_from >= 0:
			skip_until = ScriptEditing.subtree_end(_lines, skip_from)
	var raw := int(floor((local_x - indent_pad) / indent_step))
	return ScriptEditing.clamped_indent(_lines, gap, raw, skip_from, skip_until)


func _drag_block(data: Variant) -> CodeBlock:
	if not data is Dictionary:
		return null
	if str(data.get("source", "")) == "palette":
		return data.get("block") as CodeBlock
	var index := int(data.get("index", -1))
	if index < 0 or index >= _lines.size() or _lines[index] == null:
		return null
	return _lines[index].block


func _open_gap(gap: int) -> void:
	_ensure_spacer()
	var last := maxi(_rows.get_child_count() - 1, 0)
	_rows.move_child(_spacer, clampi(gap, 0, last))
	_preview_gap = gap
	if is_equal_approx(_spacer.custom_minimum_size.y, row_height):
		return
	if _gap_tween != null and _gap_tween.is_running():
		return
	_gap_tween = create_tween()
	_gap_tween.tween_property(_spacer, "custom_minimum_size:y", row_height, _GAP_SECONDS)


func _ensure_spacer() -> void:
	if _spacer != null and is_instance_valid(_spacer) and _spacer.get_parent() == _rows:
		return
	_spacer = Control.new()
	_spacer.name = "DropGap"
	_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(_spacer)


func _ensure_ghost(block: CodeBlock, indent: int) -> void:
	if _body == null:
		return
	if _ghost == null or not is_instance_valid(_ghost):
		_ghost = (load("res://systems/code_editor/block_card.tscn") as PackedScene).instantiate() as BlockCard
		_ghost.name = "DropGhost"
		_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost.allow_drag = false
		_ghost.z_index = 4
		_ghost.indent_pad = indent_pad
		_ghost.indent_step = indent_step
		_ghost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_body.add_child(_ghost)
	if _ghost_reason == null or not is_instance_valid(_ghost_reason):
		_ghost_reason = Label.new()
		_ghost_reason.name = "DropReason"
		_ghost_reason.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost_reason.z_index = 5
		_ghost_reason.add_theme_color_override(&"font_color", UiPalette.DANGER)
		_body.add_child(_ghost_reason)
	_ghost.custom_minimum_size = Vector2(0, row_height)
	_ghost.size = Vector2(maxf(_rows.size.x if _rows else size.x, 80.0), row_height)
	_ghost.setup(block, 0, false, indent)


func _follow_drop_ghost() -> void:
	if _spacer == null or not is_instance_valid(_spacer):
		if _links:
			_links.clear_drop()
		return
	var open := _spacer.custom_minimum_size.y
	if _links:
		_links.show_drop(_preview_gap, _preview_indent, open)
	if _ghost == null or _rows == null:
		return
	_ghost.position = _rows.position + _spacer.position
	_ghost.size.x = maxf(_rows.size.x, 80.0)
	if _ghost_reason:
		var chip_x := indent_pad + float(maxi(_preview_indent, 0)) * indent_step
		_ghost_reason.position = _ghost.position + Vector2(chip_x, -4.0)


func _dismiss_drop_nodes() -> void:
	_preview_gap = -1
	_preview_indent = -1
	_preview_block = null
	_preview_reason = ""
	if _gap_tween:
		_gap_tween.kill()
		_gap_tween = null
	_spacer = null
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	if _ghost_reason != null and is_instance_valid(_ghost_reason):
		_ghost_reason.queue_free()
	_ghost_reason = null
	if _indicator:
		_indicator.visible = false
	if _links:
		_links.clear_drop()


func _clear_drop_preview() -> void:
	var spacer := _spacer
	_dismiss_drop_nodes()
	if spacer != null and is_instance_valid(spacer):
		spacer.queue_free()


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
