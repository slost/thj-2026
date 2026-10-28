extends Node


const _COVERED_ALPHA := 0.6
const _FADE_SPEED := 10.0
## Pixels at or below this alpha are the empty part of a sprite.
const _ALPHA_CUTOFF := 0.12

@export var portrait: HotSwapSprite

var _fullscreen_requested := false
## Opaque texels for a texture, built once. Keys are texture instance ids.
var _opaque_masks: Dictionary = {}


func _ready() -> void:
	update_portrait()
	if _fullscreen_requested or not OS.has_feature("web"):
		return

	_fullscreen_requested = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _process(delta: float) -> void:
	if portrait == null or not is_instance_valid(portrait):
		return
	var target := _COVERED_ALPHA if _pointer_on_portrait() or _unit_under_portrait() else 1.0
	var color := portrait.modulate
	color.a = lerpf(color.a, target, 1.0 - exp(-_FADE_SPEED * delta))
	if absf(color.a - target) < 0.01:
		color.a = target
	portrait.modulate = color


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


func update_portrait() -> void:
	var texture_id := ""
	if Game.current_stage is WorldMap:
		var state := (Game.current_stage as WorldMap).current_state
		match state:
			WorldMap.State.MAP:
				texture_id = "tex_portrait_idle"
			WorldMap.State.FOCUS:
				texture_id = "tex_portrait_point"
			WorldMap.State.CAMP:
				texture_id = "tex_portrait_evil"
			WorldMap.State.CODE:
				texture_id = "tex_portrait_write"
	else:
		texture_id = "tex_portrait_evil" # TODO: add more portrait states for battle

	set_portrait(texture_id)


func set_portrait(texture_id: String) -> void:
	if portrait:
		portrait.set("asset_id", texture_id)


