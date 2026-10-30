extends SceneTree

const _SAVE := "user://saves/slot_0.json"
const _SEED_RAM: Array[int] = [8, 12, 16, 10, 8, 14, 12, 9]
const _IDS: PackedStringArray = [
	"setup", "summon", "offering", "select", "move", "bars", "cpu_gpu", "queue",
	"ram", "sacrifice", "book", "two_pages", "summoning_page", "thinking_page",
	"fight", "ending",
]

var _failed := 0
var _save_backup := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_save_backup = _read_save()
	TranslationServer.set_locale("en")
	_test_catalog()
	await _test_play()
	_restore_save()
	if _failed == 0:
		print("tutorial checks passed")
	else:
		print("%d tutorial checks failed" % _failed)
	quit(1 if _failed else 0)


func _test_catalog() -> void:
	var steps := TutorialSteps.build()
	if steps.size() != 16:
		_fail("expected 16 steps, got %d" % steps.size())
		return
	var english := _english_rows()
	for index in steps.size():
		var step := steps[index]
		if step.id != _IDS[index]:
			_fail("step %d id was %s" % [index + 1, step.id])
		if step.text_key.is_empty():
			continue
		if not english.has(step.text_key):
			_fail("missing EN text for %s" % step.text_key)
	for key in ["ui.tutorial.next", "ui.tutorial.skip", "ui.tutorial.back", "ui.tutorial.objective"]:
		if not english.has(key):
			_fail("missing EN text for %s" % key)


