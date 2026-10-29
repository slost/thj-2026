## Insert, move, indent, and remove lines on one UnitFunction.
## A line may sit at most one level deeper than the condition directly above it.
## An action does not open a deeper level. Children keep their relative indent.
class_name ScriptEditing
extends RefCounted


static func insert_line(lines: Array[ScriptLine], gap: int, requested_indent: int, block: CodeBlock) -> ScriptLine:
	var line := ScriptLine.new()
	line.block = block
	var index := clampi(gap, 0, lines.size())
	line.indent = clamped_indent(lines, index, requested_indent)
	lines.insert(index, line)
	return line


## Moves the line and every deeper line under it. gap is an index in the list
## before the move (0..size). Returns false when the drop lands inside the moved block.
static func move_lines(lines: Array[ScriptLine], from_index: int, gap: int, requested_indent: int) -> bool:
	if from_index < 0 or from_index >= lines.size() or lines[from_index] == null:
		return false
	var end := subtree_end(lines, from_index)
	if gap > from_index and gap < end:
		return false
	if gap == from_index or gap == end:
		var parked := clamped_indent(lines, from_index, requested_indent, from_index, end)
		_shift_subtree(lines, from_index, parked - lines[from_index].indent)
		return true
	var chunk: Array[ScriptLine] = []
	for index in range(from_index, end):
		chunk.append(lines[index])
	for index in range(end - 1, from_index - 1, -1):
		lines.remove_at(index)
	var dest := gap
	if gap > from_index:
		dest -= chunk.size()
	dest = clampi(dest, 0, lines.size())
	var previous: ScriptLine = lines[dest - 1] if dest > 0 else null
	var target := _clamp_after(previous, requested_indent)
	var delta := target - chunk[0].indent
	for line in chunk:
		if line:
			line.indent = maxi(0, line.indent + delta)
	for index in chunk.size():
		lines.insert(dest + index, chunk[index])
	return true


## Tab is +1, Shift+Tab is -1. Already being at the limit does nothing.
static func nudge_indent(lines: Array[ScriptLine], index: int, delta: int) -> void:
	if delta == 0 or index < 0 or index >= lines.size() or lines[index] == null:
		return
	var current := maxi(lines[index].indent, 0)
	var clamped := clamped_indent(lines, index, current + delta)
	var applied := clamped - current
	if delta > 0 and applied <= 0:
		return
	if delta < 0 and applied >= 0:
		return
	_shift_subtree(lines, index, applied)


## Removes one line. A condition outdents the deeper lines under it by one.
static func remove_line(lines: Array[ScriptLine], index: int) -> CodeBlock:
	if index < 0 or index >= lines.size():
		return null
	var line := lines[index]
	var block: CodeBlock = null
	var indent := 0
	var is_condition := false
	if line:
		block = line.block
		indent = line.indent
		is_condition = line.block is ConditionBlock
	lines.remove_at(index)
	if is_condition:
		var cursor := index
		while cursor < lines.size():
			var child := lines[cursor]
			if child == null or child.indent <= indent:
				break
			child.indent = maxi(0, child.indent - 1)
			cursor += 1
	return block


static func fits_ram(used: int, block: CodeBlock, ram_max: int) -> bool:
	var extra := 0
	if block:
		extra = block.get_ram_cost()
	return used + extra <= ram_max


## Exclusive end index of the line plus every following deeper line.
static func subtree_end(lines: Array[ScriptLine], index: int) -> int:
	if index < 0 or index >= lines.size():
		return clampi(index, 0, lines.size())
	var root := 0
	if lines[index]:
		root = lines[index].indent
	var cursor := index + 1
	while cursor < lines.size():
		var line := lines[cursor]
		if line == null or line.indent <= root:
			break
		cursor += 1
	return cursor


## gap is the insert slot. skip_from..skip_until hides a subtree being dragged.
static func clamped_indent(lines: Array[ScriptLine], gap: int, requested: int, skip_from: int = -1, skip_until: int = -1) -> int:
	return _clamp_after(_line_before(lines, gap, skip_from, skip_until), requested)


static func _clamp_after(previous: ScriptLine, requested: int) -> int:
	return clampi(requested, 0, _max_after(previous))


static func _max_after(previous: ScriptLine) -> int:
	if previous == null:
		return 0
	var base := maxi(previous.indent, 0)
	if previous.block is ConditionBlock:
		return base + 1
	return base


static func _line_before(lines: Array[ScriptLine], gap: int, skip_from: int, skip_until: int) -> ScriptLine:
	var index := gap - 1
	while index >= 0:
		if skip_from >= 0 and index >= skip_from and index < skip_until:
			index = skip_from - 1
			continue
		if index < lines.size():
			return lines[index]
		return null
	return null


static func _shift_subtree(lines: Array[ScriptLine], index: int, delta: int) -> void:
	if delta == 0:
		return
	var end := subtree_end(lines, index)
	for cursor in range(index, end):
		var line := lines[cursor]
		if line:
			line.indent = maxi(0, line.indent + delta)
