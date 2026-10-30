extends SceneTree


var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_filenames()
	_test_aliases()
	_test_missing()
	_test_throttle()
	_test_battle_cues()
	if _failed == 0:
		print("sfx checks passed")
	else:
		print("%d sfx checks failed" % _failed)
	quit(1 if _failed else 0)


func _test_filenames() -> void:
	if SfxLibrary.parse_cue_id("sfx_zombie_spawn.ogg") != "zombie.spawn":
		_fail("zombie spawn parsed as %s" % SfxLibrary.parse_cue_id("sfx_zombie_spawn.ogg"))
	if SfxLibrary.parse_cue_id("sfx_skeleton_spawn_02.ogg") != "skeleton.spawn":
		_fail("skeleton spawn parsed as %s" % SfxLibrary.parse_cue_id("sfx_skeleton_spawn_02.ogg"))
	if SfxLibrary.parse_cue_id("sfx_necromancer_laugh_soft_01.ogg") != "necromancer.laugh_soft":
		_fail("laugh parsed as %s" % SfxLibrary.parse_cue_id("sfx_necromancer_laugh_soft_01.ogg"))
	if SfxLibrary.parse_cue_id("res://contents/audio/sfx/general/sfx_general_page_turn_01.ogg") != "general.page_turn":
		_fail("page turn path did not parse")
	var shipped := load(SfxLibrary.PATH) as SfxLibrary
	var spawn := shipped.get_cue("zombie.spawn") if shipped != null else null
	if spawn == null or spawn.streams.size() != 1:
		_fail("shipped library is missing zombie.spawn")


func _test_aliases() -> void:
	var expected := {
		Unit2D.Race.ZOMBIE: "zombie",
		Unit2D.Race.SKELETON_MELEE: "skeleton",
		Unit2D.Race.SKELETON_RANGED: "skeleton",
		Unit2D.Race.DIRE_WOLF: "dog",
		Unit2D.Race.WARDOG: "dog",
		Unit2D.Race.VILLAGER_MELEE: "villager",
		Unit2D.Race.VILLAGER_RANGED: "villager",
	}
	if expected.size() != Unit2D.Race.size():
		_fail("alias table covers %d races, enum has %d" % [expected.size(), Unit2D.Race.size()])
	for race_name in Unit2D.Race.keys():
		var race: Unit2D.Race = Unit2D.Race[race_name]
		var folder := Sfx.folder_for_race(race)
		if folder != String(expected[race]):
			_fail("race %s maps to '%s'" % [race_name, folder])
	if Sfx.folder_for_race(99) != "":
		_fail("unknown race mapped to a folder")


func _test_missing() -> void:
	Sfx.use_library(SfxLibrary.new())
	if Sfx.play("missing.cue") != null:
		_fail("unknown cue returned a voice")
	var unit := Unit2D.new()
	unit.race = 99
	if Sfx.play_unit(unit, &"attack") != null:
		_fail("unknown race returned a voice")
	unit.race = Unit2D.Race.ZOMBIE
	if Sfx.play_unit(unit, &"not_an_action") != null:
		_fail("missing action returned a voice")
	unit.free()


func _test_throttle() -> void:
	var tone := _tone()
	var blocked := _cue("test.block", tone, 1, 0.0)
	var spaced := _cue("test.space", tone, 4, 10.0)
	var library := SfxLibrary.new()
	library.cues.append(blocked)
	library.cues.append(spaced)
	Sfx.use_library(library)
	var first_block := Sfx.play("test.block")
	var second_block := Sfx.play("test.block")
	if first_block == null:
		_fail("first SFX play returned null")
	if Sfx.active_voices("test.block") != 1 or second_block != null:
		_fail("max_concurrent allowed %d voices" % Sfx.active_voices("test.block"))
	Sfx.play("test.space")
	var second_space := Sfx.play("test.space")
	if Sfx.active_voices("test.space") != 1 or second_space != null:
		_fail("min_interval allowed %d voices" % Sfx.active_voices("test.space"))


func _tone() -> AudioStream:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	wav.data = PackedByteArray()
	wav.data.resize(22050)
	return wav


func _cue(id: String, stream: AudioStream, concurrent: int, interval: float) -> SfxCue:
	var cue := SfxCue.new()
	cue.id = id
	cue.streams = [stream]
	cue.max_concurrent = concurrent
	cue.min_interval = interval
	return cue


func _test_battle_cues() -> void:
	var shipped := load(SfxLibrary.PATH) as SfxLibrary
	Sfx.use_library(shipped)
	var skeleton := Unit2D.new()
	skeleton.race = Unit2D.Race.SKELETON_MELEE
	if Sfx.play_unit(skeleton, &"attack") == null:
		_fail("skeleton attack was silent")
	if Sfx.play_unit(skeleton, &"dead") != null:
		_fail("missing skeleton.dead should stay silent")
	var wolf := Unit2D.new()
	wolf.race = Unit2D.Race.DIRE_WOLF
	if Sfx.play_unit(wolf, &"spawn") != null:
		_fail("missing dog.spawn should stay silent")
	if Sfx.play_unit(wolf, &"hurt") == null:
		_fail("dog hurt was silent")
	var villager := Unit2D.new()
	villager.race = Unit2D.Race.VILLAGER_RANGED
	if Sfx.play_unit(villager, &"hurt") != null:
		_fail("missing villager.hurt should stay silent")
	if Sfx.play_unit(villager, &"attack") == null:
		_fail("villager attack was silent")
	skeleton.free()
	wolf.free()
	villager.free()


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
