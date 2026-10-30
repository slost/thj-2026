## Hover and pin focus for FocusTargetComponent hosts.
## The focus indicator follows the pointer. The pin indicator stays on the click.
extends Node
class_name FocusDirector

const GROUP := &"focus_director"

@export var indicator: Node2D
@export var pin_indicator: Node2D
@export var debug_label: Label

var accepts_pointer := true

var _hover: FocusTargetComponent
var _pinned: FocusTargetComponent
var _ranges: Node2D
var _cues: Node2D


func _ready() -> void:
	add_to_group(GROUP)
	var viewport := get_viewport()
	if viewport:
		viewport.physics_object_picking = true
	_ensure_pin_indicator()
	_ensure_ranges()
	_ensure_cues()
	_show_empty()


func set_accepts_pointer(open: bool) -> void:
	accepts_pointer = open
	if open:
		return
	_hover = null
	_pinned = null
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not accepts_pointer:
		return
	if event is not InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed:
		return
	if mouse.button_index == MOUSE_BUTTON_RIGHT:
		if _issue_move_order():
			get_viewport().set_input_as_handled()
		return
	if mouse.button_index == MOUSE_BUTTON_LEFT:
		clear_selection()


func _process(_delta: float) -> void:
	if _hover != null and (not is_instance_valid(_hover) or not _hover.can_focus()):
		_hover = null
	if _pinned != null and (not is_instance_valid(_pinned) or not _pinned.can_focus()):
		_pinned = null
	_refresh()


## Hover focus. Still works while another target is pinned.
func focus_target(target: FocusTargetComponent) -> void:
	if not accepts_pointer or target == null or not target.can_focus():
		return
	_hover = target
	_refresh()


## Drop hover focus when the pointer leaves that target. The pin stays.
func unfocus_target(target: FocusTargetComponent) -> void:
	if _hover != target:
		return
	_hover = null
	_refresh()


## Click focus. Stays until a click lands on empty space or another target.
func select_target(target: FocusTargetComponent) -> void:
	if not accepts_pointer or target == null or not target.can_select():
		return
	_pinned = target
	_refresh()


## Right-click on a unit. True when the pinned minion queued an attack and should keep the pin.
func order_attack(target: FocusTargetComponent) -> bool:
	if not accepts_pointer or target == null or not target.can_focus():
		return false
	return _issue_attack_order(target)


func clear_selection() -> void:
	_pinned = null
	_refresh()


func get_selected_unit() -> Unit2D:
	if _pinned == null or not is_instance_valid(_pinned):
		return null
	return _pinned.get_host() as Unit2D


## Hovered unit when the pointer is on one, otherwise the pinned unit.
func get_inspected_unit() -> Unit2D:
	var shown := _hover if _hover != null else _pinned
	if shown == null or not is_instance_valid(shown):
		return null
	return shown.get_host() as Unit2D


func _issue_move_order() -> bool:
	var stage := _order_stage()
	var unit := get_selected_unit()
	if stage == null or unit == null:
		return false
	var camera := get_viewport().get_camera_2d()
	var world_pos := camera.get_global_mouse_position() if camera != null else get_viewport().get_mouse_position()
	return bool(stage.call("issue_move_order", unit, world_pos))


func _issue_attack_order(target: FocusTargetComponent) -> bool:
	var stage := _order_stage()
	var unit := get_selected_unit()
	var enemy := target.get_host() as Unit2D if target != null else null
	if stage == null or unit == null or enemy == null:
		return false
	return bool(stage.call("issue_attack_order", unit, enemy))


func _order_stage() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	var game := tree.root.get_node_or_null("Game")
	if game == null:
		return null
	var stage := game.get("current_stage") as Node
	if stage == null or not is_instance_valid(stage) or not stage.has_method("issue_move_order"):
		return null
	if not bool(stage.get("direct_orders")):
		return null
	return stage


func _ensure_pin_indicator() -> void:
	if pin_indicator != null or indicator == null:
		return
	pin_indicator = indicator.duplicate()
	pin_indicator.name = "PinIndicator"
	var parent := indicator.get_parent()
	if parent:
		parent.add_child(pin_indicator)
	pin_indicator.z_index = indicator.z_index - 1
	pin_indicator.visible = false


