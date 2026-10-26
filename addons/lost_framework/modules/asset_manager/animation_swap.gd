class_name AnimationSwap
## Loads a remote Animation from .tres or .res bytes and installs it on an AnimationPlayer.
## Files are refused when they are not an Animation or when they embed or reference a Script.
## The clip already saved in the scene stays in place when this returns null.

const _SAFE_TYPES := {
	"Animation": true,
	"Texture2D": true,
	"Texture": true,
	"Image": true,
	"ImageTexture": true,
	"CompressedTexture2D": true,
	"PortableCompressedTexture2D": true,
	"AtlasTexture": true,
	"PlaceholderTexture2D": true,
	"CurveTexture": true,
	"GradientTexture1D": true,
	"GradientTexture2D": true,
	"AudioStream": true,
	"AudioStreamWAV": true,
	"AudioStreamOggVorbis": true,
	"AudioStreamMP3": true,
	"AudioStreamPlaylist": true,
	"Shader": true,
	"ShaderMaterial": true,
	"CanvasItemMaterial": true,
	"StandardMaterial3D": true,
	"ORMMaterial3D": true,
	"ParticleProcessMaterial": true,
	"Font": true,
	"FontFile": true,
	"FontVariation": true,
	"SystemFont": true,
	"Curve": true,
	"Curve2D": true,
	"Gradient": true,
	"StyleBoxFlat": true,
	"StyleBoxEmpty": true,
	"StyleBoxTexture": true,
	"Theme": true,
}
const _SCRIPT_CLASSES: PackedStringArray = [
	"Script", "GDScript", "CSharpScript", "VisualScript", "ScriptExtension", "NativeScript", "PluginScript",
]


static func asset_id_for(animation_name: String) -> String:
	var cleaned := animation_name.strip_edges().to_lower()
	cleaned = cleaned.replace("/", "_").replace(".", "_").replace(" ", "_").replace("-", "_")
	while cleaned.contains("__"):
		cleaned = cleaned.replace("__", "_")
	cleaned = cleaned.trim_prefix("_").trim_suffix("_")
	if cleaned == "":
		return ""
	return "anim_" + cleaned


