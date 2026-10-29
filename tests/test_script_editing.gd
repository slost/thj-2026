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
	await _test_world_map_book()
	await _test_raid_spawns_roster()
	await _test_stop_thinking()
	await _test_army_carry()
	var game := root.get_node_or_null(^"Game")
	if game == null:
		_fail("Game autoload is missing")
	else:
		var roster: Array = game.get("spells")
		if roster.size() != 8:
			_fail("spells were not seeded with 8 slots, got %d" % roster.size())
		var inventory = game.get("block_inventory")
		if inventory == null or inventory.get_all().is_empty():
			_fail("block inventory was not seeded")
	if _failed == 0:
		print("script editing checks passed")
	else:
		print("%d script editing checks failed" % _failed)
	quit(1 if _failed else 0)


func _test_blank_programs_are_separate() -> void:
	var first := SummonSpell.blank_program()
	var second := SummonSpell.blank_program()
	first.functions[0].lines.append(ScriptLine.new())
	if not second.functions[0].lines.is_empty():
		_fail("blank programs share their line array")
	if first.event_graph == second.event_graph:
		_fail("blank programs share an event graph")


func _test_slot_clone_keeps_shared_blocks() -> void:
	var block := _attack()
	var source := SummonSpell.blank_program()
	ScriptEditing.insert_line(source.functions[0].lines, 0, 0, block)
	var def := UnitDef.new()
	def.name = "Clone"
	def.ram = 8
	def.starting_program = source
	var slot_a := SummonSpell.new()
	var slot_b := SummonSpell.new()
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
	var cost := block.mb_cost
	function_a.lines[0].indent = 4
	if block.mb_cost != cost or source.functions[0].lines[0].indent != 0:
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
	var host := (load("res://systems/code_editor/editor_standalone.tscn") as PackedScene).instantiate()
	root.add_child(host)
	var editor := host.get_node(^"Editor")
	for _frame in 10:
		await process_frame
	var palette := editor.get_node(^"%BlockPalette") as Control
	var script := editor.get_node(^"%ScriptView") as ScriptView
	var slots := editor.get_node(^"%SpellsContainer") as Control
	var eighth := editor.get_node_or_null(^"%SpellButton8") as Button
	if eighth == null or eighth.text.is_empty():
		_fail("the book does not show eight named spells")
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
	if palette_rect.size.y < script_rect.size.y + 36.0:
		_fail("block page is not longer than the script: palette %s script %s" % [palette_rect.size.y, script_rect.size.y])
	var book := editor.get_node(^"BookScreen") as Sprite2D
	var book_rect := _sprite_world_rect(book)
	if not book_rect.has_point(palette_rect.get_center()):
		_fail("palette is not on the book: %s book %s" % [palette_rect, book_rect])
	if not book_rect.has_point(script_rect.get_center()):
		_fail("script is not on the book: %s book %s" % [script_rect, book_rect])
	var palette_list := editor.get_node(^"%PaletteList") as Control
	if not _palette_has_both(palette_list):
		_fail("palette did not show conditions and actions together")
	if not _kind_order(palette_list, true):
		_fail("conditions were not listed first")
	var actions_tab := editor.get_node(^"%SortActionsFirst") as Button
	actions_tab.pressed.emit()
	for _frame in 2:
		await process_frame
	if not _kind_order(palette_list, false):
		_fail("actions were not listed first")
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
		elif not first_palette.get_node(^"CountBadge").visible:
			_fail("palette card hid the count badge")
		elif first_palette.get_node(^"CountBadge").position.x < first_palette.get_node(^"Visual").position.x + first_palette.get_node(^"Visual").size.x - 2.0:
			_fail("the count is still inside the block")
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
			first_palette.mouse_entered.emit()
			first_palette._process(0.6)
			first_palette._process(0.6)
			var settled := first_palette.visual_position()
			first_palette._process(0.6)
			if first_palette.visual_position().distance_to(settled) > 1.5:
				_fail("hover did not slow the card to a rest")
	var owned: int = inventory.get_count(detect)
	editor.call("_on_place", detect, 0, 0)
	editor.call("_on_place", attack, 1, 5)
	for _frame in 3:
		await process_frame
	var roster: Array = game.get("spells")
	var slot = roster[0]
	var lines: Array = slot.get_update_function().lines
	if lines.size() != 2:
		_fail("place did not write two lines, got %d" % lines.size())
	elif lines[1].indent != 1:
		_fail("placed action indent was %d" % lines[1].indent)
	if inventory.get_count(detect) != owned - 1:
		_fail("placing did not consume a condition")
	var ram_label := editor.get_node(^"%RamLabel") as Label
	if not str(ram_label.text).contains("2/8") or not str(ram_label.text).contains("MB"):
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
		elif absf(first_card.get_node(^"Visual").size.x - first_card._text_width()) > 8.0:
			_fail("script block does not fit its text: %s words %s" % [first_card.get_node(^"Visual").size, first_card._text_width()])
		elif second_card.position.y - first_card.position.y > 76.0:
			_fail("script rows are still far apart: %s" % (second_card.position.y - first_card.position.y))
		elif second_card.position.y - first_card.position.y < 52.0:
			_fail("script rows overlap: %s" % (second_card.position.y - first_card.position.y))
		elif first_card.get_node(^"Visual").size.y > first_card.size.y - 8.0:
			_fail("script chip still fills its row")
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
		elif first_card.get_node(^"CountBadge").visible:
			_fail("script card showed a count badge")
		elif is_equal_approx(first_card.motion_phase(), second_card.motion_phase()):
			_fail("script cards share a float phase")
		var links := editor.get_node(^"%ScriptLinks") as ScriptLinks
		if links == null or links.segment_count() < 2:
			_fail("nested blocks drew no elbow, segments %s" % (links.segment_count() if links else -1))
		elif not links.has_block_branch():
			_fail("the nested line still shares the main rail")
		elif not links.root_row_has_elbow():
			_fail("the first row has no elbow off the main rail")
		else:
			await _test_drop_preview(script, attack)
		script.select_line(0)
		first_card.mouse_exited.emit()
		if str(first_card.get_node(^"Visual").theme_type_variation) == "ConditionCardSelected":
			_fail("the script line stayed focused after the pointer left")
		var kept: int = slot.get_update_function().lines.size()
		first_card.notification(Node.NOTIFICATION_DRAG_END)
		if slot.get_update_function().lines.size() != kept:
			_fail("letting go of a block cleared the script")
		second_card._drop_data(Vector2(12.0, 8.0), {"source": "palette", "block": attack})
		for _frame in 2:
			await process_frame
		if slot.get_update_function().lines.size() != kept + 1:
			_fail("dropping onto a block removed lines, got %d" % slot.get_update_function().lines.size())
		elif slot.get_update_function().lines[0].block != detect:
			_fail("dropping onto a block replaced the one underneath")
		editor.call("_on_remove", slot.get_update_function().lines.size() - 1)
		for _frame in 2:
			await process_frame
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
		var stocked: BlockCard = null
		for child in palette_list.get_children():
			var palette_block := child as BlockCard
			if palette_block and palette_block.block_id() == str(attack.id):
				stocked = palette_block
				break
		if stocked == null:
			_fail("quick add could not find the attack card")
		else:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.double_click = true
			stocked._gui_input(click)
			for _frame in 2:
				await process_frame
			if slot.get_update_function().lines.size() != 1:
				_fail("double click did not add a block")
			elif slot.get_update_function().lines[0].indent != 0:
				_fail("quick add did not append at the root")
			editor.call("_on_remove", 0)
			for _frame in 2:
				await process_frame
		editor.call("_on_place", attack, 0, 0)
		for _frame in 2:
			await process_frame
		var held := row_box.get_child(0) as BlockCard
		if held:
			var right := InputEventMouseButton.new()
			right.button_index = MOUSE_BUTTON_RIGHT
			right.pressed = true
			held._gui_input(right)
			if slot.get_update_function().lines.size() != 1:
				_fail("pressing right click removed a block before release")
			right.pressed = false
			held._gui_input(right)
			for _frame in 2:
				await process_frame
			if slot.get_update_function().lines.size() != 0:
				_fail("a short right click did not remove the block")
		editor.call("_on_place", detect, 0, 0)
		editor.call("_on_place", attack, 1, 1)
		editor.call("_on_place", attack, 2, 1)
		for _frame in 2:
			await process_frame
		var group_card := row_box.get_child(0) as BlockCard
		if group_card:
			var hold := InputEventMouseButton.new()
			hold.button_index = MOUSE_BUTTON_RIGHT
			hold.pressed = true
			group_card._gui_input(hold)
			group_card._right_pressed_at = Time.get_ticks_msec() - 800
			hold.pressed = false
			group_card._gui_input(hold)
			for _frame in 2:
				await process_frame
			if slot.get_update_function().lines.size() != 0:
				_fail("holding right click kept nested blocks, got %d" % slot.get_update_function().lines.size())
		editor.call("_on_place", attack, 0, 0)
		editor.call("_on_place", attack, 1, 0)
		editor.call("_on_place", attack, 2, 0)
		for _frame in 2:
			await process_frame
		script._on_right_started(0)
		script._note_row(1)
		script._note_row(2)
		script._finish_stroke(0)
		for _frame in 2:
			await process_frame
		if slot.get_update_function().lines.size() != 0:
			_fail("a right-button stroke did not remove every touched block, got %d" % slot.get_update_function().lines.size())
		editor.call("_on_place", detect, 0, 0)
		editor.call("_on_place", attack, 1, 1)
		for _frame in 2:
			await process_frame
		var on_condition := script._plan(Vector2(script.indent_pad + 4.0, script.row_height * 0.5), {"source": "palette", "block": attack})
		if int(on_condition.x) != 1 or int(on_condition.y) != 0:
			_fail("drop on a block replaced it: %s" % on_condition)
		var into := script._plan(Vector2(script.indent_pad + script.indent_step * 1.2, script.row_height * 0.5), {"source": "palette", "block": attack})
		if int(into.x) != 1 or int(into.y) != 1:
			_fail("drop inside a condition was %s" % into)
		var below_action := script._plan(Vector2(script.indent_pad + script.indent_step * 1.2, script.row_height * 1.5), {"source": "palette", "block": attack})
		if int(below_action.x) != 2 or int(below_action.y) != 1:
			_fail("drop on the nested block was %s" % below_action)
	editor.call("_on_slot_button", 3)
	for _frame in 2:
		await process_frame
	if roster[3].get_update_function().lines.size() != 0:
		_fail("slot 4 was not empty")
	var name_label := editor.get_node(^"%NameLabel") as Label
	if name_label.text != roster[3].display_name():
		_fail("header did not switch spell, got '%s'" % name_label.text)
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
	var script_scroll := editor.get_node(^"%ScriptScroll") as ScrollContainer
	script_scroll.scroll_vertical = 100000
	for _frame in 2:
		await process_frame
	var filled: int = slot.get_update_function().lines.size()
	var tail_y := float(filled) * script.row_height + 6.0 - float(script_scroll.scroll_vertical)
	var tail := script._plan(Vector2(script.indent_pad + 4.0, tail_y), {"source": "palette", "block": attack})
	if int(tail.x) != filled:
		_fail("a long script could not take a block at the end, plan %s scroll %s" % [tail, script_scroll.scroll_vertical])
	var at_cap: int = slot.get_update_function().lines.size()
	editor.call("_on_place", attack, at_cap, 0)
	if slot.get_update_function().lines.size() != at_cap:
		_fail("a block was placed past the RAM cap")
	var alert := ram_label.get_theme_color(&"font_color")
	if alert.r < 0.6 or alert.g > 0.3:
		_fail("RAM meter did not flash red, got %s" % alert)
	await _test_pages_follow_pan(editor, palette, script)
	host.queue_free()


