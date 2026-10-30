## Builds the project theme and the Necronomicon sub-theme from _Palette.
## Run res://systems/ui/theme/build_flat_theme.gd to write the .tres files.
## Those files load on their own; this script does not have to run in game.
@tool
class_name FlatThemeBuilder
extends RefCounted


const _Palette := preload("res://systems/ui/theme/ui_palette.gd")
const THEME_PATH := "res://systems/ui/theme/flat_theme.tres"
const BOOK_PATH := "res://systems/code_editor/editor_theme.tres"
const BOOK_UID := "uid://doqiyxntvcwdh"


static func save_all() -> Error:
	var font := load(_Palette.FONT_PATH) as Font
	if font == null:
		push_error("Flat theme font is missing: %s" % _Palette.FONT_PATH)
		return ERR_FILE_NOT_FOUND
	var theme := build(font)
	var book := build_book(font)
	var theme_error := ResourceSaver.save(theme, THEME_PATH)
	if theme_error != OK:
		return theme_error
	var book_error := ResourceSaver.save(book, BOOK_PATH)
	if book_error != OK:
		return book_error
	_keep_uid(BOOK_PATH, BOOK_UID)
	return OK


static func build(font: Font) -> Theme:
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = _Palette.BODY
	_controls(theme)
	_buttons(theme)
	_bars(theme)
	_book_pieces(theme, _Palette.TEXT, _Palette.TEXT_MUTED)
	return theme


## Paper colors for controls that sit on the book artwork.
## Buttons stay on the project theme so a button looks the same everywhere.
static func build_book(font: Font) -> Theme:
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = _Palette.BODY
	_paper_labels(theme)
	_book_pieces(theme, _Palette.INK, _Palette.INK_MUTED)
	_rune_silhouettes(theme)
	_style(theme, "Panel", "panel", _fill(_Palette.PAPER, _Palette.M, _Palette.M))
	_style(theme, "PanelContainer", "panel", _fill(_Palette.PAPER, _Palette.M, _Palette.M))
	return theme


static func _controls(theme: Theme) -> void:
	var panel := _fill(_Palette.PANEL, _Palette.M, _Palette.M)
	_style(theme, "Panel", "panel", panel)
	_style(theme, "PanelContainer", "panel", panel)
	_style(theme, "PanelDark", "panel", _fill(_Palette.BG_DARK, _Palette.M, _Palette.M))
	_style(theme, "PanelLight", "panel", _fill(_Palette.PAPER, _Palette.M, _Palette.M))
	theme.set_type_variation(&"PanelDark", &"PanelContainer")
	theme.set_type_variation(&"PanelLight", &"PanelContainer")

	_label(theme, "Label", _Palette.TEXT, _Palette.BODY)
	_label(theme, "LabelTitle", _Palette.TEXT, _Palette.TITLE)
	_label(theme, "LabelMuted", _Palette.TEXT_MUTED, _Palette.SMALL)
	_label(theme, "LabelNumber", _Palette.TEXT, _Palette.TITLE)
	theme.set_type_variation(&"LabelTitle", &"Label")
	theme.set_type_variation(&"LabelMuted", &"Label")
	theme.set_type_variation(&"LabelNumber", &"Label")

	_rich_text(theme, _Palette.TEXT)
	_line_edit(theme)
	_popup(theme)
	_slider(theme)
	_progress(theme, "ProgressBar", _Palette.PANEL, _Palette.ACCENT)
	_scroll(theme)
	_tabs(theme)
	_lists(theme)
	_tooltip(theme)
	_separators(theme)
	_boxes(theme)

	# TextureButton has no style boxes. Icon slots use ButtonIcon instead.
	theme.set_constant(&"h_separation", &"HBoxContainer", _Palette.M)


