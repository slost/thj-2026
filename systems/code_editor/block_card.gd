## One block shown as a paper card. The root stays still for layout and hit tests.
## Bob, tilt, and hover only move Visual.
class_name BlockCard
extends Control

signal line_pressed(index: int)
signal line_remove_requested(index: int)
signal group_remove_requested(index: int)
signal right_gesture_started(index: int)
signal right_gesture_finished(index: int, held_msec: int)
signal row_touched(index: int)
signal focus_left(index: int)
signal script_drop_returned(index: int, group: bool)
signal quick_add_requested(block: CodeBlock)
## Script rows forward a drop so it inserts below or into the block under the pointer.
signal block_drop_requested(at_position: Vector2, data: Variant)

## Palette cards take a script block dropped on them and send it back.
var accept_script_return := false

const _THEME := preload("res://systems/code_editor/editor_theme.tres")

@export var bob_pixels: float = 6.0
@export var drift_pixels: float = 5.0
@export var tilt_degrees: float = 2.2
@export var hover_lift: float = 3.0
@export var hover_scale: float = 1.045
@export var visual_inset_y: float = 2.0
@export var indent_pad: float = 8.0
@export var indent_step: float = 32.0
@export var max_width: float = 440.0
@export var block_height: float = 40.0
## Extra chip width past the words. Zero keeps the script block as wide as its text.
@export var display_extra: float = 0.0

var drag_data: Variant = null
var allow_drag := true
var line_index := -1

var _block: CodeBlock
var _count := 0
var _show_count := false
var _indent := 0
var _compact := false
var _selected := false
var _hovered := false
var _marked := false
var _ready_done := false
var _phase := 0.0
var _speed := 1.0
var _bob := 6.0
var _drift := 5.0
var _tilt := 0.02
var _wave_time := 0.0
## 1 while drifting, easing toward 0 while the pointer rests on the card.
var _motion := 1.0
var _shadow: Panel
var _press_button := MOUSE_BUTTON_LEFT
## Right-button drags delete the block and the lines nested under it.
var _drag_removes := false
var _right_armed := false
var _right_pressed_at := 0
var _active_drag: Dictionary = {}

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


func block_id() -> String:
	if _block == null:
		return ""
	return str(_block.id)


## Palette cards shrink to the words. Script rows stay full width and only the chip is short.
func set_compact(compact: bool) -> void:
	_compact = compact
	if _ready_done:
		_fit_compact()


