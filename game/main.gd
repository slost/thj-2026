extends Node2D

## Boots with the Lost framework and reports how many remote assets have arrived.

@onready var status_label: Label = $CanvasLayer/Status

var _connected := false
var _connect_tries := 0


func _ready() -> void:
	_connect_manager()


func _connect_manager() -> void:
	if Assets.manager == null:
		_connect_tries += 1
		if _connect_tries < 180:
			call_deferred("_connect_manager")
		else:
			_show("THJ 2026\nAsset manager did not start.")
			push_error("Asset manager did not start.")
		return
	if _connected:
		return
	_connected = true
	Assets.manager.asset_updated.connect(_refresh_status)
	Assets.manager.manifest_loaded.connect(_on_manifest_loaded)
	Assets.manager.all_loaded.connect(_refresh_status)
	_refresh_status()


func _on_manifest_loaded(_ok: bool) -> void:
	_refresh_status()


func _refresh_status(_id: String = "") -> void:
	var manager := Assets.manager
	var mode := "starting"
	var manifest_state := "waiting"
	var loaded := 0
	var placeholders := 0
	var pending := 0
	if manager != null:
		mode = "remote" if manager.base_url != "" else "off"
		pending = manager.pending_count()
		var assets: Variant = manager.manifest.get("assets", {})
		if manager.manifest.is_empty():
			manifest_state = "waiting" if manager.is_loading else "empty"
		elif assets is Dictionary:
			manifest_state = "%d ids" % assets.size()
			for asset_id in assets.keys():
				if Assets.is_placeholder(str(asset_id)):
					placeholders += 1
				else:
					loaded += 1
	_show("THJ 2026\nmode: %s\nmanifest: %s\nloaded: %d\nplaceholders: %d\npending: %d" % [
		mode, manifest_state, loaded, placeholders, pending
	])


func _show(text: String) -> void:
	if status_label != null:
		status_label.text = text
	print("[THJ] ", text.replace("\n", " | "))
