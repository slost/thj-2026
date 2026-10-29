## Left page. Every owned block, conditions and actions together.
## The top buttons choose the sort. Dropping a script row here returns that block.
class_name BlockPalette
extends Control

signal return_line(index: int)
signal return_group(index: int)
signal quick_add(block: CodeBlock)

const _CARD := preload("res://systems/code_editor/block_card.tscn")

enum SortMode { CONDITIONS, ACTIONS }

@export var card_max_width: float = 440.0
@export var card_height: float = 40.0
@export var grid_gap: Vector2 = Vector2(16, 18)
@export var position_jitter: float = 0.0

var _sort := SortMode.CONDITIONS
var _rebuild_queued := false
var _laying_out := false

@onready var _conditions_tab: Button = %SortConditions
@onready var _actions_tab: Button = %SortActions
@onready var _list: Control = %PaletteList


func _ready() -> void:
	_conditions_tab.pressed.connect(_set_sort.bind(SortMode.CONDITIONS))
	_actions_tab.pressed.connect(_set_sort.bind(SortMode.ACTIONS))
	if Game.block_inventory == null:
		push_error("BlockPalette: Game.block_inventory is missing")
		return
	Game.block_inventory.changed.connect(_queue_rebuild)
	if not _list.resized.is_connected(_layout_cards):
		_list.resized.connect(_layout_cards)
	_set_sort(SortMode.CONDITIONS)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _line_index(data) >= 0


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		data["handled"] = true
	var index := _line_index(data)
	if index < 0:
		return
	if data is Dictionary and bool(data.get("group", false)):
		return_group.emit(index)
	else:
		return_line.emit(index)


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild")


func _set_sort(mode: SortMode) -> void:
	_sort = mode
	_conditions_tab.set_pressed_no_signal(mode == SortMode.CONDITIONS)
	_actions_tab.set_pressed_no_signal(mode == SortMode.ACTIONS)
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
	var blocks: Array[CodeBlock] = Game.block_inventory.get_all()
	blocks.sort_custom(_before)
	var cards: Array[BlockCard] = []
	for block in blocks:
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
		card.quick_add_requested.connect(_on_quick_add)
		card.layout_mode = 0
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		cards.append(card)
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


func _before(a: CodeBlock, b: CodeBlock) -> bool:
	var a_kind := 0 if a is ConditionBlock else 1
	var b_kind := 0 if b is ConditionBlock else 1
	if _sort == SortMode.ACTIONS:
		a_kind = 1 - a_kind
		b_kind = 1 - b_kind
	if a_kind != b_kind:
		return a_kind < b_kind
	return BlockInventory.block_title(a).nocasecmp_to(BlockInventory.block_title(b)) < 0


func _jitter(block_id: String) -> Vector2:
	var hashed := absi(block_id.hash())
	var span := maxf(position_jitter, 0.0)
	if span <= 0.0:
		return Vector2.ZERO
	var x := fmod(float(hashed % 97), span * 2.0) - span
	var y := fmod(float((hashed / 97) % 97), span * 2.0) - span
	return Vector2(x, y * 0.65)


func _on_quick_add(block: CodeBlock) -> void:
	if block:
		quick_add.emit(block)


func _on_script_dropped_on_card(index: int, group: bool) -> void:
	if index < 0:
		return
	if group:
		return_group.emit(index)
	else:
		return_line.emit(index)


func _line_index(data: Variant) -> int:
	if not data is Dictionary:
		return -1
	if str(data.get("source", "")) != "script":
		return -1
	return int(data.get("index", -1))
