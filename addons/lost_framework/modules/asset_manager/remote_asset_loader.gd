extends Node
class_name RemoteAssetLoader
## Downloads a hot-swap manifest and decodes texture/audio bytes.
##
## AssetManager owns one of these when remote loading is enabled. The queue,
## cache-busting, and decoders follow the jam starter kit that was checked on
## Godot 4.2/4.3 desktop and web: per-file hashes, a capped number of downloads,
## and reload() fetching only files whose hash changed.
##
## Godot 4.4+ can load WAV with AudioStreamWAV.load_from_buffer. The parser
## below stays so 4.3 exports keep working. Web export with threads off needs
## 4.3+ templates; 4.2 has no nothreads web template.
##
## Web exports do not use HTTPRequest. Pages serves gzip, the browser decodes
## it, and HTTPRequest (HTTPClientWeb) still tries to decompress the body.
## Godot 4.8-beta1 then prints
## `Condition "err != 0 && err != 1" is true. Returning: FAILED`
## from stream_peer_gzip.cpp, and request_completed is result 8 with HTTP 200
## and an empty body. An uncompressed local response does not hit that path.
## The web path below calls fetch() with no custom headers (a header would make
## Pages answer a CORS preflight it does not handle) and reads the ArrayBuffer
## as base64.

## A remote file decoded successfully. [param file_hash] may be empty.
signal asset_ready(id: String, resource: Resource, file_hash: String)
## Manifest request finished. [param data] is the parsed object, or empty on failure.
signal manifest_ready(ok: bool, data: Dictionary)
## The queue for this reload() is finished (success, failure, or nothing to download).
signal queue_drained

const MANIFEST_NAME := "manifest.json"
const REQUEST_TIMEOUT_SEC := 30.0
## Installed once on window. fetch() is called with the URL only: no headers,
## mode, or cache option. The queue slot stays "" until the body is ready.
const _WEB_FETCH_START := """(function (url) {
	if (!window.__lostHotswapFetch) {
		window.__lostHotswapQueue = [];
		window.__lostHotswapFetch = function (target) {
			var id = window.__lostHotswapQueue.length;
			window.__lostHotswapQueue.push("");
			fetch(target).then(function (response) {
				return response.arrayBuffer().then(function (buffer) {
					var bytes = new Uint8Array(buffer);
					var parts = [];
					var step = 0x8000;
					for (var i = 0; i < bytes.length; i += step) {
						parts.push(String.fromCharCode.apply(null, bytes.subarray(i, Math.min(i + step, bytes.length))));
					}
					window.__lostHotswapQueue[id] = String(response.status) + " " + btoa(parts.join(""));
				});
			}).catch(function () {
				window.__lostHotswapQueue[id] = "0 ";
			});
			return id;
		};
		window.__lostHotswapPoll = function (id) {
			var item = window.__lostHotswapQueue[id];
			return item ? item : "";
		};
	}
	return window.__lostHotswapFetch(url);
})("""

var base_url: String = ""
var max_concurrent: int = 4
var manifest: Dictionary = {}
var is_loading: bool = false

var _resources: Dictionary = {} ## id -> Resource
var _remote_hash: Dictionary = {} ## id -> hash currently in use
var _queue: Array[Dictionary] = []
var _active: int = 0
var _generation: int = 0
var _warned_relative := false
var _web_jobs: Array[Dictionary] = []


static func select_configured_url(default_url: String, project_url: String, cmdline_url: String, query_url: String) -> String:
	var url := default_url.strip_edges()
	var project := project_url.strip_edges()
	if project != "":
		url = project
	var cmdline := cmdline_url.strip_edges()
	if cmdline != "":
		url = cmdline
	var query := query_url.strip_edges()
	if query != "":
		url = query
	return url


static func query_assets_override() -> String:
	if not OS.has_feature("web"):
		return ""
	var query: Variant = JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('assets') || ''", true)
	if query is String:
		return query.strip_edges()
	return ""


static func cmdline_assets_override() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--assets="):
			return arg.trim_prefix("--assets=").strip_edges()
	return ""