func _test_drop_preview(script: ScriptView, attack: CodeBlock) -> void:
	script.set_process(false)
	var into := Vector2(script.indent_pad + script.indent_step * 1.2, script.row_height * 0.5)
	var beside := Vector2(script.indent_pad + 4.0, script.row_height * 0.5)
	var payload := {"source": "palette", "block": attack}
	var plan := script._plan(into, payload)
	script.set_mb_budget(1, 8)
	script.preview_drop(into, payload)
	for _frame in 10:
		await process_frame
	script._follow_drop_ghost()
	var ghost := script.get_node_or_null(^"ScriptScroll/ScriptBody/DropGhost") as BlockCard
	var gap := script.get_node_or_null(^"ScriptScroll/ScriptBody/ScriptRows/DropGap") as Control
	var rows := script.get_node(^"ScriptScroll/ScriptBody/ScriptRows") as Control
	if ghost == null or gap == null:
		_fail("drop preview did not open a ghost row")
	elif gap.get_index() != int(plan.x):
		_fail("preview gap %d disagreed with the drop %s" % [gap.get_index(), plan])
	elif ghost.position.distance_to(rows.position + gap.position) > 2.0:
		_fail("ghost landed at %s, gap at %s" % [ghost.position, rows.position + gap.position])
	else:
		var visual := ghost.get_node(^"Visual") as Control
		var expected_x := script.indent_pad + plan.y * script.indent_step
		if absf(visual.position.x - expected_x) > 10.0:
			_fail("ghost indent was %s, drop indent %s" % [visual.position.x, expected_x])
		elif ghost.modulate.g < 0.9:
			_fail("a legal drop ghost was tinted red")
	script.preview_drop(beside, payload)
	await process_frame
	script._follow_drop_ghost()
	var beside_plan := script._plan(beside, payload)
	if ghost:
		var moved := ghost.get_node(^"Visual") as Control
		var beside_x := script.indent_pad + beside_plan.y * script.indent_step
		if absf(moved.position.x - beside_x) > 10.0:
			_fail("moving sideways left the ghost at %s, drop wants %s" % [moved.position.x, beside_x])
	script.set_mb_budget(8, 8)
	script.preview_drop(into, payload)
	await process_frame
	if ghost and ghost.modulate.g > 0.6:
		_fail("an over-budget drop was not tinted red")
	var reason := script.get_node_or_null(^"ScriptScroll/ScriptBody/DropReason") as Label
	if reason == null or not reason.visible or not str(reason.text).contains("MB"):
		_fail("over-budget drop gave no reason")
	if script._can_drop_data(into, payload):
		_fail("over-budget drop was accepted")
	script.clear_drop_preview()
	await process_frame
	if script.get_node_or_null(^"ScriptScroll/ScriptBody/ScriptRows/DropGap") != null:
		_fail("cancelling the drag left the gap open")
	script.set_mb_budget(1, 8)
	script.set_process(true)


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
		"stop_thinking": ["Stop thinking", "หยุดคิด"],
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
	for key in ["ui.code_editor.sort_conditions_first", "ui.code_editor.sort_actions_first", "ui.code_editor.ram_hint", "ui.code_editor.ram", "ui.code_editor.empty", "ui.code_editor.drop_mb", "ui.code_editor.drop_indent"]:
		if LocaleText.translate(key, "en").is_empty() or LocaleText.translate(key, "th").is_empty():
			_fail("missing translation %s" % key)
	TranslationServer.set_locale("en")
	var chance := load("res://data/blocks/random_chance.tres") as CodeBlock
	if not chance.get_display_description().contains("0.5"):
		_fail("chance placeholder was not filled: '%s'" % chance.get_display_description())
	var shown := BlockInventory.block_description(chance)
	if not shown.contains("50%"):
		_fail("tooltip chance was not a percent: '%s'" % shown)
	var weak := load("res://data/blocks/low_hp.tres") as CodeBlock
	if not weak.get_display_description().contains("0.35"):
		_fail("threshold placeholder was not filled: '%s'" % weak.get_display_description())
	TranslationServer.set_locale("en")