## Empty string when [param bytes] look safe to parse as an Animation. Otherwise a reason.
static func inspect(file_name: String, bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return "the file is empty."
	if _is_binary(bytes):
		return _inspect_binary(bytes)
	return _inspect_text(file_name, bytes)


## Decode a remote animation. Returns null and logs a warning when the file is refused.
static func decode_bytes(file_name: String, asset_id: String, bytes: PackedByteArray) -> Animation:
	var reason := inspect(file_name, bytes)
	if reason != "":
		_warn(asset_id, file_name, reason)
		return null
	var loaded := _load_temp(file_name, bytes)
	if loaded == null:
		_warn(asset_id, file_name, "Godot could not load it as an Animation.")
		return null
	if not (loaded is Animation):
		_warn(asset_id, file_name, "the loaded resource is %s, not an Animation." % loaded.get_class())
		return null
	var anim := loaded as Animation
	if _animation_has_script(anim):
		_warn(asset_id, file_name, "it contained a Script after loading.")
		return null
	var copy := anim.duplicate(true) as Animation
	return copy if copy != null else anim


## Replace [param animation_name] on [param player] with a copy of [param source].
## When that clip is playing, playback continues from the same time on the new clip.
## Returns an empty string on success, or a reason the scene clip was left alone.
static func install(player: AnimationPlayer, animation_name: String, source: Animation) -> String:
	if player == null or source == null or animation_name == "":
		return "missing player, animation, or name."
	var library_name := _library_name(animation_name)
	var clip := _clip_name(animation_name)
	if not player.has_animation_library(StringName(library_name)):
		return "AnimationPlayer has no library for '%s'." % animation_name
	var library := player.get_animation_library(StringName(library_name))
	if library == null or not library.has_animation(StringName(clip)):
		return "AnimationPlayer has no animation '%s' to replace. The scene clip is unchanged." % animation_name
	var copy := source.duplicate(true) as Animation
	if copy == null:
		return "could not copy animation '%s'." % animation_name
	remap_textures(copy)
	var playing_this := str(player.current_animation) == animation_name or str(player.assigned_animation) == animation_name
	var was_playing := playing_this and player.is_playing()
	var position := player.current_animation_position if playing_this else 0.0
	var scale := player.speed_scale
	library.remove_animation(StringName(clip))
	library.add_animation(StringName(clip), copy)
	if playing_this:
		player.speed_scale = scale
		player.play(animation_name)
		player.seek(_resume_time(copy, position), true)
		player.speed_scale = scale
		if not was_playing:
			player.pause()
	return ""


## Replace texture keys whose file name is a downloaded hot-swap id. Returns true when a key changed.
static func remap_textures(anim: Animation) -> bool:
	if anim == null or Assets.manager == null:
		return false
	var changed := false
	for track in anim.get_track_count():
		if anim.track_get_type(track) != Animation.TYPE_VALUE:
			continue
		for key in anim.track_get_key_count(track):
			var value: Variant = anim.track_get_key_value(track, key)
			if not (value is Texture2D):
				continue
			var tex := value as Texture2D
			var asset_id := _texture_asset_id(tex)
			if asset_id == "" or Assets.is_placeholder(asset_id):
				continue
			var swapped := Assets.fetch_texture(asset_id)
			if swapped == null or swapped == tex:
				continue
			anim.track_set_key_value(track, key, swapped)
			changed = true
	return changed


static func _warn(asset_id: String, file_name: String, reason: String) -> void:
	push_warning("[AssetManager] Rejected animation '%s' (%s): %s The scene animation is unchanged." % [asset_id, file_name, reason])


static func _is_binary(bytes: PackedByteArray) -> bool:
	if bytes.size() < 4:
		return false
	var magic := bytes.slice(0, 4).get_string_from_ascii()
	return magic == "RSRC" or magic == "RSCC"


static func _inspect_binary(bytes: PackedByteArray) -> String:
	var magic := bytes.slice(0, 4).get_string_from_ascii()
	if magic == "RSCC":
		return "compressed .res files are not supported. Save the Animation as .tres."
	var root := _binary_root_type(bytes)
	if root != "Animation":
		if root == "":
			return "it is not an Animation resource."
		return "the resource type is %s, not an Animation." % root
	for script_class in _SCRIPT_CLASSES:
		if _has_prefixed_string(bytes, script_class):
			return "it references a Script (%s)." % script_class
	if _bytes_contain(bytes, ".gd") or _bytes_contain(bytes, ".gdc") or _bytes_contain(bytes, ".cs") or _bytes_contain(bytes, "script/source"):
		return "it references a script path."
	return ""


static func _binary_root_type(bytes: PackedByteArray) -> String:
	# Godot 4 RSRC header: magic, endian, real64, major, minor, format, then the type string.
	if bytes.size() < 28:
		return ""
	var length := bytes.decode_u32(24)
	if length <= 0 or length > 128 or 28 + length > bytes.size():
		return ""
	return bytes.slice(28, 28 + length).get_string_from_utf8()


static func _as_text(bytes: PackedByteArray) -> String:
	return bytes.get_string_from_utf8()


static func _inspect_text(file_name: String, bytes: PackedByteArray) -> String:
	var text := _as_text(bytes).lstrip("\ufeff").strip_edges()
	if not text.begins_with("[gd_resource"):
		return "it is not a Godot Animation text resource (.tres). '%s' was refused." % file_name.get_extension()
	var header_end := text.find("]")
	if header_end == -1:
		return "the resource header is incomplete."
	var header := text.substr(0, header_end + 1)
	if header.find("script_class") != -1:
		return "it attaches a script class."
	var root_type := _attr(header, "type")
	if root_type != "Animation":
		if root_type == "":
			return "it is not an Animation resource."
		return "the resource type is %s, not an Animation." % root_type
	var section_re := RegEx.new()
	if section_re.compile("\\[(gd_resource|gd_scene|ext_resource|sub_resource|resource)([^\\]]*)\\]") != OK:
		return "the resource text could not be checked."
	for match in section_re.search_all(text):
		var kind := match.get_string(1)
		var body := match.get_string(2)
		if kind == "gd_scene":
			return "it is a scene, not an Animation. Save the Animation resource itself."
		if kind != "ext_resource" and kind != "sub_resource":
			continue
		var res_type := _attr(body, "type")
		var path := _attr(body, "path")
		if _is_script_type(res_type):
			return "it references a Script (%s)." % res_type
		if _path_is_script(path):
			return "it references a script path '%s'." % path
		if kind == "ext_resource" and path == "":
			return "an external resource has no path, so it cannot be checked for scripts."
		if res_type == "":
			return "a nested resource is missing a type."
		if not _SAFE_TYPES.has(res_type):
			return "it references '%s', which is not an allowed Animation dependency. Scripts and custom resources are refused." % res_type
	if _assigns_script(text) or text.find("script/source") != -1:
		return "it assigns a script property."
	return ""


static func _assigns_script(text: String) -> bool:
	var re := RegEx.new()
	if re.compile("(?m)^[\\t ]*script\\s*=") != OK:
		return true
	return re.search(text) != null


static func _attr(body: String, key: String) -> String:
	var re := RegEx.new()
	if re.compile(key + "\\s*=\\s*\"([^\"]*)\"") != OK:
		return ""
	var found := re.search(body)
	if found:
		return found.get_string(1)
	if re.compile(key + "\\s*=\\s*'([^']*)'") != OK:
		return ""
	found = re.search(body)
	if found:
		return found.get_string(1)
	return ""


static func _is_script_type(res_type: String) -> bool:
	if res_type == "":
		return false
	if res_type == "Script" or res_type.ends_with("Script"):
		return true
	return false


static func _path_is_script(path: String) -> bool:
	var lower := path.to_lower()
	return lower.ends_with(".gd") or lower.ends_with(".gdc") or lower.ends_with(".cs") or lower.ends_with(".csx")


static func _load_temp(file_name: String, bytes: PackedByteArray) -> Resource:
	var ext := file_name.get_extension().to_lower()
	if ext != "tres" and ext != "res":
		ext = "tres" if not _is_binary(bytes) else "res"
	var dir := "user://lost_framework/hotswap"
	if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		return null
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	var path := "%s/%s.%s" % [dir, ctx.finish().hex_encode().substr(0, 16), ext]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return null
	file.store_buffer(bytes)
	file.close()
	var loaded := ResourceLoader.load(path, "Animation", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.remove_absolute(path)
	return loaded


static func _animation_has_script(anim: Animation) -> bool:
	var seen := {}
	if _resource_has_script(anim, seen):
		return true
	for track in anim.get_track_count():
		var track_type := anim.track_get_type(track)
		for key in anim.track_get_key_count(track):
			if track_type == Animation.TYPE_VALUE or track_type == Animation.TYPE_METHOD:
				if _variant_has_script(anim.track_get_key_value(track, key), seen):
					return true
			elif track_type == Animation.TYPE_AUDIO:
				var stream: Resource = anim.audio_track_get_key_stream(track, key)
				if _resource_has_script(stream, seen):
					return true
	return false


static func _resource_has_script(resource: Resource, seen: Dictionary) -> bool:
	if resource == null:
		return false
	var instance_id := resource.get_instance_id()
	if seen.has(instance_id):
		return false
	seen[instance_id] = true
	if resource is Script or resource.get_script() != null:
		return true
	for prop in resource.get_property_list():
		var usage := int(prop.get("usage", 0))
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var prop_name := str(prop.get("name", ""))
		if prop_name == "" or prop_name == "script":
			continue
		if _variant_has_script(resource.get(prop_name), seen):
			return true
	return false


static func _variant_has_script(value: Variant, seen: Dictionary) -> bool:
	if value is Script:
		return true
	if value is Resource:
		return _resource_has_script(value, seen)
	if value is Array:
		for item in value:
			if _variant_has_script(item, seen):
				return true
	elif value is Dictionary:
		for key in value.keys():
			if _variant_has_script(key, seen) or _variant_has_script(value[key], seen):
				return true
	return false


static func _texture_asset_id(tex: Texture2D) -> String:
	var path := tex.resource_path
	if path == "":
		return ""
	var base := path.get_file().get_basename().to_lower()
	var re := RegEx.new()
	if re.compile("^[a-z][a-z0-9_]*(?:\\.[a-z][a-z0-9_]*)*$") != OK:
		return ""
	if re.search(base) == null:
		return ""
	return base


static func _library_name(animation_name: String) -> String:
	var sep := animation_name.find("/")
	if sep == -1:
		return ""
	return animation_name.substr(0, sep)


static func _clip_name(animation_name: String) -> String:
	var sep := animation_name.find("/")
	if sep == -1:
		return animation_name
	return animation_name.substr(sep + 1)


static func _resume_time(anim: Animation, position: float) -> float:
	if anim.length <= 0.0 or position <= 0.0:
		return 0.0
	if position <= anim.length:
		return position
	if anim.loop_mode == Animation.LOOP_NONE:
		return anim.length
	return fposmod(position, anim.length)


static func _has_prefixed_string(bytes: PackedByteArray, text: String) -> bool:
	var pat := text.to_utf8_buffer()
	var length := pat.size()
	if length <= 0 or bytes.size() < 4 + length:
		return false
	var last := bytes.size() - (4 + length)
	for i in last + 1:
		if bytes.decode_u32(i) != length:
			continue
		var matched := true
		for j in length:
			if bytes[i + 4 + j] != pat[j]:
				matched = false
				break
		if matched:
			return true
	return false


static func _bytes_contain(bytes: PackedByteArray, needle: String) -> bool:
	var pat := needle.to_ascii_buffer()
	if pat.is_empty() or bytes.size() < pat.size():
		return false
	var last := bytes.size() - pat.size()
	for i in last + 1:
		if bytes[i] != pat[0]:
			continue
		var matched := true
		for j in pat.size():
			if bytes[i + j] != pat[j]:
				matched = false
				break
		if matched:
			return true
	return false