static func _buttons(theme: Theme) -> void:
	_button_type(theme, &"Button", _Palette.PANEL_ALT, _Palette.PANEL_ALT.lightened(0.12), _Palette.ACCENT, _Palette.PANEL_ALT.lerp(_Palette.ACCENT, 0.55), _Palette.TEXT, _Palette.BODY, _Palette.M, _Palette.S)
	_button_type(theme, &"ButtonPrimary", _Palette.ACCENT, _Palette.ACCENT_HOVER, _Palette.ACCENT.darkened(0.18), _Palette.ACCENT.lerp(Color.WHITE, 0.28), _Palette.TEXT_ON_ACCENT, _Palette.BODY, _Palette.M, _Palette.S)
	_button_type(theme, &"ButtonDanger", _Palette.DANGER, _Palette.DANGER.lightened(0.15), _Palette.DANGER.darkened(0.18), _Palette.DANGER.lerp(Color.WHITE, 0.28), _Palette.TEXT, _Palette.BODY, _Palette.M, _Palette.S)
	_button_type(theme, &"ButtonGhost", Color(0, 0, 0, 0), _Palette.PANEL_ALT, _Palette.PANEL, _Palette.PANEL_ALT.lerp(_Palette.ACCENT, 0.45), _Palette.TEXT, _Palette.BODY, _Palette.M, _Palette.S)
	_button_type(theme, &"ButtonIcon", _Palette.PANEL_ALT, _Palette.PANEL_ALT.lightened(0.12), _Palette.ACCENT, _Palette.PANEL_ALT.lerp(_Palette.ACCENT, 0.55), _Palette.TEXT, _Palette.SMALL, _Palette.S, _Palette.S)
	for variation in ["ButtonPrimary", "ButtonDanger", "ButtonGhost", "ButtonIcon"]:
		theme.set_type_variation(variation, &"Button")
	# Built-in controls cannot be type variations in Godot 4.8, so they get the same fills directly.
	for inherited in ["OptionButton", "CheckBox", "CheckButton", "MenuButton"]:
		_button_type(theme, inherited, _Palette.PANEL_ALT, _Palette.PANEL_ALT.lightened(0.12), _Palette.ACCENT, _Palette.PANEL_ALT.lerp(_Palette.ACCENT, 0.55), _Palette.TEXT, _Palette.BODY, _Palette.M, _Palette.S)
	_checks(theme)
	var arrow := _triangle(_Palette.TEXT, true)
	theme.set_icon(&"arrow", &"OptionButton", arrow)
	theme.set_constant(&"arrow_margin", &"OptionButton", _Palette.S)
	theme.set_icon(&"up", &"SpinBox", _triangle(_Palette.TEXT, false))
	theme.set_icon(&"down", &"SpinBox", arrow)
	theme.set_icon(&"updown", &"SpinBox", arrow)
	theme.set_constant(&"buttons_width", &"SpinBox", _Palette.BUTTON_HUD)
	theme.set_constant(&"field_and_buttons_separation", &"SpinBox", _Palette.S)
	_line_edit_type(theme, &"SpinBox")


static func _button_type(theme: Theme, type_name: StringName, normal: Color, hover: Color, pressed: Color, focus: Color, font_color: Color, font_size: int, margin_h: int, margin_v: int) -> void:
	var disabled_fill: Color = _Palette.DISABLED_FILL
	if normal.a < 0.01:
		disabled_fill = Color(0, 0, 0, 0)
	_style(theme, type_name, "normal", _fill(normal, margin_h, margin_v))
	_style(theme, type_name, "hover", _fill(hover, margin_h, margin_v))
	_style(theme, type_name, "pressed", _fill(pressed, margin_h, margin_v))
	_style(theme, type_name, "hover_pressed", _fill(pressed, margin_h, margin_v))
	_style(theme, type_name, "disabled", _fill(disabled_fill, margin_h, margin_v))
	_style(theme, type_name, "focus", _fill(focus, margin_h, margin_v))
	theme.set_color(&"font_color", type_name, font_color)
	theme.set_color(&"font_hover_color", type_name, font_color)
	theme.set_color(&"font_pressed_color", type_name, font_color)
	theme.set_color(&"font_hover_pressed_color", type_name, font_color)
	theme.set_color(&"font_focus_color", type_name, font_color)
	theme.set_color(&"font_disabled_color", type_name, _Palette.DISABLED_TEXT)
	theme.set_font_size(&"font_size", type_name, font_size)
	theme.set_constant(&"outline_size", type_name, 0)
	theme.set_constant(&"h_separation", type_name, _Palette.S)
	var icon := font_color
	theme.set_color(&"icon_normal_color", type_name, icon)
	theme.set_color(&"icon_hover_color", type_name, icon)
	theme.set_color(&"icon_pressed_color", type_name, icon)
	theme.set_color(&"icon_hover_pressed_color", type_name, icon)
	theme.set_color(&"icon_focus_color", type_name, icon)
	theme.set_color(&"icon_disabled_color", type_name, _Palette.DISABLED_TEXT)


