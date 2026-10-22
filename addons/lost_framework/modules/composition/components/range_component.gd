extends Component
class_name RangeComponent

#region EXPORTS
## Maximum effective range in pixels
@export var range: float = 128.0

## Optional Area2D representing the range in world space
@export var range_area: Area2D

## Debug visualization
@export var debug_draw: bool = true
@export var debug_color: Color = Color(0.2, 0.8, 1.0, 0.4)
#endregion

#region STATE
var _debug_drawer: Node2D
var _collision_shape: CollisionShape2D
#endregion


#region PUBLIC API
## Returns true if target position is within range
func is_in_range(from_position: Vector2, target_position: Vector2) -> bool:
	return from_position.distance_to(target_position) <= range
#endregion


#region LIFECYCLE
func _ready() -> void:
	_bind_range_area()
	_setup_debug_drawer()

func _process(_delta: float) -> void:
	_sync_range_area()
	_update_debug_drawer()
#endregion


#region RANGE AREA
func _bind_range_area() -> void:
	# If no range_area is assigned, optionally use host
	if not range_area:
		if get_host() is Area2D:
			range_area = get_host()
		else:
			return

	# Cache first CollisionShape2D under range_area
	for child in range_area.get_children():
		if child is CollisionShape2D:
			_collision_shape = child
			break

	if not _collision_shape:
		push_warning("RangeComponent range_area has no CollisionShape2D")

func _sync_range_area() -> void:
	if not _collision_shape:
		return

	var circle: CircleShape2D = _collision_shape.shape as CircleShape2D
	if not circle:
		return

	if is_equal_approx(circle.radius, range):
		return

	circle.radius = range
#endregion


#region DEBUG
func _setup_debug_drawer() -> void:
	if not debug_draw:
		return

	var target: Node2D = get_host()
	if range_area and range_area is Node2D:
		target = range_area

	if not target:
		return

	_debug_drawer = _create_debug_drawer()
	target.add_child.call_deferred(_debug_drawer)

func _update_debug_drawer() -> void:
	if not _debug_drawer:
		return

	_debug_drawer.set("range", range)
	_debug_drawer.queue_redraw()
#endregion


#region INTERNAL
func _create_debug_drawer() -> Node2D:
	var drawer: Node2D = Node2D.new()

	drawer.set_script(_create_drawer_script())
	drawer.set("range", range)
	drawer.set("color", debug_color)
	drawer.z_as_relative = false

	return drawer


func _create_drawer_script() -> Script:
	var script: Script = GDScript.new()

	script.source_code = """
extends Node2D

var range: float = 0.0
var color: Color = Color.WHITE

func _draw() -> void:
	z_index = Game.Layer.OVERLAY
	if range <= 0.0:
		return
	draw_circle(Vector2.ZERO, range, color)
"""
	script.reload()

	return script
#endregion


func supports_preview() -> bool:
	return true
