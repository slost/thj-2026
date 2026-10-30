extends CanvasLayer

const OPENING_VIDEO := "res://contents/opening.ogv"
const ENDING_VIDEO := "res://contents/ending.ogv"
const SettingsScreenScript := preload("res://addons/lost_framework/modules/settings/settings_screen.gd")

@onready var _menu: Control = $VBoxContainer
@onready var _settings: SettingsScreenScript = $SettingsScreen
@onready var _credits: Control = $Credits
@onready var _video: VideoStreamPlayer = $Credits/VideoStreamPlayer

var _closing_credits := false
var _cutscene_opening := false


func _ready() -> void:
	_prepare_audio_settings()
	_prepare_credits()
	_settings.closed.connect(_on_settings_closed)
	_video.finished.connect(_on_credits_finished)
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer = 100
	_set_game_gui_visible(false)
	if Game.consume_play_ending():
		_play_cutscene(ENDING_VIDEO, false)
	elif _is_boot_menu() and not Game.opening_played:
		_play_cutscene(OPENING_VIDEO, true)


func _exit_tree() -> void:
	_set_game_gui_visible(true)


func _unhandled_input(event: InputEvent) -> void:
	if _credits.visible and event.is_action_pressed(&"ui_cancel"):
		_close_credits()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _settings.visible:
		_settings.close_embedded()
		get_viewport().set_input_as_handled()


func _on_world_map_button_button_down():
	Game.begin_play()


func _on_tutorial_button_pressed() -> void:
	get_tree().change_scene_to_file(Game.TUTORIAL_SCENE)


func _on_battle_button_pressed():
	Game.enter_sandbox()
	

func _on_animation_button_pressed() -> void:
	get_tree().change_scene_to_file("res://systems/debug/animation_debug.tscn")


func _on_code_button_pressed() -> void:
	get_tree().change_scene_to_file("res://systems/code_editor/editor_standalone.tscn")


func _on_setting_button_pressed() -> void:
	_menu.hide()
	_settings.present_embedded()


func _on_settings_closed() -> void:
	if not _credits.visible:
		_menu.show()


func _on_credits_button_pressed() -> void:
	_play_cutscene(ENDING_VIDEO, false)


func _on_ending_button_pressed() -> void:
	_play_cutscene(ENDING_VIDEO, false)


func _on_unlock_capital_pressed() -> void:
	Game.unlock_capital_for_debug()


func _play_cutscene(path: String, opening: bool) -> void:
	_cutscene_opening = opening
	_menu.hide()
	_settings.hide()
	var stream := VideoStreamTheora.new()
	stream.file = path
	_video.stream = stream
	_video.volume = 0.0
	_credits.show()
	_video.play()
	_set_game_gui_visible(false)
	Game.play_bgm.call_deferred(Game.BGM_BATTLE)


func _on_credits_back_pressed() -> void:
	_close_credits()


func _on_credits_finished() -> void:
	_close_credits()


func _prepare_audio_settings() -> void:
	var vbox := _settings.get_node(^"Center/Panel/Scroll/VBox")
	for section_name: String in ["LanguageSection", "Separator", "HBoxContainer", "Separator2"]:
		var section := vbox.get_node_or_null(NodePath(section_name))
		if section:
			section.hide()
	_set_text(_settings.get_node_or_null(^"TitleLabel"), "Settings")
	_set_text(vbox.get_node_or_null(^"AudioLabel"), "Audio")
	_set_text(vbox.get_node_or_null(^"BackButton"), "Back")
	var titles := {
		"MasterRow": "Master",
		"MusicRow": "Music",
		"SfxRow": "SFX",
		"UiRow": "UI",
	}
	var audio_list := vbox.get_node(^"AudioList")
	for row_name: String in titles:
		var row := audio_list.get_node_or_null(NodePath(row_name))
		if row:
			row.set("label_key", titles[row_name])


func _prepare_credits() -> void:
	_video.volume = 0.0


func _close_credits() -> void:
	if _closing_credits or not _credits.visible:
		return
	_closing_credits = true
	var opening := _cutscene_opening
	_cutscene_opening = false
	_video.stop()
	_credits.hide()
	_closing_credits = false
	if opening:
		Game.opening_played = true
	_menu.show()
	Game.play_bgm(Game.BGM_TITLE)


func _is_boot_menu() -> bool:
	var tree := get_tree()
	return tree != null and get_parent() == tree.current_scene


func _set_game_gui_visible(shown: bool) -> void:
	var gui := get_node_or_null("/root/GUI")
	if gui and gui.has_method("set_suppressed"):
		gui.call("set_suppressed", not shown)


func _set_text(node: Node, value: String) -> void:
	if node:
		node.set("text", value)
