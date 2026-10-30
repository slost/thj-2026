## Focus debug for one Unit2D. Presence of this component is what makes the unit focusable.
extends FocusTargetComponent
class_name UnitFocusComponent


func can_select() -> bool:
	var unit := get_host() as Unit2D
	if unit != null and unit.team == Unit2D.Team.VILLAGER:
		return false
	return super.can_select()


func get_debug_text() -> String:
	var unit := get_host() as Unit2D
	if unit == null:
		return super.get_debug_text()

	var lines := PackedStringArray()
	var title := unit.name
	if unit.def != null and not unit.def.name.is_empty():
		title = unit.def.get_display_name()
	lines.append(title)
	lines.append("%s  %s" % [Unit2D.Team.keys()[unit.team], Unit2D.State.keys()[unit.state]])
	if unit.stats:
		lines.append("HP %d/%d" % [unit.stats.hp, unit.stats.max_hp])
		lines.append("DMG %d  SPD %s  CPU %d  GPU %d" % [
			unit.stats.damage,
			snapped(unit.get_move_speed(), 0.1),
			unit.stats.cpu,
			unit.stats.gpu,
		])
		lines.append("Detect %d  Attack %d  CD %s" % [
			unit.stats.detect_range,
			unit.stats.attack_range,
			snapped(unit.get_attack_cooldown_left(), 0.01),
		])
	return "\n".join(lines)
