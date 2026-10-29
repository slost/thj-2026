## Code editor. Writes the selected minion's ON_UPDATE script in place.
## Page controls live in this node's space, next to the book sprite. A shared
## camera pan moves both, including when this node sits on a CanvasLayer that
## follows the viewport. That layer is what keeps the pages above the portrait.
## This node does not own a camera. Standalone play uses editor_standalone.tscn.
## No class_name: this script reads the Game autoload, and a global class would
## be compiled before that autoload exists.
extends Node2D

signal closed

## Book the pages are laid onto. Empty uses the child BookScreen, for the standalone wrapper.
@export var book: Sprite2D

## Standalone play opens immediately. The world map leaves this off and calls open().
@export var active_on_ready: bool = true

@export var slot_bar_height: float = 44.0
@export var header_height: float = 70.0
@export var page_inset: float = 10.0
@export var menu_lift: float = 42.0
@export var palette_extra: float = 84.0
@export var debug_gutter: float = 64.0
@export var min_body_height: float = 80.0
## While a card is dragging, the current MousePan limit is multiplied by this
## so the book does not slide out from under the pointer.
@export var drag_pan_scale: float = 0.35
@export var ram_alert_color: Color = Color(0.78, 0.1, 0.08, 1)

var _active := false
var _slot := 0
var _switching := false
var _book: Sprite2D
var _page_uvs: Array[Rect2] = []
var _uv_texture: Texture2D
var _fit_origin := Vector2.ZERO
var _fit_scale := Vector2.ZERO
var _fit_visible := false
var _has_fit := false
var _ram_tween: Tween
var _pan: MousePanComponent
var _pan_full := Vector2.ZERO
var _pan_captured := false
## Original mouse filters, keyed by instance id, so close() can ignore clicks
## and open() can put them back. Freed controls drop out in _forget_control.
var _stored_mouse: Dictionary = {}

@onready var _palette: BlockPalette = %BlockPalette
@onready var _script: ScriptView = %ScriptView
@onready var _name_label: Label = %NameLabel
@onready var _ram_label: Label = %RamLabel
@onready var _slots: HBoxContainer = %UnitsContainer
@onready var _slot_buttons: Array[Button] = [%UnitButton1, %UnitButton2, %UnitButton3, %UnitButton4]


func _ready() -> void:
	# After ParallaxOffset (priority 10), so a moved book is fitted the same frame.
	process_priority = 20
	_resolve_book()
	_palette.return_line.connect(_on_return_line)
	_palette.return_group.connect(_on_remove_group)
	_palette.quick_add.connect(_on_quick_add)
	_script.place_block.connect(_on_place)
	_script.move_line.connect(_on_move)
	_script.remove_line.connect(_on_remove)
	_script.remove_group.connect(_on_remove_group)
	_script.remove_rows.connect(_on_remove_rows)
	_script.indent_line.connect(_on_indent)
	_watch_input_tree(self)
	if active_on_ready:
		open()
	else:
		_set_input_enabled(false)
		visible = false
	call_deferred("_fit_pages_if_needed")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_header()


func _process(_delta: float) -> void:
	if _active:
		_update_drag_pan()
	_fit_pages_if_needed()


func is_open() -> bool:
	return _active


## Shows the editor and re-reads Game.roster and the block inventory.
func open() -> void:
	var was_open := _active
	_active = true
	visible = true
	_set_input_enabled(true)
	if not was_open:
		_pan = null
		_pan_captured = false
		_capture_pan()
	refresh()
	_has_fit = false
	_fit_pages_if_needed()


## Ignores pointer, drag, and editor shortcuts until open().
func close() -> void:
	var was_open := _active
	_active = false
	visible = false
	_set_input_enabled(false)
	_release_drag_pan()
	if was_open:
		closed.emit()


func set_active(active: bool) -> void:
	if active:
		open()
	else:
		close()


## Re-reads Game.roster and Game.block_inventory into the pages.
func refresh() -> void:
	_bind_slots()
	if _palette:
		_palette.refresh()
	_show_slot(_slot)


func _set_input_enabled(enabled: bool) -> void:
	if _script:
		_script.set_input_enabled(enabled)
	_apply_input_gate()


func _watch_input_tree(node: Node) -> void:
	if not node.child_entered_tree.is_connected(_on_input_child_entered):
		node.child_entered_tree.connect(_on_input_child_entered)
	for child in node.get_children():
		_claim_control(child)
		_watch_input_tree(child)


func _on_input_child_entered(child: Node) -> void:
	_claim_control(child)
	_watch_input_tree(child)


func _apply_input_gate() -> void:
	_apply_input_gate_from(self)


func _apply_input_gate_from(node: Node) -> void:
	_claim_control(node)
	for child in node.get_children():
		_apply_input_gate_from(child)


func _claim_control(node: Node) -> void:
	var control := node as Control
	if control == null:
		return
	var id := control.get_instance_id()
	if not _stored_mouse.has(id):
		_stored_mouse[id] = control.mouse_filter
		control.tree_exiting.connect(_forget_control.bind(id), CONNECT_ONE_SHOT)
	var stored: Control.MouseFilter = _stored_mouse[id] as Control.MouseFilter
	control.mouse_filter = stored if _active else Control.MOUSE_FILTER_IGNORE


func _forget_control(id: int) -> void:
	_stored_mouse.erase(id)


func _resolve_book() -> void:
	var owned := get_node_or_null(^"BookScreen") as Sprite2D
	if is_instance_valid(book):
		_book = book
	else:
		_book = owned
	if owned != null and owned != _book:
		owned.visible = false
	elif owned != null:
		owned.visible = true
	_uv_texture = null
	_page_uvs.clear()
	_has_fit = false


