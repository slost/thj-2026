## Faint cells showing where a selected spell can be summoned.
extends Node2D


const _TINT := Color(0.45, 0.82, 0.5, 0.22)

var _grid: GridNav
var _area: Rect2i = Rect2i()


func _ready() -> void:
	z_index = 6
	visible = false


func show_area(grid: GridNav, area: Rect2i) -> void:
	_grid = grid
	_area = area
	visible = grid != null
	queue_redraw()


func hide_area() -> void:
	visible = false


func _draw() -> void:
	if _grid == null or _area.size.x <= 0 or _area.size.y <= 0:
		return
	var tile := float(_grid.get_tile_size())
	var size := Vector2(tile, tile)
	for y in range(_area.position.y, _area.position.y + _area.size.y):
		for x in range(_area.position.x, _area.position.x + _area.size.x):
			var cell := Vector2i(x, y)
			if not _grid.is_walkable_cell(cell):
				continue
			var center := to_local(_grid.cell_to_world(cell))
			draw_rect(Rect2(center - size * 0.5, size), _TINT, true)
