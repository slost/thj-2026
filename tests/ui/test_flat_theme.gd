extends SceneTree

const THEME_PATH := "res://systems/ui/theme/flat_theme.tres"
const FONT_PATH := "res://contents/bc-rebecca-sharp-regular.otf"

var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_theme()
	_test_scenes("res://")
	if _failed == 0:
		print("flat theme checks passed")
	else:
		print("%d flat theme checks failed" % _failed)
	quit(1 if _failed else 0)


func _test_theme() -> void:
	var theme := load(THEME_PATH) as Theme
	if theme == null:
		_fail("flat theme did not load")
		return
	var font := theme.default_font
	var font_name := font.get_font_name() if font != null else ""
	var font_path := font.resource_path if font != null else ""
	if font == null or (font_path != FONT_PATH and not font_name.to_lower().contains("rebecca")):
		_fail("default font is not Rebecca Sharp (%s / %s)" % [font_path, font_name])
	var seen := {}
	for type_name in theme.get_type_list():
		for item in theme.get_stylebox_list(type_name):
			var box := theme.get_stylebox(item, type_name)
			if box == null or seen.has(box.get_instance_id()):
				continue
			seen[box.get_instance_id()] = true
			if not box is StyleBoxFlat:
				_fail("%s/%s is %s" % [type_name, item, box.get_class()])
				continue
			var flat := box as StyleBoxFlat
			for corner in 4:
				if flat.get_corner_radius(corner) != 0:
					_fail("%s/%s corner %d is %d" % [type_name, item, corner, flat.get_corner_radius(corner)])
				if flat.get_border_width(corner) != 0:
					_fail("%s/%s border %d is %d" % [type_name, item, corner, flat.get_border_width(corner)])
			if flat.shadow_size != 0:
				_fail("%s/%s shadow is %d" % [type_name, item, flat.shadow_size])


func _test_scenes(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := path.path_join(entry)
			if dir.current_is_dir():
				if entry != "addons":
					_test_scenes(full)
			elif entry.ends_with(".tscn") or entry.ends_with(".tres"):
				_scan_text(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _scan_text(path: String) -> void:
	# Condition pills and action tickets live only in the book theme.
	if path.ends_with("editor_theme.tres"):
		_test_book_runes()
		return
	var text := FileAccess.get_file_as_string(path)
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if not line.begins_with("corner_radius_") and not line.begins_with("border_width_"):
			continue
		var parts := line.split("=")
		if parts.size() < 2:
			continue
		if float(parts[1].strip_edges()) > 0.0:
			_fail("%s has %s" % [path, line])


func _test_book_runes() -> void:
	var theme := load("res://systems/code_editor/editor_theme.tres") as Theme
	if theme == null:
		_fail("book theme did not load")
		return
	var condition := theme.get_stylebox(&"panel", &"ConditionCard") as StyleBoxFlat
	var action := theme.get_stylebox(&"panel", &"ActionCard") as StyleBoxFlat
	if condition == null or action == null:
		_fail("book rune styles are missing")
		return
	for corner in 4:
		if condition.get_corner_radius(corner) < 12 or condition.get_border_width(corner) < 1:
			_fail("condition rune is not a bordered pill")
			break
	var same_corner := action.get_corner_radius(0) == action.get_corner_radius(1)
	if same_corner or action.get_border_width(0) < 1:
		_fail("action rune is not a bordered ticket")
	if condition.bg_color.is_equal_approx(action.bg_color):
		_fail("condition and action fills match")
	var shaped := ["ConditionCard", "ConditionCardSelected", "ActionCard", "ActionCardSelected"]
	for type_name in theme.get_type_list():
		if shaped.has(String(type_name)):
			continue
		for item in theme.get_stylebox_list(type_name):
			var box := theme.get_stylebox(item, type_name) as StyleBoxFlat
			if box == null:
				continue
			for corner in 4:
				if box.get_corner_radius(corner) != 0 or box.get_border_width(corner) != 0:
					_fail("book %s/%s is not flat" % [type_name, item])
					return


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