static func _checks(theme: Theme) -> void:
	var empty := _square(_Palette.PANEL_ALT, _Palette.M)
	var mark := _square(_Palette.ACCENT, _Palette.M)
	var off := _square(_Palette.DISABLED_FILL, _Palette.M)
	for type_name in ["CheckBox", "CheckButton", "Tree", "PopupMenu"]:
		theme.set_icon(&"checked", type_name, mark)
		theme.set_icon(&"unchecked", type_name, empty)
		theme.set_icon(&"checked_disabled", type_name, off)
		theme.set_icon(&"unchecked_disabled", type_name, off)
		theme.set_icon(&"radio_checked", type_name, mark)
		theme.set_icon(&"radio_unchecked", type_name, empty)
		theme.set_icon(&"radio_checked_disabled", type_name, off)
		theme.set_icon(&"radio_unchecked_disabled", type_name, off)
	theme.set_constant(&"h_separation", &"CheckBox", _Palette.S)
	theme.set_constant(&"h_separation", &"CheckButton", _Palette.S)
	theme.set_constant(&"check_v_offset", &"CheckBox", 0)
	theme.set_constant(&"check_v_offset", &"CheckButton", 0)


static func _bars(theme: Theme) -> void:
	_progress(theme, "BarHP", _Palette.BG_DARK, _Palette.DANGER)
	_progress(theme, "BarThink", _Palette.BG_DARK, _Palette.INFO)
	_progress(theme, "BarAnim", _Palette.BG_DARK, _Palette.WARN)
	_progress(theme, "BarCity", _Palette.BG_DARK, _Palette.ACCENT)
	for variation in ["BarHP", "BarThink", "BarAnim", "BarCity"]:
		theme.set_type_variation(variation, &"ProgressBar")


static func _book_pieces(theme: Theme, ink: Color, muted: Color) -> void:
	_rune(theme, &"ConditionCard", _Palette.RUNE_CONDITION)
	_rune(theme, &"ConditionCardSelected", _Palette.RUNE_CONDITION.lightened(0.18))
	_rune(theme, &"ActionCard", _Palette.RUNE_ACTION)
	_rune(theme, &"ActionCardSelected", _Palette.RUNE_ACTION.lightened(0.18))
	_rune(theme, &"OtherCard", _Palette.RUNE_OTHER)
	_rune(theme, &"OtherCardSelected", _Palette.RUNE_OTHER.lightened(0.18))
	for variation in ["ConditionCard", "ConditionCardSelected", "ActionCard", "ActionCardSelected", "OtherCard", "OtherCardSelected", "Badge"]:
		theme.set_type_variation(variation, &"PanelContainer")
	_style(theme, "Badge", "panel", _fill(Color(ink.r, ink.g, ink.b, 0.14), _Palette.S, 0))
	_label(theme, "CardTitle", ink, _Palette.BODY)
	_label(theme, "BadgeLabel", ink, _Palette.SMALL)
	_label(theme, "HeaderTitle", ink, _Palette.BODY)
	_label(theme, "Hint", muted, _Palette.SMALL)
	_label(theme, "Empty", muted, _Palette.SMALL)
	theme.set_type_variation(&"CardTitle", &"Label")
	theme.set_type_variation(&"BadgeLabel", &"Label")
	theme.set_type_variation(&"HeaderTitle", &"Label")
	theme.set_type_variation(&"Hint", &"Label")
	theme.set_type_variation(&"Empty", &"Label")
	theme.set_color(&"unowned_modulate", &"BlockCard", _Palette.TEXT_MUTED)
	theme.set_type_variation(&"BlockCard", &"Control")


