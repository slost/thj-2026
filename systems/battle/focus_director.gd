## Hover and pin focus for FocusTargetComponent hosts.
## Moves an indicator and fills a debug label, the same idea as the world map.
extends Node
class_name FocusDirector

const GROUP := &"focus_director"

@export var indicator: Node2D
@export var debug_label: Label

var _target: FocusTargetComponent
var _pinned: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	var viewport := get_viewport()
	if viewport:
		viewport.physics_object_picking = true
	_show_empty()


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		clear_selection()


func _process(_delta: float) -> void:
	if _target != null and (not is_instance_valid(_target) or not _target.can_focus()):
		_pinned = false
		_target = null
	_refresh()


## Hover focus. Ignored while a target is pinned.
func focus_target(target: FocusTargetComponent) -> void:
	if _pinned or target == null or not target.can_focus():
		return
	_set_target(target)


## Drop hover focus when the pointer leaves that target.
func unfocus_target(target: FocusTargetComponent) -> void:
	if _pinned or _target != target:
		return
	_set_target(null)


## Click focus. Stays until a click lands on empty space or another target.
func select_target(target: FocusTargetComponent) -> void:
	if target == null or not target.can_focus():
		return
	_pinned = true
	_set_target(target)


func clear_selection() -> void:
	_pinned = false
	_set_target(null)


func get_selected_unit() -> Unit2D:
	if not _pinned or _target == null or not is_instance_valid(_target):
		return null
	return _target.get_host() as Unit2D


func _set_target(target: FocusTargetComponent) -> void:
	if _target == target:
		_refresh()
		return
	_target = target
	_refresh()


func _refresh() -> void:
	if _target == null:
		_show_empty()
		return
	_place_indicator(_target.get_host() as Node2D)
	if debug_label:
		var text := _target.get_debug_text()
		if _pinned:
			text = "Pinned\n" + text
		debug_label.text = text


## The graphic sits on the unit node's origin (local position 0).
func _place_indicator(host: Node2D) -> void:
	if indicator == null:
		return
	if host == null:
		_show_empty()
		return
	indicator.visible = true
	indicator.global_position = host.global_position
	indicator.modulate = Color(1, 0.86, 0.45) if _pinned else Color.WHITE


func _show_empty() -> void:
	if indicator:
		indicator.visible = false
	if debug_label:
		debug_label.text = "Nothing focused"
