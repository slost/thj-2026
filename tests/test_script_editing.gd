extends SceneTree

var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_blank_programs_are_separate()
	_test_slot_clone_keeps_shared_blocks()
	_test_indent_and_structure()
	_test_inventory()
	_test_translations()
	await _test_editor_screen()
	var game := root.get_node_or_null(^"Game")
	if game == null:
		_fail("Game autoload is missing")
	else:
		var roster: Array = game.get("roster")
		if roster.size() != 4:
			_fail("roster was not seeded with 4 slots, got %d" % roster.size())
		var inventory = game.get("block_inventory")
		if inventory == null or inventory.get_all().is_empty():
			_fail("block inventory was not seeded")
	if _failed == 0:
		print("script editing checks passed")
	else:
		print("%d script editing checks failed" % _failed)
	quit(1 if _failed else 0)


func _test_blank_programs_are_separate() -> void:
	var first := MinionSlot.blank_program()
	var second := MinionSlot.blank_program()
	first.functions[0].lines.append(ScriptLine.new())
	if not second.functions[0].lines.is_empty():
		_fail("blank programs share their line array")
	if first.event_graph == second.event_graph:
		_fail("blank programs share an event graph")


func _test_slot_clone_keeps_shared_blocks() -> void:
	var block := _attack()
	var source := MinionSlot.blank_program()
	ScriptEditing.insert_line(source.functions[0].lines, 0, 0, block)
	var def := UnitDef.new()
	def.name = "Clone"
	def.ram = 8
	def.starting_program = source
	var slot_a := MinionSlot.new()
	var slot_b := MinionSlot.new()
	slot_a.def = def
	slot_b.def = def
	var function_a := slot_a.get_update_function()
	var function_b := slot_b.get_update_function()
	if function_a == function_b or function_a == source.functions[0]:
		_fail("slots reused a function instead of cloning")
	if function_a.lines.size() != 1 or function_a.lines[0].block != block:
		_fail("clone did not keep the shared block")
	if source.functions[0].lines[0].block != block:
		_fail("clone rewrote the starting program block")
	var linked: Array = slot_a.get_program().event_graph.get_functions(EventGraph.Event.ON_UPDATE)
	if linked.is_empty() or linked[0] != function_a:
		_fail("ON_UPDATE is not linked to the slot's own function")
	ScriptEditing.insert_line(function_a.lines, 1, 0, block)
	if function_b.lines.size() != 1 or source.functions[0].lines.size() != 1:
		_fail("an edit leaked into another program")
	var cost := block.ram_cost
	function_a.lines[0].indent = 4
	if block.ram_cost != cost or source.functions[0].lines[0].indent != 0:
		_fail("editing a line changed the shared block or the source line")


