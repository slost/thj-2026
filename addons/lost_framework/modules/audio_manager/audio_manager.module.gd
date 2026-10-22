extends Refs.MODULE
class_name AudioManager


const POOL_SIZE: int = 5
const MAX_POOL_SIZE: int = 16
const SILENT_DB := -80.0

## Bus names created at runtime and routed to Master.
const BUS := {
	"MASTER": "Master",
	"BGM": "BGM",
	"SFX": "SFX",
	"AMBIENCE": "Ambience",
	"VOICE": "Voice",
	"UI": "UI",
}

const _META_GEN := &"audio_gen"
const _META_VOICE_AT := &"voice_at"


## Emitted when a music stream starts, including the start of a crossfade.
signal music_started(stream: AudioStream)
## Emitted when music ends or [method stop_music] finishes. Not emitted when a new track replaces the current one.
signal music_finished
## Emitted after [method set_volume]. [param volume] is linear from 0 to 1.
signal bus_volume_changed(bus_name: String, volume: float)
## Emitted when [method set_muted] changes a bus mute flag.
signal bus_mute_changed(bus_name: String, muted: bool)

var music_player: AudioStreamPlayer
var _music_standby: AudioStreamPlayer
var _music_source: AudioStream
var _music_loop := false
var _music_asset_key: String = ""
var _music_generation := 0
var _hotswap_connect_attempts := 0
var _music_tween: Tween
var _in_music_finished := false

## Crossfade length used when play_music() / stop_music() omit fade_duration.
## 0 keeps a hard cut. Set this (for example to 0.45) to fade by default.
var music_fade_duration: float = 0.0

var sfx_pool: Array[AudioStreamPlayer] = []
var ui_pool: Array[AudioStreamPlayer] = []
var _bus_counters: Dictionary = {}
var _linear_volumes: Dictionary = {}
var _variation_last: Dictionary = {}
var _players_initialized := false


#region Feature Flags
## Music channel switch. While false, play_music() is ignored and current music stops.
var is_autoplay_music: bool = true:
	set(value):
		is_autoplay_music = value
		if _players_initialized and not value:
			stop_music(0.0)

## SFX channel switch. While false, [method play_sfx] and [method play_sfx_variation] are ignored and current SFX stop.
var is_sfx_enabled: bool = true:
	set(value):
		is_sfx_enabled = value
		if _players_initialized and not value:
			stop_sfx()

## UI channel switch. While false, [method play_ui] is ignored and current UI sounds stop.
var is_ui_sfx_enabled: bool = true:
	set(value):
		is_ui_sfx_enabled = value
		if _players_initialized and not value:
			stop_ui()
		
#endregion


#region Module Lifecycle
func _on_runtime_activate() -> void:
	_initialize_players()
	# Bind may still change if another AssetManager autoload activates later this frame.
	call_deferred("_connect_asset_hotswap")


func _on_deactivate() -> void:
	stop_all()
	_disconnect_asset_hotswap()

#endregion


#region Music
## Plays [param stream] on the music channel. [param stream] may be an [AudioStream] or an [AssetEntry].
## The same stream already playing is left running. A paused match is resumed instead.
## [param fade_duration] is the crossfade in seconds. A negative value uses [member music_fade_duration].
func play_music(stream: Resource, loop: bool = true, fade_duration: float = -1.0) -> void:
	_initialize_players()
	if not is_autoplay_music:
		return

	var source := _resolve_stream(stream)
	if source == null or music_player == null:
		return

	if source == _music_source and loop == _music_loop and music_player.playing:
		if _music_asset_key == "":
			_music_asset_key = _asset_key_for_playback(stream, source)
		if music_player.stream_paused:
			resume_music()
		return

	var fade := _resolve_fade(fade_duration)
	var current_busy := music_player.playing and not music_player.stream_paused and _music_source != null
	var incoming := music_player
	var outgoing := _music_standby

	if current_busy:
		incoming = _music_standby
		outgoing = music_player
		_music_standby = outgoing
		music_player = incoming

	_kill_music_tween()
	_silence_music_player(incoming)

	_music_asset_key = _asset_key_for_playback(stream, source)
	_music_source = source
	_music_loop = loop
	incoming.stream = _stream_for_playback(source, loop)
	incoming.stream_paused = false
	_arm_music(incoming)

	if fade <= 0.0:
		if outgoing and outgoing != incoming and outgoing.playing:
			_silence_music_player(outgoing)
		incoming.volume_db = 0.0
		incoming.play()
		music_started.emit(source)
		return

	incoming.volume_db = SILENT_DB
	incoming.play()
	music_started.emit(source)

	_music_tween = create_tween()
	_music_tween.set_trans(Tween.TRANS_QUAD)
	_music_tween.set_ease(Tween.EASE_IN_OUT)
	_music_tween.set_parallel(true)
	_music_tween.tween_method(_set_player_linear_volume.bind(incoming), 0.0, 1.0, fade)

	if outgoing and outgoing != incoming and outgoing.playing:
		var from_linear := db_to_linear(outgoing.volume_db)
		_music_tween.tween_method(_set_player_linear_volume.bind(outgoing), from_linear, 0.0, fade)
		_music_tween.chain().tween_callback(_silence_music_player.bind(outgoing))