static func _paper_labels(theme: Theme) -> void:
	_label(theme, "Label", _Palette.INK, _Palette.BODY)
	_rich_text(theme, _Palette.INK)


static func _rune(theme: Theme, type_name: StringName, color: Color) -> void:
	var box := _fill(color, _Palette.S, 0)
	_style(theme, type_name, "panel", box)


## Condition is a blue pill. Action is a warm ticket with the notch on the left.
## These two silhouettes are the book theme only, so the rest of the UI stays square.
static func _rune_silhouettes(theme: Theme) -> void:
	for type_name in ["ConditionCard", "ConditionCardSelected", "ActionCard", "ActionCardSelected"]:
		_style(theme, type_name, "panel", rune_panel(type_name))


static var _panels := {}


## The chip is 48px tall, so the radius is half of that. A smaller radius reads as a square.
static func rune_panel(variation: String) -> StyleBoxFlat:
	if _panels.has(variation):
		return _panels[variation]
	var box := _make_rune_panel(variation)
	_panels[variation] = box
	return box


static func _make_rune_panel(variation: String) -> StyleBoxFlat:
	var condition := variation.begins_with("Condition")
	var action := variation.begins_with("Action")
	if not condition and not action:
		return null
	var selected := variation.ends_with("Selected")
	var box := StyleBoxFlat.new()
	box.set_border_width_all(4 if selected else 3)
	box.border_color = Color(0.72, 0.45, 0.05, 1) if selected else Color(0.28, 0.42, 0.55, 1)
	box.shadow_color = Color(0.2, 0.16, 0.1, 0.18)
	box.shadow_size = 1
	box.shadow_offset = Vector2(0, 1)
	box.anti_aliasing = true
	box.content_margin_left = 12.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	if condition:
		box.bg_color = Color(0.82, 0.89, 0.93, 1)
		box.set_corner_radius_all(24)
		box.content_margin_right = 8.0
	else:
		box.bg_color = Color(0.96, 0.9, 0.74, 1)
		box.border_color = Color(0.72, 0.45, 0.05, 1) if selected else Color(0.55, 0.34, 0.12, 1)
		box.corner_radius_top_left = 8
		box.corner_radius_top_right = 24
		box.corner_radius_bottom_right = 8
		box.corner_radius_bottom_left = 20
		box.content_margin_right = 10.0
	return box


static func _label(theme: Theme, type_name: String, color: Color, size: int) -> void:
	theme.set_color(&"font_color", type_name, color)
	theme.set_font_size(&"font_size", type_name, size)
	theme.set_constant(&"outline_size", type_name, 0)
	theme.set_constant(&"shadow_offset_x", type_name, 0)
	theme.set_constant(&"shadow_offset_y", type_name, 0)
	theme.set_constant(&"shadow_outline_size", type_name, 0)
	theme.set_constant(&"line_spacing", type_name, 0)


static func _rich_text(theme: Theme, color: Color) -> void:
	theme.set_color(&"default_color", &"RichTextLabel", color)
	theme.set_font_size(&"normal_font_size", &"RichTextLabel", _Palette.BODY)
	theme.set_font_size(&"bold_font_size", &"RichTextLabel", _Palette.BODY)
	theme.set_font_size(&"italics_font_size", &"RichTextLabel", _Palette.BODY)
	theme.set_font_size(&"bold_italics_font_size", &"RichTextLabel", _Palette.BODY)
	theme.set_font_size(&"mono_font_size", &"RichTextLabel", _Palette.BODY)
	theme.set_constant(&"outline_size", &"RichTextLabel", 0)
	theme.set_constant(&"shadow_offset_x", &"RichTextLabel", 0)
	theme.set_constant(&"shadow_offset_y", &"RichTextLabel", 0)
	theme.set_constant(&"shadow_outline_size", &"RichTextLabel", 0)
	theme.set_constant(&"line_separation", &"RichTextLabel", 0)
	var focus := _fill(_Palette.PANEL_ALT.lerp(_Palette.ACCENT, 0.35), _Palette.S, _Palette.S)
	_style(theme, "RichTextLabel", "focus", focus)
	_style(theme, "RichTextLabel", "normal", _fill(Color(0, 0, 0, 0), 0, 0))


