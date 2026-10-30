## Separate script view placed in the GUI scene. Highlights the line being read.
extends Control
class_name ScriptDebugPanel


@onready var _label: RichTextLabel = get_node_or_null("Body") as RichTextLabel

## Tutorial steps hide the sections they are not talking about. All on by default.
var show_script_section := true
var show_stats_section := true
var show_queue_section := true
var show_ram_section := true
## stats, queue, ram, or script. Empty keeps every visible section at full strength.
var highlight_section := ""
var _sections: VBoxContainer
var _section_labels := {}
var _section_boxes := {}
var _highlight_style: StyleBoxFlat


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
	_ensure_sections()


func _process(_delta: float) -> void:
	if _label == null:
		return
	_ensure_sections()
	var unit := _inspected_unit()
	if unit == null:
		var idle := LocaleText.resolve("ui.spec.script", "Thinking")
		var idle_text := "%s\nNo unit focused" % _muted(idle)
		_label.text = idle_text
		_put_section("script", idle_text, true)
		_put_section("stats", "", false)
		_put_section("queue", "", false)
		_put_section("ram", "", false)
		_put_section("anim", "", false)
		return
	_label.text = _render(unit)
	_fill_sections(unit)
	_pulse_highlight()


## Screen rect of one visible section, so the tutorial can light that part only.
func section_screen_rect(section: String) -> Rect2:
	_ensure_sections()
	var box := _section_boxes.get(section) as Control
	if box == null or not box.visible or box.size.y < 4.0:
		return get_global_rect()
	var xform := box.get_global_transform_with_canvas()
	var top_left: Vector2 = xform * Vector2.ZERO
	var bottom_right: Vector2 = xform * box.size
	return Rect2(top_left, bottom_right - top_left).abs().grow(8.0)


func _ensure_sections() -> void:
	if _sections != null:
		return
	_sections = VBoxContainer.new()
	_sections.name = "Sections"
	_sections.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sections.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sections)
	for section in ["script", "stats", "queue", "ram", "anim"]:
		var box := PanelContainer.new()
		box.name = section
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(460, 0)
		box.add_child(label)
		_sections.add_child(box)
		_section_labels[section] = label
		_section_boxes[section] = box
	if _label:
		_label.visible = false


func _fill_sections(unit: Unit2D) -> void:
	_put_section("script", _script_block(unit), show_script_section)
	_put_section("stats", _stats_line(unit), show_stats_section)
	var queue := ""
	if show_queue_section:
		queue = "%s  %s\n%s  %s" % [
			_muted("Queue"), _escape(_queue_list(unit)), _muted("Doing"), _escape(_current_action(unit)),
		]
	_put_section("queue", queue, show_queue_section)
	var ram := ""
	if show_ram_section and unit.stats:
		var pattern := LocaleText.resolve("ui.code_editor.ram", "RAM: {used}/{max} MB", "en")
		var usage := pattern.format({"used": unit.get_ram_used(), "max": unit.stats.ram})
		ram = _muted(usage)
	_put_section("ram", ram, show_ram_section and unit.stats != null)
	var show_anim := show_queue_section and show_ram_section
	_put_section("anim", "%s  %s" % [_muted("Anim"), _escape(_playing_animation(unit))], show_anim)


func _put_section(section: String, body: String, shown: bool) -> void:
	var label := _section_labels.get(section) as RichTextLabel
	var box := _section_boxes.get(section) as PanelContainer
	if label == null or box == null:
		return
	var open := shown and not body.is_empty()
	box.visible = open
	if not open:
		label.text = ""
		return
	label.text = body
	var marked := not highlight_section.is_empty() and highlight_section == section
	if marked:
		box.add_theme_stylebox_override(&"panel", _section_highlight())
		label.modulate = Color.WHITE
	else:
		box.remove_theme_stylebox_override(&"panel")
		label.modulate = UiPalette.TEXT_MUTED if not highlight_section.is_empty() else Color.WHITE


func _section_highlight() -> StyleBoxFlat:
	if _highlight_style == null:
		_highlight_style = StyleBoxFlat.new()
		_highlight_style.set_corner_radius_all(0)
		_highlight_style.set_border_width_all(0)
		_highlight_style.shadow_size = 0
		_highlight_style.bg_color = UiPalette.tint(UiPalette.WARN, 0.22)
		_highlight_style.content_margin_left = UiPalette.S
		_highlight_style.content_margin_top = UiPalette.S
		_highlight_style.content_margin_right = UiPalette.S
		_highlight_style.content_margin_bottom = UiPalette.S
	return _highlight_style


func _pulse_highlight() -> void:
	if highlight_section.is_empty() or _highlight_style == null:
		return
	var wave := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	_highlight_style.bg_color.a = lerpf(0.12, 0.32, wave)


func _script_block(unit: Unit2D) -> String:
	var rows := PackedStringArray()
	var heading := LocaleText.resolve("ui.spec.script", "Thinking")
	rows.append(_muted("%s — %s" % [heading, _escape(_script_title(unit))]))
	var function := unit.runner.get_update_script() if unit.runner else null
	var current := unit.runner.read_index if unit.runner else -1
	if function == null or function.lines.is_empty():
		rows.append(_muted("(empty)"))
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
				rows.append("[color=%s][bgcolor=%s]%s[/bgcolor][/color]" % [
					UiPalette.hex(UiPalette.BG_DARK), UiPalette.hex(UiPalette.WARN), _escape(shown),
				])
			else:
				rows.append(_escape(shown))
	return "\n".join(rows)


func _stats_line(unit: Unit2D) -> String:
	return "%s  %d    %s  %d" % [_muted("CPU"), unit.get_cpu(), _muted("GPU"), unit.get_gpu()]


func _inspected_unit() -> Unit2D:
	var tree := get_tree()
	if tree == null:
		return null
	var director := tree.get_first_node_in_group(FocusDirector.GROUP) as FocusDirector
	if director == null or director.process_mode == Node.PROCESS_MODE_DISABLED:
		return null
	var unit := director.get_inspected_unit()
	if _shows_script(unit):
		return unit
	var pinned := director.get_selected_unit()
	if _shows_script(pinned):
		return pinned
	return null


func _shows_script(unit: Unit2D) -> bool:
	return unit != null and unit.team != Unit2D.Team.VILLAGER


func _render(unit: Unit2D) -> String:
	var rows := PackedStringArray()
	if show_script_section:
		rows.append(_script_block(unit))
		rows.append("")
	if show_stats_section:
		rows.append(_stats_line(unit))
	if show_queue_section:
		rows.append("%s  %s" % [_muted("Queue"), _escape(_queue_list(unit))])
		rows.append("%s  %s" % [_muted("Doing"), _escape(_current_action(unit))])
	if show_ram_section and unit.stats:
		var pattern := LocaleText.resolve("ui.code_editor.ram", "RAM: {used}/{max} MB", "en")
		var usage := pattern.format({"used": unit.get_ram_used(), "max": unit.stats.ram})
		rows.append(_muted(usage))
	if show_queue_section and show_ram_section:
		rows.append("%s  %s" % [_muted("Anim"), _escape(_playing_animation(unit))])
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


func _playing_animation(unit: Unit2D) -> String:
	var clip := unit.get_playing_animation()
	if clip.is_empty():
		return "-"
	return clip


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


func _muted(text: String) -> String:
	return "[color=%s]%s[/color]" % [UiPalette.hex(UiPalette.TEXT_MUTED), text]


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