## Stops music. [param fade_duration] uses the same rules as [method play_music].
func stop_music(fade_duration: float = -1.0) -> void:
	_music_asset_key = ""
	if music_player == null and _music_standby == null:
		return

	var fade := _resolve_fade(fade_duration)
	var player := music_player
	var should_fade := (
		fade > 0.0
		and player != null
		and player.playing
		and not player.stream_paused
		and _music_source != null
	)

	_music_loop = false
	_kill_music_tween()

	if _music_standby and _music_standby != player:
		_silence_music_player(_music_standby)

	if not should_fade:
		var had_music := _music_source != null or (player != null and player.playing)
		_music_source = null
		if player:
			_silence_music_player(player)
		if had_music:
			music_finished.emit()
		return

	_music_tween = create_tween()
	_music_tween.set_trans(Tween.TRANS_QUAD)
	_music_tween.set_ease(Tween.EASE_IN)
	var from_linear := db_to_linear(player.volume_db)
	_music_tween.tween_method(_set_player_linear_volume.bind(player), from_linear, 0.0, fade)
	_music_tween.tween_callback(func() -> void:
		if music_player != player or _music_source == null:
			return
		_music_source = null
		_silence_music_player(player)
		music_finished.emit()
	)


## Pauses music and any music fade that is still running.
func pause_music() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.pause()
	_set_music_paused(true)


## Resumes music paused by [method pause_music], including a paused fade.
func resume_music() -> void:
	_set_music_paused(false)
	if _music_tween and _music_tween.is_valid():
		_music_tween.play()


## Returns true while the current music stream is playing and not paused.
func is_music_playing() -> bool:
	return (
		music_player != null
		and music_player.playing
		and not music_player.stream_paused
		and _music_source != null
	)


## Returns the current music position in seconds, or 0 when nothing is playing.
func get_music_position() -> float:
	if music_player == null or not music_player.playing:
		return 0.0
	return music_player.get_playback_position()


## Seeks the current music stream to [param seconds]. Does nothing when music is stopped.
func seek_music(seconds: float) -> void:
	if music_player == null or not music_player.playing:
		return
	music_player.seek(maxf(seconds, 0.0))
#endregion

#region One Shots
## Plays [param stream] on the SFX bus. [param stream] may be an [AudioStream] or an [AssetEntry].
## [param pitch_scale] is clamped above 0. [param volume] is linear from 0 to 1.
## Returns the voice, or null when SFX are disabled or [param stream] cannot be played.
func play_sfx(stream: Resource, pitch_scale: float = 1.0, volume: float = 1.0) -> AudioStreamPlayer:
	_initialize_players()
	if not is_sfx_enabled:
		return null
	return _play_from_pool(sfx_pool, BUS.SFX, _resolve_stream(stream), pitch_scale, volume)


## Plays one random clip from [param variations] on the SFX bus.
## Each entry may be an [AudioStream] or an [AssetEntry]. Invalid entries are skipped.
## [param pitch_range] is the minimum and maximum pitch. x and y are swapped when x is greater.
## With more than one valid clip, the same clip is not chosen twice in a row.
## [param volume] is linear from 0 to 1.
## Returns the voice, or null when SFX are disabled or no clip can be played.
func play_sfx_variation(
	variations: Array,
	pitch_range: Vector2 = Vector2(0.95, 1.05),
	volume: float = 1.0,
) -> AudioStreamPlayer:
	var stream := _pick_variation(variations)
	if stream == null:
		return null

	var pitch_min := minf(pitch_range.x, pitch_range.y)
	var pitch_max := maxf(pitch_range.x, pitch_range.y)
	var pitch := pitch_min if is_equal_approx(pitch_min, pitch_max) else randf_range(pitch_min, pitch_max)
	return play_sfx(stream, pitch, volume)


