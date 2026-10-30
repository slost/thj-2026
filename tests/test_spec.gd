extends SceneTree

var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("en")
	_test_formulas()
	_test_resource_cap()
	_test_race_data()
	_test_costs_and_clamp()
	_test_unlock()
	_test_ram_refuses_race()
	await _test_summon_snapshot()
	_test_save_load()
	await _test_editor_pages()
	await _test_map_and_battle()
	if _failed == 0:
		print("spec checks passed")
	else:
		print("%d spec checks failed" % _failed)
	quit(1 if _failed else 0)


func _test_formulas() -> void:
	if Formular.spec_min_ingredient() != 1 or Formular.spec_max_ingredient() != 5:
		_fail("ingredient range is not 1..5")
	if Formular.spec_cpu_per_corpse() != 1 or Formular.spec_gpu_per_gore() != 1:
		_fail("spec steps are not 1")
	if Formular.spec_ram_per_cpu() != 4 or Formular.spec_ram_per_gpu() != 2:
		_fail("ram steps are not +4 per cpu and +2 per gpu")
	if Formular.spec_cpu(1, 1) != 1 or Formular.spec_gpu(1, 1) != 1 or Formular.spec_ram(8, 1, 1) != 8:
		_fail("min ingredients did not keep the base cpu/gpu/ram")
	if Formular.spec_cpu(1, 5) != 5 or Formular.spec_gpu(1, 5) != 5:
		_fail("max ingredients did not add four steps, cpu %d gpu %d" % [Formular.spec_cpu(1, 5), Formular.spec_gpu(1, 5)])
	if Formular.spec_cpu(2, 3) != 4 or Formular.spec_gpu(1, 1) != 1:
		_fail("skeleton archer corpse 3 was not CPU 4")
	if Formular.spec_ram(8, 5, 1) != 24 or Formular.spec_ram(8, 1, 5) != 16 or Formular.spec_ram(8, 5, 5) != 32:
		_fail("ram did not add 4 per cpu and 2 per gpu")
	if Formular.spec_ram(0, 1, 1) != 1:
		_fail("ram floor was %d" % Formular.spec_ram(0, 1, 1))
	if Formular.spec_cpu(3, 0) != Formular.spec_cpu(3, 1) or Formular.spec_gpu(3, 99) != Formular.spec_gpu(3, 5):
		_fail("formulas did not clamp ingredients")


func _test_resource_cap() -> void:
	var game := root.get_node(^"Game")
	game.set("corpse", 90)
	game.call(&"change_resource", 0, 20)
	if int(game.get("corpse")) != 99:
		_fail("corpse was not capped at 99, got %s" % game.get("corpse"))
	game.call(&"change_resource", 0, -10)
	if int(game.get("corpse")) != 89:
		_fail("the cap blocked a spend, corpse %s" % game.get("corpse"))
	game.set("gore", 0)
	game.call(&"change_resource", 4, -5)
	if int(game.get("gore")) != 0:
		_fail("gore went below zero")


func _test_race_data() -> void:
	var profiles := RaceProfiles.all()
	if profiles.size() != 4:
		_fail("expected 4 race profiles, got %d" % profiles.size())
		return
	_expect_profile(Unit2D.Race.ZOMBIE, 40, 6, 1, 4, 1.2, 1, 1, 0, true, {})
	_expect_profile(Unit2D.Race.SKELETON_MELEE, 30, 8, 1, 5, 1.0, 1, 2, 2, false, {1: 10, 0: 5})
	_expect_profile(Unit2D.Race.SKELETON_RANGED, 20, 5, 4, 6, 1.5, 2, 1, 4, false, {1: 12, 2: 3})
	_expect_profile(Unit2D.Race.DIRE_WOLF, 25, 6, 1, 6, 0.8, 1, 3, -2, false, {0: 8, 4: 6, 3: 2})
	TranslationServer.set_locale("th")
	var zombie := RaceProfiles.get_profile(Unit2D.Race.ZOMBIE)
	if zombie.display_name() != "ซอมบี้":
		_fail("thai zombie name was '%s'" % zombie.display_name())
	TranslationServer.set_locale("en")
	if zombie.display_name() != "Zombie":
		_fail("english zombie name was '%s'" % zombie.display_name())


