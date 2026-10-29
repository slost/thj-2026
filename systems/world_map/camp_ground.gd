## Placeholder camp floor. Summoned minions stand inside bounds.
extends Node2D


@export var bounds: Rect2 = Rect2(-900, -500, 1800, 900)


func _ready() -> void:
	_build_floor()
	_build_nav()


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


func _build_floor() -> void:
	if get_node_or_null("Floor") != null:
		return
	var poly := Polygon2D.new()
	poly.name = "Floor"
	poly.color = Color(0.16, 0.12, 0.11, 1)
	var origin := bounds.position
	var size := bounds.size
	poly.polygon = PackedVector2Array([
		origin,
		origin + Vector2(size.x, 0.0),
		origin + size,
		origin + Vector2(0.0, size.y),
	])
	add_child(poly)
	move_child(poly, 0)


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