func _ensure_ranges() -> void:
	if _ranges != null:
		return
	var parent := indicator.get_parent() if indicator != null else get_parent()
	if parent == null:
		return
	var overlay := Node2D.new()
	overlay.name = "FocusRanges"
	overlay.z_index = 8
	overlay.set_script(load("res://systems/battle/focus_range_overlay.gd"))
	parent.add_child.call_deferred(overlay)
	_ranges = overlay


func _refresh() -> void:
	_place_indicator(indicator, _hover.get_host() as Node2D if _hover != null and _hover != _pinned else null, Color.WHITE)
	_place_indicator(pin_indicator, _pinned.get_host() as Node2D if _pinned != null else null, Color(1, 0.86, 0.45))
	var shown := _hover if _hover != null else _pinned
	_place_ranges(shown.get_host() as Unit2D if shown != null else null)
	_sync_cues()
	if debug_label == null:
		return
	if shown == null:
		debug_label.text = "Nothing focused"
		return
	var text := shown.get_debug_text()
	if _pinned != null and shown == _pinned:
		text = "Pinned\n" + text
	elif _pinned != null:
		text = "Focus\n" + text
	debug_label.text = text


func _place_indicator(sprite: Node2D, host: Node2D, tint: Color) -> void:
	if sprite == null:
		return
	if host == null:
		sprite.visible = false
		return
	sprite.visible = true
	sprite.global_position = host.global_position
	sprite.modulate = tint


func _place_ranges(unit: Unit2D) -> void:
	if _ranges == null:
		return
	if unit == null or unit.stats == null or unit.team == Unit2D.Team.VILLAGER:
		_ranges.visible = false
		return
	var tile := 128.0
	var nav: Node = null
	if get_tree():
		var nodes := get_tree().get_nodes_in_group(GridNav.GROUP)
		if not nodes.is_empty():
			nav = nodes[0]
	if nav and nav.has_method("get_tile_size"):
		tile = float(nav.call("get_tile_size"))
	_ranges.visible = true
	_ranges.global_position = unit.global_position
	_ranges.set("detect_radius", float(unit.stats.detect_range) * tile)
	_ranges.set("attack_radius", float(unit.stats.attack_range) * tile)
	_ranges.queue_redraw()


func _ensure_cues() -> void:
	if _cues != null and is_instance_valid(_cues):
		return
	var parent := indicator.get_parent() if indicator != null else get_parent()
	if parent == null:
		return
	var overlay := Node2D.new()
	overlay.name = "OrderCues"
	overlay.z_index = 30
	overlay.set_script(load("res://systems/battle/order_cues.gd"))
	parent.add_child(overlay)
	_cues = overlay


func _sync_cues() -> void:
	_ensure_cues()
	if _cues == null:
		return
	var unit := get_selected_unit()
	if unit == null:
		_cues.call("set_marks", PackedVector2Array(), PackedVector2Array(), PackedVector2Array())
		return
	var moves := PackedVector2Array()
	var attacks := PackedVector2Array()
	var nav := _grid()
	for action in unit.queue_actions:
		if action == null or not action.has_method("order_marker"):
			continue
		var mark: Variant = action.call("order_marker")
		if mark is Vector2i:
			var cell: Vector2i = mark
			moves.append(nav.cell_to_world(cell) if nav != null else Vector2(cell) * 128.0)
		elif mark is Vector2:
			attacks.append(mark)
	var walked: PackedVector2Array = unit.get_shown_path()
	_cues.call("set_marks", walked, moves, attacks)


func _grid() -> GridNav:
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group(GridNav.GROUP) as GridNav


func _show_empty() -> void:
	if indicator:
		indicator.visible = false
	if pin_indicator:
		pin_indicator.visible = false
	if _ranges:
		_ranges.visible = false
	if _cues:
		_cues.call("set_marks", PackedVector2Array(), PackedVector2Array(), PackedVector2Array())
	if debug_label:
		debug_label.text = "Nothing focused"