func _expect_profile(race: Unit2D.Race, hp: int, damage: int, attack: int, detect: int, cooldown: float, cpu: int, gpu: int, ram: int, unlocked: bool, costs: Dictionary) -> void:
	var profile := RaceProfiles.get_profile(race)
	if profile == null:
		_fail("missing profile %s" % race)
		return
	if profile.max_hp != hp or profile.damage != damage or profile.attack_range != attack:
		_fail("combat stats for %s" % race)
	if profile.detect_range != detect or not is_equal_approx(profile.attack_cooldown, cooldown):
		_fail("range or cooldown for %s" % race)
	if profile.base_cpu != cpu or profile.base_gpu != gpu or profile.ram_bonus != ram:
		_fail("spec bases for %s" % race)
	if profile.starts_unlocked != unlocked:
		_fail("unlock flag for %s" % race)
	if profile.icon == null:
		_fail("missing icon for %s" % race)
	var got := {}
	for cost in profile.unlock_costs:
		if cost == null or cost.amount <= 0:
			continue
		got[int(cost.resource_type)] = int(cost.amount)
	if got != costs:
		_fail("unlock costs for %s were %s" % [race, got])


func _test_costs_and_clamp() -> void:
	var spell := _new_spell()
	spell.set_corpse_amount(3)
	spell.set_gore_amount(2)
	var costs := spell.get_costs()
	if costs.size() != 2 or costs[0].resource_type != 0 or costs[0].amount != 3:
		_fail("corpse cost did not follow the stepper")
	if costs[1].resource_type != 4 or costs[1].amount != 2:
		_fail("gore cost did not follow the stepper")
	spell.set_corpse_amount(0)
	spell.set_gore_amount(99)
	if spell.corpse_amount != 1 or spell.gore_amount != 5:
		_fail("ingredients were not clamped, corpse %d gore %d" % [spell.corpse_amount, spell.gore_amount])
	spell.set_corpse_amount(1)
	spell.set_gore_amount(1)
	if spell.ram_max() != 8:
		_fail("default ingredients changed ram to %d" % spell.ram_max())
	if not spell.set_corpse_amount(2) or spell.ram_max() != 12:
		_fail("one extra cpu did not add 4 ram, ram %d" % spell.ram_max())
	if not spell.set_gore_amount(2) or spell.ram_max() != 14:
		_fail("one extra gpu did not add 2 ram, ram %d" % spell.ram_max())
	spell.set_gore_amount(1)
	var attack := load("res://data/blocks/attack_target.tres") as CodeBlock
	var function := spell.get_update_function()
	for _index in 10:
		ScriptEditing.insert_line(function.lines, function.lines.size(), 0, attack)
	if spell.set_corpse_amount(1):
		_fail("dropping cpu was allowed to shrink ram under the program")
	if spell.corpse_amount != 2 or spell.ram_max() != 12:
		_fail("a refused corpse change edited the spell")


func _test_unlock() -> void:
	var game := root.get_node(^"Game")
	var spell := _new_spell()
	if spell.set_race(Unit2D.Race.SKELETON_MELEE) != SummonSpell.RaceChange.REFUSED_LOCKED or spell.race != Unit2D.Race.ZOMBIE:
		_fail("a locked race was accepted")
	game.set("bone", 10)
	game.set("corpse", 4)
	game.set("gore", 3)
	game.set("weapon", 1)
	game.set("collar", 1)
	var hits := [0]
	game.connect(&"resource_changed", func() -> void: hits[0] += 1)
	if bool(game.call(&"try_unlock_race", Unit2D.Race.SKELETON_MELEE)):
		_fail("unlock succeeded without enough corpses")
	if int(game.get("bone")) != 10 or int(game.get("corpse")) != 4 or hits[0] != 0:
		_fail("a failed unlock spent resources")
	game.set("corpse", 5)
	if not bool(game.call(&"try_unlock_race", Unit2D.Race.SKELETON_MELEE)):
		_fail("affordable unlock failed")
	if int(game.get("bone")) != 0 or int(game.get("corpse")) != 0 or int(game.get("gore")) != 3:
		_fail("unlock did not spend exactly bone 10 and corpse 5")
	if hits[0] < 1:
		_fail("unlock did not emit resource_changed")
	if spell.set_race(Unit2D.Race.SKELETON_MELEE) != SummonSpell.RaceChange.APPLIED:
		_fail("unlocked race could not be set")
	if spell.def.gpu != 2 or spell.def.max_hp != 30 or spell.ram_max() != 10:
		_fail("skeleton spec was not applied")
	var melee_costs := spell.get_costs()
	if melee_costs.size() != 4 or melee_costs[2].resource_type != 1 or melee_costs[2].amount != 1:
		_fail("skeleton summon is missing its bone")
	if melee_costs[3].resource_type != 2 or melee_costs[3].amount != 1:
		_fail("skeleton summon is missing its weapon")


