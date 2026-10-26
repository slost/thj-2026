extends AnimationPlayer
class_name HotSwapAnimationPlayer
## AnimationPlayer that replaces named clips from [Assets] when a remote Animation arrives.
## The clip saved in the scene stays until that file exists, and stays when remote mode is off.
## [member bind_by_name] maps [code]run[/code] to [code]anim_run[/code] and [code]player/run[/code] to [code]anim_player_run[/code].
## [member animation_ids] overrides that map: [code]{ "run": "anim_player_dash" }[/code].

@export var animation_ids: Dictionary = {}
@export var bind_by_name: bool = true

var _did_retry := false
var _warned: Dictionary = {}
var _applied: Dictionary = {}


func _ready() -> void:
	_connect_updates()
	_refresh_all()


func _connect_updates() -> void:
	if Assets.manager == null:
		if not _did_retry:
			_did_retry = true
			call_deferred("_connect_updates")
		return
	if not Assets.manager.asset_updated.is_connected(_on_asset_updated):
		Assets.manager.asset_updated.connect(_on_asset_updated)
	if _did_retry:
		_refresh_all()


func _on_asset_updated(id: String) -> void:
	var names := _names_for_asset(id)
	if not names.is_empty():
		for anim_name in names:
			_apply_id(anim_name, _id_for(anim_name))
		return
	_remap_applied()


func _refresh_all() -> void:
	var seen := {}
	for anim_name in animation_ids.keys():
		var name := str(anim_name)
		_apply_id(name, _id_for(name))
		seen[name] = true
	if not bind_by_name:
		return
	for anim_name in get_animation_list():
		var name := str(anim_name)
		if seen.has(name):
			continue
		_apply_id(name, AnimationSwap.asset_id_for(name))


func _names_for_asset(id: String) -> Array[String]:
	var names: Array[String] = []
	var wanted := id.strip_edges().to_lower()
	for anim_name in animation_ids.keys():
		var name := str(anim_name)
		if _id_for(name) == wanted:
			names.append(name)
	if bind_by_name:
		for anim_name in get_animation_list():
			var name := str(anim_name)
			if animation_ids.has(anim_name) or animation_ids.has(name):
				continue
			if AnimationSwap.asset_id_for(name) == wanted and not names.has(name):
				names.append(name)
	return names


func _id_for(anim_name: String) -> String:
	if animation_ids.has(anim_name):
		return str(animation_ids[anim_name]).strip_edges().to_lower()
	for key in animation_ids.keys():
		if str(key) == anim_name:
			return str(animation_ids[key]).strip_edges().to_lower()
	if bind_by_name:
		return AnimationSwap.asset_id_for(anim_name)
	return ""


func _apply_id(anim_name: String, asset_id: String) -> void:
	if asset_id == "" or Assets.manager == null or Assets.is_placeholder(asset_id):
		return
	var anim := Assets.fetch_animation(asset_id)
	if anim == null:
		_warn_once(asset_id, "Remote asset '%s' is not an Animation. '%s' stays on the scene clip." % [asset_id, anim_name])
		return
	var reason := AnimationSwap.install(self, anim_name, anim)
	if reason != "":
		_warn_once(anim_name, reason)
		return
	_applied[anim_name] = true


func _remap_applied() -> void:
	for anim_name in _applied.keys():
		var name := str(anim_name)
		var anim := get_animation(StringName(name))
		if anim == null or not AnimationSwap.remap_textures(anim):
			continue
		if str(current_animation) == name or str(assigned_animation) == name:
			seek(current_animation_position, true)


func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning("[AssetManager] " + message)