## Plays [param stream] on the UI bus. [param stream] may be an [AudioStream] or an [AssetEntry].
## [param volume] is linear from 0 to 1. UI audio keeps playing while the scene tree is paused.
## Returns the voice, or null when UI sounds are disabled or [param stream] cannot be played.
func play_ui(stream: Resource, volume: float = 1.0) -> AudioStreamPlayer:
	_initialize_players()
	if not is_ui_sfx_enabled:
		return null
	return _play_from_pool(ui_pool, BUS.UI, _resolve_stream(stream), 1.0, volume)


## Stops every SFX voice.
func stop_sfx() -> void:
	_stop_pool(sfx_pool)


## Stops every UI voice.
func stop_ui() -> void:
	_stop_pool(ui_pool)


## Stops [param player] and returns it to the pool. [param player] must come from [method play_sfx], [method play_sfx_variation], or [method play_ui].
func stop_voice(player: AudioStreamPlayer) -> void:
	if player == null or not is_instance_valid(player):
		return
	_reset_voice(player)


## Pauses SFX voices that are currently playing.
func pause_sfx() -> void:
	_set_pool_paused(sfx_pool, true)


## Resumes SFX voices paused by [method pause_sfx].
func resume_sfx() -> void:
	_set_pool_paused(sfx_pool, false)


## Pauses UI voices that are currently playing.
func pause_ui() -> void:
	_set_pool_paused(ui_pool, true)


## Resumes UI voices paused by [method pause_ui].
func resume_ui() -> void:
	_set_pool_paused(ui_pool, false)


## Stops music, SFX, and UI immediately.
func stop_all() -> void:
	stop_music(0.0)
	stop_sfx()
	stop_ui()

#endregion


#region Volume Control
## Sets the volume of [param bus_name]. [param volume] is linear from 0 to 1 and is remembered while the bus is muted.
## [param bus_name] is one of [constant BUS].
func set_volume(bus_name: String, volume: float) -> void:
	_initialize_players()
	var bus_idx := _bus_index(bus_name)
	if bus_idx == -1:
		return

	var linear := clampf(volume, 0.0, 1.0)
	_linear_volumes[bus_name] = linear
	AudioServer.set_bus_volume_db(bus_idx, _volume_db(linear))
	bus_volume_changed.emit(bus_name, linear)


## Returns the linear volume of [param bus_name], from 0 to 1. Mute does not change the returned value.
func get_volume(bus_name: String) -> float:
	if _linear_volumes.has(bus_name):
		return _linear_volumes[bus_name]

	_initialize_players()
	var bus_idx := _bus_index(bus_name)
	if bus_idx == -1:
		return 0.0

	return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))


## Mutes or unmutes [param bus_name] without changing the volume stored by [method set_volume].
func set_muted(bus_name: String, muted: bool) -> void:
	_initialize_players()
	var bus_idx := _bus_index(bus_name)
	if bus_idx == -1:
		return
	if AudioServer.is_bus_mute(bus_idx) == muted:
		return

	AudioServer.set_bus_mute(bus_idx, muted)
	bus_mute_changed.emit(bus_name, muted)


## Returns true when [param bus_name] is muted.
func is_muted(bus_name: String) -> bool:
	_initialize_players()
	var bus_idx := _bus_index(bus_name)
	if bus_idx == -1:
		return false
	return AudioServer.is_bus_mute(bus_idx)

#endregion


#region Internal Setup
func _initialize_players() -> void:
	if _players_initialized:
		return

	_players_initialized = true
	# Music and UI keep running while the tree is paused. SFX follow the tree pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	music_player = _create_player(BUS.BGM, false)
	_music_standby = _create_player(BUS.BGM, false)

	for _i in range(POOL_SIZE):
		sfx_pool.append(_create_player(BUS.SFX))
		ui_pool.append(_create_player(BUS.UI))

	Utils.sort_nodes_by_name_ascending(self)


