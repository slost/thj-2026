extends Node

signal unit_sacrificed(unit: Unit2D)

const _Summoner := preload("res://systems/game/summoner.gd")


const _COVERED_ALPHA := 0.6
const _FADE_SPEED := 10.0
## Pixels at or below this alpha are the empty part of a sprite.
const _ALPHA_CUTOFF := 0.12

@export var portrait: HotSwapSprite
@export var book: HotSwapSprite
@export var far: HotSwapSprite
@export var hand: HotSwapSprite

var _fullscreen_requested := false
## Title cutscenes hide this layer. Portrait updates must not show it again.
var _suppressed := false
## Opaque texels for a texture, built once. Keys are texture instance ids.
var _opaque_masks: Dictionary = {}
var _summoning := false


func _ready() -> void:
	var sacrifice := get_node_or_null("SacrificeButton") as Button
	if sacrifice and not sacrifice.pressed.is_connected(_on_sacrifice_pressed):
		sacrifice.pressed.connect(_on_sacrifice_pressed)
	update_portrait()
	if _fullscreen_requested or not OS.has_feature("web"):
		return

	_fullscreen_requested = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func set_suppressed(active: bool) -> void:
	_suppressed = active
	for child in get_children():
		if child is CanvasItem:
			child.visible = not active
	if not active:
		update_portrait()


func _process(delta: float) -> void:
	if _suppressed:
		return
	_sync_sacrifice_button()
	if portrait == null or not is_instance_valid(portrait):
		return
	var target := _COVERED_ALPHA if _pointer_on_portrait() or _unit_under_portrait() else 1.0
	var color := portrait.modulate
	color.a = lerpf(color.a, target, 1.0 - exp(-_FADE_SPEED * delta))
	if absf(color.a - target) < 0.01:
		color.a = target
	portrait.modulate = color


func _sync_sacrifice_button() -> void:
	var button := get_node_or_null("SacrificeButton") as Button
	if button:
		button.disabled = _pinned_minion() == null


func _pinned_minion() -> Unit2D:
	var tree := get_tree()
	if tree == null:
		return null
	for node in tree.get_nodes_in_group(FocusDirector.GROUP):
		var director := node as FocusDirector
		if director == null or director.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		var unit := director.get_selected_unit()
		if unit == null or not is_instance_valid(unit):
			continue
		if unit.team != Unit2D.Team.MINION or unit.state == Unit2D.State.DEAD:
			continue
		return unit
	return null


func _on_sacrifice_pressed() -> void:
	var unit := _pinned_minion()
	if unit == null:
		return
	_Summoner.refund_unit(unit)
	unit_sacrificed.emit(unit)
	unit.die()


func get_portrait() -> HotSwapSprite:
	return portrait if portrait else HotSwapSprite.new()


func _pointer_on_portrait() -> bool:
	if portrait.texture == null:
		return false
	var viewport := portrait.get_viewport()
	if viewport == null:
		return false
	var mask := _mask_of(portrait.texture)
	if mask.is_empty():
		return false
	var inverse := portrait.get_global_transform_with_canvas().affine_inverse()
	return _mask_hit(portrait, mask, inverse, viewport.get_mouse_position())


## True when a unit's visible pixels sit on the portrait's visible pixels.
func _unit_under_portrait() -> bool:
	if portrait.texture == null:
		return false
	var tree := get_tree()
	if tree == null:
		return false
	var portrait_rect := _screen_rect(portrait)
	if portrait_rect.size.x <= 1.0 or portrait_rect.size.y <= 1.0:
		return false
	var portrait_mask := _mask_of(portrait.texture)
	if portrait_mask.is_empty():
		return false
	var portrait_inverse := portrait.get_global_transform_with_canvas().affine_inverse()
	for node in tree.get_nodes_in_group(Unit2D.GROUP):
		var unit := node as Unit2D
		if unit == null or not unit.visible or unit.modulate.a < 0.05:
			continue
		var sprite := unit.get_node_or_null("HotSwapSprite") as Sprite2D
		if sprite != null and sprite.visible and sprite.texture != null:
			if _opaque_overlap(sprite, portrait_rect, portrait_mask, portrait_inverse):
				return true
			continue
		if _mask_hit(portrait, portrait_mask, portrait_inverse, unit.get_global_transform_with_canvas().origin):
			return true
	return false