func _palette_has_both(board: Control) -> bool:
	var saw_condition := false
	var saw_action := false
	for child in board.get_children():
		var card := child as BlockCard
		if card == null:
			continue
		var shape := str(card.get_node(^"Visual").theme_type_variation)
		if shape.begins_with("Condition"):
			saw_condition = true
		elif shape.begins_with("Action"):
			saw_action = true
	return saw_condition and saw_action


func _kind_order(board: Control, conditions_first: bool) -> bool:
	var saw_second := false
	var saw_first := false
	for child in board.get_children():
		var card := child as BlockCard
		if card == null:
			continue
		var shape := str(card.get_node(^"Visual").theme_type_variation)
		var is_condition := shape.begins_with("Condition")
		var is_first := is_condition == conditions_first
		if is_first:
			saw_first = true
			if saw_second:
				return false
		elif shape.begins_with("Condition") or shape.begins_with("Action"):
			saw_second = true
	return saw_first and saw_second


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


func _map_state(world: Node, state_name: String) -> int:
	var states: Dictionary = world.get_script().get_script_constant_map()["State"]
	return int(states[state_name])


func _set_map_state(world: Node, state_name: String) -> void:
	world.call(&"set_state", _map_state(world, state_name))


func _editor_is_open(editor: Node) -> bool:
	return bool(editor.call(&"is_open"))


