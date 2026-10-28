## World-space state and last-rule label, plus the unit's current path.
## BattleTest toggles every overlay with F1.
extends Node2D
class_name UnitDebugOverlay

const GROUP := &"unit_debug_overlay"

var _label: Label
var _current_action: String = "-"


func _ready() -> void:
	add_to_group(GROUP)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2(-110, -240)
	_label.z_index = 40
	var settings := LabelSettings.new()
	settings.font_size = 22
	settings.font_color = Color.WHITE
	settings.outline_size = 6
	settings.outline_color = Color(0, 0, 0, 1)
	_label.label_settings = settings
	add_child(_label)
	call_deferred("_bind_runner")


func _bind_runner() -> void:
	var unit := get_parent() as Unit2D
	if unit == null or unit.runner == null:
		return
	if not unit.runner.rule_executed.is_connected(_on_rule_executed):
		unit.runner.rule_executed.connect(_on_rule_executed)


func _on_rule_executed(_fn: UnitFunction, rule: ProgramRule) -> void:
	_current_action = rule.get_action_label() if rule != null else "-"


func set_overlay_visible(shown: bool) -> void:
	visible = shown and not _unit_is_dead()


func _unit_is_dead() -> bool:
	var unit := get_parent() as Unit2D
	return unit != null and unit.state == Unit2D.State.DEAD


func _process(_delta: float) -> void:
	if _unit_is_dead():
		visible = false
		return
	if not visible:
		return
	var unit := get_parent() as Unit2D
	if unit == null or _label == null:
		return
	var cpu := 1
	var gpu := 1
	if unit.stats != null:
		cpu = unit.stats.cpu
		gpu = unit.stats.gpu
	_label.text = "%s\nCPU %d  GPU %d\n%s\n%s" % [unit.name, cpu, gpu, Unit2D.State.keys()[unit.state], _current_action]
	queue_redraw()


func _draw() -> void:
	var unit := get_parent() as Unit2D
	if unit == null:
		return
	var points := unit.get_debug_waypoints()
	if points.size() < 2:
		return
	var previous := to_local(points[0])
	for index in range(1, points.size()):
		var here := to_local(points[index])
		draw_line(previous, here, Color(1, 0.85, 0.2, 0.9), 4.0)
		previous = here
	draw_circle(previous, 10.0, Color(1, 0.55, 0.15, 0.9))
