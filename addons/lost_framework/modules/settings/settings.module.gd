extends Refs.MODULE


const CONFIG_PATH := "user://settings.cfg" ## Window size, bus volume, and language saved in user://settings.cfg.

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

const LANGUAGES: Array[String] = ["en", "th"]
const LANGUAGE_LABELS := {
	"en": "English",
	"th": "ไทย",
}
const VOLUME_BUSES: Array[String] = ["Master", "BGM", "SFX", "Ambience", "Voice", "UI"]

var resolution_index: int = 0
var fullscreen: bool = false
var language := "th"

var _volumes: Dictionary = {}
var _dirty := false
var _save_timer: Timer


func _exit_tree() -> void:
	_write_config()


func _on_runtime_activate() -> void:
	_reset_volumes()
	_load()
	_sanitize()
	apply_audio()
	apply_language()
	apply_display()

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.2
	_save_timer.timeout.connect(_write_config)
	add_child(_save_timer)


## The browser page and the editor's embedded Game tab own the window, so leave them alone.
func can_change_window() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return false
	if DisplayServer.get_name() == "headless":
		return false
	return not Engine.is_embedded_in_editor()


func resolution_size(index: int = -1) -> Vector2i:
	var resolved := resolution_index if index < 0 else index
	return RESOLUTIONS[clampi(resolved, 0, RESOLUTIONS.size() - 1)]


func get_volume(bus_name: String) -> float:
	return float(_volumes.get(bus_name, 1.0))


func set_resolution_index(index: int) -> void:
	var next := clampi(index, 0, RESOLUTIONS.size() - 1)
	if next == resolution_index and not fullscreen:
		return
	resolution_index = next
	fullscreen = false
	apply_display()
	_persist_now()


func set_fullscreen(enabled: bool) -> void:
	if fullscreen == enabled:
		return
	fullscreen = enabled
	apply_display()
	_persist_now()


func set_volume(bus_name: String, linear: float) -> void:
	if not _volumes.has(bus_name):
		return

	var clamped := clampf(linear, 0.0, 1.0)
	if is_equal_approx(float(_volumes[bus_name]), clamped):
		return

	_volumes[bus_name] = clamped
	if is_instance_valid(Audio):
		Audio.set_volume(bus_name, clamped)
	_request_save()


func set_language(locale: String) -> void:
	if LANGUAGES.find(locale) == -1 or locale == language:
		return
	language = locale
	apply_language()
	_persist_now()


func flush() -> void:
	_write_config()


func apply_display() -> void:
	if not can_change_window():
		return

	var window := get_window()
	if window == null:
		return

	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		return

	var size := RESOLUTIONS[resolution_index]
	window.mode = Window.MODE_WINDOWED
	window.min_size = RESOLUTIONS[0]
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	if size.x >= usable.size.x or size.y >= usable.size.y:
		window.mode = Window.MODE_MAXIMIZED
		return

	window.size = size
	window.position = usable.position + (usable.size - size) / 2


func apply_audio() -> void:
	if not is_instance_valid(Audio):
		return
	for bus_name in VOLUME_BUSES:
		Audio.set_volume(bus_name, get_volume(bus_name))


func apply_language() -> void:
	TranslationServer.set_locale(language)
	# Game is a host-project autoload. Resolve it by path so this script still
	# parses in projects that do not register Game.
	var game := get_node_or_null("/root/Game")
	if game != null and "current_language" in game:
		game.set("current_language", language)


func _reset_volumes() -> void:
	_volumes.clear()
	for bus_name in VOLUME_BUSES:
		_volumes[bus_name] = 1.0


func _sanitize() -> void:
	resolution_index = clampi(resolution_index, 0, RESOLUTIONS.size() - 1)
	if LANGUAGES.find(language) == -1:
		language = "th"
	for bus_name in VOLUME_BUSES:
		_volumes[bus_name] = clampf(float(_volumes.get(bus_name, 1.0)), 0.0, 1.0)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return

	resolution_index = int(config.get_value("display", "resolution_index", resolution_index))
	fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	language = str(config.get_value("locale", "language", language))
	for bus_name in VOLUME_BUSES:
		_volumes[bus_name] = float(config.get_value("audio", bus_name, _volumes[bus_name]))


func _request_save() -> void:
	_dirty = true
	if _save_timer:
		_save_timer.start()


func _persist_now() -> void:
	_dirty = true
	_write_config()


func _write_config() -> void:
	if not _dirty:
		return

	var config := ConfigFile.new()
	config.set_value("display", "resolution_index", resolution_index)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("locale", "language", language)
	for bus_name in VOLUME_BUSES:
		config.set_value("audio", bus_name, get_volume(bus_name))

	if config.save(CONFIG_PATH) == OK:
		_dirty = false
