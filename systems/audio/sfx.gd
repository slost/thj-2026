## Thin cue player. Buses, pools, and pitch variation stay in the Audio autoload.
## Edit [constant RACE_FOLDER] and [constant RACE_WEAPON] when a race or weapon is added.
extends RefCounted
class_name Sfx


const LIBRARY_PATH := "res://data/audio/sfx_library.tres"
## Preload so the web exporter packs the library and every ogg it references.
const _PACKED_LIBRARY: SfxLibrary = preload("res://data/audio/sfx_library.tres")
const OFFSCREEN_VOLUME := 0.5
const IDLE_CHANCE := 0.22
const IDLE_GAP_MIN := 2.0
const IDLE_GAP_MAX := 4.0
const LAUGH_CUE := "necromancer.laugh_soft"
const LAUGH_SUMMON_CHANCE := 0.2
const LAUGH_COOLDOWN := 8.0

const _FORK_TEXTURE := preload("res://contents/assets/tex_villager_weapons_1.png")
const _SLING_TEXTURE := preload("res://contents/assets/tex_villager_weapons_2.png")

## Race value -> voice folder under contents/audio/sfx.
const RACE_FOLDER := {
	Unit2D.Race.ZOMBIE: "zombie",
	Unit2D.Race.SKELETON_MELEE: "skeleton",
	Unit2D.Race.SKELETON_RANGED: "skeleton",
	Unit2D.Race.DIRE_WOLF: "dog",
	Unit2D.Race.WARDOG: "dog",
	Unit2D.Race.VILLAGER_MELEE: "villager",
	Unit2D.Race.VILLAGER_RANGED: "villager",
}

## Used when the body has no tool sprite yet. Villager tools override this.
const RACE_WEAPON := {
	Unit2D.Race.SKELETON_MELEE: "weapon.sword",
	Unit2D.Race.SKELETON_RANGED: "weapon.bow",
	Unit2D.Race.VILLAGER_MELEE: "weapon.fork",
	Unit2D.Race.VILLAGER_RANGED: "weapon.bow",
}

static var library: SfxLibrary
static var _loaded := false
static var _warned: Dictionary = {}
static var _last_at: Dictionary = {}
static var _until: Dictionary = {}
static var _ui_last: Dictionary = {}
static var _idle_ready_at := 0.0
static var _idle_roll_at: Dictionary = {}
static var _laugh_ready_at := 0.0


static func use_library(next: SfxLibrary) -> void:
	library = next
	_loaded = true
	_last_at.clear()
	_until.clear()


static func folder_for_race(race: Unit2D.Race) -> String:
	if not RACE_FOLDER.has(race):
		return ""
	return String(RACE_FOLDER[race])


## Fork and sling come from the villager Tool sprite. A sling plays weapon.slingshot when that cue exists, otherwise the bow.
static func weapon_cue(unit: Unit2D) -> String:
	if unit == null:
		return ""
	var from_tool := _villager_tool_cue(unit)
	if not from_tool.is_empty():
		return from_tool
	if not RACE_WEAPON.has(unit.race):
		return ""
	return String(RACE_WEAPON[unit.race])


## SFX bus. Missing cues and throttled plays return null.
static func play(cue_id: String, volume_scale: float = 1.0) -> AudioStreamPlayer:
	var cue := _claim(cue_id)
	if cue == null:
		return null
	var audio := _audio()
	if audio == null:
		return null
	return audio.play_sfx_variation(_streams(cue), cue.pitch_range, _volume(cue, volume_scale))


## UI bus, so the book still speaks while the tree is paused.
static func play_ui(cue_id: String) -> AudioStreamPlayer:
	var cue := _claim(cue_id)
	if cue == null:
		return null
	var stream := _pick_ui(cue)
	if stream == null:
		return null
	var audio := _audio()
	if audio == null:
		return null
	var player := audio.play_ui(stream, _volume(cue, 1.0))
	if player != null:
		player.pitch_scale = _pitch(cue.pitch_range)
	return player


## Voice for [param action], plus the weapon layer when the action is an attack.
static func play_unit(unit: Unit2D, action: StringName) -> AudioStreamPlayer:
	if unit == null or not is_instance_valid(unit):
		return null
	if action == &"idle":
		return _play_idle(unit)
	var scale := _audibility(unit, action)
	if scale <= 0.0:
		return null
	var played: AudioStreamPlayer = null
	var folder := folder_for_race(unit.race)
	if not folder.is_empty():
		played = play("%s.%s" % [folder, action], scale)
	if action == &"attack":
		var weapon := weapon_cue(unit)
		if not weapon.is_empty():
			var swing := play(weapon, scale)
			if played == null:
				played = swing
	return played


## Battle win passes [param while_paused] because the result screen pauses the tree and the SFX bus pauses with it.
static func play_laugh(chance: float = 1.0, while_paused: bool = false) -> AudioStreamPlayer:
	_ensure()
	var now := _now()
	if now < _laugh_ready_at:
		return null
	if chance < 1.0 and randf() > chance:
		return null
	var played := play_ui(LAUGH_CUE) if while_paused else play(LAUGH_CUE)
	if played != null:
		_laugh_ready_at = now + LAUGH_COOLDOWN
	return played


