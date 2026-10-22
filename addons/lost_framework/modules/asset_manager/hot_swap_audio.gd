extends AudioStreamPlayer
class_name HotSwapAudio
## AudioStreamPlayer whose stream comes from [Assets] ([code]sfx_jump[/code], [code]bgm_menu[/code], ...).
## If the stream is swapped while playing, playback restarts when [member restart_on_swap] is on.
## For positional audio, duplicate this script and change [code]extends[/code] to
## [AudioStreamPlayer2D] or [AudioStreamPlayer3D]. The rest of the script stays the same.

@export var asset_id: String = "":
	set(value):
		asset_id = value.strip_edges().to_lower()
		if is_inside_tree():
			_refresh()
@export var restart_on_swap: bool = true
@export var prefer_editor_stream: bool = true

var _editor_stream: AudioStream
var _did_retry := false


func _ready() -> void:
	_editor_stream = stream
	_connect_updates()
	_refresh()
	# autoplay already fired before _refresh() could set the stream
	if autoplay and not playing:
		play()


func _connect_updates() -> void:
	if Assets.manager == null:
		if not _did_retry:
			_did_retry = true
			call_deferred("_connect_updates")
		return
	if not Assets.manager.asset_updated.is_connected(_on_asset_updated):
		Assets.manager.asset_updated.connect(_on_asset_updated)
	if _did_retry:
		_refresh()


func _on_asset_updated(id: String) -> void:
	if id == asset_id:
		_refresh()


func _refresh() -> void:
	if asset_id == "":
		return
	var was_playing := playing
	var new_stream: AudioStream
	if prefer_editor_stream and _editor_stream != null and Assets.is_placeholder(asset_id):
		new_stream = _editor_stream
	else:
		new_stream = Assets.fetch_audio(asset_id)
	if new_stream == stream:
		return
	stream = new_stream
	if was_playing and restart_on_swap:
		play()