## Turn a configured base URL into an absolute URL that HTTPRequest can call.
## Relative URLs are resolved against the page on web export. Anywhere else they
## cannot be fetched, and the caller should keep placeholders.
static func resolve_configured(configured: String) -> String:
	var trimmed := configured.strip_edges()
	if trimmed == "" or trimmed == "off" or trimmed == "none":
		return ""
	var with_slash := trimmed if trimmed.ends_with("/") else trimmed + "/"
	if with_slash.begins_with("http://") or with_slash.begins_with("https://"):
		return with_slash
	if OS.has_feature("web"):
		var from_js := _absolute_url_from_page(with_slash)
		if from_js != "":
			return from_js
		var joined := join_url(_page_href(), with_slash)
		if joined.begins_with("http://") or joined.begins_with("https://"):
			return joined
	return ""


## Join [param relative] onto [param base_href] the way a browser resolves a URL
## against window.location (query and fragment on the page are dropped).
static func join_url(base_href: String, relative: String) -> String:
	var rel := relative.strip_edges()
	if rel.begins_with("http://") or rel.begins_with("https://"):
		return rel if rel.ends_with("/") or _has_file_suffix(rel) else rel + "/"
	var base := base_href.strip_edges()
	var hash_at := base.find("#")
	if hash_at != -1:
		base = base.substr(0, hash_at)
	var query_at := base.find("?")
	if query_at != -1:
		base = base.substr(0, query_at)
	var scheme_sep := base.find("://")
	if scheme_sep == -1:
		return ""
	var path_at := base.find("/", scheme_sep + 3)
	var origin := base if path_at == -1 else base.substr(0, path_at)
	var path := "/" if path_at == -1 else base.substr(path_at)
	if rel.begins_with("/"):
		path = rel
	else:
		if not path.ends_with("/"):
			var slash := path.rfind("/")
			path = "/" if slash == -1 else path.substr(0, slash + 1)
		path += rel
	var query := ""
	var rel_query := path.find("?")
	if rel_query != -1:
		query = path.substr(rel_query)
		path = path.substr(0, rel_query)
	var keep_slash := path.ends_with("/")
	var parts := path.split("/")
	var stack: PackedStringArray = PackedStringArray()
	for part in parts:
		if part == "" or part == ".":
			continue
		if part == "..":
			if stack.size() > 0:
				stack.remove_at(stack.size() - 1)
			continue
		stack.append(part)
	var normalized := "/" + "/".join(stack)
	if keep_slash and not normalized.ends_with("/"):
		normalized += "/"
	return origin + normalized + query


static func _has_file_suffix(url: String) -> bool:
	var path := url
	var query_at := path.find("?")
	if query_at != -1:
		path = path.substr(0, query_at)
	var slash := path.rfind("/")
	var last := path.substr(slash + 1) if slash != -1 else path
	return last.find(".") != -1


static func _page_href() -> String:
	if not OS.has_feature("web"):
		return ""
	var href: Variant = JavaScriptBridge.eval("window.location.href", true)
	if href is String:
		return href
	return ""