func _ensure_audio_buses() -> void:
	_ensure_audio_bus(BUS.BGM)
	_ensure_audio_bus(BUS.SFX)
	_ensure_audio_bus(BUS.AMBIENCE)
	_ensure_audio_bus(BUS.VOICE)
	_ensure_audio_bus(BUS.UI)


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	AudioServer.add_bus()
	var bus_idx := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_idx, bus_name)
	AudioServer.set_bus_send(bus_idx, BUS.MASTER)


func _create_player(bus_name: String, one_shot: bool = true) -> AudioStreamPlayer:
	if not _bus_counters.has(bus_name):
		_bus_counters[bus_name] = 0

	var index: int = _bus_counters[bus_name]
	_bus_counters[bus_name] += 1

	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	player.name = "%sPlayer%d" % [bus_name, index]
	player.add_to_group(bus_name + "Player")
	player.process_mode = Node.PROCESS_MODE_PAUSABLE if bus_name == BUS.SFX else Node.PROCESS_MODE_ALWAYS
	add_child(player)

	if one_shot:
		player.finished.connect(_on_voice_finished.bind(player))
	else:
		player.finished.connect(_on_music_finished.bind(player))

	return player

#endregion


#region Pool Logic
func _play_from_pool(
	pool: Array[AudioStreamPlayer],
	bus_name: String,
	stream: AudioStream,
	pitch_scale: float,
	volume: float,
) -> AudioStreamPlayer:
	if stream == null:
		return null

	var player := _borrow_player(pool, bus_name)
	player.stream = stream
	player.pitch_scale = maxf(pitch_scale, 0.01)
	player.volume_db = _volume_db(volume)
	player.stream_paused = false
	player.set_meta(_META_VOICE_AT, Time.get_ticks_msec())
	player.play()
	return player


func _borrow_player(pool: Array[AudioStreamPlayer], bus_name: String) -> AudioStreamPlayer:
	for player in pool:
		if not player.playing:
			return player

	if pool.size() >= MAX_POOL_SIZE:
		return _oldest_voice(pool)

	var created := _create_player(bus_name)
	pool.append(created)
	return created


