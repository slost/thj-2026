## Separate script view. Highlights the line the pinned or hovered unit is reading.
extends Control
class_name ScriptDebugPanel


const _PORTRAIT_MARGIN := 16.0

var _label: RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 24.0
	offset_top = 24.0
	offset_right = 480.0
	offset_bottom = 460.0
	_fit_above_portrait()

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
	_fit_above_portrait()
	if _label == null:
		return
	var unit := _inspected_unit()
	if unit == null:
		_label.text = "[color=#9aa4b2]Script[/color]\nNo unit focused"
		return
	_label.text = _render(unit)


## Bottom edge sits just above the portrait, in camp and in battle.
func _fit_above_portrait() -> void:
	var bottom := offset_top + 120.0
	if GUI != null and GUI.has_method("portrait_screen_rect"):
		var rect: Rect2 = GUI.portrait_screen_rect()
		if rect.size.y > 1.0:
			bottom = rect.position.y - _PORTRAIT_MARGIN
	bottom = maxf(bottom, offset_top + 120.0)
	if not is_equal_approx(offset_bottom, bottom):
		offset_bottom = bottom


func _inspected_unit() -> Unit2D:
	var tree := get_tree()
	if tree == null:
		return null
	var director := tree.get_first_node_in_group(FocusDirector.GROUP) as FocusDirector
	if director == null or director.process_mode == Node.PROCESS_MODE_DISABLED:
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
		var pattern := LocaleText.resolve("ui.code_editor.ram", "RAM: {used}/{max} MB", "en")
		var usage := pattern.format({"used": unit.get_ram_used(), "max": unit.stats.ram})
		rows.append("[color=#9aa4b2]%s[/color]" % usage)
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
