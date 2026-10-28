## Focus debug for one Unit2D. Presence of this component is what makes the unit focusable.
extends FocusTargetComponent
class_name UnitFocusComponent


var _last_rule_line: String = ""
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


func _on_rule_executed(fn: UnitFunction, rule: ProgramRule) -> void:
	if rule == null:
		_last_rule_line = fn.function_name if fn else ""
		return
	var fn_name := fn.function_name if fn else "function"
	_last_rule_line = "%s: %s" % [fn_name, rule.get_label()]


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
		lines.append("Damage: %d  Speed: %s  CPU: %s" % [
			unit.stats.damage,
			snapped(unit.stats.speed, 0.1),
			snapped(unit.stats.cpu, 0.01),
		])
		lines.append("Detect: %d  Attack: %d  Cooldown: %s" % [
			unit.stats.detect_range,
			unit.stats.attack_range,
			snapped(unit.get_attack_cooldown_left(), 0.01),
		])
		var used := unit.program.get_total_lines() if unit.program else 0
		lines.append("Lines: %d / %d RAM" % [used, unit.stats.ram])
	if unit.program:
		for fn in unit.program.functions:
			if fn == null:
				continue
			lines.append("[%s]" % fn.function_name)
			for rule in fn.rules:
				if rule:
					lines.append("  %s" % rule.get_label())
	if not _last_rule_line.is_empty():
		lines.append("Last rule: %s" % _last_rule_line)
	return "\n".join(lines)
