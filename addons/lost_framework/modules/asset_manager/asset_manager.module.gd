@tool
extends Refs.MODULE
class_name AssetManager
## Indexes local [AssetEntry] resources and, when enabled, overlays textures and
## audio from a remote manifest. Remote loading is off by default.
## See [code]HOTSWAP.md[/code] in this folder.

## A remote file replaced the local placeholder or an older remote version.
signal asset_updated(id: String)
## Manifest fetch finished. [param ok] is false when remote mode is off or the request failed.
signal manifest_loaded(ok: bool)
## Download queue drained, or the manifest could not be loaded. Fires once per [method reload].
signal all_loaded

const SETTING_REMOTE_ENABLED := "lost_framework/asset_manager/remote_enabled"
const SETTING_BASE_URL := "lost_framework/asset_manager/base_url"
const SETTING_MAX_CONCURRENT := "lost_framework/asset_manager/max_concurrent"
const DEFAULT_BASE_URL := "assets/"
const DEFAULT_MAX_CONCURRENT := 4

var _assets_dir := Paths.data_asset_entries() as String ## Directory containing AssetEntry files
var cache: Dictionary = {} ## Cache for fast lookup
var by_uid: Dictionary = {} ## uid -> AssetEntry
var by_key: Dictionary = {} ## In-memory index (key -> AssetEntry) (runtime only)

var base_url: String = "" ## Absolute remote base URL ending in "/", or "" when remote is off.
var manifest: Dictionary = {} ## Last manifest that parsed. Empty while remote is off.
var is_loading: bool = false ## True from [method reload] until [signal all_loaded].

var _loader: RemoteAssetLoader
var _announced_base := false
var _type_mismatch: Dictionary = {}
var _placeholder_tex: Texture2D
var _placeholder_beep: AudioStream


#region Lifecycle
func _on_editor_activate() -> void:
	rebuild_index()


func _on_runtime_activate() -> void:
	rebuild_index()
	Assets.bind(self)
	# Scene nodes connect during _ready, which runs before this deferred call.
	call_deferred("_start_remote_if_bound")


func _on_deactivate() -> void:
	if _loader and is_instance_valid(_loader):
		_loader.cancel()
	is_loading = false
#endregion

#region Interal Logic
func rebuild_index() -> void:
	by_uid.clear()
	by_key.clear()

	for entry in _load_all_entries():
		by_uid[entry.uid] = entry

		if entry.key != "":
			by_key[entry.key] = entry


func _load_all_entries() -> Array[AssetEntry]:
	var result: Array[AssetEntry] = []

	var normalized_dir := _assets_dir.rstrip("/")
	var files: PackedStringArray = ResourceLoader.list_directory(normalized_dir)
	for file in files:
		if not file.ends_with(".tres"):
			continue

		var path := normalized_dir.path_join(file)
		if not ResourceLoader.exists(path):
			continue

		var entry := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if entry is AssetEntry:
			result.append(entry)

	return result


func get_all_assets() -> Array[AssetEntry]:
	var result: Array[AssetEntry] = []
	for e in by_uid.values():
		result.append(e)
	return result
#endregion

#region File Operations
func create_new_asset() -> AssetEntry:
	var entry := AssetEntry.new()
	entry.uid = Utils.generate_uid()
	entry.key = ""

	entry = save_asset(entry)
	by_uid[entry.uid] = entry

	return entry

	
func save_asset(entry: AssetEntry) -> AssetEntry:
	_ensure_dir()

	if entry.uid == "":
		entry.uid = Utils.generate_uid()

	var prefix := _get_prefix(entry)
	var file_name := "%s_%s.tres" % [prefix, entry.uid]
	var path := _assets_dir + file_name

	var err := ResourceSaver.save(entry, path)
	if err != OK:
		push_error("Failed to save asset entry: %s" % path)
		return entry

	# Reload and return canonical instance
	var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as AssetEntry
	if saved == null:
		return entry

	_update_indexes_for_saved_entry(saved)
	return saved


func delete_asset(entry: AssetEntry) -> void:
	# Always clean in-memory references first
	by_key.erase(entry.key)
	by_uid.erase(entry.uid)

	# Physical file removal is optional
	if entry.resource_path != "" and ResourceLoader.exists(entry.resource_path):
		DirAccess.remove_absolute(entry.resource_path)

	rebuild_index()