func _opaque_overlap(sprite: Sprite2D, portrait_rect: Rect2, portrait_mask: Dictionary, portrait_inverse: Transform2D) -> bool:
	var overlap := portrait_rect.intersection(_screen_rect(sprite))
	if overlap.size.x < 0.5 or overlap.size.y < 0.5 or sprite.texture == null:
		return false
	var sprite_mask := _mask_of(sprite.texture)
	if sprite_mask.is_empty():
		return false
	var sprite_to_screen := sprite.get_global_transform_with_canvas()
	var sprite_inverse := sprite_to_screen.affine_inverse()
	var hframes := maxi(sprite.hframes, 1)
	var vframes := maxi(sprite.vframes, 1)
	var frame_size := sprite.texture.get_size() / Vector2(hframes, vframes)
	# Large sheets stay on a short sample grid. Tiny sprites can check every texel.
	if frame_size.x * frame_size.y > 4096.0:
		return _overlap_samples(sprite, sprite_mask, sprite_inverse, portrait_mask, portrait_inverse, overlap)
	return _overlap_texels(sprite, sprite_mask, sprite_inverse, sprite_to_screen, portrait_mask, portrait_inverse, overlap, frame_size)


func _overlap_samples(sprite: Sprite2D, sprite_mask: Dictionary, sprite_inverse: Transform2D, portrait_mask: Dictionary, portrait_inverse: Transform2D, overlap: Rect2) -> bool:
	var sprite_bytes: PackedByteArray = sprite_mask["bytes"]
	var portrait_bytes: PackedByteArray = portrait_mask["bytes"]
	var sprite_width: int = sprite_mask["w"]
	var sprite_height: int = sprite_mask["h"]
	var portrait_width: int = portrait_mask["w"]
	var portrait_height: int = portrait_mask["h"]
	var across := 8
	var step_x := maxf(overlap.size.x / float(across), 4.0)
	var step_y := maxf(overlap.size.y / float(across), 4.0)
	var y := overlap.position.y + step_y * 0.5
	while y < overlap.end.y:
		var x := overlap.position.x + step_x * 0.5
		while x < overlap.end.x:
			var point := Vector2(x, y)
			if _bytes_hit(sprite, sprite_bytes, sprite_width, sprite_height, sprite_inverse, point) and _bytes_hit(portrait, portrait_bytes, portrait_width, portrait_height, portrait_inverse, point):
				return true
			x += step_x
		y += step_y
	return false


func _overlap_texels(sprite: Sprite2D, sprite_mask: Dictionary, sprite_inverse: Transform2D, sprite_to_screen: Transform2D, portrait_mask: Dictionary, portrait_inverse: Transform2D, overlap: Rect2, frame_size: Vector2) -> bool:
	var sprite_bytes: PackedByteArray = sprite_mask["bytes"]
	var portrait_bytes: PackedByteArray = portrait_mask["bytes"]
	var sprite_width: int = sprite_mask["w"]
	var sprite_height: int = sprite_mask["h"]
	var portrait_width: int = portrait_mask["w"]
	var portrait_height: int = portrait_mask["h"]
	var y := 0
	while y < int(frame_size.y):
		var x := 0
		while x < int(frame_size.x):
			var local := Vector2(float(x) + 0.5, float(y) + 0.5)
			if sprite.flip_h:
				local.x = frame_size.x - local.x
			if sprite.flip_v:
				local.y = frame_size.y - local.y
			if sprite.centered:
				local -= frame_size * 0.5
			var point := sprite_to_screen * local
			if overlap.has_point(point) and _bytes_hit(sprite, sprite_bytes, sprite_width, sprite_height, sprite_inverse, point) and _bytes_hit(portrait, portrait_bytes, portrait_width, portrait_height, portrait_inverse, point):
				return true
			x += 1
		y += 1
	return false


func _mask_hit(sprite: Sprite2D, mask: Dictionary, inverse: Transform2D, screen_pos: Vector2) -> bool:
	var bytes: PackedByteArray = mask["bytes"]
	var width: int = mask["w"]
	var height: int = mask["h"]
	return _bytes_hit(sprite, bytes, width, height, inverse, screen_pos)


func _bytes_hit(sprite: Sprite2D, bytes: PackedByteArray, width: int, height: int, inverse: Transform2D, screen_pos: Vector2) -> bool:
	var pixel := _texture_pixel(sprite, inverse, screen_pos)
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= width or pixel.y >= height:
		return false
	return bytes[pixel.y * width + pixel.x] != 0