static func _absolute_url_from_page(relative: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var abs_url: Variant = JavaScriptBridge.eval(
		"new URL(%s, window.location.href).href" % JSON.stringify(relative), true)
	if abs_url is String and (abs_url.begins_with("http://") or abs_url.begins_with("https://")):
		return abs_url
	return ""


func _ready() -> void:
	# Polling is only used for the web fetch() queue. Desktop downloads use HTTPRequest.
	set_process(false)


func apply_base_url(configured: String) -> String:
	var resolved := resolve_configured(configured)
	base_url = resolved
	var trimmed := configured.strip_edges()
	if resolved == "" and trimmed != "" and trimmed != "off" and trimmed != "none" and not _warned_relative:
		_warned_relative = true
		push_warning("[AssetManager] Base URL '%s' is relative and cannot be resolved here; using placeholders only." % trimmed)
	return resolved


func get_resource(id: String) -> Resource:
	if id == "":
		return null
	return _resources.get(id.to_lower()) as Resource


func key_for_resource(res: Resource) -> String:
	if res == null:
		return ""
	var instance_id := res.get_instance_id()
	for id in _resources.keys():
		var stored := _resources[id] as Resource
		if stored and stored.get_instance_id() == instance_id:
			return str(id)
	return ""


func pending_count() -> int:
	return _queue.size() + _active


func cancel() -> void:
	_generation += 1
	_queue.clear()
	_active = 0
	is_loading = false
	_free_requests()


func reload() -> void:
	_generation += 1
	var gen := _generation
	_queue.clear()
	_active = 0
	_free_requests()
	is_loading = true
	if base_url == "":
		manifest_ready.emit(false, {})
		_finish()
		return
	var url := base_url + MANIFEST_NAME + "?t=" + str(Time.get_ticks_usec()) + str(randi())
	_http_get(url, _on_manifest_completed, [gen])


func _free_requests() -> void:
	for child in get_children():
		if child is HTTPRequest:
			child.cancel_request()
			child.queue_free()
	# Drop in-flight web polls. reload() already bumped the generation, so a
	# late JavaScript result cannot complete the cancelled batch.
	_web_jobs.clear()


func _http_get(url: String, callback: Callable, extra: Array) -> void:
	if OS.has_feature("web"):
		_http_get_web(url, callback, extra)
		return
	var req := HTTPRequest.new()
	req.timeout = REQUEST_TIMEOUT_SEC
	add_child(req)
	req.request_completed.connect(
		func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
			callback.callv([result, code, headers, body, req] + extra),
		CONNECT_ONE_SHOT)
	var err := req.request(url)
	if err != OK:
		push_warning("[AssetManager] Could not start request %s (error %d)" % [url, err])
		req.queue_free()
		var args := [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), null] + extra
		(func() -> void: callback.callv(args)).call_deferred()


## Browser fetch(). No request headers: GitHub Pages does not answer the CORS
## preflight a custom header would trigger. Cache-busting is the query string
## already present on [param url]. The body comes back as base64 because
## JavaScriptBridge can return strings, not ArrayBuffers.
func _http_get_web(url: String, callback: Callable, extra: Array) -> void:
	var script := _WEB_FETCH_START + JSON.stringify(url) + ")"
	var raw: Variant = JavaScriptBridge.eval(script, true)
	if not (raw is int or raw is float):
		push_warning("[AssetManager] Web fetch did not start for %s" % url)
		var failed: Array = [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), null] + extra
		(func() -> void: callback.callv(failed)).call_deferred()
		return
	_web_jobs.append({
		"id": int(raw),
		"gen": _generation,
		"url": url,
		"callback": callback,
		"extra": extra,
		"started_msec": Time.get_ticks_msec(),
	})
	set_process(true)


func _process(_delta: float) -> void:
	if _web_jobs.is_empty():
		set_process(false)
		return
	# Completing a job may queue the next download. Snapshot first so that new
	# job is not dropped when this frame finishes.
	var batch: Array[Dictionary] = _web_jobs.duplicate()
	_web_jobs.clear()
	var now := Time.get_ticks_msec()
	var timeout_msec := int(REQUEST_TIMEOUT_SEC * 1000.0)
	var still: Array[Dictionary] = []
	for job in batch:
		if int(job["gen"]) != _generation:
			continue
		if now - int(job["started_msec"]) > timeout_msec:
			push_warning("[AssetManager] Web fetch timed out for %s" % str(job["url"]))
			_complete_web_job(job, HTTPRequest.RESULT_TIMEOUT, 0, PackedByteArray())
			continue
		var raw: Variant = JavaScriptBridge.eval("window.__lostHotswapPoll(%d)" % int(job["id"]), true)
		var text := str(raw)
		if text.is_empty() or text == "null" or text == "<null>":
			still.append(job)
			continue
		var result := HTTPRequest.RESULT_SUCCESS
		var code := 0
		var body := PackedByteArray()
		var split_at := text.find(" ")
		if split_at <= 0:
			result = HTTPRequest.RESULT_CONNECTION_ERROR
		else:
			code = text.substr(0, split_at).to_int()
			var encoded := text.substr(split_at + 1)
			if code <= 0:
				result = HTTPRequest.RESULT_CANT_CONNECT
				code = 0
			elif not encoded.is_empty():
				body = Marshalls.base64_to_raw(encoded)
		_complete_web_job(job, result, code, body)
	still.append_array(_web_jobs)
	_web_jobs = still
	if _web_jobs.is_empty():
		set_process(false)


