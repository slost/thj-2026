## Spec pages. The left page lists races. The right page edits the open spell.
## No class_name: this script reads the Game autoload.
extends Control

signal race_selected(race_value: int)
signal corpse_changed(amount: int)
signal gore_changed(amount: int)
signal unlock_pressed(race_value: int)

var _spell: SummonSpell
var _race_page: Control
var _detail_page: Control
var _race_list: VBoxContainer
var _race_group := ButtonGroup.new()
var _cards_queued := false

var _portrait: TextureRect
var _race_name: Label
var _corpse_caption: Label
var _gore_caption: Label
var _corpse_value: Label
var _gore_value: Label
var _corpse_minus: Button
var _corpse_plus: Button
var _gore_minus: Button
var _gore_plus: Button
var _stats: VBoxContainer
var _costs: HBoxContainer
var _explain: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_race_group.allow_unpress = false
	_build_pages()
	if not Game.resource_changed.is_connected(_on_resources):
		Game.resource_changed.connect(_on_resources)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree():
		refresh()


func bind(spell: SummonSpell) -> void:
	_spell = spell
	refresh()


func refresh() -> void:
	_update_detail()
	if _cards_queued:
		return
	_cards_queued = true
	call_deferred("_rebuild_cards")


func race_card_count() -> int:
	if _race_list == null:
		return 0
	return _race_list.get_child_count()


func layout_pages(left: Rect2, right: Rect2) -> void:
	if _race_page == null or _detail_page == null:
		return
	_place(_race_page, left)
	_place(_detail_page, right)


func _on_resources() -> void:
	if visible:
		refresh()


func _build_pages() -> void:
	_race_page = Control.new()
	_race_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_race_page)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_race_page.add_child(scroll)
	_race_list = VBoxContainer.new()
	_race_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_race_list.add_theme_constant_override(&"separation", 8)
	scroll.add_child(_race_list)

	_detail_page = Control.new()
	_detail_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail_page)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override(&"separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_page.add_child(box)

	var title := HBoxContainer.new()
	title.add_theme_constant_override(&"separation", 10)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	_portrait = TextureRect.new()
	_portrait.name = "RacePortrait"
	_portrait.custom_minimum_size = Vector2(72, 72)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(_portrait)
	_race_name = Label.new()
	_race_name.name = "RaceName"
	_race_name.theme_type_variation = &"HeaderTitle"
	_race_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_race_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_race_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_child(_race_name)

	var corpse_row := _stepper()
	_corpse_caption = corpse_row[0]
	_corpse_minus = corpse_row[1]
	_corpse_value = corpse_row[2]
	_corpse_plus = corpse_row[3]
	box.add_child(corpse_row[4])
	_corpse_minus.pressed.connect(_step_corpse.bind(-1))
	_corpse_plus.pressed.connect(_step_corpse.bind(1))

	var gore_row := _stepper()
	_gore_caption = gore_row[0]
	_gore_minus = gore_row[1]
	_gore_value = gore_row[2]
	_gore_plus = gore_row[3]
	box.add_child(gore_row[4])
	_gore_minus.pressed.connect(_step_gore.bind(-1))
	_gore_plus.pressed.connect(_step_gore.bind(1))

	_stats = VBoxContainer.new()
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.add_theme_constant_override(&"separation", 2)
	box.add_child(_stats)

	_costs = HBoxContainer.new()
	_costs.name = "CostRow"
	_costs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_costs.add_theme_constant_override(&"separation", 6)
	box.add_child(_costs)

	_explain = Label.new()
	_explain.name = "ExplainLabel"
	_explain.theme_type_variation = &"Hint"
	_explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_explain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_explain)


func _stepper() -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption := Label.new()
	caption.custom_minimum_size = Vector2(88, 0)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	var minus := _step_button("-")
	row.add_child(minus)
	var value := Label.new()
	value.custom_minimum_size = Vector2(28, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value)
	var plus := _step_button("+")
	row.add_child(plus)
	return [caption, minus, value, plus, row]


