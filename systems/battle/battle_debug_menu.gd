## Always-running battle controls: delete the pinned unit, spawn, pause.
extends VBoxContainer
class_name BattleDebugMenu

var _delete: Button
var _pause: Button
var _unit_debug: Button
var _situations: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -520.0
	offset_top = UiPalette.SCREEN_MARGIN
	offset_right = -UiPalette.SCREEN_MARGIN
	offset_bottom = 480.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	clip_contents = true

	var title := Label.new()
	title.text = "Debug"
	title.theme_type_variation = &"LabelTitle"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var actions := _button_grid()
	add_child(actions)
	_delete = _add_button(actions, "Delete Unit", _on_delete, &"ButtonDanger")
	_add_button(actions, "Spawn Minion", _on_spawn_minion)
	_add_button(actions, "Spawn Villager", _on_spawn_villager)
	_unit_debug = _add_button(actions, "Hide Unit Debug", _on_toggle_debug)
	_pause = _add_button(actions, "Pause", _on_pause)
	var situations := Label.new()
	situations.text = "Situation"
	situations.theme_type_variation = &"LabelMuted"
	situations.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(situations)
	var cases := _button_grid()
	add_child(cases)
	_situations.append(_add_button(cases, "Enemy In Attack", _on_attack_range))
	_situations.append(_add_button(cases, "Enemy In Detect", _on_detect_range))
	_situations.append(_add_button(cases, "Enemy Out Of Range", _on_out_of_range))
	_situations.append(_add_button(cases, "Low HP", _on_low_hp))
	_situations.append(_add_button(cases, "Full HP", _on_full_hp))
	_situations.append(_add_button(cases, "Clear Memory", _on_clear_memory))


func _process(_delta: float) -> void:
	var director := _director()
	var pinned := director != null and director.get_selected_unit() != null
	if _delete:
		_delete.disabled = not pinned
	for button in _situations:
		button.disabled = not pinned
	if _pause:
		var paused := get_tree() != null and get_tree().paused
		_pause.text = "Unpause" if paused else "Pause"
	var battle := _battle()
	if _unit_debug and battle and battle.has_method("is_unit_debug_visible"):
		var shown: bool = battle.call("is_unit_debug_visible")
		_unit_debug.text = "Hide Unit Debug" if shown else "Show Unit Debug"


func _button_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return grid


func _add_button(parent: Node, label: String, callback: Callable, variation: StringName = &"") -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, UiPalette.BUTTON_HUD)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	if variation != &"":
		button.theme_type_variation = variation
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _on_delete() -> void:
	_call_battle(&"delete_selected_unit")


func _on_spawn_minion() -> void:
	_call_battle(&"spawn_minion")


func _on_spawn_villager() -> void:
	_call_battle(&"spawn_villager")


func _on_pause() -> void:
	_call_battle(&"toggle_pause")


func _on_toggle_debug() -> void:
	_call_battle(&"toggle_unit_debug")


func _on_attack_range() -> void:
	_call_battle(&"situation_in_attack_range")


func _on_detect_range() -> void:
	_call_battle(&"situation_in_detect_range")


func _on_out_of_range() -> void:
	_call_battle(&"situation_out_of_range")


func _on_low_hp() -> void:
	_call_battle(&"situation_low_hp")


func _on_full_hp() -> void:
	_call_battle(&"situation_full_hp")


func _on_clear_memory() -> void:
	_call_battle(&"situation_clear_memory")


func _battle() -> Node:
	var ui := get_parent()
	if ui == null:
		return null
	return ui.get_parent()


func _call_battle(method: StringName) -> void:
	var battle := _battle()
	if battle:
		battle.call(method)


func _director() -> FocusDirector:
	var battle := _battle()
	if battle == null:
		return null
	return battle.get_node_or_null("FocusDirector") as FocusDirector