func _test_play() -> void:
	var battle = load("res://systems/tutorial/tutorial.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame
	var director = battle.get_node_or_null("TutorialDirector")
	if director == null or director.steps.size() != 16:
		_fail("tutorial director did not start")
		battle.free()
		return
	if director.index != 1 or director.steps[director.index].id != "summon":
		_fail("setup did not advance to the summon step")
	var summoning := battle.get_node("CodeLayer/Editor/PageButtons/SpecPageButton") as Button
	var thinking := battle.get_node("CodeLayer/Editor/PageButtons/ScriptPageButton") as Button
	if summoning.text != "Summoning" or thinking.text != "Thinking":
		_fail("page buttons were '%s' / '%s'" % [summoning.text, thinking.text])
	var retreat := battle.get_node("CanvasLayer/RetreatButton") as CanvasItem
	if retreat.visible:
		_fail("retreat stayed visible")
	var code := battle.get_node("CanvasLayer/StateContainer/CodeButton") as Button
	if not code.disabled:
		_fail("the spell book was already enabled")
	var sacrifice := root.get_node_or_null("GUI/SacrificeButton") as CanvasItem
	if sacrifice and sacrifice.visible:
		_fail("sacrifice was visible before that step")
	if battle.allows_summon(1) or battle.allows_order():
		_fail("spell 2 or orders were open on the summon step")
	if battle.shows_spell(7) == false or battle.allows_spell(7):
		_fail("the other spell slots were not shown and locked")
	if battle.allows_summon(0) == false:
		_fail("spell 1 could not be summoned")
	await _walk(director, battle, code, sacrifice)
	director.travel_on_exit = false
	director.skip()
	_assert_seeded("skip")
	var host := root.get_node("Game")
	host.call("set_wallet", 4, 4, 4, 4, 4)
	host.set("tutorial_done", false)
	host.call("finish_tutorial", false)
	_assert_seeded("finish")
	battle.free()


func _walk(director, battle, code: Button, sacrifice: CanvasItem) -> void:
	_expect_closed(director, "summon")
	battle.note_summon()
	director.notify_summoned()
	if director.steps[director.index].id != "offering" or not director.next_enabled:
		_fail("summoning did not advance to the offering")
		return
	director.press_next()
	if director.steps[director.index].id != "offering" or director.next_enabled:
		_fail("select started before the unit finished spawning")
	director.notify_spawn_finished()
	if director.steps[director.index].id != "select":
		_fail("select did not start after spawn")
		return
	_expect_closed(director, "select")
	if battle.allows_order():
		_fail("an order was allowed before the move step")
	director.notify_selected()
	if director.steps[director.index].id != "move" or battle.allows_order() == false or not battle.tutorial_short_move:
		_fail("the short move was not available")
		return
	_expect_closed(director, "move")
	battle.note_order()
	director.notify_move()
	if director.steps[director.index].id != "bars" or battle.allows_order() or battle.allows_summon(0):
		_fail("the first move did not advance, or a second order got through")
		return
	if battle.tutorial_short_move:
		_fail("later steps still forced the short walk")
	_confirm(director, "bars")
	director.press_next()
	_confirm(director, "cpu_gpu")
	var panel := root.get_node_or_null("GUI/ScriptPreview")
	if panel == null or not panel.show_stats_section or panel.show_queue_section or panel.show_ram_section or panel.show_script_section:
		_fail("the stats step did not start with stats only")
	if panel.highlight_section != "stats":
		_fail("the stats step did not highlight stats")
	if battle.allows_order() or battle.allows_summon(0):
		_fail("locks dropped before the queue step")
	director.press_next()
	if director.steps[director.index].id != "queue" or battle.allows_order() == false:
		_fail("orders stayed capped on the queue step")
		return
	_expect_closed(director, "queue")
	if not panel.show_stats_section or not panel.show_queue_section or panel.show_ram_section or panel.highlight_section != "queue":
		_fail("the queue step did not keep stats and highlight the queue")
	director.notify_ram_full()
	_confirm(director, "ram")
	if not panel.show_stats_section or not panel.show_queue_section or not panel.show_ram_section or panel.highlight_section != "ram":
		_fail("the RAM step did not keep the earlier sections")
	director.press_next()
	if sacrifice and not sacrifice.visible:
		_fail("sacrifice stayed hidden")
	_expect_closed(director, "sacrifice")
	director.notify_sacrificed()
	if director.steps[director.index].id != "book" or code.disabled:
		_fail("sacrificing did not open the book step")
		return
	_expect_closed(director, "book")
	director.notify_code()
	var field := battle.get_node("CanvasLayer/StateContainer/FieldButton") as Button
	if field == null or not field.disabled:
		_fail("the field flag stayed usable after the book opened")
	battle.set_state(1)
	battle.set_state(0)
	if battle.is_coding() == false:
		_fail("the field flag closed the book during the script lesson")
	battle.tutorial_lock_field = false
	battle.set_state(0)
	battle.tutorial_lock_field = true
	battle.call("_update_state_buttons")
	_confirm(director, "two_pages")
	director.press_next()
	_expect_closed(director, "summoning_page")
	director.notify_page(0)
	if director.steps[director.index].id != "thinking_page":
		_fail("Summoning did not advance to Thinking")
		return
	if battle.allows_spell(7) == false:
		_fail("spell slots stayed locked on the script step")
	_expect_closed(director, "thinking_page")
	if director._current_focus(director.steps[director.index]) != "thinking_page_button":
		_fail("thinking step did not point at Thinking")
	director.notify_page(1)
	if director.steps[director.index].id != "thinking_page":
		_fail("opening Thinking advanced before an action rune")
	if director._current_focus(director.steps[director.index]) != "rune_palette":
		_fail("thinking step did not move to the rune palette")
	if director.next_enabled:
		_fail("thinking step advanced before an action rune")
	var host := root.get_node("Game")
	var spell = host.get("spells")[0]
	var attack: ActionBlock = load("res://data/blocks/attack_target.tres")
	ScriptEditing.insert_line(spell.get_update_function().lines, 0, 0, attack)
	director.poke()
	if director.steps[director.index].id != "fight" or not director.next_enabled:
		_fail("an action rune did not advance to the fight")
		return
	if battle.get_node("CanvasLayer/StateContainer/FieldButton").disabled:
		_fail("the field flag stayed locked after the script lesson")
	if battle.allows_summon(0):
		_fail("summoning unlocked before the fight was confirmed")
	host.call("set_wallet", 1, 0, 0, 0, 2)
	director.press_next()
	if director.next_enabled or battle.allows_summon(0) == false:
		_fail("the fight did not unlock summoning and wait for a win")
	if int(host.get("corpse")) < 6 or int(host.get("gore")) < 6:
		_fail("resources were not topped up to 6")
	var villagers := 0
	for node in get_nodes_in_group("units"):
		var unit := node as Unit2D
		if unit and unit.team == Unit2D.Team.VILLAGER:
			villagers += 1
	if villagers != 3:
		_fail("spawned %d villagers" % villagers)
	director.notify_victory()
	if director.steps[director.index].id != "ending":
		_fail("winning did not advance to the ending")
	var back := battle.get_node("CanvasLayer/StageEndScreen/BackButton") as Button
	var ending := battle.get_node_or_null("CanvasLayer/StageEndScreen/TutorialEnding") as RichTextLabel
	if back.text != "Back to world":
		_fail("back button was '%s'" % back.text)
	if ending == null or not ending.text.contains("wiped out"):
		_fail("the win line was not on the stage end")


func _confirm(director, id: String) -> void:
	if director.steps[director.index].id != id or not director.next_enabled:
		_fail("%s was not ready to confirm" % id)


func _expect_closed(director, id: String) -> void:
	if director.steps[director.index].id != id:
		_fail("expected step %s, on %s" % [id, director.steps[director.index].id])
		return
	if director.next_enabled or not director._next.disabled:
		_fail("Next was enabled on %s before its wait" % id)
	var before = director.index
	director.press_next()
	if director.index != before:
		_fail("Next advanced %s before its wait" % id)


func _expect_open(director) -> void:
	if not director.next_enabled or director._next.disabled:
		_fail("Next stayed disabled on %s" % director.steps[director.index].id)


func _assert_seeded(label: String) -> void:
	var host := root.get_node("Game")
	if host.get("tutorial_done") != true:
		_fail("%s did not set tutorial_done" % label)
	var raw := _read_save()
	if not raw.contains("tutorial_done"):
		_fail("%s did not save tutorial_done" % label)
	for kind in ["corpse", "bone", "weapon", "collar", "gore"]:
		if int(host.get(kind)) != 0:
			_fail("%s left %s at %s" % [label, kind, host.get(kind)])
	var army: Array = host.get("army")
	if not army.is_empty():
		_fail("%s left %d minions in the army" % [label, army.size()])
	var spells: Array = host.get("spells")
	if spells.size() != _SEED_RAM.size():
		_fail("%s left %d spells" % [label, spells.size()])
		return
	for index in spells.size():
		var spell = spells[index]
		if int(spell.base_ram) != _SEED_RAM[index] or int(spell.race) != 0:
			_fail("%s spell %d was not the zombie seed" % [label, index])
		if int(spell.corpse_amount) != 1 or int(spell.gore_amount) != 1:
			_fail("%s spell %d offering was not 1/1" % [label, index])
		if spell.get_update_function().lines.size() != 0:
			_fail("%s spell %d kept a rune" % [label, index])
	var inventory = host.get("block_inventory")
	var attack: CodeBlock = load("res://data/blocks/attack_target.tres")
	if inventory == null or inventory.get_count(attack) != 3:
		_fail("%s did not restore the starter runes" % label)


func _english_rows() -> Dictionary:
	var found := {}
	var file := FileAccess.open("res://contents/translations/ui.csv", FileAccess.READ)
	if file == null:
		_fail("ui.csv did not open")
		return found
	while not file.eof_reached():
		var line := file.get_line()
		var comma := line.find(",")
		if comma <= 0:
			continue
		var key := line.substr(0, comma)
		var rest := line.substr(comma + 1).strip_edges()
		if rest.is_empty() or rest.begins_with(","):
			continue
		found[key] = true
	return found


func _read_save() -> String:
	if not FileAccess.file_exists(_SAVE):
		return ""
	return FileAccess.get_file_as_string(_SAVE)


func _restore_save() -> void:
	if _save_backup.is_empty():
		if FileAccess.file_exists(_SAVE):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE))
		return
	var file := FileAccess.open(_SAVE, FileAccess.WRITE)
	if file:
		file.store_string(_save_backup)


func _fail(reason: String) -> void:
	_failed += 1
	push_error(reason)