func rename_asset(entry: AssetEntry, new_key: String) -> void:
	new_key = new_key.strip_edges()
	if new_key == "" or new_key == entry.key:
		return

	if by_key.has(new_key):
		push_error("Duplicate asset key: %s" % new_key)
		return

	var canonical := by_uid.get(entry.uid)
	if canonical == null:
		push_error("Asset UID not found: " + entry.uid)
		return

	if canonical.key != "":
		by_key.erase(canonical.key)

	canonical.key = new_key
	by_key[new_key] = canonical
	save_asset(canonical)
#endregion

#region Utils
func _update_indexes_for_saved_entry(entry: AssetEntry) -> void:
	var previous := by_uid.get(entry.uid) as AssetEntry
	if previous and previous.key != entry.key:
		by_key.erase(previous.key)

	by_uid[entry.uid] = entry

	if entry.key != "":
		by_key[entry.key] = entry


## Ensure the asset entry directory exists
func _ensure_dir() -> void:
	var assets_dir_abs := ProjectSettings.globalize_path(_assets_dir)
	if not DirAccess.dir_exists_absolute(assets_dir_abs):
		DirAccess.make_dir_recursive_absolute(assets_dir_abs)


func _get_prefix(entry: AssetEntry) -> String:
	return "asset"
#endregion


#region Remote hot-swap
## Registers the opt-in project settings. Defaults stay off, so existing projects keep local assets only.
static func register_project_settings() -> void:
	_register_setting(SETTING_REMOTE_ENABLED, false, TYPE_BOOL, PROPERTY_HINT_NONE, "")
	_register_setting(SETTING_BASE_URL, DEFAULT_BASE_URL, TYPE_STRING, PROPERTY_HINT_NONE, "")
	_register_setting(SETTING_MAX_CONCURRENT, DEFAULT_MAX_CONCURRENT, TYPE_INT, PROPERTY_HINT_RANGE, "1,16,1")


static func _register_setting(setting_name: String, default_value: Variant, type: int, hint: int, hint_string: String) -> void:
	if not ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, default_value)
	ProjectSettings.set_initial_value(setting_name, default_value)
	ProjectSettings.add_property_info({
		"name": setting_name,
		"type": type,
		"hint": hint,
		"hint_string": hint_string,
	})


## Local entry whose key matches [param id], ignoring ASCII case.
func entry_for_id(id: String) -> AssetEntry:
	if id == "":
		return null
	if by_key.has(id):
		return by_key[id]
	var norm := id.to_lower()
	if by_key.has(norm):
		return by_key[norm]
	for key in by_key.keys():
		if str(key).to_lower() == norm:
			return by_key[key]
	return null


## Key of a local entry or a downloaded remote resource, matched by object identity.
func key_for_resource(res: Resource) -> String:
	if res == null:
		return ""
	var instance_id := res.get_instance_id()
	for key in by_key.keys():
		var entry := by_key[key] as AssetEntry
		if entry and entry.resource and entry.resource.get_instance_id() == instance_id:
			return str(key)
	if _loader:
		return _loader.key_for_resource(res)
	return ""


## Downloaded resource for [param id], or null when that id has no remote file yet.
func get_remote(id: String) -> Resource:
	if _loader == null or id == "":
		return null
	return _loader.get_resource(id)


## True when a downloaded file should replace the local entry for [param key].
## Scenes and other non-media entries are left alone when the remote type differs.
func remote_overrides(key: String) -> bool:
	var remote := get_remote(key)
	if remote == null:
		return false
	var entry := entry_for_id(key)
	if entry == null or entry.resource == null:
		return true
	return _same_media_kind(entry.resource, remote)


## True while [param id] is still the built-in placeholder (no compatible remote file yet).
func is_placeholder(id: String) -> bool:
	return not remote_overrides(id)


## Downloads still queued or in flight. Zero when remote mode is off.
func pending_count() -> int:
	if _loader == null:
		return 0
	return _loader.pending_count()