func _test_indent_and_structure() -> void:
	var condition := _detect()
	var attack := _attack()
	var move := _move()
	var lines: Array[ScriptLine] = []
	ScriptEditing.insert_line(lines, 0, 5, condition)
	if lines[0].indent != 0:
		_fail("the first line accepted an indent")
	ScriptEditing.insert_line(lines, 1, 5, attack)
	if lines[1].indent != 1:
		_fail("a line under a condition was not clamped to +1, got %d" % lines[1].indent)
	ScriptEditing.insert_line(lines, 2, 9, move)
	if lines[2].indent != 1:
		_fail("a line under an action went deeper than the action, got %d" % lines[2].indent)
	ScriptEditing.nudge_indent(lines, 0, 1)
	if lines[0].indent != 0:
		_fail("Tab indented the first line")
	ScriptEditing.nudge_indent(lines, 1, 1)
	if lines[1].indent != 1:
		_fail("Tab indented past the condition")
	ScriptEditing.insert_line(lines, 2, 1, condition)
	# [condition] 0, <attack> 1, [condition] 1, <move> 1
	ScriptEditing.nudge_indent(lines, 3, 1)
	if not _indents(lines, [0, 1, 1, 2]):
		_fail("Tab did not indent under the new condition: %s" % _text(lines))
	ScriptEditing.nudge_indent(lines, 2, -1)
	if not _indents(lines, [0, 1, 0, 1]):
		_fail("Shift+Tab did not outdent the condition and its child: %s" % _text(lines))
	# Rebuild a nested tree and move it.
	lines.clear()
	ScriptEditing.insert_line(lines, 0, 0, condition)
	ScriptEditing.insert_line(lines, 1, 1, attack)
	ScriptEditing.insert_line(lines, 2, 2, move)
	# Force the nested shape the runner uses. insert under the action clamps to 1,
	# so set the grandchild indent directly for the move/remove cases.
	lines[2].indent = 2
	if ScriptEditing.move_lines(lines, 0, 1, 0):
		_fail("dropping inside the moved subtree was allowed")
	if lines[0].block != condition or lines[1].block != attack or lines[2].block != move:
		_fail("a rejected move changed the list")
	if not ScriptEditing.move_lines(lines, 0, lines.size(), 4):
		_fail("moving a subtree to the end failed")
	if lines[0].block != condition or lines[0].indent != 0:
		_fail("moving the whole script changed its root")
	if lines[1].indent != 1 or lines[2].indent != 2:
		_fail("moving a subtree did not keep relative indents: %s" % _text(lines))
	# Move the inner action (and its deeper child) above the root.
	if not ScriptEditing.move_lines(lines, 1, 0, 5):
		_fail("moving a nested subtree to the top failed")
	if lines[0].block != attack or lines[0].indent != 0:
		_fail("a block moved to the top kept a deep indent: %s" % _text(lines))
	if lines[1].block != move or lines[1].indent != 1:
		_fail("the moved child did not follow: %s" % _text(lines))
	if lines[2].block != condition:
		_fail("the condition did not stay behind the moved subtree")
	var removed := ScriptEditing.remove_line(lines, 2)
	if removed != condition:
		_fail("remove did not return the condition")
	if not _indents(lines, [0, 1]):
		_fail("removing a trailing condition changed the lines above it: %s" % _text(lines))
	lines.append(_line(condition, 0))
	lines.append(_line(attack, 1))
	lines.append(_line(move, 2))
	# [attack 0] [move 1] [condition 0] [attack 1] [move 2]
	# The list is currently attack, move. Append makes:
	# attack 0, move 1, condition 0, attack 1, move 2
	ScriptEditing.remove_line(lines, 2)
	if not _indents(lines, [0, 1, 0, 1]):
		_fail("removing a condition did not outdent its body: %s" % _text(lines))
	if lines[2].block != attack or lines[3].block != move:
		_fail("removing a condition dropped its body")
	var action := ScriptEditing.remove_line(lines, 0)
	if action != attack:
		_fail("remove did not return the action")
	if lines[0].indent != 1:
		_fail("removing an action outdented the following line")
	if ScriptEditing.fits_ram(8, attack, 8):
		_fail("a full RAM bar accepted another block")
	if ScriptEditing.fits_ram(7, attack, 8) != true:
		_fail("a block that fits was refused")


func _test_inventory() -> void:
	var inventory := BlockInventory.new()
	inventory.seed_if_empty()
	var expected := 0
	var dir := DirAccess.open("res://data/blocks")
	for file_name in dir.get_files():
		if str(file_name).ends_with(".tres"):
			expected += 1
	if inventory.get_all().size() != expected:
		_fail("seeded %d blocks, directory has %d" % [inventory.get_all().size(), expected])
	var attack := _attack()
	if inventory.get_count(attack) != BlockInventory.SEED_COUNT:
		_fail("attack was not seeded x%d" % BlockInventory.SEED_COUNT)
	inventory.seed_if_empty()
	if inventory.get_count(attack) != BlockInventory.SEED_COUNT:
		_fail("seeding twice increased the count")
	if not inventory.remove(attack, 1):
		_fail("remove refused a block that was in stock")
	if inventory.get_count(attack) != BlockInventory.SEED_COUNT - 1:
		_fail("remove did not lower the count")
	if inventory.remove(attack, 100):
		_fail("remove took more copies than were owned")
	inventory.add(attack, 1)
	if inventory.get_count(attack) != BlockInventory.SEED_COUNT:
		_fail("add did not stack on the shared block")
	var title := BlockInventory.block_title(attack)
	if title.is_empty():
		_fail("block title was empty")


