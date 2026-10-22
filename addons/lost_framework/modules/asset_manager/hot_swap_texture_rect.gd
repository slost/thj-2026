extends TextureRect
class_name HotSwapTextureRect
## TextureRect whose texture comes from [Assets] and updates when a remote file arrives.
## Set [member asset_id] in the Inspector. See [HotSwapSprite].

@export var asset_id: String = "":
	set(value):
		asset_id = value.strip_edges().to_lower()
		if is_inside_tree():
			_refresh()
@export var prefer_editor_texture: bool = true

var _editor_texture: Texture2D
var _did_retry := false


func _ready() -> void:
	_editor_texture = texture
	_connect_updates()
	_refresh()


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
	if prefer_editor_texture and _editor_texture != null and Assets.is_placeholder(asset_id):
		texture = _editor_texture
	else:
		texture = Assets.fetch_texture(asset_id)