func _test_ram_refuses_race() -> void:
	var game := root.get_node(^"Game")
	game.set("corpse", 8)
	game.set("gore", 6)
	game.set("collar", 2)
	if not bool(game.call(&"try_unlock_race", Unit2D.Race.DIRE_WOLF)):
		_fail("dire wolf unlock failed")
		return
	var spell := _new_spell()
	spell.base_ram = 8
	if spell.ram_for(Unit2D.Race.DIRE_WOLF) != 6:
		_fail("dire wolf ram was %d" % spell.ram_for(Unit2D.Race.DIRE_WOLF))
	spell.base_ram = 1
	if spell.ram_for(Unit2D.Race.DIRE_WOLF) != 1:
		_fail("ram floor was %d" % spell.ram_for(Unit2D.Race.DIRE_WOLF))
	spell.base_ram = 8
	if spell.set_race(Unit2D.Race.DIRE_WOLF) != SummonSpell.RaceChange.APPLIED:
		_fail("empty dire wolf spec was refused")
	var wolf_costs := spell.get_costs()
	if wolf_costs.size() != 3 or wolf_costs[2].resource_type != 3 or wolf_costs[2].amount != 1:
		_fail("dire wolf summon is missing its collar")
	spell.set_race(Unit2D.Race.ZOMBIE)
	var attack := load("res://data/blocks/attack_target.tres") as CodeBlock
	var function := spell.get_update_function()
	var program := spell.get_program()
	for _index in 7:
		ScriptEditing.insert_line(function.lines, function.lines.size(), 0, attack)
	if spell.set_race(Unit2D.Race.DIRE_WOLF) != SummonSpell.RaceChange.REFUSED_RAM:
		_fail("race change was allowed past the new ram max")
	if spell.race != Unit2D.Race.ZOMBIE or function.lines.size() != 7 or spell.get_program() != program:
		_fail("a refused race change edited the spell")
	if spell.set_race(Unit2D.Race.SKELETON_MELEE) != SummonSpell.RaceChange.APPLIED:
		_fail("a roomier race was refused")
	if spell.get_program() != program or function.lines.size() != 7:
		_fail("changing race replaced the program")


func _test_summon_snapshot() -> void:
	var game := root.get_node(^"Game")
	game.get("army").clear()
	game.set("bone", 13)
	game.set("weapon", 4)
	game.set("corpse", 4)
	game.set("gore", 5)
	if not bool(game.call(&"try_unlock_race", Unit2D.Race.SKELETON_RANGED)):
		_fail("archer unlock failed")
		return
	var spell := _new_spell()
	if spell.set_race(Unit2D.Race.SKELETON_RANGED) != SummonSpell.RaceChange.APPLIED:
		_fail("archer spec was refused")
		return
	spell.set_corpse_amount(3)
	spell.set_gore_amount(1)
	if spell.def.cpu != 4 or spell.def.gpu != 1:
		_fail("archer corpse 3 was cpu %d gpu %d" % [spell.def.cpu, spell.def.gpu])
	var costs := spell.get_costs()
	if costs.size() != 4 or costs[0].amount != 3 or costs[0].resource_type != 0 or costs[1].amount != 1 or costs[1].resource_type != 4:
		_fail("archer cost was not 3 corpse + 1 gore plus bone and weapon")
	if costs[2].resource_type != 1 or costs[2].amount != 1 or costs[3].resource_type != 2 or costs[3].amount != 1:
		_fail("archer extras were not 1 bone + 1 weapon")
	var summoner: Script = load("res://systems/game/summoner.gd")
	var host := Node2D.new()
	root.add_child(host)
	var unit: Unit2D = summoner.summon(spell, host, Vector2.ZERO)
	await process_frame
	if unit == null:
		_fail("archer summon did not spawn")
		host.queue_free()
		return
	var member: ArmyMember = game.get("army")[0]
	if member.def == spell.def or member.def.cpu != 4 or member.def.race != Unit2D.Race.SKELETON_RANGED:
		_fail("army snapshot did not keep the summon spec")
	spell.set_corpse_amount(1)
	if spell.def.cpu != 2 or member.def.cpu != 4 or unit.def.cpu != 4:
		_fail("editing the spec changed the summoned body")
	if int(game.get("corpse")) != 1 or int(game.get("gore")) != 4 or int(game.get("bone")) != 0 or int(game.get("weapon")) != 0:
		_fail("archer summon spent corpse %s gore %s bone %s weapon %s" % [game.get("corpse"), game.get("gore"), game.get("bone"), game.get("weapon")])
	host.queue_free()
	game.get("army").clear()


