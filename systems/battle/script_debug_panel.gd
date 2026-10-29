## Separate script view. Highlights the line the pinned or hovered unit is reading.
extends Control
class_name ScriptDebugPanel


var _label: RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 32.0
	offset_top = -520.0
	offset_right = 820.0
	offset_bottom = -24.0

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.scroll_active = true
	_label.fit_content = false
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_font_size_override(&"normal_font_size", 22)
	_label.add_theme_color_override(&"default_color", Color(0.82, 0.86, 0.9))
	add_child(_label)


func _process(_delta: float) -> void:
	if _label == null:
		return
	var unit := _inspected_unit()
	if unit == null:
		_label.text = "[color=#9aa4b2]Script[/color]\nNo unit focused"
		return
	_label.text = _render(unit)


func _inspected_unit() -> Unit2D:
	var battle := get_parent()
	if battle:
		battle = battle.get_parent()
	if battle == null:
		return null
	var director := battle.get_node_or_null("FocusDirector") as FocusDirector
	if director == null:
		return null
	return director.get_inspected_unit()


func _render(unit: Unit2D) -> String:
	var rows := PackedStringArray()
	rows.append("[color=#9aa4b2]Script — %s[/color]" % _escape(unit.name))
	var function := unit.runner.get_update_script() if unit.runner else null
	var current := unit.runner.read_index if unit.runner else -1
	if function == null or function.lines.is_empty():
		rows.append("[color=#9aa4b2](empty)[/color]")
	else:
		for index in function.lines.size():
			var line := function.lines[index]
			var indent := 0
			var text := "..."
			if line:
				indent = maxi(line.indent, 0)
				text = _line_text(line)
			var shown := "%s%s" % ["    ".repeat(indent), text]
			if index == current:
				rows.append("[color=#1a1408][bgcolor=#ffe08a]%s[/bgcolor][/color]" % _escape(shown))
			else:
				rows.append(_escape(shown))
	rows.append("")
	rows.append("[color=#9aa4b2]Targets[/color]  %s" % _escape(_target_list(unit)))
	rows.append("[color=#9aa4b2]Queue[/color]  %s" % _escape(_queue_list(unit)))
	if unit.stats:
		rows.append("[color=#9aa4b2]RAM[/color]  %d / %d" % [unit.get_ram_used(), unit.stats.ram])
	return "\n".join(rows)


func _target_list(unit: Unit2D) -> String:
	if unit.targets.is_empty():
		return "-"
	var names := PackedStringArray()
	for target in unit.targets:
		if target == null or not is_instance_valid(target):
			names.append("gone")
		else:
			names.append(target.name)
	return ", ".join(names)


func _queue_list(unit: Unit2D) -> String:
	if unit.queue_actions.is_empty():
		return "-"
	var names := PackedStringArray()
	for action in unit.queue_actions:
		names.append("-" if action == null else BlockInventory.block_title(action))
	return ", ".join(names)


func _line_text(line: ScriptLine) -> String:
	if line == null or line.block == null:
		return "..."
	return BlockInventory.block_title(line.block)


func _escape(text: String) -> String:
	var out := ""
	for index in text.length():
		var ch := text[index]
		if ch == "[":
			out += "[lb]"
		elif ch == "]":
			out += "[rb]"
		else:
			out += ch
	return out
