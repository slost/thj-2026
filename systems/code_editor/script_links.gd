## Connectors for the script page.
## One main rail runs down the left. Every row, including indent 0, takes a |_ elbow
## off its parent rail. A nested row hangs off its parent condition's stem, and that
## stem joins back to the rail above it. A drop preview is one extra row in the same list.
class_name ScriptLinks
extends Control

var _lines: Array[ScriptLine] = []
var _row_height := 44.0
var _indent_step := 32.0
var _indent_pad := 8.0
var _preview_gap := -1
var _preview_indent := 0
var _preview_open := 0.0


func show_script(lines: Array[ScriptLine], row_height: float, indent_step: float, indent_pad: float) -> void:
	_lines = lines
	_row_height = row_height
	_indent_step = indent_step
	_indent_pad = indent_pad
	queue_redraw()


## gap is the insert slot. open_height is how far the rows have slid, from 0 to one row.
func show_drop(gap: int, indent: int, open_height: float) -> void:
	_preview_gap = gap
	_preview_indent = maxi(indent, 0)
	_preview_open = maxf(open_height, 0.0)
	queue_redraw()


func clear_drop() -> void:
	_preview_gap = -1
	_preview_open = 0.0
	queue_redraw()


func segment_count() -> int:
	return _polylines().size()


## True when a nested group uses an elbow beside the root rail.
func has_block_branch() -> bool:
	var rail := _rail(0)
	for piece in _polylines():
		var start: Vector2 = piece[0]
		if start.x > rail + 8.0:
			return true
	return false


## True when the first row's elbow leaves the main rail.
func root_row_has_elbow() -> bool:
	if _virtual_count() <= 0:
		return false
	var rail := _rail(0)
	var y := _center_v(0)
	for piece in _polylines():
		var start: Vector2 = piece[0]
		var finish: Vector2 = piece[1]
		var flat := absf(start.y - y) < 1.5 and absf(finish.y - y) < 1.5
		if flat and absf(start.x - rail) < 1.5 and finish.x > start.x + 2.0:
			return true
	return false


func _draw() -> void:
	if _virtual_count() <= 0 or _row_height <= 0.0:
		return
	var color := get_theme_color(&"guide_color", &"BlockCard")
	color.a = 0.9
	for piece in _polylines():
		var ends: Array = piece
		draw_line(ends[0], ends[1], color, 2.5, true)


func _polylines() -> Array:
	var pieces: Array = []
	var count := _virtual_count()
	if count <= 0 or _row_height <= 0.0:
		return pieces
	var indents: Array[int] = []
	for index in count:
		indents.append(_indent_at(index))
	var rail := _rail(0)
	var first := _center_v(0)
	var last := _center_v(count - 1)
	var stub := minf(_row_height * 0.35, 22.0)
	_add(pieces, rail, first - stub, rail, maxf(last, first))
	for index in count:
		var y := _center_v(index)
		var indent := indents[index]
		_add(pieces, _rail(indent), y, _chip_left(indent), y)
		var child_end := _descendant_end(indents, index)
		if child_end <= index:
			continue
		var stem := _rail(indent + 1)
		_add(pieces, _chip_left(indent), y, stem, y)
		_add(pieces, stem, y, stem, _center_v(child_end))
	return pieces


func _virtual_count() -> int:
	var count := _lines.size()
	if _preview_gap >= 0:
		count += 1
	return count


func _is_preview(virtual_index: int) -> bool:
	return _preview_gap >= 0 and virtual_index == clampi(_preview_gap, 0, _lines.size())


func _indent_at(virtual_index: int) -> int:
	if _is_preview(virtual_index):
		return _preview_indent
	var source := virtual_index
	if _preview_gap >= 0 and virtual_index > _preview_gap:
		source -= 1
	return _indent_of(source)


func _span(virtual_index: int) -> float:
	if _is_preview(virtual_index):
		return _preview_open
	return _row_height


func _top(virtual_index: int) -> float:
	var y := 0.0
	for index in virtual_index:
		y += _span(index)
	return y


func _center_v(virtual_index: int) -> float:
	return _top(virtual_index) + _span(virtual_index) * 0.5


func _descendant_end(indents: Array[int], index: int) -> int:
	var base := indents[index]
	var cursor := index + 1
	var last := index
	while cursor < indents.size():
		if indents[cursor] <= base:
			break
		last = cursor
		cursor += 1
	return last


func _indent_of(index: int) -> int:
	if index < 0 or index >= _lines.size() or _lines[index] == null:
		return 0
	return maxi(_lines[index].indent, 0)


func _chip_left(indent: int) -> float:
	return _indent_pad + float(indent) * _indent_step


func _rail(indent: int) -> float:
	return maxf(_chip_left(indent) - 8.0, 2.0)


func _add(pieces: Array, x0: float, y0: float, x1: float, y1: float) -> void:
	var from := Vector2(x0, y0)
	var to := Vector2(x1, y1)
	if from.distance_to(to) < 1.0:
		return
	pieces.append([from, to])
