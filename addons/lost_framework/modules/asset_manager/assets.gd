class_name Assets

static var manager: AssetManager

const PLACEHOLDER_DIR := "res://placeholders/"
const TEXTURE_FILE_EXTS: PackedStringArray = ["png", "webp", "jpg", "jpeg", "svg", "tres", "res"]
const AUDIO_FILE_EXTS: PackedStringArray = ["ogg", "mp3", "wav", "tres", "res"]

static var _fallback_tex: Texture2D
static var _fallback_beep: AudioStream


#region Public API
static func bind(new_manager: AssetManager):
	manager = new_manager


## Return asset by key.
## When remote hot-swap is enabled and a compatible file has downloaded, that file is returned.
static func fetch(key: String) -> Variant:
	return _fetch(key, true)


## Like [method fetch], but a missing key returns null without a warning.
static func try_fetch(key: String) -> Variant:
	return _fetch(key, false)


static func _fetch(key: String, warn_missing: bool) -> Variant:
	if not manager:
		if warn_missing:
			push_error("AssetManager not bound. Call Assets.bind(manager) before fetching assets.")
		return null
	if not key:
		if warn_missing:
			push_warning("Empty asset key provided")
		return null

	if manager.remote_overrides(key):
		var remote := manager.get_remote(key)
		manager.cache[key] = remote
		return remote

	var cached: Variant = manager.cache.get(key)
	if cached:
		return cached

	# Lookup entry once
	var entry: AssetEntry = manager.by_key.get(key)
	if entry == null:
		if warn_missing:
			log_no_asset(key)
		return null

	# Validate resource
	var res: Resource = entry.resource
	if res == null:
		if warn_missing:
			push_warning("Asset '%s' has no resource" % key)
		return null

	# Cache and return
	manager.cache[key] = res
	return res


## Texture for [param key]. Falls back to [code]res://placeholders/[/code], then a generated checkerboard.
## Never returns null.
static func fetch_texture(key: String) -> Texture2D:
	var res: Variant = try_fetch(key)
	if res is Texture2D:
		return res
	var from_file := _load_placeholder_file(key, TEXTURE_FILE_EXTS)
	if from_file is Texture2D:
		return from_file
	return _placeholder_texture()


## Audio stream for [param key]. Falls back to [code]res://placeholders/[/code], then a generated beep.
## Never returns null. Ids starting with [code]bgm_[/code] or [code]bgm.[/code] loop once the remote file arrives.
static func fetch_audio(key: String) -> AudioStream:
	var res: Variant = try_fetch(key)
	if res is AudioStream:
		return res
	var from_file := _load_placeholder_file(key, AUDIO_FILE_EXTS)
	if from_file is AudioStream:
		return from_file
	return _placeholder_audio()


## True while [param key] has no compatible remote file yet. True when remote mode is off.
static func is_placeholder(key: String) -> bool:
	if manager == null:
		return true
	return manager.is_placeholder(key)


## Use asset by key with type checking
static func fetch_as(key: String, expected_class: StringName ) -> Resource:
	var res: Variant = fetch(key)
	if res == null:
		log_no_asset(key)
		return null
	
	if not res.is_class(expected_class):
		push_warning(
			"Asset type mismatch for key: %s. Expected: %s, Found: %s"
			% [key, expected_class, res.get_class()]
		)
		# Return placeholder if available
		if get_placeholder(expected_class) != null:
			return get_placeholder(expected_class)
		return null
	
	return res
#endregion

#region Helpers
## Return a placeholder resource for the expected class
static func get_placeholder(expected_class: StringName) -> Resource:
	match expected_class:
		"Texture2D":
			var placeholder_key := "lost_framework/placeholder/texture"
			return fetch_as(placeholder_key, expected_class)
		
		"Font":
			var placeholder_key := "lost_framework/placeholder/font"
			return fetch_as(placeholder_key, expected_class)
		
		"ShaderMaterial":
			var placeholder_key := "lost_framework/placeholder/material_shader"
			return fetch_as(placeholder_key, expected_class)
		
		_:
			push_warning("No placeholder defined for class: " + str(expected_class))
			var placeholder_key := "lost_framework/placeholder/generic"
	return null


static func log_no_asset(key: String) -> void:
	push_warning("Asset not found: " + key)


static func _load_placeholder_file(id: String, exts: PackedStringArray) -> Resource:
	if id == "":
		return null
	for ext in exts:
		var path := PLACEHOLDER_DIR + id + "." + ext
		if ResourceLoader.exists(path):
			var loaded := load(path)
			if loaded != null:
				return loaded
	return null


static func _placeholder_texture() -> Texture2D:
	if manager:
		return manager.placeholder_texture()
	if _fallback_tex == null:
		_fallback_tex = AssetManager.create_placeholder_texture()
	return _fallback_tex


static func _placeholder_audio() -> AudioStream:
	if manager:
		return manager.placeholder_audio()
	if _fallback_beep == null:
		_fallback_beep = AssetManager.create_placeholder_audio()
	return _fallback_beep
#endregion
