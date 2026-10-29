extends SceneTree

var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_raid_damage_formula()
	_test_town_recover_amount()
	await _test_other_towns_recover()
	await _test_retreat_after_half()
	await _test_walk_directions()
	await _test_spawn_preview_does_not_edit_shared_clip()
	await _test_scenes_open()
	if _failed == 0:
		print("game loop checks passed")
	else:
		print("%d game loop checks failed" % _failed)
	quit(1 if _failed else 0)


func _test_raid_damage_formula() -> void:
	if not is_equal_approx(Formular.raid_damage(100.0, 0.0), 0.0):
		_fail("lost ratio 0 dealt %s" % Formular.raid_damage(100.0, 0.0))
	if not is_equal_approx(Formular.raid_damage(100.0, 0.5), 15.0):
		_fail("lost ratio 0.5 dealt %s" % Formular.raid_damage(100.0, 0.5))
	if not is_equal_approx(Formular.raid_damage(100.0, 1.0), 30.0):
		_fail("lost ratio 1 dealt %s" % Formular.raid_damage(100.0, 1.0))
	if not is_equal_approx(Formular.raid_stake_ratio(), 0.3):
		_fail("stake ratio is %s" % Formular.raid_stake_ratio())


func _test_town_recover_amount() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for _i in 40:
		var amount := Formular.town_recover_amount(100.0, rng)
		if amount < 10.0 - 0.001 or amount > 15.0 + 0.001:
			_fail("recover amount %s is outside 10-15%%" % amount)
			return
	if not is_equal_approx(Formular.town_recover_min_ratio(), 0.10):
		_fail("recover min ratio changed")
	if not is_equal_approx(Formular.town_recover_max_ratio(), 0.15):
		_fail("recover max ratio changed")


func _test_other_towns_recover() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var raided = await _make_town(40.0, 100.0)
	var healthy = await _make_town(50.0, 100.0)
	var clamped = await _make_town(95.0, 100.0)
	var destroyed = await _make_town(20.0, 100.0)
	destroyed.has_been_destroyed = true
	var locked = await _make_town(30.0, 100.0)
	if raided == null or healthy == null or clamped == null or destroyed == null or locked == null:
		return
	var blocker := Area2D.new()
	root.add_child(blocker)
	var gates: Array[Area2D] = [blocker]
	locked.required_locations = gates
	if not locked.is_locked():
		_fail("locked town was treated as open")
	var towns: Array = [raided, healthy, clamped, destroyed, locked]
	var map_script = load("res://systems/world_map/world_map.gd")
	map_script.recover_towns(towns, raided, rng)
	if not is_equal_approx(raided.restore_points, 40.0):
		_fail("raided town changed to %s" % raided.restore_points)
	if not is_equal_approx(destroyed.restore_points, 20.0):
		_fail("destroyed town changed to %s" % destroyed.restore_points)
	if not is_equal_approx(locked.restore_points, 30.0):
		_fail("locked town changed to %s" % locked.restore_points)
	var healed = healthy.restore_points - 50.0
	if healed < 10.0 - 0.001 or healed > 15.0 + 0.001:
		_fail("healthy town healed by %s" % healed)
	if healthy.restore_points > 100.0:
		_fail("healthy town passed its max")
	if not is_equal_approx(clamped.restore_points, 100.0):
		_fail("town near max clamped to %s" % clamped.restore_points)
	for town in towns:
		town.queue_free()
	blocker.queue_free()