func _line(block: CodeBlock, indent: int) -> ScriptLine:
	var line := ScriptLine.new()
	line.block = block
	line.indent = indent
	return line


func _indents(lines: Array[ScriptLine], expected: Array) -> bool:
	if lines.size() != expected.size():
		return false
	for index in lines.size():
		if lines[index] == null or lines[index].indent != int(expected[index]):
			return false
	return true


func _text(lines: Array[ScriptLine]) -> String:
	var parts: PackedStringArray = []
	for line in lines:
		var label := "..."
		if line and line.block:
			label = line.block.get_block_label()
		parts.append("%d %s" % [line.indent if line else -1, label])
	return ", ".join(parts)


func _test_editor_screen() -> void:
	TranslationServer.set_locale("th")
	var game := root.get_node(^"Game")
	var inventory = game.get("block_inventory")
	var attack := load("res://data/blocks/attack_target.tres") as CodeBlock
	var detect := load("res://data/blocks/enemy_in_detect_range.tres") as ConditionBlock
	inventory.add(attack, 20)
	var editor := (load("res://systems/code_editor/editor.tscn") as PackedScene).instantiate()
	root.add_child(editor)
	for _frame in 10:
		await process_frame
	var palette := editor.get_node(^"%BlockPalette") as Control
	var script := editor.get_node(^"%ScriptView") as ScriptView
	var slots := editor.get_node(^"%UnitsContainer") as Control
	var palette_rect := palette.get_global_rect()
	var script_rect := script.get_global_rect()
	if palette_rect.size.x < 200.0 or palette_rect.size.y < 200.0:
		_fail("palette was not fitted to the page: %s" % palette_rect)
	if script_rect.size.x < 200.0 or script_rect.size.y < 200.0:
		_fail("script page was not fitted: %s" % script_rect)
	if palette_rect.end.x > script_rect.position.x + 8.0:
		_fail("palette overlaps the script page")
	if slots.get_global_rect().position.y > script_rect.position.y:
		_fail("unit buttons are not above the script")
	var book := editor.get_node(^"BookScreen") as Sprite2D
	var book_rect := _sprite_world_rect(book)
	if not book_rect.has_point(palette_rect.get_center()):
		_fail("palette is not on the book: %s book %s" % [palette_rect, book_rect])
	if not book_rect.has_point(script_rect.get_center()):
		_fail("script is not on the book: %s book %s" % [script_rect, book_rect])
	var palette_list := editor.get_node(^"%PaletteList") as Control
	if palette_list.get_child_count() < 2:
		_fail("palette did not build cards")
	else:
		var first_palette := palette_list.get_child(0) as BlockCard
		var second_palette := palette_list.get_child(1) as BlockCard
		if first_palette == null or second_palette == null:
			_fail("palette rows are not cards")
		elif first_palette.size.x > palette.size.x * 0.85:
			_fail("palette card is still page-wide: %s" % first_palette.size)
		elif first_palette.position.distance_to(second_palette.position) < 8.0:
			_fail("palette cards are stacked as a list: %s %s" % [first_palette.position, second_palette.position])
		elif not _spread_across(palette_list):
			_fail("palette cards stayed in one column")
		elif is_equal_approx(first_palette.motion_phase(), second_palette.motion_phase()):
			_fail("palette cards share a float phase")
		elif not first_palette.get_node(^"Visual/Row/CountBadge").visible:
			_fail("palette card hid the count badge")
		elif _has_thai(first_palette.displayed_title()) or _has_thai(first_palette.tooltip_text):
			_fail("palette card was still Thai: '%s'" % first_palette.displayed_title())
		elif _has_thai(str(first_palette.get_node(^"Visual/Row/RamBadge/Ram").text)):
			_fail("palette RAM badge was still Thai")
		elif first_palette.tooltip_text.is_empty():
			_fail("palette card tooltip was empty")
		else:
			var slot_before := first_palette.position
			var visual_before := first_palette.visual_position()
			first_palette._process(1.0)
			if not first_palette.position.is_equal_approx(slot_before):
				_fail("floating moved the palette card slot")
			if is_equal_approx(first_palette.visual_position().y, visual_before.y):
				_fail("palette card visual did not float")
	var owned: int = inventory.get_count(detect)
	editor.call("_on_place", detect, 0, 0)
	editor.call("_on_place", attack, 1, 5)
	for _frame in 3:
		await process_frame
	var roster: Array = game.get("roster")
	var slot = roster[0]
	var lines: Array = slot.get_update_function().lines
	if lines.size() != 2:
		_fail("place did not write two lines, got %d" % lines.size())
	elif lines[1].indent != 1:
		_fail("placed action indent was %d" % lines[1].indent)
	if inventory.get_count(detect) != owned - 1:
		_fail("placing did not consume a condition")
	var ram_label := editor.get_node(^"%RamLabel") as Label
	if not str(ram_label.text).contains("2 / 8"):
		_fail("RAM meter was '%s'" % ram_label.text)
	var row_box := editor.get_node(^"%ScriptRows") as Node
	if row_box.get_child_count() < 2:
		_fail("script view did not build rows")
	else:
		var first_card := row_box.get_child(0) as BlockCard
		var second_card := row_box.get_child(1) as BlockCard
		if first_card == null or first_card.displayed_title() != "Enemy in sight":
			_fail("condition card title was '%s'" % (first_card.displayed_title() if first_card else ""))
		elif first_card.get_node(^"Visual").size.x > script.size.x * 0.85:
			_fail("script block is still too long: %s" % first_card.get_node(^"Visual").size)
		elif first_card.tooltip_text != "You can see an enemy.":
			_fail("condition tooltip was '%s'" % first_card.tooltip_text)
		elif first_card.get_node(^"Visual").theme_type_variation != &"ConditionCard":
			_fail("condition card was not the condition shape")
		if second_card == null or second_card.displayed_title() != "Attack the target":
			_fail("action card title was '%s'" % (second_card.displayed_title() if second_card else ""))
		elif second_card.get_node(^"Visual").theme_type_variation != &"ActionCard":
			_fail("action card was not the action shape")
		elif second_card.visual_position().x <= first_card.visual_position().x:
			_fail("action card was not indented on the page")
		elif first_card.get_node(^"Visual/Row/CountBadge").visible:
			_fail("script card showed a count badge")
		elif is_equal_approx(first_card.motion_phase(), second_card.motion_phase()):
			_fail("script cards share a float phase")
		var palette_card := palette_list.get_child(0) as BlockCard
		if palette_card == null or not palette_card._can_drop_data(Vector2.ZERO, {"source": "script", "index": 1}):
			_fail("palette card did not accept a script block")
		palette_card._drop_data(Vector2.ZERO, {"source": "script", "index": 1})
		for _frame in 2:
			await process_frame
		if slot.get_update_function().lines.size() != 1:
			_fail("dropping a script block on the palette did not return it")
		var last_card := row_box.get_child(0) as BlockCard
		if last_card:
			last_card.line_remove_requested.emit(0)
		for _frame in 2:
			await process_frame
		if slot.get_update_function().lines.size() != 0:
			_fail("the last block could not be removed")
		elif row_box.get_child_count() != 0:
			_fail("an empty script still showed a block")
		elif not editor.get_node(^"%EmptyLabel").visible:
			_fail("an empty script hid the empty label")
		elif _has_thai(str(editor.get_node(^"%EmptyLabel").text)):
			_fail("empty script label was Thai")
		if inventory.get_count(detect) != owned:
			_fail("clearing the script did not return the condition")
		editor.call("_on_place", detect, 0, 0)
		editor.call("_on_place", attack, 1, 1)
		for _frame in 2:
			await process_frame
		var top := script._plan(Vector2(script.indent_pad + 4.0, 2.0), {"source": "palette", "block": attack})
		if int(top.x) != 0:
			_fail("drop at the top row was gap %s" % top)
		var between_y := script.row_height * 1.2
		var between_x := script.indent_pad + script.indent_step * 1.2
		var between := script._plan(Vector2(between_x, between_y), {"source": "palette", "block": attack})
		if int(between.x) != 1 or int(between.y) != 1:
			_fail("drop under the condition was %s" % between)
	editor.call("_on_slot_button", 3)
	for _frame in 2:
		await process_frame
	if roster[3].get_update_function().lines.size() != 0:
		_fail("slot 4 was not empty")
	var name_label := editor.get_node(^"%NameLabel") as Label
	if name_label.text != "Minion 4":
		_fail("header did not switch slot, got '%s'" % name_label.text)
	editor.call("_on_slot_button", 0)
	for _frame in 2:
		await process_frame
	if slot.get_update_function().lines.size() != 2:
		_fail("slot 1 lost its script after switching away")
	var guard := 0
	while slot.get_update_function().lines.size() < 8 and guard < 12:
		var index: int = slot.get_update_function().lines.size()
		editor.call("_on_place", attack, index, 0)
		guard += 1
	if slot.get_update_function().lines.size() != 8:
		_fail("RAM cap did not stop at 8 lines, got %d" % slot.get_update_function().lines.size())
	var at_cap: int = slot.get_update_function().lines.size()
	editor.call("_on_place", attack, at_cap, 0)
	if slot.get_update_function().lines.size() != at_cap:
		_fail("a block was placed past the RAM cap")
	var alert := ram_label.get_theme_color(&"font_color")
	if alert.r < 0.6 or alert.g > 0.3:
		_fail("RAM meter did not flash red, got %s" % alert)
	await _test_pages_follow_pan(editor, palette, script)
	editor.queue_free()