func _mask_of(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {}
	var key := texture.get_instance_id()
	if _opaque_masks.has(key):
		return _opaque_masks[key]
	var image := texture.get_image()
	if image == null:
		return {}
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var raw := image.get_data()
	var width := image.get_width()
	var height := image.get_height()
	var bytes := PackedByteArray()
	bytes.resize(width * height)
	var cutoff := int(_ALPHA_CUTOFF * 255.0)
	var pixel_count := width * height
	var source := 0
	for index in pixel_count:
		bytes[index] = 1 if raw[source + 3] > cutoff else 0
		source += 4
	var mask := {"w": width, "h": height, "bytes": bytes}
	_opaque_masks[key] = mask
	return mask


func _texture_pixel(sprite: Sprite2D, inverse: Transform2D, screen_pos: Vector2) -> Vector2i:
	var texture := sprite.texture
	if texture == null:
		return Vector2i(-1, -1)
	var local := inverse * screen_pos
	var hframes := maxi(sprite.hframes, 1)
	var vframes := maxi(sprite.vframes, 1)
	var frame_size := texture.get_size() / Vector2(hframes, vframes)
	var top_left := -frame_size * 0.5 if sprite.centered else Vector2.ZERO
	var in_frame := local - top_left
	if in_frame.x < 0.0 or in_frame.y < 0.0 or in_frame.x >= frame_size.x or in_frame.y >= frame_size.y:
		return Vector2i(-1, -1)
	if sprite.flip_h:
		in_frame.x = frame_size.x - in_frame.x - 1.0
	if sprite.flip_v:
		in_frame.y = frame_size.y - in_frame.y - 1.0
	var frame := sprite.frame
	var column := frame % hframes
	var row := int(frame / float(hframes))
	var pixel := Vector2i(
		int(in_frame.x) + column * int(frame_size.x),
		int(in_frame.y) + row * int(frame_size.y)
	)
	if sprite.region_enabled:
		pixel += Vector2i(sprite.region.position)
	return pixel


func _screen_rect(sprite: Sprite2D) -> Rect2:
	if sprite == null or sprite.texture == null:
		return Rect2()
	var frames := Vector2(maxi(sprite.hframes, 1), maxi(sprite.vframes, 1))
	var frame_size := sprite.texture.get_size() / frames
	var xform := sprite.get_global_transform_with_canvas()
	var drawn := xform.get_scale().abs()
	var size := Vector2(frame_size.x * drawn.x, frame_size.y * drawn.y)
	if sprite.centered:
		return Rect2(xform.origin - size * 0.5, size)
	return Rect2(xform.origin, size)


func portrait_screen_rect() -> Rect2:
	if portrait == null or not is_instance_valid(portrait):
		return Rect2()
	return _screen_rect(portrait)


func update_portrait() -> void:
	if _suppressed:
		return
	hand.hide()
	if _summoning:
		_apply_point_portrait()
		return
	var stage := Game.current_stage
	if stage is WorldMap:
		_apply_world_portrait((stage as WorldMap).current_state)
		return
	if stage != null and stage.has_method("is_coding"):
		if bool(stage.call("is_coding")):
			_apply_code_portrait()
		else:
			_apply_battle_field_portrait()


func _apply_world_portrait(state: WorldMap.State) -> void:
	if state == WorldMap.State.CODE:
		_apply_code_portrait()
		return
	var portrait_texture := ""
	var book_texture := ""
	var far_texture := ""
	match state:
		WorldMap.State.MAP:
			portrait_texture = "tex_portrait_idle_1"
		WorldMap.State.PINNED:
			portrait_texture = "tex_portrait_point"
			book_texture = "tex_portrait_point_book"
		WorldMap.State.CAMP:
			portrait_texture = "tex_portrait_evil"
			book_texture = "tex_portrait_evil_book"
		_:
			portrait_texture = "tex_portrait_evil"
	if state == WorldMap.State.MAP:
		far.show()
		book.hide()
		far_texture = "tex_portrait_idle_book"
	else:
		far.hide()
		book.show()
	set_portrait(portrait_texture)
	set_book(book_texture)
	set_far(far_texture)


## The writing portrait used on the map and in battle while the book is open.
func _apply_code_portrait() -> void:
	hand.show()
	far.show()
	book.show()
	set_portrait("tex_portrait_write")
	set_book("tex_portrait_write_book")
	set_far("tex_portrait_write_effects")


## Field view uses the camp portrait. The camp icon is the field button.
func _apply_battle_field_portrait() -> void:
	far.hide()
	book.show()
	set_portrait("tex_portrait_evil")
	set_book("tex_portrait_evil_book")
	set_far("")


## Pointing portrait while a summon ghost is on the field.
func set_summoning(active: bool) -> void:
	if _summoning == active:
		return
	_summoning = active
	update_portrait()


func _apply_point_portrait() -> void:
	far.hide()
	book.show()
	set_portrait("tex_portrait_point")
	set_book("tex_portrait_point_book")
	set_far("")


func set_portrait(texture_Id: String) -> void:
	if portrait:
		portrait.set("asset_id", texture_Id)


func set_book(texture_Id: String) -> void:
	if book:
		book.set("asset_id", texture_Id)


func set_far(texture_Id: String) -> void:
	if far:
		far.set("asset_id", texture_Id)