## Fetch the manifest again and download files whose hash changed.
## When remote mode is off, emits [signal manifest_loaded] with false and then [signal all_loaded].
func reload() -> void:
	if Assets.manager != null and Assets.manager != self:
		return
	if not is_inside_tree():
		push_warning("[AssetManager] reload() needs AssetManager in the scene tree.")
		return
	if not _remote_opted_in():
		is_loading = false
		manifest_loaded.emit(false)
		all_loaded.emit()
		return
	if _loader == null:
		_loader = RemoteAssetLoader.new()
		_loader.name = "RemoteAssetLoader"
		add_child(_loader)
		_loader.asset_ready.connect(_on_remote_asset_ready)
		_loader.manifest_ready.connect(_on_remote_manifest_ready)
		_loader.queue_drained.connect(_on_remote_queue_drained)
	var resolved := _loader.apply_base_url(_configured_url())
	base_url = resolved
	if resolved == "":
		is_loading = false
		manifest_loaded.emit(false)
		all_loaded.emit()
		return
	_loader.max_concurrent = _max_concurrent()
	is_loading = true
	if not _announced_base:
		_announced_base = true
		print("[AssetManager] remote base_url = ", base_url)
	_loader.reload()


func placeholder_texture() -> Texture2D:
	if _placeholder_tex == null:
		_placeholder_tex = create_placeholder_texture()
	return _placeholder_tex


func placeholder_audio() -> AudioStream:
	if _placeholder_beep == null:
		_placeholder_beep = create_placeholder_audio()
	return _placeholder_beep


static func create_placeholder_texture() -> Texture2D:
	var size := 64
	var cell := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(0, size, cell):
		for x in range(0, size, cell):
			var color := Color.MAGENTA if ((x + y) / cell) % 2 == 0 else Color.BLACK
			img.fill_rect(Rect2i(x, y, cell, cell), color)
	return ImageTexture.create_from_image(img)


static func create_placeholder_audio() -> AudioStream:
	var rate := 22050
	var duration := 0.15
	var freq := 880.0
	var count := int(rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var env := minf(1.0, minf(t / 0.005, (duration - t) / 0.03))
		data.encode_s16(i * 2, int(sin(TAU * freq * t) * env * 0.4 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _start_remote_if_bound() -> void:
	if Assets.manager != self:
		return
	if not _remote_opted_in():
		return
	reload()


func _configured_url() -> String:
	var project_url := str(ProjectSettings.get_setting(SETTING_BASE_URL, DEFAULT_BASE_URL))
	return RemoteAssetLoader.select_configured_url(
		DEFAULT_BASE_URL,
		project_url,
		RemoteAssetLoader.cmdline_assets_override(),
		RemoteAssetLoader.query_assets_override())


func _remote_opted_in() -> bool:
	var selected := _configured_url().strip_edges()
	if selected == "off" or selected == "none":
		return false
	if RemoteAssetLoader.query_assets_override() != "":
		return true
	if RemoteAssetLoader.cmdline_assets_override() != "":
		return true
	return bool(ProjectSettings.get_setting(SETTING_REMOTE_ENABLED, false))


func _max_concurrent() -> int:
	return clampi(int(ProjectSettings.get_setting(SETTING_MAX_CONCURRENT, DEFAULT_MAX_CONCURRENT)), 1, 16)


func _on_remote_asset_ready(id: String, res: Resource, _file_hash: String) -> void:
	var keys: Array[String] = []
	var entry := entry_for_id(id)
	if entry and entry.key != "":
		keys.append(entry.key)
	if not keys.has(id):
		keys.append(id)
	var applied := false
	for key in keys:
		if remote_overrides(key):
			cache[key] = res
			applied = true
		elif entry and entry.resource != null and key == entry.key:
			_warn_type_mismatch(id, entry.resource, res)
	if applied:
		asset_updated.emit(id)


func _warn_type_mismatch(id: String, local: Resource, remote: Resource) -> void:
	if _type_mismatch.has(id):
		return
	_type_mismatch[id] = true
	push_warning("[AssetManager] Remote asset '%s' is %s but the local entry is %s. Keeping the local resource." % [id, remote.get_class(), local.get_class()])


func _on_remote_manifest_ready(ok: bool, data: Dictionary) -> void:
	if ok:
		manifest = data
	manifest_loaded.emit(ok)


func _on_remote_queue_drained() -> void:
	is_loading = false
	all_loaded.emit()


func _same_media_kind(local: Resource, remote: Resource) -> bool:
	if local is Texture2D and remote is Texture2D:
		return true
	if local is AudioStream and remote is AudioStream:
		return true
	return local.get_class() == remote.get_class()
#endregion