func _oldest_voice(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	var oldest := pool[0]
	var oldest_at := int(oldest.get_meta(_META_VOICE_AT, 0))
	for player in pool:
		var started := int(player.get_meta(_META_VOICE_AT, 0))
		if started < oldest_at:
			oldest = player
			oldest_at = started
	_reset_voice(oldest)
	return oldest


func _on_voice_finished(player: AudioStreamPlayer) -> void:
	# stop() can emit finished. Ignore the callback if this voice was already reused.
	if player.playing:
		return
	_reset_voice(player)


func _reset_voice(player: AudioStreamPlayer) -> void:
	if player.playing:
		player.stop()
	player.stream = null
	player.pitch_scale = 1.0
	player.volume_db = 0.0
	player.stream_paused = false


func _stop_pool(pool: Array[AudioStreamPlayer]) -> void:
	for player in pool:
		_reset_voice(player)


func _set_pool_paused(pool: Array[AudioStreamPlayer], paused: bool) -> void:
	for player in pool:
		if player.playing:
			player.stream_paused = paused
#endregion


#region Music Internals
func _on_music_finished(player: AudioStreamPlayer) -> void:
	# play() stops the current playback first, which emits finished again.
	if _in_music_finished:
		return
	if player != music_player or player.playing:
		return
	if int(player.get_meta(_META_GEN, -1)) != _music_generation:
		return
	if _music_source == null:
		return
	if _music_loop and is_autoplay_music:
		_in_music_finished = true
		player.play()
		_in_music_finished = false
		return

	_music_source = null
	if _music_standby and _music_standby != player:
		_silence_music_player(_music_standby)
	_kill_music_tween()
	music_finished.emit()


func _silence_music_player(player: AudioStreamPlayer) -> void:
	if player == null or not is_instance_valid(player):
		return

	player.set_meta(_META_GEN, -1)
	if player.playing:
		player.stop()
	player.stream = null
	player.volume_db = 0.0
	player.stream_paused = false


func _arm_music(player: AudioStreamPlayer) -> void:
	_music_generation += 1
	player.set_meta(_META_GEN, _music_generation)


func _set_music_paused(paused: bool) -> void:
	if music_player and music_player.stream != null:
		music_player.stream_paused = paused
	if _music_standby and _music_standby.stream != null and _music_standby.playing:
		_music_standby.stream_paused = paused


func _stream_for_playback(source: AudioStream, loop: bool) -> AudioStream:
	if source is AudioStreamWAV:
		var desired := AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		if (source as AudioStreamWAV).loop_mode == desired:
			return source
		var wav := source.duplicate() as AudioStreamWAV
		if wav == null:
			return source
		wav.loop_mode = desired
		return wav

	if not ("loop" in source) or bool(source.get("loop")) == loop:
		return source

	var copy := source.duplicate() as AudioStream
	if copy == null:
		return source
	copy.set("loop", loop)
	return copy


func _set_player_linear_volume(linear: float, player: AudioStreamPlayer) -> void:
	if not is_instance_valid(player):
		return
	player.volume_db = _volume_db(linear)


func _kill_music_tween() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null


func _resolve_fade(fade_duration: float) -> float:
	if fade_duration < 0.0:
		return maxf(music_fade_duration, 0.0)
	return fade_duration

#endregion


#region Helpers
func _pick_variation(variations: Array) -> AudioStream:
	var streams: Array[AudioStream] = []
	for item in variations:
		if not item is Resource:
			continue
		var stream := _resolve_stream(item)
		if stream:
			streams.append(stream)

	if streams.is_empty():
		return null
	if streams.size() == 1:
		return streams[0]

	var key := _variation_key(streams)
	var last_id := int(_variation_last.get(key, -1))
	var index := randi() % streams.size()
	if streams[index].get_instance_id() == last_id:
		index = (index + 1 + randi() % (streams.size() - 1)) % streams.size()

	var picked := streams[index]
	_variation_last[key] = picked.get_instance_id()
	return picked


func _variation_key(streams: Array[AudioStream]) -> String:
	var ids := PackedStringArray()
	for stream in streams:
		ids.append(str(stream.get_instance_id()))
	ids.sort()
	return "|".join(ids)


func _resolve_stream(source: Resource) -> AudioStream:
	if source == null:
		return null
	if source is AssetEntry:
		var entry := source as AssetEntry
		# Remote files overlay the entry only after a compatible download. Otherwise this
		# returns the same resource play_music() used before hot-swap existed.
		if entry.key != "" and Assets.manager != null and Assets.manager.remote_overrides(entry.key):
			var fetched: Variant = Assets.try_fetch(entry.key)
			if fetched is AudioStream:
				return fetched
		return entry.resource as AudioStream
	return source as AudioStream


func _asset_key_for_playback(stream: Resource, source: AudioStream) -> String:
	if stream is AssetEntry:
		return (stream as AssetEntry).key
	if Assets.manager and source:
		return Assets.manager.key_for_resource(source)
	return ""


func _connect_asset_hotswap() -> void:
	if Assets.manager == null:
		_hotswap_connect_attempts += 1
		if _hotswap_connect_attempts <= 5:
			call_deferred("_connect_asset_hotswap")
		return
	if not Assets.manager.asset_updated.is_connected(_on_hotswap_asset_updated):
		Assets.manager.asset_updated.connect(_on_hotswap_asset_updated)


func _disconnect_asset_hotswap() -> void:
	if Assets.manager and Assets.manager.asset_updated.is_connected(_on_hotswap_asset_updated):
		Assets.manager.asset_updated.disconnect(_on_hotswap_asset_updated)


## Restarts looping music when the remote file for the current asset arrives.
## One-shot voices are left as played; they are too short to swap mid-playback.
func _on_hotswap_asset_updated(id: String) -> void:
	if _music_asset_key == "" or not is_music_playing():
		return
	if _music_asset_key.to_lower() != id.to_lower():
		return
	var updated: Variant = Assets.try_fetch(_music_asset_key)
	if not (updated is AudioStream) or updated == _music_source:
		return
	play_music(updated, _music_loop, 0.0)


func _volume_db(linear: float) -> float:
	var clamped := clampf(linear, 0.0, 1.0)
	if clamped <= 0.0:
		return SILENT_DB
	return linear_to_db(clamped)


func _bus_index(bus_name: String) -> int:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		push_warning("AudioManager: bus not found: %s" % bus_name)
	return bus_idx

#endregion
