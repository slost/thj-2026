## AStar grid plus a navigation mesh for NavigationAgent2D.
## Units are not holes in the mesh. Agents steer around each other.
class_name GridNav
extends Node

## Used only when the battle map has no TileSet. Runtime size comes from the map.
const TILE_SIZE_FALLBACK := 128
const GROUP := &"grid_nav"

## Custom data layer names that mark a painted tile as a wall.
const SOLID_DATA_NAMES: PackedStringArray = ["solid", "wall", "blocked", "collision"]

var tile_size: int = TILE_SIZE_FALLBACK

var _map: TileMapLayer
var _grid: AStarGrid2D
var _nav_region: NavigationRegion2D


func _ready() -> void:
	add_to_group(GROUP)
	_map = _find_map_upwards()
	_build()
	_bake_navigation()


## The map stays on the battle level. GridNav itself lives under the shared Battle scene.
func _find_map_upwards() -> TileMapLayer:
	var node: Node = self
	while node != null:
		var found := _find_map(node)
		if found:
			return found
		node = node.get_parent()
	return null


func navigation_vertex_count() -> int:
	if _nav_region == null or _nav_region.navigation_polygon == null:
		return 0
	return _nav_region.navigation_polygon.vertices.size()


func get_tile_size() -> int:
	return tile_size


func world_to_cell(world_pos: Vector2) -> Vector2i:
	if _map:
		return _map.local_to_map(_map.to_local(world_pos))
	return Vector2i(
		floori(world_pos.x / float(tile_size)),
		floori(world_pos.y / float(tile_size))
	)


func cell_to_world(cell: Vector2i) -> Vector2:
	if _map:
		return _map.to_global(_map.map_to_local(cell))
	return Vector2(cell) * float(tile_size) + Vector2(tile_size, tile_size) * 0.5


func is_walkable_cell(cell: Vector2i) -> bool:
	return _grid != null and _grid.is_in_boundsv(cell) and not _grid.is_point_solid(cell)


## A walkable cell next to goal when goal itself cannot be used.
## Returns null when every neighbor is blocked or excluded.
func find_alternate_cell(from_pos: Vector2, goal: Vector2i, excluded: Array[Vector2i]) -> Variant:
	var origin := world_to_cell(from_pos)
	var best := goal
	var best_cost := 1 << 30
	var found := false
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var cell := goal + Vector2i(dx, dy)
			if excluded.has(cell) or not is_walkable_cell(cell):
				continue
			if cell == origin:
				continue
			var path := find_path_world(from_pos, cell_to_world(cell))
			if path.is_empty():
				continue
			var cost := path.size()
			if not found or cost < best_cost:
				found = true
				best = cell
				best_cost = cost
	if not found:
		return null
	return best


func find_path_world(from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	if _grid == null:
		return PackedVector2Array([to_pos])
	var from_cell := world_to_cell(from_pos)
	var to_cell := world_to_cell(to_pos)
	if not _grid.is_in_boundsv(from_cell) or not _grid.is_in_boundsv(to_cell):
		return PackedVector2Array()
	if _grid.is_point_solid(from_cell) or _grid.is_point_solid(to_cell):
		return PackedVector2Array()
	var ids: Array[Vector2i] = _grid.get_id_path(from_cell, to_cell)
	var points := PackedVector2Array()
	for id in ids:
		points.append(cell_to_world(id))
	return points


## Walkable cells become quads that share corner vertices, so agents can path across the map.
func _bake_navigation() -> void:
	if _map == null or _grid == null:
		return
	var region := NavigationRegion2D.new()
	region.name = "NavigationRegion2D"
	add_child(region)
	_nav_region = region
	var rect := _map.get_used_rect()
	var polygon := NavigationPolygon.new()
	var vertices := PackedVector2Array()
	var corner_index: Dictionary = {}
	var quads: Array[PackedInt32Array] = []
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if not is_walkable_cell(cell):
				continue
			var corners: Array[Vector2i] = [
				Vector2i(x, y),
				Vector2i(x + 1, y),
				Vector2i(x + 1, y + 1),
				Vector2i(x, y + 1),
			]
			var quad := PackedInt32Array()
			for corner in corners:
				if not corner_index.has(corner):
					corner_index[corner] = vertices.size()
					vertices.append(region.to_local(_corner_to_world(corner)))
				quad.append(int(corner_index[corner]))
			quads.append(quad)
	polygon.vertices = vertices
	for quad in quads:
		polygon.add_polygon(quad)
	region.navigation_polygon = polygon


func _corner_to_world(corner: Vector2i) -> Vector2:
	return cell_to_world(corner) - Vector2(tile_size, tile_size) * 0.5


func _build() -> void:
	if _map == null or _map.tile_set == null:
		push_error("GridNav: Map TileMapLayer with a TileSet is required.")
		return
	tile_size = _map.tile_set.tile_size.x
	if tile_size <= 0:
		tile_size = TILE_SIZE_FALLBACK
	var rect := _map.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		push_error("GridNav: Map has no used cells.")
		return
	_grid = AStarGrid2D.new()
	_grid.region = rect
	_grid.cell_size = Vector2(tile_size, tile_size)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			if _is_solid(cell):
				_grid.set_point_solid(cell)


## Empty cells are solid. A painted tile is solid when any physics layer has a
## collision polygon, or a custom data layer named solid/wall/blocked/collision is set.
func _is_solid(cell: Vector2i) -> bool:
	if _map.get_cell_source_id(cell) == -1:
		return true
	var data := _map.get_cell_tile_data(cell)
	if data == null:
		return true
	return _has_collision_polygon(data) or _custom_data_blocks(data)


func _has_collision_polygon(data: TileData) -> bool:
	var layers := _map.tile_set.get_physics_layers_count()
	for layer in layers:
		if data.get_collision_polygons_count(layer) > 0:
			return true
	return false


func _custom_data_blocks(data: TileData) -> bool:
	var tile_set := _map.tile_set
	var layers := tile_set.get_custom_data_layers_count()
	for layer in layers:
		var layer_name := String(tile_set.get_custom_data_layer_name(layer)).to_lower()
		if layer_name not in SOLID_DATA_NAMES:
			continue
		var value: Variant = data.get_custom_data_by_layer_id(layer)
		if _value_is_set(value):
			return true
	return false


func _value_is_set(value: Variant) -> bool:
	if value is bool:
		return value
	if value is int:
		return int(value) != 0
	if value is float:
		return not is_zero_approx(float(value))
	return false


func _find_map(node: Node) -> TileMapLayer:
	if node == null:
		return null
	for child in node.get_children():
		if child is TileMapLayer and String(child.name) == "Map":
			return child as TileMapLayer
		var found := _find_map(child)
		if found:
			return found
	return null