static func play_summon_laugh() -> AudioStreamPlayer:
	return play_laugh(LAUGH_SUMMON_CHANCE)


## Voices of [param cue_id] that have not reached their stream length yet.
static func active_voices(cue_id: String) -> int:
	return _live(cue_id, _now()).size()


static func _audio() -> AudioManager:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(^"Audio") as AudioManager


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	library = _PACKED_LIBRARY


static func _play_idle(unit: Unit2D) -> AudioStreamPlayer:
	if unit.state != Unit2D.State.IDLE or not _on_screen(unit):
		return null
	var now := _now()
	if now < _idle_ready_at:
		return null
	var key := unit.get_instance_id()
	var due := float(_idle_roll_at.get(key, 0.0))
	if due <= 0.0:
		_idle_roll_at[key] = now + randf_range(0.4, 1.4)
		return null
	if now < due:
		return null
	_idle_roll_at[key] = now + 1.0
	if randf() > IDLE_CHANCE:
		return null
	var folder := folder_for_race(unit.race)
	if folder.is_empty():
		return null
	var played := play("%s.idle" % folder)
	if played != null:
		_idle_ready_at = now + randf_range(IDLE_GAP_MIN, IDLE_GAP_MAX)
	return played


static func _claim(cue_id: String) -> SfxCue:
	_ensure()
	if library == null or cue_id.is_empty():
		_warn(cue_id if not cue_id.is_empty() else "library")
		return null
	var cue := library.get_cue(cue_id)
	if cue == null or _streams(cue).is_empty():
		_warn(cue_id)
		return null
	var now := _now()
	var live := _live(cue_id, now)
	if cue.min_interval > 0.0 and now - float(_last_at.get(cue_id, -999.0)) < cue.min_interval:
		_until[cue_id] = live
		return null
	if live.size() >= maxi(cue.max_concurrent, 1):
		_until[cue_id] = live
		return null
	var length := 0.4
	if not cue.streams.is_empty() and cue.streams[0] != null:
		length = maxf(cue.streams[0].get_length(), 0.05)
	live.append(now + length)
	_until[cue_id] = live
	_last_at[cue_id] = now
	return cue


static func _live(cue_id: String, now: float) -> Array:
	var kept: Array = []
	var raw: Variant = _until.get(cue_id, [])
	if raw is Array:
		for item in raw:
			if float(item) > now:
				kept.append(float(item))
	return kept


static func _streams(cue: SfxCue) -> Array:
	var batch: Array = []
	for stream in cue.streams:
		if stream != null:
			batch.append(stream)
	return batch


static func _volume(cue: SfxCue, scale: float) -> float:
	return clampf(cue.volume * scale, 0.0, 1.0)


static func _pitch(pitch_range: Vector2) -> float:
	var low := minf(pitch_range.x, pitch_range.y)
	var high := maxf(pitch_range.x, pitch_range.y)
	if is_equal_approx(low, high):
		return maxf(low, 0.01)
	return randf_range(low, high)


static func _pick_ui(cue: SfxCue) -> AudioStream:
	var options := _streams(cue)
	if options.is_empty():
		return null
	if options.size() == 1:
		return options[0]
	var last_id := int(_ui_last.get(cue.id, -1))
	var index := randi() % options.size()
	if options[index].get_instance_id() == last_id:
		index = (index + 1) % options.size()
	var picked: AudioStream = options[index]
	_ui_last[cue.id] = picked.get_instance_id()
	return picked


static func _audibility(unit: Node2D, action: StringName) -> float:
	if _on_screen(unit):
		return 1.0
	if action == &"hurt" or action == &"idle":
		return 0.0
	if action == &"attack" or action == &"dead":
		return OFFSCREEN_VOLUME
	return 1.0


static func _on_screen(unit: Node2D) -> bool:
	if unit == null or not is_instance_valid(unit) or not unit.is_inside_tree():
		return true
	var viewport := unit.get_viewport()
	if viewport == null:
		return true
	var point := unit.get_global_transform_with_canvas().origin
	return viewport.get_visible_rect().has_point(point)


static func _villager_tool_cue(unit: Unit2D) -> String:
	if not Unit2D.is_villager_race(unit.race):
		return ""
	var tool := unit.get_node_or_null(^"Visual/Tool") as Sprite2D
	if tool == null or tool.texture == null:
		return ""
	if tool.texture == _SLING_TEXTURE:
		if library != null:
			var sling := library.get_cue("weapon.slingshot")
			if sling != null and not sling.streams.is_empty():
				return "weapon.slingshot"
		return "weapon.bow"
	if tool.texture == _FORK_TEXTURE:
		return "weapon.fork"
	return ""


static func _warn(cue_id: String) -> void:
	if not OS.is_debug_build() or cue_id.is_empty() or _warned.has(cue_id):
		return
	_warned[cue_id] = true
	push_warning("Sfx: missing cue '%s'" % cue_id)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
