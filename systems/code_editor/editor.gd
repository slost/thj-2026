## Code editor. Writes the selected minion's ON_UPDATE script in place.
## Page controls are children of this node, in the same world space as the book,
## so mouse pan slides the pages and the cards together.
extends Node2D

@export var slot_bar_height: float = 48.0
@export var header_height: float = 88.0
@export var page_inset: float = 10.0
@export var debug_gutter: float = 64.0
@export var min_body_height: float = 80.0
@export var drag_pan_scale: float = 0.35
@export var ram_alert_color: Color = Color(0.78, 0.1, 0.08, 1)

var _slot := 0
var _switching := false
var _layout_texture: Texture2D
var _ram_tween: Tween
var _pan_full := Vector2.ZERO

@onready var _book: Sprite2D = $BookScreen
@onready var _pan: MousePanComponent = $Camera2D/MousePan
@onready var _palette: BlockPalette = %BlockPalette
@onready var _script: ScriptView = %ScriptView
@onready var _name_label: Label = %NameLabel
@onready var _ram_label: Label = %RamLabel
@onready var _slots: HBoxContainer = %UnitsContainer
@onready var _slot_buttons: Array[Button] = [%UnitButton1, %UnitButton2, %UnitButton3, %UnitButton4]


func _ready() -> void:
	_pan_full = _pan.max_offset
	_palette.return_line.connect(_on_return_line)
	_script.place_block.connect(_on_place)
	_script.move_line.connect(_on_move)
	_script.remove_line.connect(_on_remove)
	_script.indent_line.connect(_on_indent)
	_bind_slots()
	_show_slot(0)
	call_deferred("_fit_pages")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_header()


func _process(_delta: float) -> void:
	if _pan:
		var scale := drag_pan_scale if get_viewport().gui_is_dragging() else 1.0
		var limit := _pan_full * scale
		if not _pan.max_offset.is_equal_approx(limit):
			_pan.max_offset = limit
	if _book == null or _book.texture == _layout_texture:
		return
	_fit_pages()


func _bind_slots() -> void:
	for index in _slot_buttons.size():
		var button := _slot_buttons[index]
		var shown := index < Game.roster.size()
		button.visible = shown
		if not shown:
			continue
		if not button.pressed.is_connected(_on_slot_button):
			button.pressed.connect(_on_slot_button.bind(index))


func _fit_pages() -> void:
	if _book == null or _palette == null:
		return
	var book := _book_rect(_book)
	if book.size.x < 100.0 or book.size.y < 100.0:
		return
	var pages := BookLayout.page_uvs(_book.texture)
	var left := _map_uv(book, pages[0]).grow(-page_inset)
	var right := _map_uv(book, pages[1]).grow(-page_inset)
	# Keep the script clear of the debug overlay pinned to the right edge.
	right = Rect2(right.position, Vector2(maxf(right.size.x - debug_gutter, 280.0), right.size.y))
	_place(_palette, left)
	var slots := _slots as Control
	_place(slots, Rect2(right.position, Vector2(right.size.x, slot_bar_height)))
	var header := %ScriptHeader as Control
	_place(header, Rect2(right.position + Vector2(0, slot_bar_height), Vector2(right.size.x, header_height)))
	var body := slot_bar_height + header_height
	_place(_script, Rect2(right.position + Vector2(0, body), Vector2(right.size.x, maxf(right.size.y - body, min_body_height))))
	_layout_texture = _book.texture


## World rect of the centered sprite, without the camera. Page controls use this
## same space, then the camera pans the book and the pages together.
func _book_rect(sprite: Sprite2D) -> Rect2:
	var tex_size := Vector2(1920, 1080)
	if sprite.texture:
		tex_size = sprite.texture.get_size()
	var xform := sprite.get_global_transform()
	var shown := tex_size * xform.get_scale()
	return Rect2(xform.origin - shown * 0.5, shown)


func _map_uv(book: Rect2, uv: Rect2) -> Rect2:
	return Rect2(
		book.position + Vector2(book.size.x * uv.position.x, book.size.y * uv.position.y),
		Vector2(book.size.x * uv.size.x, book.size.y * uv.size.y)
	)


func _place(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y


func _show_slot(index: int) -> void:
	if Game.roster.is_empty():
		return
	_switching = true
	_slot = clampi(index, 0, Game.roster.size() - 1)
	if _slot < _slot_buttons.size():
		_slot_buttons[_slot].button_pressed = true
	_switching = false
	var slot := Game.roster[_slot]
	_script.set_lines(slot.get_update_function().lines)
	_refresh_header()


func _refresh_header() -> void:
	var slot := _current_slot()
	if slot == null or _name_label == null:
		return
	_name_label.text = slot.display_name()
	_show_ram()


func _show_ram() -> void:
	var slot := _current_slot()
	if slot == null or _ram_label == null:
		return
	var used := slot.get_update_function().get_ram_cost()
	var pattern := LocaleText.resolve("ui.code_editor.ram", "RAM  {used} / {max}")
	_ram_label.text = pattern.format({"used": used, "max": slot.ram_max()})
	_ram_label.remove_theme_color_override(&"font_color")


func _flash_ram() -> void:
	if _ram_label == null:
		return
	_ram_label.add_theme_color_override(&"font_color", ram_alert_color)
	if _ram_tween:
		_ram_tween.kill()
	_ram_tween = create_tween()
	_ram_tween.tween_interval(0.45)
	_ram_tween.tween_callback(_show_ram)


func _on_slot_button(index: int) -> void:
	if _switching or index == _slot:
		return
	_show_slot(index)


func _on_place(block: CodeBlock, index: int, indent: int) -> void:
	var slot := _current_slot()
	if slot == null or block == null or Game.block_inventory == null:
		return
	var function := slot.get_update_function()
	if not ScriptEditing.fits_ram(function.get_ram_cost(), block, slot.ram_max()):
		_flash_ram()
		return
	if not Game.block_inventory.remove(block, 1):
		return
	ScriptEditing.insert_line(function.lines, index, indent, block)
	_script.refresh()
	_show_ram()


func _on_move(from_index: int, index: int, indent: int) -> void:
	var slot := _current_slot()
	if slot == null:
		return
	if ScriptEditing.move_lines(slot.get_update_function().lines, from_index, index, indent):
		_script.refresh()


func _on_remove(index: int) -> void:
	var slot := _current_slot()
	if slot == null:
		return
	var block := ScriptEditing.remove_line(slot.get_update_function().lines, index)
	if block and Game.block_inventory:
		Game.block_inventory.add(block, 1)
	_script.refresh()
	_show_ram()


func _on_return_line(index: int) -> void:
	_on_remove(index)


func _on_indent(index: int, delta: int) -> void:
	var slot := _current_slot()
	if slot == null:
		return
	ScriptEditing.nudge_indent(slot.get_update_function().lines, index, delta)
	_script.refresh()


func _current_slot() -> MinionSlot:
	if _slot < 0 or _slot >= Game.roster.size():
		return null
	return Game.roster[_slot]