func _test_save_load() -> void:
	var game := root.get_node(^"Game")
	var spell: SummonSpell = game.get("spells")[0]
	var program := spell.get_program()
	var function := spell.get_update_function()
	var attack := load("res://data/blocks/attack_target.tres") as CodeBlock
	var before := function.lines.size()
	ScriptEditing.insert_line(function.lines, function.lines.size(), 0, attack)
	if spell.set_race(Unit2D.Race.SKELETON_RANGED) != SummonSpell.RaceChange.APPLIED:
		_fail("save setup could not select the archer")
	spell.set_corpse_amount(4)
	spell.set_gore_amount(2)
	var captured: Dictionary = game.call(&"capture_progress")
	var encoded: Dictionary = JSON.parse_string(JSON.stringify(captured))
	spell.set_corpse_amount(1)
	game.call(&"apply_saved_progress", {"army": []})
	var unlocked: Array = game.get("unlocked_races")
	if unlocked.size() != 1 or int(unlocked[0]) != int(Unit2D.Race.ZOMBIE):
		_fail("old save unlocked %s" % unlocked)
	if spell.race != Unit2D.Race.ZOMBIE or spell.corpse_amount != 1 or spell.gore_amount != 1:
		_fail("old save kept a spec")
	if spell.get_program() != program or function.lines.size() != before + 1:
		_fail("old save replaced the program")
	game.call(&"apply_saved_progress", encoded)
	if not bool(game.call(&"is_race_unlocked", Unit2D.Race.SKELETON_RANGED)):
		_fail("loaded save lost the archer unlock")
	if spell.race != Unit2D.Race.SKELETON_RANGED or spell.corpse_amount != 4 or spell.gore_amount != 2:
		_fail("loaded save lost the spell spec")
	if spell.get_program() != program or function.lines.size() != before + 1:
		_fail("loaded save replaced the program")
	if spell.def.cpu != Formular.spec_cpu(2, 4) or spell.def.gpu != Formular.spec_gpu(1, 2):
		_fail("loaded spec did not rebuild cpu and gpu")
	ScriptEditing.remove_line(function.lines, function.lines.size() - 1)
	spell.set_race(Unit2D.Race.ZOMBIE)
	spell.set_corpse_amount(1)
	spell.set_gore_amount(1)


func _test_editor_pages() -> void:
	var host := (load("res://systems/code_editor/editor_standalone.tscn") as PackedScene).instantiate()
	root.add_child(host)
	var editor := host.get_node(^"Editor")
	for _frame in 8:
		await process_frame
	await _exercise_pages(editor, "standalone")
	var book := editor.get_node(^"BookScreen") as Sprite2D
	var book_rect := _sprite_world_rect(book)
	var spec_button := editor.get_node(^"%SpecPageButton") as Button
	var script_button := editor.get_node(^"%ScriptPageButton") as Button
	var script := editor.get_node(^"%ScriptView") as Control
	if spec_button.get_global_rect().position.y >= script_button.get_global_rect().position.y:
		_fail("page buttons are not stacked")
	var center := spec_button.get_global_rect().get_center()
	if not book_rect.grow(8.0).has_point(center):
		_fail("page buttons are not on the book: %s book %s" % [center, book_rect])
	if center.x < script.get_global_rect().end.x - 8.0:
		_fail("page buttons are not on the right edge")
	var icon := editor.get_node(^"%SpellButton1/RaceIcon") as TextureRect
	if icon == null or icon.texture == null:
		_fail("spell slot has no race icon")
	host.queue_free()


