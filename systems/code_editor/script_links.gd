## Connectors for the script page. Same-level blocks share a straight rail.
## Every child under a condition hangs off one shared elbow, shaped like |_.
class_name ScriptLinks
extends Control

var _lines: Array[ScriptLine] = []
var _row_height := 44.0
var _indent_step := 32.0
var _indent_pad := 8.0


func show_script(lines: Array[ScriptLine], row_height: float, indent_step: float, indent_pad: float) -> void:
	_lines = lines
	_row_height = row_height
	_indent_step = indent_step
	_indent_pad = indent_pad
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


func _draw() -> void:
	if _lines.size() < 2 or _row_height <= 0.0:
		return
	var color := get_theme_color(&"guide_color", &"BlockCard")
	color.a = 0.9
	for piece in _polylines():
		var ends: Array = piece
		draw_line(ends[0], ends[1], color, 2.5, true)


func _polylines() -> Array:
	var pieces: Array = []
	if _lines.size() < 2 or _row_height <= 0.0:
		return pieces
	for index in range(1, _lines.size()):
		var indent := _indent_of(index)
		if indent <= 0:
			var sibling := _previous_at(index, 0)
			if sibling >= 0:
				var rail := _rail(0)
				_add(pieces, rail, _center(sibling), rail, _center(index))
			continue
		var stem := _rail(indent)
		var from_y := _center(index - 1)
		if _indent_of(index - 1) < indent:
			from_y = _center(index - 1) + 18.0
		elif _indent_of(index - 1) > indent:
			var earlier := _previous_at(index, indent)
			if earlier >= 0:
				from_y = _center(earlier)
		_add(pieces, stem, from_y, stem, _center(index))
		_add(pieces, stem, _center(index), _chip_left(indent), _center(index))
	return pieces


func _indent_of(index: int) -> int:
	var line := _lines[index]
	if line == null:
		return 0
	return maxi(line.indent, 0)


func _previous_at(index: int, indent: int) -> int:
	var cursor := index - 1
	while cursor >= 0:
		if _indent_of(cursor) == indent:
			return cursor
		cursor -= 1
	return -1


func _chip_left(indent: int) -> float:
	return _indent_pad + float(indent) * _indent_step


func _rail(indent: int) -> float:
	return maxf(_chip_left(indent) - 8.0, 2.0)


func _center(index: int) -> float:
	return (float(index) + 0.5) * _row_height


func _add(pieces: Array, x0: float, y0: float, x1: float, y1: float) -> void:
	var from := Vector2(x0, y0)
	var to := Vector2(x1, y1)
	if from.distance_to(to) < 1.0:
		return
	pieces.append([from, to])
