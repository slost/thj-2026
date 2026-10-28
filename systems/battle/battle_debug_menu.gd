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
	offset_left = -292.0
	offset_top = 24.0
	offset_right = -24.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_theme_constant_override(&"separation", 8)

	var title := Label.new()
	title.text = "Debug"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override(&"font_size", 28)
	add_child(title)

	_delete = _add_button("Delete Unit", _on_delete)
	_add_button("Spawn Minion", _on_spawn_minion)
	_add_button("Spawn Villager", _on_spawn_villager)
	_unit_debug = _add_button("Hide Unit Debug", _on_toggle_debug)
	_pause = _add_button("Pause", _on_pause)
	var situations := Label.new()
	situations.text = "Situation"
	situations.mouse_filter = Control.MOUSE_FILTER_IGNORE
	situations.add_theme_font_size_override(&"font_size", 20)
	add_child(situations)
	_situations.append(_add_button("Enemy In Attack", _on_attack_range))
	_situations.append(_add_button("Enemy In Detect", _on_detect_range))
	_situations.append(_add_button("Enemy Out Of Range", _on_out_of_range))
	_situations.append(_add_button("Low HP", _on_low_hp))
	_situations.append(_add_button("Full HP", _on_full_hp))
	_situations.append(_add_button("Clear Memory", _on_clear_memory))


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


func _add_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(260, 36)
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.add_theme_font_size_override(&"font_size", 18)
	button.pressed.connect(callback)
	add_child(button)
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