func _complete_web_job(job: Dictionary, result: int, code: int, body: PackedByteArray) -> void:
	_complete_http(job["callback"] as Callable, job["extra"] as Array, result, code, body)


func _complete_http(callback: Callable, extra: Array, result: int, code: int, body: PackedByteArray) -> void:
	var args: Array = [result, code, PackedStringArray(), body, null]
	args.append_array(extra)
	callback.callv(args)


func _on_manifest_completed(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray, req: HTTPRequest, gen: int) -> void:
	if is_instance_valid(req):
		req.queue_free()
	if gen != _generation:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_warning("[AssetManager] Manifest fetch failed (result %d, HTTP %d). Using placeholders." % [result, code])
		manifest_ready.emit(false, {})
		_finish()
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Dictionary) or not (data.get("assets") is Dictionary):
		push_warning("[AssetManager] Manifest is not valid JSON with an 'assets' object.")
		manifest_ready.emit(false, {})
		_finish()
		return
	manifest = data
	var assets: Dictionary = data["assets"]
	for raw_id in assets.keys():
		var entry: Variant = assets[raw_id]
		if not (entry is Dictionary) or not entry.has("file"):
			push_warning("[AssetManager] Bad manifest entry for '%s'" % raw_id)
			continue
		var id := str(raw_id).to_lower()
		var file_hash := str(entry.get("hash", ""))
		if _remote_hash.get(id, null) == file_hash and file_hash != "":
			continue
		_queue.append({
			"id": id,
			"file": str(entry["file"]),
			"hash": file_hash,
			"type": str(entry.get("type", "")),
			"loop": entry.get("loop", null),
		})
	manifest_ready.emit(true, manifest)
	_pump(gen)


func _pump(gen: int) -> void:
	if gen != _generation:
		return
	while _active < maxi(1, max_concurrent) and not _queue.is_empty():
		var entry: Dictionary = _queue.pop_front()
		_active += 1
		var cache_buster: String = entry["hash"] if entry["hash"] != "" else str(manifest.get("version", Time.get_ticks_msec()))
		var url := base_url + _encode_path(entry["file"]) + "?v=" + str(cache_buster).uri_encode()
		_http_get(url, _on_file_completed, [gen, entry])
	if _active == 0 and _queue.is_empty():
		_finish()


func _on_file_completed(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray, req: HTTPRequest, gen: int, entry: Dictionary) -> void:
	if is_instance_valid(req):
		req.queue_free()
	if gen != _generation:
		return
	_active -= 1
	var id: String = entry["id"]
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_warning("[AssetManager] Download failed for '%s' (%s): result %d, HTTP %d. Keeping placeholder."
				% [id, entry["file"], result, code])
	else:
		var res := decode_bytes(str(entry["file"]), id, body, entry.get("loop", null))
		if res == null:
			push_warning("[AssetManager] Could not decode '%s' (%s). Keeping placeholder." % [id, entry["file"]])
		else:
			_resources[id] = res
			_remote_hash[id] = entry["hash"]
			asset_ready.emit(id, res, str(entry["hash"]))
	_pump(gen)


func _finish() -> void:
	is_loading = false
	queue_drained.emit()


func _encode_path(path: String) -> String:
	var parts := path.split("/", false)
	for i in parts.size():
		parts[i] = parts[i].uri_encode()
	return "/".join(parts)


