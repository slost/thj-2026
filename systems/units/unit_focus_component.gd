## Focus debug for one Unit2D. Presence of this component is what makes the unit focusable.
extends FocusTargetComponent
class_name UnitFocusComponent


var _current_action: String = ""
var _runner: ProgramRunner


func _setup() -> void:
	super._setup()
	call_deferred("_bind_runner")


func _bind_runner() -> void:
	var unit := get_host() as Unit2D
	if unit == null or unit.runner == null:
		return
	_runner = unit.runner
	if not _runner.rule_executed.is_connected(_on_rule_executed):
		_runner.rule_executed.connect(_on_rule_executed)


func _teardown() -> void:
	if _runner != null and is_instance_valid(_runner) and _runner.rule_executed.is_connected(_on_rule_executed):
		_runner.rule_executed.disconnect(_on_rule_executed)
	_runner = null
	super._teardown()


func _on_rule_executed(_fn: UnitFunction, rule: ProgramRule) -> void:
	_current_action = rule.get_action_label() if rule != null else ""


func get_debug_text() -> String:
	var unit := get_host() as Unit2D
	if unit == null:
		return super.get_debug_text()

	var lines := PackedStringArray()
	var title := unit.name
	if unit.def != null and not unit.def.name.is_empty():
		title = unit.def.get_display_name()
	lines.append("Focusing on: %s" % title)
	lines.append("Node: %s" % unit.name)
	lines.append("Team: %s" % Unit2D.Team.keys()[unit.team])
	lines.append("State: %s" % Unit2D.State.keys()[unit.state])
	if unit.stats:
		lines.append("HP: %d/%d" % [unit.stats.hp, unit.stats.max_hp])
		lines.append("Damage: %d  Move: %s  CPU: %d  GPU: %d" % [
			unit.stats.damage,
			snapped(unit.get_move_speed(), 0.1),
			unit.stats.cpu,
			unit.stats.gpu,
		])
		lines.append("Detect: %d  Attack: %d  Cooldown: %s" % [
			unit.stats.detect_range,
			unit.stats.attack_range,
			snapped(unit.get_attack_cooldown_left(), 0.01),
		])
		var used := unit.program.get_ram_cost() if unit.program else 0
		lines.append("RAM: %d / %d" % [used, unit.stats.ram])
	if unit.program:
		for fn in unit.program.functions:
			if fn == null:
				continue
			lines.append("[%s]" % fn.function_name)
			for rule in fn.rules:
				if rule:
					lines.append("  %s" % rule.get_label())
	if not _current_action.is_empty():
		lines.append("Action: %s" % _current_action)
	return "\n".join(lines)
