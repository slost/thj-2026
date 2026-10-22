extends Component
class_name HealthBarComponent

#region ENUMS
enum DisplayMode {
	ALWAYS,
	ON_HOVER
}
#endregion

#region EXPORTS
## Offset from host position (world units)
@export var offset: Vector2 = Vector2(0, -32)

## Size of the health bar (inner fill size)
@export var size: Vector2 = Vector2(48, 6)

## Outline thickness (world units)
@export var outline_thickness: float = 1.0

## Colors
@export var outline_color: Color = Color.WHITE
@export var background_color: Color = Color(0, 0, 0, 0.8)
@export var fill_color: Color = Color(0.8, 0.1, 0.1)

## Display behavior
@export var display_mode: DisplayMode = DisplayMode.ALWAYS
@export var hide_when_full: bool = false
#endregion

#region STATE
var _host: Node2D
var _health: HealthComponent

var _root: Node2D
var _outline: ColorRect
var _bg: ColorRect
var _fill: ColorRect

var _is_hovered: bool = false
#endregion

#region LIFECYCLE
func _ready() -> void:
	_host = get_host()
	if not _host:
		push_warning("HealthBarComponent has no host")
		return

	_health = Utils.get_component(_host, HealthComponent)
	if not _health:
		push_warning("HealthBarComponent requires HealthComponent")
		return

	_create_bar()
	_update_from_health()

	if not _health.health_changed.is_connected(_on_health_changed):
		_health.health_changed.connect(_on_health_changed)

	if display_mode == DisplayMode.ON_HOVER:
		_setup_hover_detection()

	set_process(true)
#endregion

#region PROCESS
func _process(_delta: float) -> void:
	if not _root or not _host:
		return

	_root.global_position = _host.global_position + offset
	_root.global_rotation = 0.0
#endregion

#region BAR CREATION
func _create_bar() -> void:
	_root = Node2D.new()
	_root.z_index = 98
	add_child(_root)

	var outline_size: Vector2 = size + Vector2.ONE * outline_thickness * 2.0

	# Outline (centered)
	_outline = ColorRect.new()
	_outline.color = outline_color
	_outline.size = outline_size
	_outline.position = -outline_size * 0.5
	_root.add_child(_outline)

	# Background (centered inside outline)
	_bg = ColorRect.new()
	_bg.color = background_color
	_bg.size = size
	_bg.position = Vector2(
		outline_thickness,
		outline_thickness
	)
	_outline.add_child(_bg)

	# Fill (left-aligned inside background)
	_fill = ColorRect.new()
	_fill.color = fill_color
	_fill.size = size
	_fill.position = Vector2.ZERO
	_bg.add_child(_fill)

#endregion

#region HEALTH CALLBACK
func _on_health_changed(current: int, max: int) -> void:
	var ratio: float = 0.0
	if max > 0:
		ratio = clamp(float(current) / float(max), 0.0, 1.0)

	_fill.size.x = size.x * ratio
	_update_visibility()
#endregion

#region VISIBILITY
func _update_from_health() -> void:
	_on_health_changed(_health.current_health, _health.max_health)

func _update_visibility() -> void:
	match display_mode:
		DisplayMode.ALWAYS:
			_root.visible = not (hide_when_full and _fill.size.x >= size.x)
		DisplayMode.ON_HOVER:
			_root.visible = _is_hovered
#endregion

#region HOVER DETECTION
func _setup_hover_detection() -> void:
	var area: Area2D = Area2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()

	rect.size = size * 2.5
	shape.shape = rect

	area.add_child(shape)

	# IMPORTANT: attach to bar root
	_root.add_child(area)

	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_visibility()


func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_visibility()
#endregion