func _test_world_map_book() -> void:
	await process_frame
	var game := root.get_node(^"Game")
	var world := (load("res://systems/world_map/world_map.tscn") as PackedScene).instantiate() as Node2D
	if world == null:
		_fail("world map scene did not instantiate")
		return
	root.add_child(world)
	for _frame in 8:
		await process_frame
	if world.get_node_or_null(^"BookBackground/Label") != null:
		_fail("book placeholder is still mounted")
	var pages := world.get_node_or_null(^"CodeLayer") as CanvasLayer
	var editor := world.get_node_or_null(^"CodeLayer/Editor")
	if editor == null:
		_fail("world map has no code editor")
		world.queue_free()
		return
	if pages == null or not pages.follow_viewport_enabled or pages.layer <= 1 or pages.layer >= 10:
		_fail("code pages are not on a layer between the portrait and the map buttons")
	var gui := root.get_node_or_null(^"GUI") as CanvasLayer
	if gui and pages.layer <= gui.layer:
		_fail("code pages are still under the portrait layer")
	if world.get_node_or_null(^"BookBackground/Editor") != null:
		_fail("code pages are still parented under the book")
	if editor.get_node_or_null(^"Camera2D") != null:
		_fail("editor still owns a camera")
	var screen := world.get_node(^"BookBackground/BookScreen") as Sprite2D
	if editor.get("book") != screen:
		_fail("editor is not laid out on the world map book")
	var owned := editor.get_node(^"BookScreen") as CanvasItem
	if owned.visible:
		_fail("editor drew a second book sprite")
	if bool(editor.get("active_on_ready")):
		_fail("world map editor starts active")
	if _editor_is_open(editor):
		_fail("editor was open on the map")
	if editor.visible:
		_fail("closed editor is still drawn over the map")
	var pan := world.get_node(^"Camera2D/MousePan") as MousePanComponent
	pan.max_offset = Vector2(21, 13)
	await process_frame
	if not pan.max_offset.is_equal_approx(Vector2(21, 13)):
		_fail("closed editor changed the map pan, got %s" % pan.max_offset)
	pan.max_offset = Vector2(76.8, 48)
	var closes: Array[int] = [0]
	editor.connect(&"closed", func() -> void: closes[0] += 1)
	_set_map_state(world, "MAP")
	if closes[0] != 0:
		_fail("closing an already closed editor emitted closed")
	_set_map_state(world, "CODE")
	for _frame in 8:
		await process_frame
	if not _editor_is_open(editor):
		_fail("Code state did not open the editor")
	if not editor.visible:
		_fail("Code state left the pages hidden")
	var roster: Array = game.get("spells")
	var slot := roster[0] as SummonSpell
	var count := slot.get_update_function().lines.size()
	if count <= 0:
		_fail("roster slot 0 was empty before the map round-trip")
	var palette := editor.get_node(^"%BlockPalette") as Control
	var script := editor.get_node(^"%ScriptView") as ScriptView
	var book_rect := _sprite_world_rect(screen)
	if not book_rect.has_point(palette.get_global_rect().get_center()):
		_fail("palette is not on the world map book: %s book %s" % [palette.get_global_rect(), book_rect])
	if not book_rect.has_point(script.get_global_rect().get_center()):
		_fail("script is not on the world map book: %s book %s" % [script.get_global_rect(), book_rect])
	var button := editor.get_node(^"%SpellButton1") as Button
	if button.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("open editor blocked its own buttons")
	var background := world.get_node(^"BookBackground") as Node2D
	background.position = Vector2(80, -40)
	screen.position = Vector2(30, -20)
	for _frame in 3:
		await process_frame
	book_rect = _sprite_world_rect(screen)
	if not book_rect.has_point(palette.get_global_rect().get_center()):
		_fail("pages did not follow the book after it moved: palette %s book %s" % [palette.get_global_rect(), book_rect])
	if not book_rect.has_point(script.get_global_rect().get_center()):
		_fail("script did not follow the book after it moved: script %s book %s" % [script.get_global_rect(), book_rect])
	background.position = Vector2.ZERO
	screen.position = Vector2.ZERO
	for _frame in 2:
		await process_frame
	var parallax := background.get_node(^"ParallaxOffset") as ParallaxOffsetComponent
	parallax.enabled = true
	pan.set_process(false)
	var book_before := _canvas_origin(screen)
	var palette_before := _canvas_origin(palette)
	pan.offset = Vector2(50, 20)
	await process_frame
	await process_frame
	var book_delta := _canvas_origin(screen) - book_before
	var palette_delta := _canvas_origin(palette) - palette_before
	if book_delta.length() < 5.0:
		_fail("parallax did not move the book, delta %s" % book_delta)
	if palette_delta.distance_to(book_delta) > 1.5:
		_fail("pages did not stay on the parallaxed book, book %s pages %s" % [book_delta, palette_delta])
	parallax.enabled = false
	background.position = Vector2.ZERO
	pan.offset = Vector2.ZERO
	var camera := world.get_node(^"Camera2D") as Camera2D
	camera.offset = Vector2.ZERO
	for _frame in 2:
		await process_frame
	var book_before_pan := _canvas_origin(screen)
	var palette_before_pan := _canvas_origin(palette)
	camera.offset = Vector2(36, -18)
	await process_frame
	await process_frame
	var book_pan := _canvas_origin(screen) - book_before_pan
	var palette_pan := _canvas_origin(palette) - palette_before_pan
	if book_pan.length() < 5.0:
		_fail("camera did not move the book, delta %s" % book_pan)
	if palette_pan.distance_to(book_pan) > 1.5:
		_fail("pages slipped off the book when the camera moved, book %s pages %s" % [book_pan, palette_pan])
	camera.offset = Vector2.ZERO
	pan.set_process(true)
	var rows := editor.get_node(^"%ScriptRows") as Node
	if rows.get_child_count() != count:
		_fail("open editor did not show the roster script, rows %d lines %d" % [rows.get_child_count(), count])
	script.select_line(0)
	_set_map_state(world, "MAP")
	if _editor_is_open(editor):
		_fail("map state left the editor open")
	if editor.visible:
		_fail("map state left the pages drawn")
	if closes[0] != 1:
		_fail("leaving the book did not emit closed once, got %d" % closes[0])
	if script.is_processing_input():
		_fail("closed editor still reads the keyboard")
	if button.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("closed editor still takes clicks")
	var key := InputEventKey.new()
	key.keycode = KEY_DELETE
	key.pressed = true
	script._input(key)
	if slot.get_update_function().lines.size() != count:
		_fail("closed editor deleted a line")
	_set_map_state(world, "CODE")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	world._unhandled_input(click)
	if int(world.get("current_state")) != _map_state(world, "CODE"):
		_fail("a click left the book")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	world.get_viewport().push_input(escape)
	if int(world.get("current_state")) != _map_state(world, "MAP"):
		_fail("escape did not return to the map")
	if _editor_is_open(editor):
		_fail("escape left the editor open")
	_set_map_state(world, "CODE")
	for _frame in 3:
		await process_frame
	rows = editor.get_node(^"%ScriptRows") as Node
	if rows.get_child_count() != slot.get_update_function().lines.size():
		_fail("reopening the book did not keep the roster script")
	game.set("world_map", null)
	game.set("current_stage", null)
	world.queue_free()


