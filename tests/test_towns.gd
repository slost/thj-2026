extends SceneTree


var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("en")
	_test_town_art()
	_test_race_scenes()
	_test_garrison_names()
	_test_town_resources()
	await _test_capital_lock_and_art()
	_test_capital_victory()
	await _test_old_save()
	if _failed == 0:
		print("town checks passed")
	else:
		print("%d town checks failed" % _failed)
	quit(1 if _failed else 0)


func _test_town_art() -> void:
	var town = _bare_town(2, 100.0)
	if town == null:
		return
	var sprite := town.get_node("Visual/HotSwapSprite") as Sprite2D
	if town.get_node_or_null("Visual/PlaceholderSprite") != null:
		_fail("placeholder sprite is still in the town scene")
	if sprite == null or sprite.texture != load("res://contents/assets/tex_village_2.png"):
		_fail("healthy town did not use village 2")
	town.restore_points = 20.0
	town.refresh_visual()
	if sprite.texture != load("res://contents/assets/tex_village_destroyed_2.png"):
		_fail("town under the ruined ratio kept its whole art")
	town.restore_points = 100.0
	town.has_been_destroyed = false
	town.refresh_visual()
	if sprite.texture != load("res://contents/assets/tex_village_2.png"):
		_fail("refilled town stayed ruined")
	town.has_been_destroyed = true
	town.refresh_visual()
	if not town.shows_ruined() or sprite.texture != load("res://contents/assets/tex_village_destroyed_2.png"):
		_fail("fallen town did not use destroyed art")
	var blocker := Area2D.new()
	root.add_child(blocker)
	var gates: Array[Area2D] = [blocker]
	town.required_locations = gates
	town.refresh_visual()
	if town.modulate != UiPalette.dim(Color.WHITE):
		_fail("locked town was not dimmed with the flat palette")
	if town.modulate == Color.LIGHT_GRAY or town.modulate == Color.RED:
		_fail("locked town still uses the old tint")
	town.queue_free()
	blocker.queue_free()


func _test_race_scenes() -> void:
	for race_name in Unit2D.Race.keys():
		var race: Unit2D.Race = Unit2D.Race[race_name]
		var path := Unit2D.scene_path_for_race(race)
		var scene := load(path) as PackedScene
		if scene == null:
			_fail("race %s has no animation scene" % race_name)
			continue
		var body := scene.instantiate()
		if body == null or body.get_node_or_null("AnimationPlayer") == null:
			_fail("race %s scene has no AnimationPlayer" % race_name)
		if body:
			body.free()


func _test_garrison_names() -> void:
	var csv := FileAccess.get_file_as_string("res://contents/translations/ui.csv")
	var races: Array[Unit2D.Race] = [
		Unit2D.Race.VILLAGER_MELEE,
		Unit2D.Race.VILLAGER_RANGED,
		Unit2D.Race.WARDOG,
		Unit2D.Race.HERO_MELEE,
		Unit2D.Race.HERO_RANGED,
	]
	for race in races:
		var row := TownGarrison.new()
		row.race = race
		var key := row.unit_name_key()
		if key.is_empty() or not csv.contains(key + ","):
			_fail("garrison race %s is missing a name key" % Unit2D.Race.keys()[race])
		if row.inspector_line().is_empty():
			_fail("garrison race %s has an empty line" % Unit2D.Race.keys()[race])


func _test_town_resources() -> void:
	var dir := DirAccess.open("res://data/towns")
	if dir == null:
		_fail("data/towns did not open")
		return
	var files: PackedStringArray = []
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if not dir.current_is_dir() and entry_name.ends_with(".tres"):
			files.append(entry_name)
		entry_name = dir.get_next()
	if files.size() < 9:
		_fail("expected at least 9 town files, got %d" % files.size())
	for town_file in files:
		var def := load("res://data/towns/%s" % town_file) as TownDef
		if def == null:
			_fail("%s did not load as a TownDef" % town_file)
			continue
		if def.garrison.is_empty() or def.unit_count() < 1:
			_fail("%s has no garrison" % town_file)