func _ready() -> void:
	_ready_done = true
	if theme == null:
		theme = _THEME
	_phase = randf() * TAU
	_speed = randf_range(0.55, 1.05)
	_bob = bob_pixels * randf_range(0.75, 1.15)
	_drift = drift_pixels * randf_range(0.7, 1.15)
	_tilt = deg_to_rad(tilt_degrees) * randf_range(0.65, 1.25)
	_visual.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_visual.layout_mode = 0
	_highlight.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_highlight.layout_mode = 0
	_shadow = _make_plate(Color(0.12, 0.08, 0.04, 0.9), 14)
	move_child(_shadow, _visual.get_index())
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply()
	_fit_compact()
	_place_visual(0.0, 0.0, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_apply()
	elif what == NOTIFICATION_DRAG_END:
		_finish_remove_drag()


func _process(delta: float) -> void:
	var target := 0.0 if _hovered else 1.0
	_motion = lerpf(_motion, target, 1.0 - exp(-2.4 * delta))
	_wave_time += delta * _speed * _motion
	var wave := sin(_wave_time + _phase)
	var sway := cos(_wave_time * 0.7 + _phase)
	var lift := hover_lift if _hovered else 0.0
	var shown := hover_scale if _hovered else 1.0
	_place_visual(wave * _bob + lift, wave * _tilt, shown, sway * _drift)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index == MOUSE_BUTTON_RIGHT and line_index >= 0:
		if mouse.pressed:
			_press_button = mouse.button_index
			_right_armed = true
			_right_pressed_at = Time.get_ticks_msec()
			right_gesture_started.emit(line_index)
		elif _right_armed:
			_right_armed = false
			var held := Time.get_ticks_msec() - _right_pressed_at
			right_gesture_finished.emit(line_index, held)
		return
	if not mouse.pressed:
		return
	_press_button = mouse.button_index
	if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.double_click and line_index < 0:
		if _block != null and (not _show_count or _count > 0):
			quick_add_requested.emit(_block)
			accept_event()
		return
	if line_index < 0 or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	line_pressed.emit(line_index)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if accept_script_return and _script_drag_index(data) >= 0:
		return true
	return line_index >= 0 and _is_script_edit(data)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	_mark_handled(data)
	var returned := _script_drag_index(data)
	if accept_script_return and returned >= 0:
		var grouped := data is Dictionary and bool(data.get("group", false))
		script_drop_returned.emit(returned, grouped)
		return
	if line_index >= 0 and _is_script_edit(data):
		block_drop_requested.emit(at_position, data)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not allow_drag or drag_data == null:
		return null
	var payload: Dictionary = drag_data.duplicate() if drag_data is Dictionary else {}
	_drag_removes = false
	_active_drag = payload
	if line_index >= 0:
		line_pressed.emit(line_index)
	var preview := _make_preview()
	if _drag_removes:
		preview.modulate = Color(1.0, 0.72, 0.68)
	if get_viewport().gui_is_dragging():
		set_drag_preview(preview)
	else:
		preview.queue_free()
	return _active_drag


func _apply() -> void:
	if _title == null:
		return
	_title.text = BlockInventory.block_title(_block) if _block else "..."
	tooltip_text = BlockInventory.block_description(_block) if _block else ""
	_count_badge.visible = _show_count and _count > 0
	var count_pattern := LocaleText.resolve("ui.code_editor.count", "x{count}", "en")
	_count_label.text = count_pattern.format({"count": _count})
	var cost := _block.get_ram_cost() if _block else 0
	var ram_pattern := LocaleText.resolve("ui.code_editor.ram_badge", "{cost} RAM", "en")
	_ram_label.text = ram_pattern.format({"cost": cost})
	var condition := _block is ConditionBlock
	if _selected:
		_visual.theme_type_variation = &"ConditionCardSelected" if condition else &"ActionCardSelected"
	else:
		_visual.theme_type_variation = &"ConditionCard" if condition else &"ActionCard"
	_sync_highlight()
	var owned := not _show_count or _count > 0
	modulate = Color.WHITE if owned else get_theme_color(&"unowned_modulate", &"BlockCard")
	var can_drag := allow_drag and owned
	mouse_default_cursor_shape = Control.CURSOR_MOVE if can_drag else Control.CURSOR_ARROW
	_fit_compact()
	queue_redraw()


func _fit_compact() -> void:
	if not _compact or _visual == null:
		return
	var title_slot: Control = null
	if _title:
		title_slot = _title.get_parent() as Control
	if title_slot:
		title_slot.custom_minimum_size.x = _label_width(_title)
	var needed := _visual.get_combined_minimum_size().x + 8.0
	var fitted := Vector2(clampf(needed, 96.0, max_width) + _stock_width() + 8.0, block_height)
	custom_minimum_size = fitted
	size = fitted


func _text_width() -> float:
	var width := _label_width(_title) + 28.0
	if _ram_label != null and _ram_label.visible:
		width += _label_width(_ram_label) + 20.0
	return clampf(width, 96.0, max_width)


func _label_width(label: Label) -> float:
	if label == null:
		return 72.0
	var font := label.get_theme_font(&"font")
	if font == null:
		return 72.0
	var font_size := label.get_theme_font_size(&"font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _chip_rect() -> Rect2:
	if _compact:
		var block_width := maxf(size.x - _stock_width() - 4.0, 24.0)
		return Rect2(2.0, 1.0, block_width, maxf(size.y - 2.0, 12.0))
	var chip_height := block_height
	var y := maxf((size.y - chip_height) * 0.5, 0.0)
	var x := indent_pad + float(_indent) * indent_step
	var available := maxf(size.x - x - 8.0, 72.0)
	var width := minf(_text_width() + display_extra, available)
	return Rect2(x, y, maxf(width, 72.0), chip_height)


func _place_visual(y_offset: float, rotation_radians: float, shown_scale: float, x_offset: float = 0.0) -> void:
	if _visual == null:
		return
	var chip := _chip_rect()
	_sync_highlight()
	_visual.position = chip.position + Vector2(x_offset, y_offset)
	_visual.size = chip.size
	_visual.pivot_offset = _visual.size * 0.5
	_visual.rotation = rotation_radians
	_visual.scale = Vector2(shown_scale, shown_scale)
	_place_shadow(chip, y_offset, x_offset, rotation_radians)
	_place_stock()


func _make_preview() -> Control:
	var preview := (load("res://systems/code_editor/block_card.tscn") as PackedScene).instantiate() as BlockCard
	preview.theme = _THEME
	preview.max_width = max_width
	preview.block_height = block_height
	preview.setup(_block, _count, _show_count, 0)
	preview.set_compact(true)
	preview.allow_drag = false
	var preview_size := Vector2(_text_width(), block_height)
	preview.custom_minimum_size = preview_size
	preview.size = preview_size
	return preview


func _is_script_edit(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var source := str(data.get("source", ""))
	if source == "palette":
		return data.get("block") != null
	return source == "script" and int(data.get("index", -1)) >= 0


func _script_drag_index(data: Variant) -> int:
	if not data is Dictionary:
		return -1
	if str(data.get("source", "")) != "script":
		return -1
	return int(data.get("index", -1))


func _stock_width() -> float:
	if not _show_count or _count <= 0 or _count_label == null:
		return 0.0
	return _label_width(_count_label) + 18.0


func _place_stock() -> void:
	if _count_badge == null or _visual == null:
		return
	var show := _show_count and _count > 0
	_count_badge.visible = show
	if not show:
		return
	var stock := _count_badge.get_combined_minimum_size()
	_count_badge.size = stock
	var beat := sin(_wave_time * 1.65 + _phase + 1.8)
	var drift := cos(_wave_time * 0.85 + _phase + 0.6)
	var beside := _visual.position + Vector2(_visual.size.x + 8.0, maxf((_visual.size.y - stock.y) * 0.5, 0.0))
	_count_badge.position = beside + Vector2(drift * 3.5, beat * _bob * 0.85)
	_count_badge.pivot_offset = stock * 0.5
	_count_badge.rotation = beat * 0.07


func _place_shadow(chip: Rect2, y_offset: float, x_offset: float, rotation_radians: float) -> void:
	if _shadow == null:
		return
	var risen := maxf(-y_offset, 0.0)
	_shadow.size = chip.size
	_shadow.pivot_offset = chip.size * 0.5
	_shadow.position = chip.position + Vector2(3.0 + x_offset * 0.2, 6.0 + risen * 0.55)
	_shadow.rotation = rotation_radians * 0.35
	var closeness := clampf(1.0 - risen / 22.0, 0.84, 1.0)
	_shadow.scale = Vector2(closeness, closeness)
	_shadow.modulate = Color(1, 1, 1, clampf(0.5 - risen * 0.012, 0.2, 0.5))


func _make_plate(color: Color, radius: int) -> Panel:
	var plate := Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.layout_mode = 0
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	plate.add_theme_stylebox_override(&"panel", style)
	add_child(plate)
	return plate


func _sync_highlight() -> void:
	if _highlight == null:
		return
	var show := line_index >= 0 and (_hovered or _marked)
	if not show:
		_highlight.color = Color(0, 0, 0, 0)
	elif _marked:
		_highlight.color = Color(0.78, 0.1, 0.08, 0.42)
	else:
		_highlight.color = Color(0.55, 0.38, 0.16, 0.22)
	_highlight.position = Vector2.ZERO
	_highlight.size = size


func set_marked(marked: bool) -> void:
	_marked = marked
	_sync_highlight()


func _finish_remove_drag() -> void:
	if not _drag_removes:
		return
	_drag_removes = false
	_right_armed = false
	var handled := bool(_active_drag.get("handled", false))
	var grouped := bool(_active_drag.get("group", false))
	var index := int(_active_drag.get("index", line_index))
	_active_drag = {}
	if handled or index < 0:
		return
	if grouped:
		group_remove_requested.emit(index)
	else:
		line_remove_requested.emit(index)


func _mark_handled(data: Variant) -> void:
	if data is Dictionary:
		data["handled"] = true


func _on_mouse_entered() -> void:
	_hovered = true
	z_index = 1
	_sync_highlight()
	if line_index >= 0:
		row_touched.emit(line_index)


func _on_mouse_exited() -> void:
	_hovered = false
	z_index = 0
	_sync_highlight()
	if line_index >= 0:
		focus_left.emit(line_index)
		release_focus()
