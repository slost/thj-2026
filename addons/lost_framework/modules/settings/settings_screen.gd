extends Control

const SettingsScript := preload("res://addons/lost_framework/modules/settings/settings.module.gd")

@export var resolution_value: Label
@export var resolution_previous: Button
@export var resolution_next: Button
@export var fullscreen_check: BaseButton
@export var display_hint: Label
@export var volume_list: Container
@export var language_value: Label
@export var language_previous: Button
@export var language_next: Button
@export var back_button: Button
@export_file("*.tscn") var back_scene_path: String = ""

const _DEFAULT_BACK_SCENE := "res://systems/game/main_menu.tscn"

signal closed

## When true, Back and Esc hide this screen instead of changing scene.
var embedded := false

var _rows: Array[Node] = []
var _closing := false


func _ready() -> void:
	_resolve_controls()
	_rows = _collect_rows()
	_connect_signals()
	_sync_from_settings()


func present_embedded() -> void:
	embedded = true
	_closing = false
	show()
	_sync_from_settings()


func close_embedded() -> void:
	if not embedded:
		return
	_on_back_pressed()


func _unhandled_input(event: InputEvent) -> void:
	# The pause menu owns Esc while this screen is embedded in a level.
	if embedded or _closing or not is_visible_in_tree() or not event.is_action_pressed("ui_cancel"):
		return
	if is_inside_tree():
		var viewport := get_viewport()
		if viewport:
			viewport.set_input_as_handled()
	_on_back_pressed()


func _settings():
	return get_node_or_null("/root/Settings")


func _resolve_controls() -> void:
	resolution_value = _control(resolution_value, "Center/Panel/Scroll/VBox/ResolutionSection/ResolutionSelector/Value") as Label
	resolution_previous = _control(resolution_previous, "Center/Panel/Scroll/VBox/ResolutionSection/ResolutionSelector/Previous") as Button
	resolution_next = _control(resolution_next, "Center/Panel/Scroll/VBox/ResolutionSection/ResolutionSelector/Next") as Button
	fullscreen_check = _control(fullscreen_check, "Center/Panel/Scroll/VBox/HBoxContainer/FullscreenSection/FullscreenCheck") as BaseButton
	fullscreen_check = _control(fullscreen_check, "Center/Panel/Scroll/VBox/FullscreenSection/FullscreenCheck") as BaseButton
	display_hint = _control(display_hint, "Center/Panel/Scroll/VBox/HBoxContainer/FullscreenSection/DisplayHint") as Label
	display_hint = _control(display_hint, "Center/Panel/Scroll/VBox/FullscreenSection/DisplayHint") as Label
	volume_list = _control(volume_list, "Center/Panel/Scroll/VBox/AudioList") as Container
	language_value = _control(language_value, "Center/Panel/Scroll/VBox/LanguageSection/LanguageSelector/Value") as Label
	language_previous = _control(language_previous, "Center/Panel/Scroll/VBox/LanguageSection/LanguageSelector/Previous") as Button
	language_next = _control(language_next, "Center/Panel/Scroll/VBox/LanguageSection/LanguageSelector/Next") as Button
	back_button = _control(back_button, "Center/Panel/Scroll/VBox/BackButton") as Button


func _control(current: Node, path: String) -> Node:
	if current:
		return current
	return get_node_or_null(path)


func _row_title(row: Node) -> Label:
	var title := row.get("title_label") as Label
	if title == null:
		title = row.get_node_or_null("Header/TitleLabel") as Label
	return title


func _row_slider(row: Node) -> HSlider:
	var slider := row.get("slider") as HSlider
	if slider == null:
		slider = row.get_node_or_null("Slider") as HSlider
	return slider


func _row_value(row: Node) -> Label:
	var value_label := row.get("value_label") as Label
	if value_label == null:
		value_label = row.get_node_or_null("Header/ValueLabel") as Label
	return value_label


func _collect_rows() -> Array[Node]:
	var rows: Array[Node] = []
	if volume_list == null:
		return rows
	for child in volume_list.get_children():
		if child.get("bus_name") != null and _row_slider(child) != null:
			rows.append(child)
	return rows


