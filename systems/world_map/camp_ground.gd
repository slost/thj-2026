## Camp yard. Summoned minions stand inside bounds.
extends Node2D


const _Map := preload("res://systems/battle/map_generator.gd")

@export var bounds: Rect2 = Rect2(-900, -500, 1800, 900)


func _ready() -> void:
	_paint_ground()
	_build_nav()
	if get_node_or_null("GridNav") == null:
		var grid := GridNav.new()
		grid.name = "GridNav"
		add_child(grid)


func contains_world(world_pos: Vector2) -> bool:
	return bounds.has_point(to_local(world_pos))


## Evenly spaced standing spots, in camp world space.
func muster_points(count: int) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	var columns := 4
	for index in maxi(count, 0):
		var column := index % columns
		var row := int(index / float(columns))
		var local := bounds.position + Vector2(220.0 + float(column) * 200.0, 240.0 + float(row) * 180.0)
		spots.append(to_global(local))
	return spots


func _paint_ground() -> void:
	var map := get_node_or_null("Map") as TileMapLayer
	if map == null:
		return
	var top_left := map.local_to_map(bounds.position)
	var bottom_right := map.local_to_map(bounds.end - Vector2.ONE)
	var origin := Vector2i(mini(top_left.x, bottom_right.x), mini(top_left.y, bottom_right.y))
	var end := Vector2i(maxi(top_left.x, bottom_right.x), maxi(top_left.y, bottom_right.y))
	_Map.generate_yard(map, origin, end - origin + Vector2i.ONE)


func _build_nav() -> void:
	var region := get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	if region == null:
		region = NavigationRegion2D.new()
		region.name = "NavigationRegion2D"
		add_child(region)
	var polygon := NavigationPolygon.new()
	var origin := bounds.position
	var size := bounds.size
	polygon.vertices = PackedVector2Array([
		origin,
		origin + Vector2(size.x, 0.0),
		origin + size,
		origin + Vector2(0.0, size.y),
	])
	polygon.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_polygon = polygon
