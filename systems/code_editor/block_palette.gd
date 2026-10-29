## Left page. Conditions and actions the player still owns.
## Dropping a script row here returns that block to the inventory.
class_name BlockPalette
extends Control

signal return_line(index: int)

const _CARD := preload("res://systems/code_editor/block_card.tscn")

var _showing_conditions := true
var _rebuild_queued := false

@onready var _condition_tab: Button = %ConditionsTab
@onready var _action_tab: Button = %ActionsTab
@onready var _list: VBoxContainer = %PaletteList


func _ready() -> void:
	_condition_tab.pressed.connect(_show_conditions)
	_action_tab.pressed.connect(_show_actions)
	if Game.block_inventory == null:
		push_error("BlockPalette: Game.block_inventory is missing")
		return
	Game.block_inventory.changed.connect(_queue_rebuild)
	_show_conditions()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _line_index(data) >= 0


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var index := _line_index(data)
	if index >= 0:
		return_line.emit(index)


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild")


func _show_conditions() -> void:
	_showing_conditions = true
	_condition_tab.set_pressed_no_signal(true)
	_action_tab.set_pressed_no_signal(false)
	_queue_rebuild()


func _show_actions() -> void:
	_showing_conditions = false
	_condition_tab.set_pressed_no_signal(false)
	_action_tab.set_pressed_no_signal(true)
	_queue_rebuild()


func _rebuild() -> void:
	_rebuild_queued = false
	if _list == null or Game.block_inventory == null:
		return
	for child in _list.get_children():
		var node := child as Node
		if node == null:
			continue
		_list.remove_child(node)
		node.free()
	for block in Game.block_inventory.get_all():
		var is_condition := block is ConditionBlock
		if is_condition != _showing_conditions:
			continue
		var count := Game.block_inventory.get_count(block)
		var card := _CARD.instantiate() as BlockCard
		card.setup(block, count, true, 0)
		card.allow_drag = count > 0
		card.drag_data = {"source": "palette", "block": block}
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_list.add_child(card)


func _line_index(data: Variant) -> int:
	if not data is Dictionary:
		return -1
	if str(data.get("source", "")) != "script":
		return -1
	return int(data.get("index", -1))
