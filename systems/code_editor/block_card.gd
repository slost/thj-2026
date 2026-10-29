## One block shown as a paper card. The root stays still for layout and hit tests.
## Bob, tilt, and hover only move Visual.
class_name BlockCard
extends Control

signal line_pressed(index: int)
signal line_remove_requested(index: int)

const _THEME := preload("res://systems/code_editor/editor_theme.tres")

@export var bob_pixels: float = 2.5
@export var tilt_degrees: float = 1.3
@export var hover_lift: float = 3.0
@export var hover_scale: float = 1.045
@export var visual_inset_y: float = 3.0
@export var indent_pad: float = 8.0
@export var indent_step: float = 32.0

var drag_data: Variant = null
var allow_drag := true
var line_index := -1

var _block: CodeBlock
var _count := 0
var _show_count := false
var _indent := 0
var _selected := false
var _hovered := false
var _ready_done := false
var _phase := 0.0
var _speed := 1.0
var _bob := 2.5
var _tilt := 0.02
var _wave_time := 0.0

@onready var _visual: PanelContainer = %Visual
@onready var _title: Label = %Title
@onready var _count_badge: Control = %CountBadge
@onready var _count_label: Label = %Count
@onready var _ram_label: Label = %Ram
@onready var _highlight: ColorRect = %Highlight


func setup(block: CodeBlock, count: int, show_count: bool, indent_level: int = 0) -> void:
	_block = block
	_count = count
	_show_count = show_count
	_indent = maxi(indent_level, 0)
	if _ready_done:
		_apply()


func set_selected(selected: bool) -> void:
	_selected = selected
	if _ready_done:
		_apply()


func displayed_title() -> String:
	if _title == null:
		return ""
	return _title.text


func visual_position() -> Vector2:
	if _visual == null:
		return Vector2.ZERO
	return _visual.position


func motion_phase() -> float:
	return _phase


func motion_speed() -> float:
	return _speed


func _ready() -> void:
	_ready_done = true
	if theme == null:
		theme = _THEME
	_phase = randf() * TAU
	_speed = randf_range(0.65, 1.35)
	_bob = bob_pixels * randf_range(0.75, 1.15)
	_tilt = deg_to_rad(tilt_degrees) * randf_range(0.65, 1.25)
	_visual.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply()
	_place_visual(0.0, 0.0, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_apply()


func _process(delta: float) -> void:
	_wave_time += delta * _speed
	var wave := sin(_wave_time + _phase)
	var lift := hover_lift if _hovered else 0.0
	var shown := hover_scale if _hovered else 1.0
	_place_visual(wave * _bob + lift, wave * _tilt, shown)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or line_index < 0:
		return
	if mouse.button_index == MOUSE_BUTTON_LEFT:
		line_pressed.emit(line_index)
	elif mouse.button_index == MOUSE_BUTTON_RIGHT:
		line_pressed.emit(line_index)
		line_remove_requested.emit(line_index)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not allow_drag or drag_data == null:
		return null
	if line_index >= 0:
		line_pressed.emit(line_index)
	set_drag_preview(_make_preview())
	return drag_data


func _draw() -> void:
	if _indent <= 0:
		return
	var color := get_theme_color(&"guide_color", &"BlockCard")
	for level in _indent:
		var x := indent_pad + float(level) * indent_step + 5.0
		draw_line(Vector2(x, 4.0), Vector2(x, maxf(size.y - 4.0, 8.0)), color, 1.0)


func _apply() -> void:
	if _title == null:
		return
	_title.text = BlockInventory.block_title(_block) if _block else "..."
	tooltip_text = _block.get_display_description() if _block else ""
	_count_badge.visible = _show_count
	var count_pattern := LocaleText.resolve("ui.code_editor.count", "x{count}")
	_count_label.text = count_pattern.format({"count": _count})
	var cost := _block.get_ram_cost() if _block else 0
	var ram_pattern := LocaleText.resolve("ui.code_editor.ram_badge", "{cost} RAM")
	_ram_label.text = ram_pattern.format({"cost": cost})
	var condition := _block is ConditionBlock
	if _selected:
		_visual.theme_type_variation = &"ConditionCardSelected" if condition else &"ActionCardSelected"
	else:
		_visual.theme_type_variation = &"ConditionCard" if condition else &"ActionCard"
	var wash := get_theme_color(&"selected_color", &"BlockCard")
	_highlight.color = wash if _selected else Color(wash.r, wash.g, wash.b, 0.0)
	var owned := not _show_count or _count > 0
	modulate = Color.WHITE if owned else get_theme_color(&"unowned_modulate", &"BlockCard")
	var can_drag := allow_drag and owned
	mouse_default_cursor_shape = Control.CURSOR_MOVE if can_drag else Control.CURSOR_ARROW
	queue_redraw()


func _place_visual(y_offset: float, rotation_radians: float, shown_scale: float) -> void:
	if _visual == null:
		return
	var x := indent_pad + float(_indent) * indent_step
	var width := maxf(size.x - x - 6.0, 24.0)
	var height := maxf(size.y - visual_inset_y * 2.0, 12.0)
	_visual.position = Vector2(x, visual_inset_y + y_offset)
	_visual.size = Vector2(width, height)
	_visual.pivot_offset = _visual.size * 0.5
	_visual.rotation = rotation_radians
	_visual.scale = Vector2(shown_scale, shown_scale)


func _make_preview() -> Control:
	var preview := (load("res://systems/code_editor/block_card.tscn") as PackedScene).instantiate() as BlockCard
	preview.theme = _THEME
	preview.setup(_block, _count, _show_count, 0)
	preview.allow_drag = false
	var preview_size := Vector2(maxf(size.x, 200.0), maxf(custom_minimum_size.y, 46.0))
	preview.custom_minimum_size = preview_size
	preview.size = preview_size
	return preview


func _on_mouse_entered() -> void:
	_hovered = true
	z_index = 1


func _on_mouse_exited() -> void:
	_hovered = false
	z_index = 0
