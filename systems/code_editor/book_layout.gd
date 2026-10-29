## Finds the two cream pages of the open book, as fractions of the texture.
## The sprite is centered on the full image, including the transparent margin.
class_name BookLayout
extends RefCounted

const _FALLBACK_LEFT := Rect2(0.125, 0.16, 0.34, 0.66)
const _FALLBACK_RIGHT := Rect2(0.535, 0.16, 0.325, 0.66)


static func page_uvs(texture: Texture2D) -> Array[Rect2]:
	var fallback: Array[Rect2] = [_FALLBACK_LEFT, _FALLBACK_RIGHT]
	if texture == null:
		return fallback
	var image := texture.get_image()
	if image == null or image.is_empty():
		return fallback
	if image.is_compressed():
		image.decompress()
	var width := image.get_width()
	var height := image.get_height()
	if width < 8 or height < 8:
		return fallback
	var step_y := maxi(1, int(float(height) / 48.0))
	var step_x := maxi(1, int(float(width) / 160.0))
	var rows: Array[Dictionary] = []
	var y := step_y
	while y < height - step_y:
		var left := _span(image, y, 0, int(width / 2.0), step_x)
		var right := _span(image, y, int(width / 2.0), width, step_x)
		if left.y - left.x > int(float(width) * 0.18) and right.y - right.x > int(float(width) * 0.18):
			rows.append({"y": y, "l0": left.x, "l1": left.y, "r0": right.x, "r1": right.y})
		y += step_y
	if rows.size() < 4:
		return fallback
	var first := int(float(rows.size()) * 0.12)
	var last := int(float(rows.size()) * 0.88)
	if last <= first:
		first = 0
		last = rows.size()
	var left_start := 0
	var left_end := width
	var right_start := 0
	var right_end := width
	for index in range(first, last):
		var row: Dictionary = rows[index]
		left_start = maxi(left_start, int(row.l0))
		left_end = mini(left_end, int(row.l1))
		right_start = maxi(right_start, int(row.r0))
		right_end = mini(right_end, int(row.r1))
	var top := int(rows[first].y)
	var bottom := int(rows[last - 1].y)
	var pad_x := int(float(width) * 0.02)
	var pad_y := int(float(height) * 0.025)
	left_start += pad_x
	right_start += pad_x
	left_end -= pad_x
	right_end -= pad_x
	top += pad_y
	bottom -= pad_y
	if left_end - left_start < int(float(width) * 0.12):
		return fallback
	if right_end - right_start < int(float(width) * 0.12) or bottom - top < int(float(height) * 0.2):
		return fallback
	var pages: Array[Rect2] = [
		Rect2(float(left_start) / width, float(top) / height, float(left_end - left_start) / width, float(bottom - top) / height),
		Rect2(float(right_start) / width, float(top) / height, float(right_end - right_start) / width, float(bottom - top) / height),
	]
	return pages


static func _span(image: Image, y: int, x0: int, x1: int, step: int) -> Vector2i:
	var best_start := x0
	var best_end := x0
	var best_length := 0
	var run_start := -1
	var previous := x0
	var x := x0
	while x < x1:
		if _is_page(image.get_pixel(x, y)):
			if run_start < 0:
				run_start = x
			previous = x
		elif run_start >= 0:
			var length := previous - run_start
			if length > best_length:
				best_length = length
				best_start = run_start
				best_end = previous + step
			run_start = -1
		x += step
	if run_start >= 0 and previous - run_start > best_length:
		best_start = run_start
		best_end = mini(previous + step, x1)
	return Vector2i(best_start, mini(best_end, x1))


static func _is_page(color: Color) -> bool:
	if color.a < 0.2:
		return false
	return color.r > 0.7 and color.g > 0.62 and color.r + color.g + color.b > 2.25
