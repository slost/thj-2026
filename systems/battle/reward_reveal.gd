## Pops the resources this raid pays, one icon at a time.
extends VBoxContainer


const _POP := 0.38
const _STAGGER := 0.2

var revealed_count := 0

@onready var _row: HBoxContainer = get_node_or_null("Row") as HBoxContainer


func play(rows: Array) -> void:
	if _row == null:
		return
	for child in _row.get_children():
		child.free()
	revealed_count = 0
	if rows.is_empty():
		var empty := _card(LocaleText.resolve("ui.battle.no_rewards", "No rewards"), "")
		_row.add_child(empty)
		_pop(empty, 0)
		return
	for entry in rows:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var amount := maxi(int(entry.get("amount", 0)), 0)
		if amount <= 0:
			continue
		var title := _resource_name(int(entry.get("resource_type", 0)))
		var card := _card("%s x%d" % [title, amount], _icon_id(int(entry.get("resource_type", 0))))
		_row.add_child(card)
		_pop(card, revealed_count)
		revealed_count += 1


func _pop(card: Control, index: int) -> void:
	card.pivot_offset = Vector2(60, 80)
	card.scale = Vector2(0.15, 0.15)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(float(index) * _STAGGER)
	tween.tween_property(card, "scale", Vector2.ONE, _POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _card(caption: String, icon_id: String) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(120, 160)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := HotSwapTextureRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if icon_id != "":
		icon.asset_id = icon_id
	card.add_child(icon)
	var label := Label.new()
	label.theme_type_variation = &"LabelNumber"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = caption
	card.add_child(label)
	return card


func _icon_id(kind: int) -> String:
	var game := get_tree().root.get_node_or_null("Game") if get_tree() != null else null
	if game != null and game.has_method("resource_icon_id"):
		return str(game.call("resource_icon_id", kind))
	return ""


func _resource_name(kind: int) -> String:
	match kind:
		1:
			return LocaleText.resolve("ui.resource.bone", "Bone")
		2:
			return LocaleText.resolve("ui.resource.weapon", "Weapon")
		3:
			return LocaleText.resolve("ui.resource.collar", "Collar")
		4:
			return LocaleText.resolve("ui.resource.gore", "Gore")
		_:
			return LocaleText.resolve("ui.resource.corpse", "Corpse")