static func infer_loop(asset_id: String, loop_override: Variant) -> bool:
	if loop_override is bool:
		return loop_override
	var id := asset_id.to_lower()
	return id.begins_with("bgm_") or id.begins_with("bgm.")


static func decode_bytes(file_name: String, asset_id: String, bytes: PackedByteArray, loop_override: Variant = null) -> Resource:
	if bytes.is_empty():
		return null
	var ext := file_name.get_extension().to_lower()
	var loop := infer_loop(asset_id, loop_override)
	match ext:
		"png", "jpg", "jpeg", "webp":
			var img := Image.new()
			var err: Error
			if ext == "png":
				err = img.load_png_from_buffer(bytes)
			elif ext == "webp":
				err = img.load_webp_from_buffer(bytes)
			else:
				err = img.load_jpg_from_buffer(bytes)
			if err != OK or img.is_empty():
				return null
			return ImageTexture.create_from_image(img)
		"ogg":
			var ogg := AudioStreamOggVorbis.load_from_buffer(bytes)
			if ogg != null:
				ogg.loop = loop
			return ogg
		"mp3":
			var mp3 := AudioStreamMP3.new()
			mp3.data = bytes
			if mp3.get_length() <= 0.0:
				return null
			mp3.loop = loop
			return mp3
		"wav":
			return parse_wav(bytes, loop)
	push_warning("[AssetManager] Unsupported file type '.%s' for '%s'" % [ext, asset_id])
	return null


## Minimal RIFF/WAVE parser -> AudioStreamWAV. Supports PCM 8/16/24/32-bit int and
## 32-bit float, mono or stereo (converted to 8 or 16-bit). Compressed WAV
## (ADPCM and similar) is not supported.
static func parse_wav(b: PackedByteArray, loop: bool) -> AudioStreamWAV:
	if b.size() < 44 or b.slice(0, 4).get_string_from_ascii() != "RIFF" \
			or b.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	var fmt := -1
	var channels := 0
	var rate := 0
	var bits := 0
	var pcm := PackedByteArray()
	var pos := 12
	while pos + 8 <= b.size():
		var cid := b.slice(pos, pos + 4).get_string_from_ascii()
		var csize := b.decode_u32(pos + 4)
		var start := pos + 8
		var end := mini(start + csize, b.size())
		if cid == "fmt " and csize >= 16:
			fmt = b.decode_u16(start)
			channels = b.decode_u16(start + 2)
			rate = b.decode_u32(start + 4)
			bits = b.decode_u16(start + 14)
			if fmt == 0xFFFE and csize >= 26:
				fmt = b.decode_u16(start + 24)
		elif cid == "data":
			pcm = b.slice(start, end)
		pos = start + csize + (csize & 1)
	if fmt == -1 or pcm.is_empty() or channels < 1 or channels > 2 or rate <= 0:
		return null
	var wav := AudioStreamWAV.new()
	wav.mix_rate = rate
	wav.stereo = channels == 2
	if fmt == 1 and bits == 8:
		var out := pcm.duplicate()
		for i in out.size():
			out[i] = out[i] ^ 0x80
		wav.format = AudioStreamWAV.FORMAT_8_BITS
		wav.data = out
	elif fmt == 1 and bits == 16:
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.data = pcm
	elif (fmt == 1 and (bits == 24 or bits == 32)) or (fmt == 3 and bits == 32):
		var step := bits / 8
		var n := pcm.size() / step
		var out := PackedByteArray()
		out.resize(n * 2)
		for i in n:
			var sample: int
			if fmt == 3:
				sample = int(clampf(pcm.decode_float(i * step), -1.0, 1.0) * 32767.0)
			else:
				sample = pcm.decode_s16(i * step + step - 2)
			out.encode_s16(i * 2, sample)
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.data = out
	else:
		push_warning("[AssetManager] Unsupported WAV encoding (format %d, %d-bit)" % [fmt, bits])
		return null
	if loop:
		var frame_bytes := (1 if wav.format == AudioStreamWAV.FORMAT_8_BITS else 2) * channels
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / frame_bytes
	return wav