func _capture_pan() -> void:
	var pan := _resolve_pan()
	if pan == null:
		return
	_pan_full = pan.max_offset
	_pan_captured = true


func _resolve_pan() -> MousePanComponent:
	if is_instance_valid(_pan):
		return _pan
	if not is_inside_tree():
		return null
	_pan = get_tree().get_first_node_in_group(&"mouse_pan") as MousePanComponent
	return _pan


func _update_drag_pan() -> void:
	var pan := _resolve_pan()
	if pan == null:
		return
	if not _pan_captured:
		_pan_full = pan.max_offset
		_pan_captured = true
	var viewport := get_viewport()
	var dragging := viewport != null and viewport.gui_is_dragging()
	var limit := _pan_full * (drag_pan_scale if dragging else 1.0)
	if not pan.max_offset.is_equal_approx(limit):
		pan.max_offset = limit


func _release_drag_pan() -> void:
	if _pan_captured and is_instance_valid(_pan):
		_pan.max_offset = _pan_full
	_pan_captured = false
	_pan = null


func _fit_pages_if_needed() -> void:
	if _book == null or not is_instance_valid(_book):
		return
	var relative := get_global_transform().affine_inverse() * _book.get_global_transform()
	var origin := relative.origin
	var scale := relative.get_scale()
	var shown := _book.is_visible_in_tree()
	var same_texture := _book.texture == _uv_texture
	var same_place := origin.is_equal_approx(_fit_origin) and scale.is_equal_approx(_fit_scale)
	if _has_fit and same_texture and same_place and shown == _fit_visible:
		return
	if not _fit_pages():
		return
	_fit_origin = origin
	_fit_scale = scale
	_fit_visible = shown
	_has_fit = true


func _bind_slots() -> void:
	for index in _slot_buttons.size():
		var button := _slot_buttons[index]
		var shown := index < Game.roster.size()
		button.visible = shown
		if not shown:
			continue
		if not button.pressed.is_connected(_on_slot_button):
			button.pressed.connect(_on_slot_button.bind(index))


func _fit_pages() -> bool:
	if _book == null or not is_instance_valid(_book) or _palette == null:
		return false
	var book_rect := _book_rect(_book)
	if book_rect.size.x < 100.0 or book_rect.size.y < 100.0:
		return false
	if _page_uvs.size() < 2 or _book.texture != _uv_texture:
		_page_uvs = BookLayout.page_uvs(_book.texture)
		_uv_texture = _book.texture
	if _page_uvs.size() < 2:
		return false
	var left := _map_uv(book_rect, _page_uvs[0]).grow(-page_inset)
	left.position.y -= palette_extra * 0.4
	left.size.y += palette_extra
	var right := _map_uv(book_rect, _page_uvs[1]).grow(-page_inset)
	# Keep the script clear of the debug overlay pinned to the right edge.
	right = Rect2(right.position, Vector2(maxf(right.size.x - debug_gutter, 280.0), right.size.y))
	_place(_palette, left)
	var slots := _slots as Control
	var menu_y := right.position.y - menu_lift
	_place(slots, Rect2(Vector2(right.position.x, menu_y), Vector2(right.size.x, slot_bar_height)))
	var header := %ScriptHeader as Control
	_place(header, Rect2(Vector2(right.position.x, menu_y + slot_bar_height), Vector2(right.size.x, header_height)))
	var script_top := menu_y + slot_bar_height + header_height
	_place(_script, Rect2(Vector2(right.position.x, script_top), Vector2(right.size.x, maxf(right.end.y - script_top, min_body_height))))
	return true


## Rect of the centered sprite in this node's space, without the camera.
## A parent that pans or parallaxes both nodes does not change this rect,
## so the pages stay glued to the book instead of being offset twice.
func _book_rect(sprite: Sprite2D) -> Rect2:
	var tex_size := Vector2(1920, 1080)
	if sprite.texture:
		tex_size = sprite.texture.get_size()
	var xform := get_global_transform().affine_inverse() * sprite.get_global_transform()
	var shown := tex_size * xform.get_scale()
	return Rect2(xform.origin - shown * 0.5, shown)


func _map_uv(book_rect: Rect2, uv: Rect2) -> Rect2:
	return Rect2(
		book_rect.position + Vector2(book_rect.size.x * uv.position.x, book_rect.size.y * uv.position.y),
		Vector2(book_rect.size.x * uv.size.x, book_rect.size.y * uv.size.y)
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
	var used := slot.get_update_function().get_mb_cost()
	var pattern := LocaleText.resolve("ui.code_editor.ram", "RAM: {used}/{max} MB")
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
	if not ScriptEditing.fits_ram(function.get_mb_cost(), block, slot.ram_max()):
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


func _on_remove_rows(indexes: Array) -> void:
	var ordered: Array[int] = []
	for item in indexes:
		var index := int(item)
		if not ordered.has(index):
			ordered.append(index)
	ordered.sort()
	ordered.reverse()
	for index in ordered:
		_on_remove(index)


func _on_remove_group(index: int) -> void:
	var slot := _current_slot()
	if slot == null:
		return
	var lines: Array[ScriptLine] = slot.get_update_function().lines
	var end := ScriptEditing.subtree_end(lines, index)
	for cursor in range(end - 1, index - 1, -1):
		var block := ScriptEditing.remove_line(lines, cursor)
		if block and Game.block_inventory:
			Game.block_inventory.add(block, 1)
	_script.refresh()
	_show_ram()


func _on_quick_add(block: CodeBlock) -> void:
	var slot := _current_slot()
	if slot == null or block == null:
		return
	var lines: Array[ScriptLine] = slot.get_update_function().lines
	var index := lines.size()
	var indent := ScriptEditing.clamped_indent(lines, index, 0)
	_on_place(block, index, indent)


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
