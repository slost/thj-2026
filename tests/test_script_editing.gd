extends SceneTree

var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_blank_programs_are_separate()
	_test_slot_clone_keeps_shared_blocks()
	_test_indent_and_structure()
	_test_inventory()
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
	var game := root.get_node(^"Game")
	var inventory = game.get("block_inventory")
	var attack := load("res://data/blocks/attack_target.tres") as CodeBlock
	var detect := load("res://data/blocks/enemy_in_detect_range.tres") as ConditionBlock
	inventory.add(attack, 20)
	var editor := (load("res://systems/code_editor/editor.tscn") as PackedScene).instantiate()
	root.add_child(editor)
	for _frame in 10:
		await process_frame
	var palette := editor.get_node(^"CanvasLayer/BlockPalette") as Control
	var script := editor.get_node(^"CanvasLayer/ScriptView") as Control
	var header := editor.get_node(^"CanvasLayer/ScriptHeader") as Control
	var slots := editor.get_node(^"CanvasLayer/UnitsContainer") as Control
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
	var ram_label := header.get_child(0).get_child(1) as Label
	if not str(ram_label.text).contains("2 / 8"):
		_fail("RAM meter was '%s'" % ram_label.text)
	var row_box := script.get_child(0).get_child(0) as Node
	if row_box.get_child_count() < 2:
		_fail("script view did not build rows")
	else:
		var first_label := row_box.get_child(0).get_child(1) as Label
		var second_label := row_box.get_child(1).get_child(1) as Label
		if first_label == null or not first_label.text.begins_with("["):
			_fail("condition row was not bracketed")
		if second_label == null or not second_label.text.begins_with("<"):
			_fail("action row was not in angle brackets")
		elif second_label.offset_left <= first_label.offset_left:
			_fail("action row was not indented on the page")
	editor.call("_on_slot_button", 3)
	for _frame in 2:
		await process_frame
	if roster[3].get_update_function().lines.size() != 0:
		_fail("slot 4 was not empty")
	var name_label := header.get_child(0).get_child(0) as Label
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
	editor.queue_free()


func _attack() -> ActionBlock:
	return load("res://data/blocks/attack_target.tres") as ActionBlock


func _move() -> ActionBlock:
	return load("res://data/blocks/move_to_target.tres") as ActionBlock


func _detect() -> ConditionBlock:
	return load("res://data/blocks/enemy_in_detect_range.tres") as ConditionBlock


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
