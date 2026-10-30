## Separate script view placed in the GUI scene. Highlights the line being read.
extends Control
class_name ScriptDebugPanel


@onready var _label: RichTextLabel = get_node_or_null("Body") as RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _label == null:
		_label = RichTextLabel.new()
		_label.name = "Body"
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_label)
	_label.bbcode_enabled = true
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.scroll_active = true
	_label.fit_content = false
	_label.add_theme_font_size_override(&"normal_font_size", 22)
	_label.add_theme_color_override(&"default_color", Color(0.82, 0.86, 0.9))


func _process(_delta: float) -> void:
	if _label == null:
		return
	var unit := _inspected_unit()
	if unit == null:
		_label.text = "[color=#9aa4b2]Script[/color]\nNo unit focused"
		return
	_label.text = _render(unit)


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
	rows.append("[color=#9aa4b2]Script — %s[/color]" % _escape(_script_title(unit)))
	rows.append("[color=#9aa4b2]Doing[/color]  %s" % _escape(_current_action(unit)))
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


func _script_title(unit: Unit2D) -> String:
	var slot := unit.spell_slot
	if slot < 0 or Game == null or slot >= Game.spells.size():
		return unit.name
	var spell := Game.spells[slot]
	if spell == null:
		return unit.name
	var title := spell.display_name()
	if title.is_empty():
		title = unit.name
	if not _matches_spell(unit, spell):
		title += " (Old)"
	return title


func _matches_spell(unit: Unit2D, spell: SummonSpell) -> bool:
	var live := spell.get_update_function()
	var owned := unit.runner.get_update_script() if unit.runner else null
	if live == null or owned == null:
		return false
	if live.lines.size() != owned.lines.size():
		return false
	for index in live.lines.size():
		var current := live.lines[index]
		var copied := owned.lines[index]
		if current == null or copied == null:
			if current != copied:
				return false
			continue
		if current.indent != copied.indent:
			return false
		var current_id := ""
		var copied_id := ""
		if current.block:
			current_id = str(current.block.id)
		if copied.block:
			copied_id = str(copied.block.id)
		if current_id != copied_id:
			return false
	return true


func _current_action(unit: Unit2D) -> String:
	if unit.queue_actions.is_empty() or unit.queue_actions[0] == null:
		return "-"
	return BlockInventory.block_title(unit.queue_actions[0])


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