func _test_capital_lock_and_art() -> void:
	var game := root.get_node(^"Game")
	game.set("save_slot", 7)
	game.set("ending_after_map", false)
	game.set("play_ending_on_title", false)
	game.set("raid_outcome_pending", false)
	game.set("debug_unlock_capital", false)
	_saves().call("delete_slot", 7)
	var world := (load("res://systems/world_map/world_map.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var capital: TownLocation = null
	var others: Array[TownLocation] = []
	for town in world._towns():
		if town.def != null and town.def.is_capital:
			capital = town
		else:
			others.append(town)
	if capital == null or others.size() != 8:
		_fail("map should have 8 towns and 1 capital, got %d others" % others.size())
		world.queue_free()
		return
	if not capital.is_locked():
		_fail("capital started unlocked")
	var info := world.get_node(^"UI/TownInfo")
	info.call("show_town", capital)
	var body := str(info.get_node(^"VBoxContainer/BodyLabel").text)
	if not body.contains("Capital") or not body.contains("Destroy every other town."):
		_fail("capital panel did not explain the lock: %s" % body)
	var sprite := capital.get_node("Visual/HotSwapSprite") as Sprite2D
	if sprite == null or sprite.texture != load("res://contents/assets/tex_capital.png"):
		_fail("capital did not use the capital art")
	for town in others:
		if String(town.def.id) == "small_village" and town.is_locked():
			_fail("the first town started locked")
		town.has_been_destroyed = true
	capital.refresh_visual()
	if capital.is_locked():
		_fail("capital stayed locked after every other town fell")
	others[0].has_been_destroyed = false
	if not capital.is_locked():
		_fail("capital unlocked while a town still stands")
	others[0].has_been_destroyed = true
	capital.has_been_destroyed = true
	capital.refresh_visual()
	if sprite.texture != load("res://contents/assets/tex_capital_destroyed.png"):
		_fail("fallen capital did not use the ruined capital art")
	world.queue_free()
	await process_frame


func _test_capital_victory() -> void:
	var game := root.get_node(^"Game")
	game.set("game_won", false)
	game.set("ending_after_map", false)
	game.set("play_ending_on_title", false)
	game.set("raid_target_is_capital", true)
	game.set("raid_target_destroyed", false)
	game.set("raid_outcome_pending", true)
	game.set("raid_target_points", 100.0)
	game.set("raid_target_max_points", 100.0)
	game.set("pending_raid_damage", 20.0)
	if bool(game.call("capital_falls_from_pending")):
		_fail("a shallow raid was treated as the fall of the capital")
	game.set("raid_target_points", 60.0)
	game.set("pending_raid_damage", 20.0)
	if not bool(game.call("capital_falls_from_pending")):
		_fail("a killing raid did not count as the fall of the capital")
	if not bool(game.call("prepare_battle_exit")) or not bool(game.get("ending_after_map")):
		_fail("the battle exit did not arm the ending")
	var town := (load("res://systems/world_map/town_location.tscn") as PackedScene).instantiate()
	var def := load("res://data/towns/capital.tres") as TownDef
	town.def = def
	root.add_child(town)
	town.restore_points = 40.0
	town.sync_destroyed_state()
	game.set("raid_target_destroyed", false)
	game.call("mark_capital_fallen", town)
	if not bool(game.get("game_won")):
		_fail("destroying the capital did not set game_won")
	if not bool(game.call("take_victory_exit")) or not bool(game.get("play_ending_on_title")):
		_fail("the victory exit did not route to the ending")
	if bool(game.call("consume_play_ending")) != true:
		_fail("the title did not consume the ending request")
	if bool(game.get("play_ending_on_title")):
		_fail("the ending request played twice")
	town.queue_free()
	game.set("game_won", false)
	game.set("ending_after_map", false)
	game.set("raid_outcome_pending", false)
	game.set("raid_target_is_capital", false)


func _test_old_save() -> void:
	var game := root.get_node(^"Game")
	game.set("save_slot", 7)
	game.set("ending_after_map", false)
	game.set("raid_outcome_pending", false)
	game.set("pending_raid_damage", 0.0)
	_saves().call("delete_slot", 7)
	var payload := {
		"meta": {"tutorial_done": true},
		"data": {
			"small_village": {"restore_points": 70.0, "has_been_destroyed": true},
			"small_village_b": {"restore_points": 80.0, "has_been_destroyed": false},
			"small_village_c": {"restore_points": 100.0, "has_been_destroyed": true},
			"TownLocation7": {"restore_points": 7.0, "has_been_destroyed": false},
		},
		"runtime_instances": [],
	}
	var path := "user://saves/slot_7.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("could not write the old save")
		return
	file.store_string(JSON.stringify(payload))
	file.close()
	var world := (load("res://systems/world_map/world_map.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	if not bool(_saves().call("load_slot", 7)):
		_fail("old save did not load")
		world.queue_free()
		return
	var by_id := {}
	for town in world._towns():
		if town.def != null:
			by_id[String(town.def.id)] = town
	for key in ["small_village", "small_village_b", "small_village_c"]:
		if not by_id.has(key):
			_fail("original town %s is missing" % key)
	var easy: TownLocation = by_id.get("small_village")
	var cross: TownLocation = by_id.get("small_village_b")
	var palisade: TownLocation = by_id.get("small_village_c")
	if easy == null or not easy.has_been_destroyed or not is_equal_approx(easy.restore_points, 70.0):
		_fail("small_village did not keep its old save")
	if cross == null or cross.has_been_destroyed or not is_equal_approx(cross.restore_points, 80.0):
		_fail("small_village_b did not keep its old save")
	if palisade == null or not palisade.has_been_destroyed or not is_equal_approx(palisade.restore_points, 100.0):
		_fail("small_village_c did not keep its old save")
	var fresh: TownLocation = by_id.get("orchard_hamlet")
	if fresh == null or fresh.has_been_destroyed:
		_fail("a new town was marked destroyed by the old save")
	elif fresh.def != null and not is_equal_approx(fresh.restore_points, fresh.def.max_restore_points):
		_fail("a new town did not start at full points")
	world.queue_free()
	_saves().call("delete_slot", 7)


func _saves() -> Node:
	return root.get_node(^"SaveManager")


func _bare_town(variant: int, maximum: float):
	var town := (load("res://systems/world_map/town_location.tscn") as PackedScene).instantiate()
	if town == null:
		_fail("town scene did not instantiate")
		return null
	var def := TownDef.new()
	def.id = &"art_town"
	def.name = "Art Town"
	def.max_restore_points = maximum
	def.art_variant = variant
	town.def = def
	root.add_child(town)
	return town


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