static func _line_edit(theme: Theme) -> void:
	for type_name in ["LineEdit", "TextEdit"]:
		_line_edit_type(theme, type_name)


static func _line_edit_type(theme: Theme, type_name: StringName) -> void:
	_style(theme, type_name, "normal", _fill(_Palette.PANEL, _Palette.S, _Palette.S))
	_style(theme, type_name, "focus", _fill(_Palette.PANEL_ALT.lerp(_Palette.ACCENT, 0.4), _Palette.S, _Palette.S))
	_style(theme, type_name, "read_only", _fill(_Palette.DISABLED_FILL, _Palette.S, _Palette.S))
	theme.set_color(&"font_color", type_name, _Palette.TEXT)
	theme.set_color(&"font_selected_color", type_name, _Palette.TEXT_ON_ACCENT)
	theme.set_color(&"font_placeholder_color", type_name, _Palette.TEXT_MUTED)
	theme.set_color(&"font_uneditable_color", type_name, _Palette.DISABLED_TEXT)
	theme.set_color(&"caret_color", type_name, _Palette.ACCENT)
	theme.set_color(&"selection_color", type_name, _Palette.tint(_Palette.ACCENT, 0.45))
	theme.set_font_size(&"font_size", type_name, _Palette.BODY)
	theme.set_constant(&"outline_size", type_name, 0)
	theme.set_constant(&"caret_width", type_name, 2)


static func _popup(theme: Theme) -> void:
	_style(theme, "PopupMenu", "panel", _fill(_Palette.PANEL, _Palette.S, _Palette.S))
	_style(theme, "PopupMenu", "hover", _fill(_Palette.ACCENT, _Palette.S, _Palette.S))
	var rule := _fill(_Palette.PANEL_ALT, 0, 1)
	_style(theme, "PopupMenu", "separator", rule)
	_style(theme, "PopupMenu", "labeled_separator_left", rule)
	_style(theme, "PopupMenu", "labeled_separator_right", rule)
	theme.set_color(&"font_color", &"PopupMenu", _Palette.TEXT)
	theme.set_color(&"font_hover_color", &"PopupMenu", _Palette.TEXT_ON_ACCENT)
	theme.set_color(&"font_accelerator_color", &"PopupMenu", _Palette.TEXT_MUTED)
	theme.set_color(&"font_disabled_color", &"PopupMenu", _Palette.DISABLED_TEXT)
	theme.set_color(&"font_separator_color", &"PopupMenu", _Palette.TEXT_MUTED)
	theme.set_font_size(&"font_size", &"PopupMenu", _Palette.BODY)
	theme.set_constant(&"v_separation", &"PopupMenu", _Palette.S)
	theme.set_constant(&"h_separation", &"PopupMenu", _Palette.S)
	theme.set_icon(&"submenu", &"PopupMenu", _triangle(_Palette.TEXT, false))


static func _slider(theme: Theme) -> void:
	var track := _fill(_Palette.BG_DARK, 0, _Palette.S / 2)
	var fill := _fill(_Palette.ACCENT, 0, _Palette.S / 2)
	var grabber := _square(_Palette.TEXT, 12)
	var grabber_on := _square(_Palette.ACCENT_HOVER, 12)
	var grabber_off := _square(_Palette.DISABLED_TEXT, 12)
	for type_name in ["HSlider", "VSlider"]:
		_style(theme, type_name, "slider", track)
		_style(theme, type_name, "grabber_area", fill)
		_style(theme, type_name, "grabber_area_highlight", _fill(_Palette.ACCENT_HOVER, 0, _Palette.S / 2))
		theme.set_icon(&"grabber", type_name, grabber)
		theme.set_icon(&"grabber_highlight", type_name, grabber_on)
		theme.set_icon(&"grabber_disabled", type_name, grabber_off)
		theme.set_constant(&"center_grabber", type_name, 1)
		theme.set_constant(&"grabber_offset", type_name, 0)


