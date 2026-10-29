## Code editor. Writes the selected minion's ON_UPDATE script in place.
extends Node2D

const _INK := Color(0.16, 0.12, 0.08)
const _HINT := Color(0.38, 0.3, 0.22)
const _RAM_ALERT := Color(0.78, 0.1, 0.08)

var _palette: BlockPalette
var _script: ScriptView
var _header: Control
var _name_label: Label
var _ram_label: Label
var _buttons: Array[Button] = []
var _group := ButtonGroup.new()
var _slot := 0
var _switching := false
var _layout_texture: Texture2D
var _ram_tween: Tween


func _ready() -> void:
	_disable_pan()
	_build_ui()
	_bind_slots()
	_show_slot(0)
	call_deferred("_fit_pages")


func _process(_delta: float) -> void:
	var sprite := $BookScreen as Sprite2D
	if sprite == null or sprite.texture == _layout_texture:
		return
	_fit_pages()


func _disable_pan() -> void:
	# The page controls sit in screen space. Panning the book would slide it
	# out from under a drag, so this screen keeps the book still.
	var pan := $Camera2D/MousePan as MousePanComponent
	if pan:
		pan.set_active(false)


func _build_ui() -> void:
	var layer := $CanvasLayer
	_palette = BlockPalette.new()
	_palette.name = "BlockPalette"
	_palette.return_line.connect(_on_return_line)
	layer.add_child(_palette)

	_header = Control.new()
	_header.name = "ScriptHeader"
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_row := HBoxContainer.new()
	title_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_row.offset_bottom = 32.0
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label = _label("", 22, _INK)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ram_label = _label("RAM  0 / 0", 22, _INK)
	_ram_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ram_label.custom_minimum_size = Vector2(150, 0)
	title_row.add_child(_name_label)
	title_row.add_child(_ram_label)
	var hint := _label("Targets and queued actions also use RAM at runtime.", 15, _HINT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint.offset_top = 32.0
	_header.add_child(title_row)
	_header.add_child(hint)
	layer.add_child(_header)

	_script = ScriptView.new()
	_script.name = "ScriptView"
	_script.place_block.connect(_on_place)
	_script.move_line.connect(_on_move)
	_script.remove_line.connect(_on_remove)
	_script.indent_line.connect(_on_indent)
	layer.add_child(_script)


func _bind_slots() -> void:
	var container := $CanvasLayer/UnitsContainer as HBoxContainer
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override(&"separation", 8)
	_group.allow_unpress = false
	for index in Game.roster.size():
		var node_name := "UnitButton%d" % (index + 1)
		var button := container.get_node_or_null(node_name) as Button
		if button == null:
			button = Button.new()
			button.name = node_name
			button.layout_mode = 2
			container.add_child(button)
		button.text = str(index + 1)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.button_group = _group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override(&"font_size", 22)
		button.pressed.connect(_on_slot_button.bind(index))
		_buttons.append(button)


func _fit_pages() -> void:
	var sprite := $BookScreen as Sprite2D
	if sprite == null or _palette == null:
		return
	var book := _book_rect(sprite)
	if book.size.x < 100.0 or book.size.y < 100.0:
		return
	var pages := BookLayout.page_uvs(sprite.texture)
	var left := _map_uv(book, pages[0]).grow(-10.0)
	var right := _map_uv(book, pages[1]).grow(-10.0)
	# Keep the script clear of the debug overlay pinned to the right edge.
	right = Rect2(right.position, Vector2(maxf(right.size.x - 64.0, 280.0), right.size.y))
	_place(_palette, left)
	var buttons_h := 48.0
	var header_h := 88.0
	var slots := $CanvasLayer/UnitsContainer as Control
	_place(slots, Rect2(right.position, Vector2(right.size.x, buttons_h)))
	_place(_header, Rect2(right.position + Vector2(0, buttons_h), Vector2(right.size.x, header_h)))
	var body := buttons_h + header_h
	_place(_script, Rect2(right.position + Vector2(0, body), Vector2(right.size.x, maxf(right.size.y - body, 80.0))))
	_layout_texture = sprite.texture


func _book_rect(sprite: Sprite2D) -> Rect2:
	var tex_size := Vector2(1920, 1080)
	if sprite.texture:
		tex_size = sprite.texture.get_size()
	var xform := sprite.get_global_transform_with_canvas()
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
	if _slot < _buttons.size():
		_buttons[_slot].button_pressed = true
	_switching = false
	var slot := Game.roster[_slot]
	_name_label.text = slot.display_name()
	_script.set_lines(slot.get_update_function().lines)
	_show_ram()


func _show_ram() -> void:
	var slot := _current_slot()
	if slot == null or _ram_label == null:
		return
	var used := slot.get_update_function().get_ram_cost()
	_ram_label.text = "RAM  %d / %d" % [used, slot.ram_max()]
	_ram_label.add_theme_color_override(&"font_color", _INK)


func _flash_ram() -> void:
	if _ram_label == null:
		return
	_ram_label.add_theme_color_override(&"font_color", _RAM_ALERT)
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


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label