func _test_map_and_battle() -> void:
	var game := root.get_node(^"Game")
	var world := (load("res://systems/world_map/world_map.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(world)
	for _frame in 8:
		await process_frame
	world.call(&"set_state", _map_state(world, "CAMP"))
	await process_frame
	world.call(&"set_state", _map_state(world, "CODE"))
	for _frame in 6:
		await process_frame
	var editor := world.get_node(^"CodeLayer/Editor")
	if not bool(editor.call(&"is_open")):
		_fail("camp code state did not open the editor")
	else:
		await _exercise_pages(editor, "camp")
	game.set("world_map", null)
	game.set("current_stage", null)
	world.queue_free()
	await process_frame
	var battle := (load("res://systems/battle/battle.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(battle)
	for _frame in 6:
		await process_frame
	battle.call(&"set_state", 1)
	for _frame in 6:
		await process_frame
	var battle_editor := battle.get_node(^"CodeLayer/Editor")
	if not bool(battle_editor.call(&"is_open")):
		_fail("battle book did not open")
	else:
		await _exercise_pages(battle_editor, "battle")
	battle.queue_free()


func _exercise_pages(editor: Node, where: String) -> void:
	for _frame in 4:
		await process_frame
	var palette := editor.get_node(^"%BlockPalette") as Control
	var script := editor.get_node(^"%ScriptView") as Control
	var spec := editor.get_node(^"%SpecView") as Control
	var hint := editor.get_node(^"%RamHint") as Label
	var spec_button := editor.get_node(^"%SpecPageButton") as Button
	var script_button := editor.get_node(^"%ScriptPageButton") as Button
	if not palette.visible or not script.visible or spec.visible or not hint.visible:
		_fail("%s editor did not open on the script page" % where)
	if not script_button.button_pressed or spec_button.button_pressed:
		_fail("%s script page button was not pressed" % where)
	editor.call(&"_on_page_button", 0)
	for _frame in 3:
		await process_frame
	if palette.visible or script.visible or not spec.visible or hint.visible:
		_fail("%s spec page did not swap the book" % where)
	if int(spec.call(&"race_card_count")) != 4:
		_fail("%s spec page listed %d races" % [where, int(spec.call(&"race_card_count"))])
	var explain := spec.find_child("ExplainLabel", true, false) as Label
	if explain == null or not explain.text.contains("CPU") or not explain.text.contains("GPU") or not explain.text.contains("RAM"):
		_fail("%s spec page has no body/brain line" % where)
	var name_label := editor.get_node(^"%NameLabel") as Label
	var slot: SummonSpell = editor.call(&"_current_slot")
	if slot == null or name_label.text != slot.display_name():
		_fail("%s header was not the race name" % where)
	editor.call(&"_on_slot_button", 2)
	for _frame in 2:
		await process_frame
	if not spec.visible or palette.visible:
		_fail("%s left the spec page when the spell changed" % where)
	editor.call(&"_on_page_button", 1)
	for _frame in 2:
		await process_frame
	if not palette.visible or not script.visible or spec.visible or not hint.visible:
		_fail("%s did not return to the script page" % where)


func _new_spell() -> SummonSpell:
	var spell := SummonSpell.new()
	var def := UnitDef.new()
	def.team = Unit2D.Team.MINION
	def.starting_program = SummonSpell.blank_program()
	spell.def = def
	spell.base_ram = 8
	spell.build_def()
	return spell


func _map_state(world: Node, state_name: String) -> int:
	var states: Dictionary = world.get_script().get_script_constant_map()["State"]
	return int(states[state_name])


func _sprite_world_rect(sprite: Sprite2D) -> Rect2:
	var tex_size := Vector2(1920, 1080)
	if sprite.texture:
		tex_size = sprite.texture.get_size()
	var xform := sprite.get_global_transform()
	var shown := tex_size * xform.get_scale()
	return Rect2(xform.origin - shown * 0.5, shown)


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