func _test_raid_spawns_roster() -> void:
	await process_frame
	var game := root.get_node(^"Game")
	var roster: Array = game.get("spells")
	var slot := roster[0] as SummonSpell
	var expected_lines := slot.get_update_function().lines
	if expected_lines.is_empty():
		_fail("raid test needs a script on slot 0")
		return
	var slots: Array[int] = [0, 0, 99]
	game.set("raid_slots", slots)
	var battle := (load("res://systems/battle/battle.tscn") as PackedScene).instantiate() as Node2D
	if battle == null:
		_fail("battle scene did not instantiate")
		return
	root.add_child(battle)
	await process_frame
	if not _minions_under(battle).is_empty():
		_fail("battle spawned a party before it was the raid")
	battle.call("mount_raid_tools")
	battle.call("spawn_raid_party")
	await process_frame
	var minions := _minions_under(battle)
	if minions.size() != 1:
		_fail("raid spawned %d minions for one slot" % minions.size())
	else:
		var unit := minions[0]
		if unit.program == slot.get_program():
			_fail("raid unit is running the live roster program")
		var function := unit.runner.get_update_script() if unit.runner else null
		var got := function.lines.size() if function else -1
		if got != expected_lines.size():
			_fail("raid script has %d lines, roster has %d" % [got, expected_lines.size()])
		elif function.lines[0] and expected_lines[0] and function.lines[0].block and expected_lines[0].block:
			if str(function.lines[0].block.id) != str(expected_lines[0].block.id):
				_fail("raid script does not start with the roster block")
		if unit.stats and slot.def and unit.stats.ram != slot.ram_max():
			_fail("raid unit ram is %d, slot ram is %d" % [unit.stats.ram, slot.ram_max()])
	if battle.get_node_or_null(^"CanvasLayer/ScriptDebugPanel") == null:
		_fail("raid battle has no script panel")
	var director := battle.get_node_or_null(^"FocusDirector") as FocusDirector
	if director == null or director.get_inspected_unit() == null:
		_fail("raid script panel has no minion pinned")
	elif minions.size() == 1 and director.get_inspected_unit() != minions[0]:
		_fail("raid script panel is showing a different unit")
	battle.call("spawn_raid_party")
	if _minions_under(battle).size() != 1:
		_fail("raid spawned the party twice")
	game.set("raid_slots", [])
	game.set("current_stage", null)
	battle.queue_free()