static func _progress(theme: Theme, type_name: String, background: Color, fill: Color) -> void:
	_style(theme, type_name, "background", _fill(background, 0, 0))
	_style(theme, type_name, "fill", _fill(fill, 0, 0))
	theme.set_color(&"font_color", type_name, _Palette.TEXT)
	theme.set_font_size(&"font_size", type_name, _Palette.SMALL)
	theme.set_constant(&"outline_size", type_name, 0)


static func _scroll(theme: Theme) -> void:
	var track := _fill(_Palette.BG_DARK, _Palette.S / 2, _Palette.S / 2)
	var grabber := _fill(_Palette.PANEL_ALT, _Palette.S / 2, _Palette.S / 2)
	var grabber_on := _fill(_Palette.ACCENT, _Palette.S / 2, _Palette.S / 2)
	var blank := _square(Color(0, 0, 0, 0), 8)
	for type_name in ["VScrollBar", "HScrollBar"]:
		_style(theme, type_name, "scroll", track)
		_style(theme, type_name, "scroll_focus", track)
		_style(theme, type_name, "grabber", grabber)
		_style(theme, type_name, "grabber_highlight", grabber_on)
		_style(theme, type_name, "grabber_pressed", grabber_on)
		for icon_name in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
			theme.set_icon(icon_name, type_name, blank)
	_style(theme, "ScrollContainer", "panel", _fill(Color(0, 0, 0, 0), 0, 0))


static func _tabs(theme: Theme) -> void:
	var idle := _fill(_Palette.PANEL, _Palette.M, _Palette.S)
	var hot := _fill(_Palette.PANEL_ALT, _Palette.M, _Palette.S)
	var on := _fill(_Palette.ACCENT, _Palette.M, _Palette.S)
	_style(theme, "TabContainer", "panel", _fill(_Palette.PANEL, _Palette.M, _Palette.M))
	_style(theme, "TabBar", "tab_unselected", idle)
	_style(theme, "TabBar", "tab_hovered", hot)
	_style(theme, "TabBar", "tab_selected", on)
	_style(theme, "TabBar", "tab_disabled", _fill(_Palette.DISABLED_FILL, _Palette.M, _Palette.S))
	_style(theme, "TabBar", "tab_focus", _fill(_Palette.PANEL_ALT.lerp(_Palette.ACCENT, 0.55), _Palette.M, _Palette.S))
	_style(theme, "TabBar", "button_pressed", on)
	_style(theme, "TabBar", "button_highlight", hot)
	theme.set_color(&"font_selected_color", &"TabBar", _Palette.TEXT_ON_ACCENT)
	theme.set_color(&"font_unselected_color", &"TabBar", _Palette.TEXT)
	theme.set_color(&"font_hovered_color", &"TabBar", _Palette.TEXT)
	theme.set_color(&"font_disabled_color", &"TabBar", _Palette.DISABLED_TEXT)
	theme.set_color(&"font_outline_color", &"TabBar", Color(0, 0, 0, 0))
	theme.set_font_size(&"font_size", &"TabBar", _Palette.BODY)
	theme.set_constant(&"outline_size", &"TabBar", 0)
	theme.set_constant(&"h_separation", &"TabBar", _Palette.S)
	var blank := _square(Color(0, 0, 0, 0), 8)
	theme.set_icon(&"increment", &"TabBar", blank)
	theme.set_icon(&"decrement", &"TabBar", blank)
	theme.set_icon(&"drop_mark", &"TabBar", _square(_Palette.ACCENT, _Palette.S))
	theme.set_icon(&"close", &"TabBar", _square(_Palette.DANGER, _Palette.S))


