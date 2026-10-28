## Fill that counts up to the next program loop, then resets.
extends Component
class_name ThinkBarComponent

@export var offset: Vector2 = Vector2(0, -242)
@export var size: Vector2 = Vector2(128, 6)
@export var outline_thickness: float = 1.0
@export var outline_color: Color = Color.WHITE
@export var background_color: Color = Color(0, 0, 0, 0.8)
@export var fill_color: Color = Color(0.25, 0.8, 1.0)

var _host: Node2D
var _runner: ProgramRunner
var _root: Node2D
var _fill: ColorRect


func _setup() -> void:
	_host = get_host() as Node2D
	if _host == null:
		push_warning("ThinkBarComponent has no host")
		return
	_create_bar()


func _process(_delta: float) -> void:
	if _root == null or _host == null:
		return
	var unit := _host as Unit2D
	if unit != null and unit.state == Unit2D.State.DEAD:
		_root.visible = false
		return
	_root.global_position = _host.global_position + offset
	_root.global_rotation = 0.0
	var ratio := 0.0
	var runner := _runner_or_find()
	if runner != null:
		ratio = runner.get_think_ratio()
	if _fill:
		_fill.size.x = size.x * ratio


func _runner_or_find() -> ProgramRunner:
	if _runner != null and is_instance_valid(_runner):
		return _runner
	if _host == null:
		return null
	_runner = _host.get_node_or_null("ProgramRunner") as ProgramRunner
	return _runner


func _create_bar() -> void:
	_root = Node2D.new()
	_root.z_index = 98
	add_child(_root)

	var outline_size := size + Vector2.ONE * outline_thickness * 2.0
	var outline := ColorRect.new()
	outline.color = outline_color
	outline.size = outline_size
	outline.position = -outline_size * 0.5
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(outline)

	var background := ColorRect.new()
	background.color = background_color
	background.size = size
	background.position = Vector2(outline_thickness, outline_thickness)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.add_child(background)

	_fill = ColorRect.new()
	_fill.color = fill_color
	_fill.size = Vector2(0, size.y)
	_fill.position = Vector2.ZERO
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(_fill)