func _test_stop_thinking() -> void:
	var stop := load("res://data/blocks/stop_thinking.tres") as CodeBlock
	var stand := load("res://data/blocks/stand_still.tres") as CodeBlock
	if stop == null or stand == null:
		_fail("stop thinking block is missing")
		return
	var program := SummonSpell.blank_program()
	var update := program.functions[0]
	update.lines.append(_line(stop, 0))
	update.lines.append(_line(stand, 0))
	var hit := UnitFunction.new()
	hit.function_name = "ON_HIT"
	hit.lines.append(_line(stop, 0))
	hit.lines.append(_line(stand, 0))
	program.functions.append(hit)
	program.event_graph.connect_function(EventGraph.Event.ON_HIT, hit)
	var def := UnitDef.new()
	def.team = Unit2D.Team.MINION
	def.cpu = 1
	var events: Array[EventGraph.Event] = [EventGraph.Event.ON_UPDATE, EventGraph.Event.ON_HIT]
	def.allowed_events = events
	def.starting_program = program
	var unit := (load("res://systems/units/unit.tscn") as PackedScene).instantiate() as Unit2D
	unit.def = def
	root.add_child(unit)
	await process_frame
	unit.targets.append(unit)
	var remembered := unit.targets.size()
	if not unit.runner.fire(EventGraph.Event.ON_HIT, null):
		_fail("stop thinking did not run during an instant event")
	if not unit.queue_actions.is_empty():
		_fail("stop thinking kept reading the instant event")
	if unit.targets.size() != remembered:
		_fail("stop thinking cleared remembered targets")
	unit.state = Unit2D.State.IDLE
	unit.runner.read_index = 0
	unit.runner.set("_timer_armed", true)
	unit.runner.set("_read_timer", 0.0)
	var interval := Formular.calculate_think_interval(unit.get_cpu())
	unit.runner.tick(0.0)
	if unit.runner.read_index != 0 or not unit.queue_actions.is_empty():
		_fail("stop thinking read the next line in the same think")
	unit.runner.tick(interval * 0.5)
	if unit.runner.read_index != 0 or not unit.queue_actions.is_empty():
		_fail("stop thinking read again before the think bar filled")
	unit.state = Unit2D.State.IDLE
	unit.runner.tick(interval * 0.5)
	if unit.runner.read_index != 0:
		_fail("the next think did not start at line 0")
	if not unit.queue_actions.is_empty():
		_fail("the line after stop thinking ran after a full think")
	var left := float(unit.runner.get("_read_timer"))
	if left < interval * 0.75:
		_fail("line 0 was read again without a full think interval, timer %s" % left)
	if unit.targets.size() != remembered:
		_fail("a stopped think cleared remembered targets")
	unit.queue_free()