static func _lists(theme: Theme) -> void:
	var panel := _fill(_Palette.PANEL, _Palette.S, _Palette.S)
	var hover := _fill(_Palette.PANEL_ALT, _Palette.S, _Palette.S)
	var selected := _fill(_Palette.ACCENT, _Palette.S, _Palette.S)
	var focus := _fill(_Palette.PANEL_ALT.lerp(_Palette.ACCENT, 0.45), _Palette.S, _Palette.S)
	for type_name in ["ItemList", "Tree"]:
		_style(theme, type_name, "panel", panel)
		_style(theme, type_name, "hovered", hover)
		_style(theme, type_name, "selected", selected)
		_style(theme, type_name, "cursor", selected)
		_style(theme, type_name, "focus", focus)
		theme.set_color(&"font_color", type_name, _Palette.TEXT)
		theme.set_color(&"font_hovered_color", type_name, _Palette.TEXT)
		theme.set_color(&"font_selected_color", type_name, _Palette.TEXT_ON_ACCENT)
		theme.set_color(&"guide_color", type_name, _Palette.TEXT_MUTED)
		theme.set_font_size(&"font_size", type_name, _Palette.BODY)
		theme.set_constant(&"h_separation", type_name, _Palette.S)
		theme.set_constant(&"v_separation", type_name, _Palette.S)
		theme.set_constant(&"outline_size", type_name, 0)
	_style(theme, "ItemList", "hovered_selected", selected)
	theme.set_color(&"relationship_line_color", &"Tree", _Palette.TEXT_MUTED)
	theme.set_color(&"parent_hl_line_color", &"Tree", _Palette.ACCENT)
	theme.set_color(&"children_hl_line_color", &"Tree", _Palette.ACCENT)
	theme.set_color(&"drop_position_color", &"Tree", _Palette.WARN)
	theme.set_constant(&"relationship_line_width", &"Tree", 0)
	theme.set_constant(&"parent_hl_line_width", &"Tree", 0)
	theme.set_constant(&"children_hl_line_width", &"Tree", 0)
	theme.set_icon(&"arrow", &"Tree", _triangle(_Palette.TEXT, true))
	theme.set_icon(&"arrow_collapsed", &"Tree", _triangle(_Palette.TEXT, false))
	_style(theme, "Tree", "button_pressed", selected)
	_style(theme, "Tree", "button_hover", hover)


static func _tooltip(theme: Theme) -> void:
	_style(theme, "TooltipPanel", "panel", _fill(_Palette.PANEL, _Palette.M, _Palette.S))
	theme.set_color(&"font_color", &"TooltipLabel", _Palette.TEXT)
	theme.set_font_size(&"font_size", &"TooltipLabel", _Palette.BODY)
	theme.set_constant(&"outline_size", &"TooltipLabel", 0)


static func _separators(theme: Theme) -> void:
	var rule := _fill(_Palette.PANEL_ALT, 0, 1)
	_style(theme, "HSeparator", "separator", rule)
	_style(theme, "VSeparator", "separator", rule)
	theme.set_constant(&"separation", &"HSeparator", _Palette.S)
	theme.set_constant(&"separation", &"VSeparator", _Palette.S)


static func _boxes(theme: Theme) -> void:
	for type_name in ["HBoxContainer", "VBoxContainer"]:
		theme.set_constant(&"separation", type_name, _Palette.M)
	theme.set_constant(&"h_separation", &"GridContainer", _Palette.M)
	theme.set_constant(&"v_separation", &"GridContainer", _Palette.M)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		theme.set_constant(side, &"MarginContainer", _Palette.M)


static func _style(theme: Theme, type_name: String, item: String, box: StyleBox) -> void:
	theme.set_stylebox(item, type_name, box)


static func _fill(color: Color, margin_h: float, margin_v: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(0)
	box.set_border_width_all(0)
	box.shadow_size = 0
	box.anti_aliasing = false
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	return box


static func _square(color: Color, size: int) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


static func _triangle(color: Color, point_down: bool) -> ImageTexture:
	var size := 12
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in size:
		var span := y if point_down else size - 1 - y
		var half := int(float(span) * 0.45)
		var mid := size / 2
		for x in range(mid - half, mid + half):
			if x >= 0 and x < size:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


static func _keep_uid(path: String, uid: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return
	var line_end := text.find("\n")
	var header := text.substr(0, line_end)
	var rest := text.substr(line_end)
	if header.contains("uid="):
		var start := header.find("uid=\"")
		var stop := header.find("\"", start + 5)
		header = header.substr(0, start) + "uid=\"%s\"" % uid + header.substr(stop + 1)
	else:
		header = header.replace("[gd_resource ", "[gd_resource uid=\"%s\" " % uid)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(header + rest)
	file.close()