func _test_translations() -> void:
	var names := {
		"enemy_in_attack_range": ["Enemy within reach", "ศัตรูอยู่ในระยะโจมตี"],
		"enemy_in_detect_range": ["Enemy in sight", "เห็นศัตรู"],
		"has_remembered_target": ["Remembers someone", "จำใครไว้อยู่"],
		"no_remembered_target": ["Remembers no one", "ไม่ได้จำใครไว้"],
		"remembered_target_dead": ["Target is dead", "เป้าหมายตายแล้ว"],
		"remembered_target_in_attack_range": ["Target within reach", "เป้าหมายอยู่ในระยะโจมตี"],
		"low_hp": ["Feeling weak", "เลือดเหลือน้อย"],
		"random_chance": ["Feeling lucky", "ดวงดี"],
		"attack_target": ["Attack the target", "โจมตีเป้าหมาย"],
		"move_to_target": ["Walk to the target", "เดินไปหาเป้าหมาย"],
		"move_away_from_target": ["Run from the target", "หนีจากเป้าหมาย"],
		"wander": ["Wander around", "เดินเตร็ดเตร่"],
		"stand_still": ["Stand still", "ยืนนิ่ง ๆ"],
		"remember_hostile": ["Remember an enemy", "จำศัตรูไว้"],
		"remember_ally": ["Remember a friend", "จำพวกเดียวกันไว้"],
		"remember_any": ["Remember anyone", "จำใครก็ได้ไว้"],
		"forget_first_target": ["Forget the first target", "ลืมเป้าหมายแรก"],
		"forget_last_target": ["Forget the latest target", "ลืมเป้าหมายล่าสุด"],
		"forget_all_targets": ["Forget all targets", "ลืมเป้าหมายทั้งหมด"],
		"forget_first_action": ["Forget the first plan", "ลืมแผนแรก"],
		"forget_last_action": ["Forget the latest plan", "ลืมแผนล่าสุด"],
		"forget_all_actions": ["Forget all plans", "ลืมแผนทั้งหมด"],
		"forget_everything": ["Forget everything", "ลืมทุกอย่าง"],
	}
	for id in names.keys():
		var pair: Array = names[id]
		var block := load("res://data/blocks/%s.tres" % str(id)) as CodeBlock
		if block == null:
			_fail("missing block %s" % str(id))
			continue
		if block.name != str(pair[0]):
			_fail("tres name for %s was '%s'" % [str(id), block.name])
		TranslationServer.set_locale("en")
		if block.get_display_name() != str(pair[0]):
			_fail("en name for %s was '%s'" % [str(id), block.get_display_name()])
		TranslationServer.set_locale("th")
		if block.get_display_name() != str(pair[1]):
			_fail("th name for %s was '%s'" % [str(id), block.get_display_name()])
		if LocaleText.translate("code.%s.desc" % str(id), "en").is_empty():
			_fail("missing english desc for %s" % str(id))
		if LocaleText.translate("code.%s.desc" % str(id), "th").is_empty():
			_fail("missing thai desc for %s" % str(id))
	for key in ["ui.code_editor.tab_conditions", "ui.code_editor.tab_actions", "ui.code_editor.ram_hint", "ui.code_editor.ram", "ui.code_editor.empty"]:
		if LocaleText.translate(key, "en").is_empty() or LocaleText.translate(key, "th").is_empty():
			_fail("missing translation %s" % key)
	TranslationServer.set_locale("en")
	var chance := load("res://data/blocks/random_chance.tres") as CodeBlock
	if not chance.get_display_description().contains("0.5"):
		_fail("chance placeholder was not filled: '%s'" % chance.get_display_description())
	var weak := load("res://data/blocks/low_hp.tres") as CodeBlock
	if not weak.get_display_description().contains("0.35"):
		_fail("threshold placeholder was not filled: '%s'" % weak.get_display_description())
	TranslationServer.set_locale("en")


