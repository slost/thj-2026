## Left page. Conditions and actions the player still owns.
## Dropping a script row here returns that block to the inventory.
class_name BlockPalette
extends Control

signal return_line(index: int)

const _CARD := preload("res://systems/code_editor/block_card.tscn")

@export var card_max_width: float = 440.0
@export var card_height: float = 40.0
@export var grid_gap: Vector2 = Vector2(16, 18)
@export var position_jitter: float = 8.0

var _showing_conditions := true
var _rebuild_queued := false
var _laying_out := false

@onready var _condition_tab: Button = %ConditionsTab
@onready var _action_tab: Button = %ActionsTab
@onready var _list: Control = %PaletteList


func _ready() -> void:
	_condition_tab.pressed.connect(_show_conditions)
	_action_tab.pressed.connect(_show_actions)
	if Game.block_inventory == null:
		push_error("BlockPalette: Game.block_inventory is missing")
		return
	Game.block_inventory.changed.connect(_queue_rebuild)
	if not _list.resized.is_connected(_layout_cards):
		_list.resized.connect(_layout_cards)
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
	var cards: Array[BlockCard] = []
	for block in Game.block_inventory.get_all():
		var is_condition := block is ConditionBlock
		if is_condition != _showing_conditions:
			continue
		var count := Game.block_inventory.get_count(block)
		var card := _CARD.instantiate() as BlockCard
		card.max_width = card_max_width
		card.block_height = card_height
		card.setup(block, count, true, 0)
		card.set_compact(true)
		card.allow_drag = count > 0
		card.drag_data = {"source": "palette", "block": block}
		card.accept_script_return = true
		card.script_drop_returned.connect(_on_script_dropped_on_card)
		card.layout_mode = 0
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		cards.append(card)
	cards.sort_custom(func(a: BlockCard, b: BlockCard) -> bool:
		return _spot(a.block_id()) < _spot(b.block_id())
	)
	for card in cards:
		_list.add_child(card)
	_layout_cards()


func _layout_cards() -> void:
	if _laying_out or _list == null:
		return
	var width := _list.size.x
	if width < 80.0:
		return
	_laying_out = true
	var x := grid_gap.x
	var y := grid_gap.y
	var row_height := card_height
	var bottom := grid_gap.y
	for child in _list.get_children():
		var card := child as BlockCard
		if card == null:
			continue
		var chip := card.size
		if chip.x < 24.0:
			chip = Vector2(card_max_width, card_height)
		var shift := _jitter(card.block_id())
		if x + chip.x + shift.x > width - 8.0 and x > grid_gap.x + 4.0:
			x = grid_gap.x
			y += row_height + grid_gap.y
			row_height = card_height
		card.position = Vector2(x, y) + shift
		card.size = chip
		x += chip.x + grid_gap.x
		row_height = maxf(row_height, chip.y + absf(shift.y))
		bottom = maxf(bottom, card.position.y + chip.y)
	_list.custom_minimum_size = Vector2(0, bottom + grid_gap.y)
	_laying_out = false


func _spot(block_id: String) -> int:
	return absi(block_id.hash())


func _jitter(block_id: String) -> Vector2:
	var hashed := absi(block_id.hash())
	var span := maxf(position_jitter, 0.0)
	if span <= 0.0:
		return Vector2.ZERO
	var x := fmod(float(hashed % 97), span * 2.0) - span
	var y := fmod(float((hashed / 97) % 97), span * 2.0) - span
	return Vector2(x, y * 0.65)


func _on_script_dropped_on_card(index: int) -> void:
	if index >= 0:
		return_line.emit(index)


func _line_index(data: Variant) -> int:
	if not data is Dictionary:
		return -1
	if str(data.get("source", "")) != "script":
		return -1
	return int(data.get("index", -1))
