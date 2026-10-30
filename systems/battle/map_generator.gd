## Paints the battle field from the terrain sets on the project tileset.
## Land fills the playable rectangle. A dark edge and a path are painted on top
## so Godot picks the matching autotiles. Empty cells stay solid for navigation.
extends RefCounted


const PLAY_ORIGIN := Vector2i(-12, -7)
const PLAY_SIZE := Vector2i(24, 15)
const LAND_SET := 1
const LAND := 0
const DARK_SET := 0
const DARK := 0
const PATH_SET := 2
const PATH := 0


static func generate(map: TileMapLayer, decor: TileMapLayer) -> void:
	if map == null or map.tile_set == null:
		return
	map.clear()
	var land := _rect_cells(PLAY_ORIGIN, PLAY_SIZE)
	map.set_cells_terrain_connect(land, LAND_SET, LAND)
	map.set_cells_terrain_connect(_edge_cells(), DARK_SET, DARK)
	map.set_cells_terrain_connect(_path_cells(), PATH_SET, PATH)
	_paint_decor(decor)


static func _rect_cells(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			cells.append(origin + Vector2i(x, y))
	return cells


static func _edge_cells() -> Array[Vector2i]:
	return _border_cells(PLAY_ORIGIN, PLAY_SIZE)


static func _border_cells(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var end := origin + size - Vector2i.ONE
	for x in range(origin.x, end.x + 1):
		cells.append(Vector2i(x, origin.y))
		cells.append(Vector2i(x, end.y))
	for y in range(origin.y + 1, end.y):
		cells.append(Vector2i(origin.x, y))
		cells.append(Vector2i(end.x, y))
	return cells


## A cross through the field. The horizontal arm is the road between the summon side and the town.
static func _path_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var end := PLAY_ORIGIN + PLAY_SIZE - Vector2i.ONE
	for x in range(PLAY_ORIGIN.x + 2, end.x - 1):
		cells.append(Vector2i(x, 0))
	for y in range(PLAY_ORIGIN.y + 2, end.y - 1):
		var cell := Vector2i(-2, y)
		if not cells.has(cell):
			cells.append(cell)
	return cells


static func _decor_source(decor: TileMapLayer) -> int:
	if decor.tile_set.has_source(1):
		return 1
	return 0


static func _paint_decor(decor: TileMapLayer) -> void:
	if decor == null or decor.tile_set == null:
		return
	decor.clear()
	var spots: Array[Vector2i] = [
		Vector2i(-6, -3), Vector2i(3, -4), Vector2i(7, 3), Vector2i(-9, 4), Vector2i(5, 5),
	]
	var sprites: Array[Vector2i] = [Vector2i(6, 1), Vector2i(2, 2), Vector2i(8, 2), Vector2i(4, 1), Vector2i(7, 1)]
	for index in spots.size():
		decor.set_cell(spots[index], _decor_source(decor), sprites[index])


## A yard: land, a dark rim, and a path cross. Used by the camp.
static func generate_yard(map: TileMapLayer, origin: Vector2i, size: Vector2i) -> void:
	if map == null or map.tile_set == null or size.x < 3 or size.y < 3:
		return
	map.clear()
	map.set_cells_terrain_connect(_rect_cells(origin, size), LAND_SET, LAND)
	map.set_cells_terrain_connect(_border_cells(origin, size), DARK_SET, DARK)
	map.set_cells_terrain_connect(_yard_path(origin, size), PATH_SET, PATH)


static func _yard_path(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var end := origin + size - Vector2i.ONE
	var mid_y := origin.y + int(size.y / 2.0)
	var mid_x := origin.x + int(size.x / 2.0)
	for x in range(origin.x + 1, end.x):
		cells.append(Vector2i(x, mid_y))
	for y in range(origin.y + 1, end.y):
		var cell := Vector2i(mid_x, y)
		if not cells.has(cell):
			cells.append(cell)
	return cells