func _test_army_carry() -> void:
	TranslationServer.set_locale("en")
	var game := root.get_node(^"Game")
	game.set("corpse", 2)
	var army: Array = game.get("army")
	army.clear()
	var spells: Array = game.get("spells")
	var spell := spells[7] as SummonSpell
	var stand := load("res://data/blocks/stand_still.tres") as CodeBlock
	var stop := load("res://data/blocks/stop_thinking.tres") as CodeBlock
	var fn := spell.get_update_function()
	fn.lines.clear()
	var line := ScriptLine.new()
	line.block = stand
	fn.lines.append(line)
	var summoner: Script = load("res://systems/game/summoner.gd")
	if str(summoner.deny_reason(spell)) != "Not enough corpses" and int(game.get("corpse")) == 0:
		_fail("broke summon gave no reason")
	var camp := Node2D.new()
	root.add_child(camp)
	var first: Unit2D = summoner.summon(spell, camp, Vector2(48, 48))
	var second: Unit2D = summoner.summon(spell, camp, Vector2(160, 48))
	if first == null or second == null:
		_fail("camp summon did not spend a corpse and spawn")
		return
	if int(game.get("corpse")) != 0:
		_fail("two summons did not spend 2 corpses, left %s" % str(game.get("corpse")))
	if army.size() != 2:
		_fail("army did not record both summons, got %d" % army.size())
		return
	if summoner.summon(spell, camp, Vector2(240, 48)) != null:
		_fail("summoned with no corpses left")
	if str(summoner.deny_reason(spell)) != "Not enough corpses":
		_fail("missing corpse flash was '%s'" % str(summoner.deny_reason(spell)))
	var spell_block: CodeBlock = fn.lines[0].block
	var unit_block: CodeBlock = _update_lines(first.program)[0].block
	if unit_block == spell_block:
		_fail("summoned unit shares the spell's block")
	var extra := ScriptLine.new()
	extra.block = stop
	fn.lines.append(extra)
	if _update_lines(first.program).size() != 1 or _update_lines(second.program).size() != 1:
		_fail("editing the spell changed a summoned unit")
	var member_a: ArmyMember = army[0]
	var member_b: ArmyMember = army[1]
	if _update_lines(member_a.def.starting_program).size() != 1:
		_fail("editing the spell changed the army snapshot")
	first.health.current_health = 11
	first.stats.hp = 11
	second.health.current_health = 4
	second.stats.hp = 4
	summoner.stash_army()
	army = game.get("army")
	if army.size() != 2 or int(army[0].hp) != 11 or int(army[1].hp) != 4:
		_fail("stash did not keep both survivors' hp")
		return
	var battle := (load("res://systems/battle/battle.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(battle)
	await process_frame
	battle.call("spawn_army")
	await process_frame
	var brought := _minions_under(battle)
	if brought.size() != 2:
		_fail("raid did not bring the camp army, got %d" % brought.size())
		return
	var wounded: Unit2D = null
	for unit in brought:
		if _update_lines(unit.program).size() != 1:
			_fail("battle unit did not keep the snapshot script")
		if unit.program.functions[0].lines[0].block == spell_block:
			_fail("battle unit shares the edited spell block")
		if int(round(unit.health.get_health())) == 11:
			wounded = unit
	if wounded == null:
		_fail("survivor hp was not carried into battle")
		return
	for unit in brought:
		if unit == wounded:
			continue
		unit.health.current_health = 0
		unit.set_state(Unit2D.State.DEAD)
	summoner.stash_army()
	army = game.get("army")
	if army.size() != 1 or int(army[0].hp) != 11:
		_fail("the dead unit stayed in the army, size %d" % army.size())
		return
	var home := Node2D.new()
	root.add_child(home)
	summoner.spawn_army_at(home)
	await process_frame
	var returned := _minions_under(home)
	if returned.size() != 1:
		_fail("the survivor did not return to camp, got %d" % returned.size())
		return
	if int(round(returned[0].health.get_health())) != 11:
		_fail("returned survivor lost hp, got %s" % str(returned[0].health.get_health()))
	if _update_lines(returned[0].program).size() != 1:
		_fail("returned survivor followed the edited spell")
	fn.lines.append(extra)
	if _update_lines(returned[0].program).size() != 1:
		_fail("a later spell edit changed the camp army")
	var encoded: Variant = JSON.parse_string(JSON.stringify(summoner.army_to_data(army)))
	var restored: Array = summoner.army_from_data(encoded)
	if restored.size() != 1 or int(restored[0].hp) != 11:
		_fail("army save did not keep the survivor")
		return
	if _update_lines(restored[0].def.starting_program).size() != 1:
		_fail("army save lost the script")
	if str(_update_lines(restored[0].def.starting_program)[0].block.id) != "stand_still":
		_fail("army save lost the block")
	var saves := root.get_node(^"SaveManager")
	saves.call("set_metadata_value", "army", summoner.army_to_data(army))
	if not bool(saves.call("save_slot", 9)):
		_fail("army metadata did not save")
	else:
		var meta: Dictionary = saves.call("get_slot_metadata", 9)
		var from_slot: Array = summoner.army_from_data(meta.get("army", []))
		if from_slot.size() != 1 or int(from_slot[0].hp) != 11:
			_fail("map slot did not restore the army")
		saves.call("delete_slot", 9)
	army.clear()
	camp.queue_free()
	home.queue_free()
	battle.queue_free()


func _update_lines(program: UnitProgram) -> Array[ScriptLine]:
	if program == null:
		return []
	for fn in program.functions:
		if fn and fn.function_name == "ON_UPDATE":
			return fn.lines
	return []


func _minions_under(battle: Node) -> Array[Unit2D]:
	var found: Array[Unit2D] = []
	for child in battle.get_children():
		var unit := child as Unit2D
		if unit and unit.team == Unit2D.Team.MINION:
			found.append(unit)
	return found


func _test_pages_follow_pan(editor: Node, palette: Control, script: Control) -> void:
	var host := editor.get_parent()
	var pan := host.get_node(^"Camera2D/MousePan") as Node
	pan.set_process(false)
	var camera := host.get_node(^"Camera2D") as Camera2D
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
	var plan := view._plan(Vector2(view.indent_pad + 4.0, view.row_height * 0.5), {"source": "palette", "block": _attack()})
	if int(plan.x) != 1:
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
