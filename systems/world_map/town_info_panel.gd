## Side panel for the town under the map pin. Shows who defends it and what a raid can pay.
extends PanelContainer


func show_town(town: TownLocation) -> void:
	visible = true
	var def := town.def if town != null else null
	var title := LocaleText.resolve("ui.town.untitled", "Town")
	var description := ""
	var rank := 1
	if def != null:
		title = def.get_display_name()
		description = def.get_display_description()
		rank = def.difficulty
	_label("NameLabel").text = title
	_label("BodyLabel").text = _body(def, description, rank)
	var maximum := def.max_restore_points if def != null else town.restore_points
	var bar := get_node(^"VBoxContainer/ProgressBar") as ProgressBar
	bar.max_value = maxf(maximum, 1.0)
	bar.value = clampf(town.restore_points, 0.0, bar.max_value)
	var button := get_node(^"VBoxContainer/RaidButton") as Button
	var locked := town.is_locked()
	var cleared := town.has_been_destroyed
	button.disabled = locked or cleared
	if locked:
		button.text = LocaleText.resolve("ui.town.locked", "Locked")
	elif cleared:
		button.text = LocaleText.resolve("ui.town.cleared", "Cleared")
	else:
		button.text = LocaleText.resolve("ui.town.raid", "Raid")


func _body(def: TownDef, description: String, rank: int) -> String:
	var lines: PackedStringArray = []
	if not description.is_empty():
		lines.append(description)
		lines.append("")
	lines.append(LocaleText.resolve("ui.town.difficulty", "Difficulty {rank}").format({"rank": rank}))
	lines.append(LocaleText.resolve("ui.town.units", "Villagers"))
	var listed := 0
	if def != null:
		for row in def.garrison:
			if row == null or row.count <= 0:
				continue
			lines.append(row.inspector_line())
			listed += 1
	if listed == 0:
		lines.append(LocaleText.resolve("ui.town.no_units", "None"))
	lines.append("")
	lines.append(LocaleText.resolve("ui.town.rewards", "Possible rewards"))
	var rewards := 0
	if def != null:
		for reward in def.rewards:
			if reward == null or reward.amount <= 0:
				continue
			lines.append(reward.inspector_line())
			rewards += 1
	if rewards == 0:
		lines.append(LocaleText.resolve("ui.town.no_rewards", "None"))
	return "\n".join(lines)


func _label(node_name: String) -> Label:
	return get_node("VBoxContainer/%s" % node_name) as Label