func _step_button(text: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.text = text
	button.custom_minimum_size = Vector2(36, 36)
	return button


func _step_corpse(delta: int) -> void:
	if _spell == null:
		return
	corpse_changed.emit(_spell.corpse_amount + delta)


func _step_gore(delta: int) -> void:
	if _spell == null:
		return
	gore_changed.emit(_spell.gore_amount + delta)


func _update_detail() -> void:
	if _race_name == null:
		return
	_explain.text = LocaleText.resolve(
		"ui.spec.explain",
		"Each extra corpse adds 1 CPU and 4 RAM. Each extra gore adds 1 GPU and 2 RAM."
	)
	if _corpse_caption:
		_corpse_caption.text = LocaleText.resolve("ui.spec.corpse", "Corpse")
	if _gore_caption:
		_gore_caption.text = LocaleText.resolve("ui.spec.gore", "Gore")
	if _spell == null:
		_race_name.text = ""
		_portrait.texture = null
		_corpse_value.text = ""
		_gore_value.text = ""
		return
	var profile := RaceProfiles.get_profile(_spell.race)
	_race_name.text = _spell.display_name()
	_portrait.texture = profile.icon if profile != null else null
	_corpse_value.text = str(_spell.corpse_amount)
	_gore_value.text = str(_spell.gore_amount)
	_set_step_enabled(_corpse_minus, _spell.corpse_amount > Formular.spec_min_ingredient())
	_set_step_enabled(_corpse_plus, _spell.corpse_amount < Formular.spec_max_ingredient())
	_set_step_enabled(_gore_minus, _spell.gore_amount > Formular.spec_min_ingredient())
	_set_step_enabled(_gore_plus, _spell.gore_amount < Formular.spec_max_ingredient())
	_fill_stats()
	_fill_summon_costs()


func _set_step_enabled(button: Button, enabled: bool) -> void:
	if button == null:
		return
	button.disabled = not enabled
	button.modulate = Color.WHITE if enabled else Game.DISABLED_COLOR


func _fill_stats() -> void:
	for child in _stats.get_children():
		_stats.remove_child(child)
		child.queue_free()
	if _spell == null or _spell.def == null:
		return
	var def := _spell.def
	var rows: Array[String] = [
		_stat("ui.spec.hp", "HP", def.max_hp),
		_stat("ui.spec.dmg", "DMG", def.damage),
		_stat("ui.spec.range", "Range", def.attack_range),
		_stat("ui.spec.cpu", "CPU", def.cpu),
		_stat("ui.spec.gpu", "GPU", def.gpu),
		_stat("ui.spec.ram", "RAM", _spell.ram_max()),
	]
	for text in rows:
		var label := Label.new()
		label.text = text
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stats.add_child(label)


func _stat(key: String, fallback: String, value: int) -> String:
	return "%s %d" % [LocaleText.resolve(key, fallback), value]


func _fill_summon_costs() -> void:
	_clear(_costs)
	if _spell == null:
		return
	var prefix := Label.new()
	prefix.text = LocaleText.resolve("ui.spec.costs_prefix", "Costs:")
	prefix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prefix.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_costs.add_child(prefix)
	var costs := _spell.get_costs()
	for index in costs.size():
		var cost := costs[index]
		if cost == null:
			continue
		_costs.add_child(_resource_icon(cost.resource_type))
		var bit := Label.new()
		var comma := "," if index < costs.size() - 1 else ""
		bit.text = "%d %s%s" % [cost.amount, _resource_name(cost.resource_type), comma]
		bit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_costs.add_child(bit)


func _rebuild_cards() -> void:
	_cards_queued = false
	if _race_list == null:
		return
	_clear(_race_list)
	for profile in RaceProfiles.all():
		_race_list.add_child(_race_card(profile))


func _race_card(profile: RaceProfile) -> Control:
	var unlocked := Game.is_race_unlocked(profile.race)
	if not unlocked:
		return _locked_card(profile)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	button.button_group = _race_group
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 72)
	button.clip_contents = true
	var row := _icon_name_row(profile)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8.0
	row.offset_right = -8.0
	button.add_child(row)
	if _spell != null and _spell.race == profile.race:
		button.set_pressed_no_signal(true)
	button.pressed.connect(_on_race_pressed.bind(int(profile.race)))
	return button


func _locked_card(profile: RaceProfile) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ActionCard"
	panel.custom_minimum_size = Vector2(0, 96)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 8)
	margin.add_theme_constant_override(&"margin_top", 6)
	margin.add_theme_constant_override(&"margin_right", 8)
	margin.add_theme_constant_override(&"margin_bottom", 6)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	margin.add_child(column)
	column.add_child(_icon_name_row(profile))
	var locked := Label.new()
	locked.theme_type_variation = &"Hint"
	locked.text = LocaleText.resolve("ui.spec.locked", "Locked")
	column.add_child(locked)
	var price := HBoxContainer.new()
	price.add_theme_constant_override(&"separation", 6)
	column.add_child(price)
	for cost in profile.unlock_costs:
		if cost == null or cost.amount <= 0:
			continue
		price.add_child(_resource_icon(cost.resource_type))
		var amount := Label.new()
		amount.text = str(cost.amount)
		amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price.add_child(amount)
	var unlock := Button.new()
	unlock.focus_mode = Control.FOCUS_NONE
	unlock.text = LocaleText.resolve("ui.spec.unlock", "Unlock")
	var affordable := Game.can_afford(profile.unlock_costs)
	unlock.disabled = not affordable
	unlock.modulate = Color.WHITE if affordable else Game.DISABLED_COLOR
	unlock.pressed.connect(_on_unlock_pressed.bind(int(profile.race)))
	price.add_child(unlock)
	return panel


func _icon_name_row(profile: RaceProfile) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = profile.icon
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var name := Label.new()
	name.text = profile.display_name()
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.clip_text = true
	row.add_child(name)
	return row


func _on_race_pressed(race_value: int) -> void:
	race_selected.emit(race_value)


func _on_unlock_pressed(race_value: int) -> void:
	unlock_pressed.emit(race_value)


func _resource_icon(type_value: int) -> TextureRect:
	var icon := HotSwapTextureRect.new()
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kind: Game.ResourceType = type_value
	icon.asset_id = Game.resource_icon_id(kind)
	return icon


func _resource_name(type_value: int) -> String:
	match type_value:
		Game.ResourceType.CORPSE:
			return LocaleText.resolve("ui.resource.corpse", "Corpse")
		Game.ResourceType.BONE:
			return LocaleText.resolve("ui.resource.bone", "Bone")
		Game.ResourceType.WEAPON:
			return LocaleText.resolve("ui.resource.weapon", "Weapon")
		Game.ResourceType.COLLAR:
			return LocaleText.resolve("ui.resource.collar", "Collar")
		Game.ResourceType.GORE:
			return LocaleText.resolve("ui.resource.gore", "Gore")
		_:
			return ""


func _clear(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _place(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y