func _test_retreat_after_half() -> void:
	var game := root.get_node(^"Game")
	game.set("raid_target_id", "small_village")
	game.set("raid_target_max_points", 100.0)
	game.set("raid_outcome_pending", true)
	game.set("pending_raid_damage", 0.0)
	var battle := (load("res://systems/battle/battle.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(battle)
	await process_frame
	var first := _villager(battle, Vector2i(-8, 0))
	var second := _villager(battle, Vector2i(-8, 2))
	await process_frame
	first.die()
	await process_frame
	battle.call("commit_raid_outcome")
	var damage := float(game.get("pending_raid_damage"))
	if not is_equal_approx(damage, 15.0):
		_fail("retreat after half stored %s" % damage)
	game.set("pending_raid_damage", 0.0)
	game.set("raid_outcome_pending", false)
	game.set("raid_target_id", "")
	game.set("raid_target_max_points", 0.0)
	game.set("current_stage", null)
	battle.queue_free()
	await process_frame


func _test_walk_directions() -> void:
	var battle := (load("res://systems/battle/battle.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(battle)
	for _frame in 3:
		await process_frame
	var nav := battle.get_node(^"GridNav") as GridNav
	var specs := [
		{"path": "res://data/blocks/walk_left.tres", "from": Vector2i(-8, 0), "to": Vector2i(-9, 0)},
		{"path": "res://data/blocks/walk_right.tres", "from": Vector2i(-8, 2), "to": Vector2i(-7, 2)},
		{"path": "res://data/blocks/walk_up.tres", "from": Vector2i(-5, 0), "to": Vector2i(-5, -1)},
		{"path": "res://data/blocks/walk_down.tres", "from": Vector2i(-5, 2), "to": Vector2i(-5, 3)},
	]
	var jobs: Array[Dictionary] = []
	for spec in specs:
		var unit := _walker(battle, nav, spec["from"])
		var block := (load(spec["path"]) as WalkDirection).duplicate() as WalkDirection
		if block == null or block.mb_cost != 1:
			_fail("walk block missing %s" % spec["path"])
			continue
		var title := block.get_display_name()
		if title.is_empty():
			_fail("walk block has no name %s" % spec["path"])
		jobs.append({"unit": unit, "block": block, "to": spec["to"], "result": -1})
	for _frame in 2:
		await process_frame
	for job in jobs:
		var unit: Unit2D = job["unit"]
		unit.set_state(Unit2D.State.IDLE)
	var frames := 0
	while frames < 240:
		var running := false
		for job in jobs:
			if int(job["result"]) != -1:
				continue
			var result := _step_walk(job["unit"], job["block"])
			if result == ActionBlock.StepResult.RUNNING:
				running = true
			else:
				job["result"] = result
		if not running:
			break
		await process_frame
		frames += 1
	for job in jobs:
		var unit: Unit2D = job["unit"]
		var goal: Vector2i = job["to"]
		if int(job["result"]) != ActionBlock.StepResult.DONE:
			_fail("walk to %s ended %s at %s" % [goal, job["result"], nav.world_to_cell(unit.global_position)])
		elif nav.world_to_cell(unit.global_position) != goal:
			_fail("walk landed on %s, wanted %s" % [nav.world_to_cell(unit.global_position), goal])
	var blocked := _walker(battle, nav, Vector2i(-12, 0))
	await process_frame
	blocked.set_state(Unit2D.State.IDLE)
	var left := (load("res://data/blocks/walk_left.tres") as WalkDirection).duplicate() as WalkDirection
	var blocked_result := _step_walk(blocked, left)
	if blocked_result != ActionBlock.StepResult.CANCELLED:
		_fail("blocked step was %s" % blocked_result)
	var spawning := _walker(battle, nav, Vector2i(-10, 0))
	await process_frame
	spawning.set_state(Unit2D.State.SPAWNING)
	var spawn_result := _step_walk(spawning, left.duplicate() as WalkDirection)
	if spawn_result != ActionBlock.StepResult.CANCELLED:
		_fail("spawning step was %s" % spawn_result)
	var inventory := BlockInventory.new()
	inventory.seed_if_empty()
	for path in ["walk_left", "walk_right", "walk_up", "walk_down"]:
		var block := load("res://data/blocks/%s.tres" % path) as CodeBlock
		if inventory.get_count(block) != BlockInventory.SEED_COUNT:
			_fail("%s was not seeded" % path)
		TranslationServer.set_locale("th")
		if LocaleText.translate("code.%s.name" % path, "th").is_empty():
			_fail("missing thai name %s" % path)
		if LocaleText.translate("code.%s.desc" % path, "th").is_empty():
			_fail("missing thai desc %s" % path)
		TranslationServer.set_locale("en")
		if block.get_display_name() != block.name:
			_fail("english name for %s was %s" % [path, block.get_display_name()])
	var game := root.get_node(^"Game")
	game.set("current_stage", null)
	battle.queue_free()
	await process_frame


func _test_spawn_preview_does_not_edit_shared_clip() -> void:
	var visual := (load("res://contents/animations/zombie.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(visual)
	var player := visual.get_node(^"AnimationPlayer") as AnimationPlayer
	var source := player.get_animation(&"spawn")
	var before := source.loop_mode
	var clip := source.duplicate(true) as Animation
	clip.loop_mode = Animation.LOOP_LINEAR
	if player.get_animation(&"spawn").loop_mode != before:
		_fail("duplicating spawn changed the shared clip")
	if clip.loop_mode != Animation.LOOP_LINEAR:
		_fail("spawn copy did not loop")
	visual.queue_free()


func _test_scenes_open() -> void:
	var game := root.get_node(^"Game")
	game.set("raid_outcome_pending", false)
	game.set("pending_raid_damage", 0.0)
	var rooms := (load("res://systems/debug/debug_rooms.tscn") as PackedScene).instantiate()
	root.add_child(rooms)
	for _frame in 3:
		await process_frame
	rooms.queue_free()
	await process_frame
	var world := (load("res://systems/world_map/world_map.tscn") as PackedScene).instantiate()
	if world == null:
		_fail("world map scene did not instantiate")
		return
	root.add_child(world)
	for _frame in 5:
		await process_frame
	var map_script = load("res://systems/world_map/world_map.gd")
	if world._towns().is_empty():
		_fail("world map did not find its towns")
	world.set_state(map_script.State.CAMP)
	for _frame in 3:
		await process_frame
	world.set_state(map_script.State.CODE)
	for _frame in 5:
		await process_frame
	var editor := world.get_node(^"CodeLayer/Editor")
	if not world.is_coding() or not bool(editor.call("is_open")):
		_fail("map book did not open")
	if world.book == null or not world.book.visible:
		_fail("map book sprite stayed hidden")
	world.set_state(map_script.State.MAP)
	for _frame in 2:
		await process_frame
	if bool(editor.call("is_open")):
		_fail("map book stayed open")
	world.queue_free()
	game.set("world_map", null)
	game.set("current_stage", null)
	await process_frame
	var battle := (load("res://systems/battle/battle.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(battle)
	for _frame in 5:
		await process_frame
	var area: Rect2i = battle.get("summon_area")
	if not area.has_point(Vector2i(-11, -7)) or not area.has_point(Vector2i(-4, 7)):
		_fail("summon area %s missed the left edge" % area)
	if area.has_point(Vector2i(-12, 0)) or area.has_point(Vector2i(-3, 0)):
		_fail("summon area %s is wider than x -11..-4" % area)
	if battle.get_node_or_null(^"CanvasLayer/StateContainer/FieldButton") == null:
		_fail("battle is missing the field button")
	if battle.get_node_or_null(^"CanvasLayer/StateContainer/CodeButton") == null:
		_fail("battle is missing the code button")
	var map_button := battle.get_node_or_null(^"CanvasLayer/StateContainer/MapButton")
	if map_button != null:
		_fail("battle has a map button")
	battle.set_state(1)
	for _frame in 5:
		await process_frame
	var battle_editor := battle.get_node(^"CodeLayer/Editor")
	if not bool(battle.call("is_coding")) or not bool(battle_editor.call("is_open")):
		_fail("battle book did not open")
	var battle_book := battle.get_node(^"BookBackground") as CanvasItem
	if battle_book == null or not battle_book.visible:
		_fail("battle book sprite stayed hidden")
	var battle_screen := battle.get_node(^"BookBackground/BookScreen")
	if battle_editor.get("book") != battle_screen:
		_fail("battle editor is not laid out on the battle book")
	battle.call("set_state", 0)
	for _frame in 2:
		await process_frame
	if bool(battle_editor.call("is_open")):
		_fail("battle book stayed open after returning to the field")
	game.set("current_stage", null)
	battle.queue_free()


func _make_town(points: float, maximum: float):
	var town := (load("res://systems/world_map/town_location.tscn") as PackedScene).instantiate()
	if town == null:
		_fail("town scene did not instantiate")
		return null
	var def := TownDef.new()
	def.id = &"test_town"
	def.name = "Test Town"
	def.max_restore_points = maximum
	town.def = def
	root.add_child(town)
	await process_frame
	town.restore_points = points
	town.has_been_destroyed = false
	return town


func _villager(battle: Node, cell: Vector2i) -> Unit2D:
	var nav := battle.get_node(^"GridNav") as GridNav
	var def := UnitDef.new()
	def.team = Unit2D.Team.VILLAGER
	def.max_hp = 10
	def.race = Unit2D.Race.ZOMBIE
	def.starting_program = SummonSpell.blank_program()
	var unit := (load("res://systems/units/unit.tscn") as PackedScene).instantiate() as Unit2D
	unit.def = def
	battle.add_child(unit)
	unit.global_position = nav.cell_to_world(cell)
	return unit


func _walker(battle: Node, nav: GridNav, cell: Vector2i) -> Unit2D:
	var def := UnitDef.new()
	def.team = Unit2D.Team.MINION
	def.race = Unit2D.Race.ZOMBIE
	def.gpu = 16
	def.cpu = 8
	def.starting_program = SummonSpell.blank_program()
	var unit := (load("res://systems/units/unit.tscn") as PackedScene).instantiate() as Unit2D
	unit.def = def
	battle.add_child(unit)
	unit.global_position = nav.cell_to_world(cell)
	return unit


func _step_walk(unit: Unit2D, block: WalkDirection) -> int:
	var ctx := ExecContext.new(unit, EventGraph.Event.ON_UPDATE, null)
	return block.step(unit, ctx)


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