func _sync_from_settings() -> void:
	var settings = _settings()
	if settings == null:
		push_error("Settings autoload is missing.")
		return
	_show_resolution(int(settings.resolution_index))
	_show_fullscreen(bool(settings.fullscreen))
	for row in _rows:
		var title := _row_title(row)
		var key := str(row.get("label_key"))
		if title and not key.is_empty() and key != "<null>":
			title.text = key
		var slider := _row_slider(row)
		var value_label := _row_value(row)
		if slider == null:
			continue
		slider.set_value_no_signal(float(settings.get_volume(str(row.get("bus_name")))) * 100.0)
		_set_percent(value_label, slider.value)
	_show_language(str(settings.language))
	_update_window_controls()


func _connect_signals() -> void:
	_connect_step(resolution_previous, _on_resolution_previous)
	_connect_step(resolution_next, _on_resolution_next)
	_connect_step(language_previous, _on_language_previous)
	_connect_step(language_next, _on_language_next)
	if fullscreen_check and not fullscreen_check.toggled.is_connected(_on_fullscreen_toggled):
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	for row in _rows:
		var slider := _row_slider(row)
		if slider == null:
			continue
		slider.value_changed.connect(
			_on_volume_changed.bind(str(row.get("bus_name")), _row_value(row))
		)


func _connect_step(button: Button, handler: Callable) -> void:
	if button and not button.pressed.is_connected(handler):
		button.pressed.connect(handler)


func _update_window_controls() -> void:
	var settings = _settings()
	if display_hint == null:
		return
	var embedded := Engine.is_embedded_in_editor()
	var blocked := settings == null or not bool(settings.can_change_window())
	display_hint.visible = embedded or blocked


func _show_fullscreen(enabled: bool) -> void:
	if fullscreen_check == null:
		return
	fullscreen_check.set_pressed_no_signal(enabled)
	fullscreen_check.text = "settings.fullscreen" if enabled else "settings.window_mode"


func _show_resolution(index: int) -> void:
	if resolution_value == null:
		return
	var size := SettingsScript.RESOLUTIONS[clampi(index, 0, SettingsScript.RESOLUTIONS.size() - 1)]
	resolution_value.text = "%d×%d" % [size.x, size.y]


func _show_language(locale: String) -> void:
	if language_value == null:
		return
	language_value.text = str(SettingsScript.LANGUAGE_LABELS.get(locale, locale))


func _step_resolution(delta: int) -> void:
	var settings = _settings()
	if settings == null:
		push_error("Settings autoload is missing.")
		return
	var count := SettingsScript.RESOLUTIONS.size()
	var index := posmod(int(settings.resolution_index) + delta, count)
	_show_resolution(index)
	settings.set_resolution_index(index)
	_show_fullscreen(bool(settings.fullscreen))


func _step_language(delta: int) -> void:
	var settings = _settings()
	if settings == null:
		push_error("Settings autoload is missing.")
		return
	var count := SettingsScript.LANGUAGES.size()
	var current := SettingsScript.LANGUAGES.find(str(settings.language))
	var index := posmod(maxi(current, 0) + delta, count)
	var locale: String = SettingsScript.LANGUAGES[index]
	_show_language(locale)
	settings.set_language(locale)


func _on_resolution_previous() -> void:
	_step_resolution(-1)


func _on_resolution_next() -> void:
	_step_resolution(1)


func _on_fullscreen_toggled(enabled: bool) -> void:
	var settings = _settings()
	if settings:
		settings.set_fullscreen(enabled)
	_show_fullscreen(enabled)
	_update_window_controls()


func _on_volume_changed(value: float, bus_name: String, value_label: Label) -> void:
	_set_percent(value_label, value)
	var settings = _settings()
	if settings:
		settings.set_volume(bus_name, value / 100.0)


func _on_language_previous() -> void:
	_step_language(-1)


func _on_language_next() -> void:
	_step_language(1)


func _on_back_pressed() -> void:
	if _closing or (embedded and not visible):
		return
	var settings = _settings()
	if settings and settings.has_method("flush"):
		settings.flush()
	if embedded:
		hide()
		closed.emit()
		return
	_closing = true
	var path := back_scene_path if not back_scene_path.is_empty() else _DEFAULT_BACK_SCENE
	get_tree().call_deferred("change_scene_to_file", path)


func _set_percent(value_label: Label, value: float) -> void:
	if value_label:
		value_label.text = "%d%%" % roundi(value)