func _has_thai(text: String) -> bool:
	for index in text.length():
		var code := text.unicode_at(index)
		if code >= 0x0E00 and code <= 0x0E7F:
			return true
	return false


func _spread_across(board: Control) -> bool:
	var origin := 0.0
	var saw := false
	for child in board.get_children():
		var card := child as Control
		if card == null:
			continue
		if not saw:
			origin = card.position.x
			saw = true
			continue
		if absf(card.position.x - origin) > 24.0:
			return true
	return false


func _sprite_world_rect(sprite: Sprite2D) -> Rect2:
	var tex_size := Vector2(1920, 1080)
	if sprite.texture:
		tex_size = sprite.texture.get_size()
	var xform := sprite.get_global_transform()
	var shown := tex_size * xform.get_scale()
	return Rect2(xform.origin - shown * 0.5, shown)


func _canvas_origin(item: CanvasItem) -> Vector2:
	return item.get_global_transform_with_canvas().origin


func _test_pages_follow_pan(editor: Node, palette: Control, script: Control) -> void:
	var pan := editor.get_node(^"Camera2D/MousePan") as Node
	pan.set_process(false)
	var camera := editor.get_node(^"Camera2D") as Camera2D
	var book := editor.get_node(^"BookScreen") as CanvasItem
	await process_frame
	var book_before := _canvas_origin(book)
	var palette_before := _canvas_origin(palette)
	var script_before := _canvas_origin(script)
	camera.offset = Vector2(48, 24)
	await process_frame
	await process_frame
	var book_delta := _canvas_origin(book) - book_before
	var palette_delta := _canvas_origin(palette) - palette_before
	var script_delta := _canvas_origin(script) - script_before
	if book_delta.length() < 5.0:
		_fail("pan did not move the book, delta %s" % book_delta)
	if palette_delta.distance_to(book_delta) > 1.5:
		_fail("palette did not follow the book, book %s palette %s" % [book_delta, palette_delta])
	if script_delta.distance_to(book_delta) > 1.5:
		_fail("script did not follow the book, book %s script %s" % [book_delta, script_delta])
	var view := script as ScriptView
	var plan := view._plan(Vector2(view.indent_pad + 4.0, 2.0), {"source": "palette", "block": _attack()})
	if int(plan.x) != 0:
		_fail("drop target changed after pan: %s" % plan)
	camera.offset = Vector2.ZERO


func _attack() -> ActionBlock:
	return load("res://data/blocks/attack_target.tres") as ActionBlock


func _move() -> ActionBlock:
	return load("res://data/blocks/move_to_target.tres") as ActionBlock


func _detect() -> ConditionBlock:
	return load("res://data/blocks/enemy_in_detect_range.tres") as ConditionBlock


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
