@tool
extends RichTextLabel
class_name EffectTextLabel


const PRESETS := {
	"crit": {
		"open": "[squash x=1.4 y=0.6][float_wave amp=9 speed=9][color=#ff4040]",
		"close": "[/color][/float_wave][/squash]"
	},
	"dot": {
		"open": "[float_wave amp=4 speed=5 fade=1.2][color=#80ff80]",
		"close": "[/color][/float_wave]"
	}
}


## Base text to display
@export_multiline var base_text: String:
	set(value):
		base_text = value
		_on_base_text_changed()

@export_category("Configures")
@export var font_size: int = 16:
	set(value):
		font_size = value
		_update()

@export var auto_resize: bool = true
@export var effects: Array = []

func _init() -> void:
	Utils.set_to_main_theme(self)

func _ready() -> void:
	_setup()
	_update()


func set_text(new_text) -> void:
	base_text = new_text
	_update()

## Initial setup
func _setup() -> void:
	bbcode_enabled = true
	fit_content = false
	scroll_active = false
	autowrap_mode = TextServer.AUTOWRAP_OFF


func _on_base_text_changed() -> void:
	_update()


func _update() -> void:
	_update_text(base_text)
	_change_font_size()
	_resize_to_content()


func _update_text(raw_text: String) -> void:
	text = raw_text


func _change_font_size() -> void:
	add_theme_font_size_override("normal_font_size", font_size)
	add_theme_font_size_override("bbcode_normal_font_size", font_size)

func apply_presets(text: String) -> String:
	for key in PRESETS.keys():
		var p = PRESETS[key]
		text = text.replace(
			"[%s]" % key,
			p.open
		)
		text = text.replace(
			"[/%s]" % key,
			p.close
		)
	return text


func _resize_to_content() -> void:
	return
	if not auto_resize:
		return

	var font: Font = get_theme_font("normal_font")
	var font_size: int = get_theme_font_size("normal_font_size")
	
	if font == null:
		return
	
	var plain_text: String = get_parsed_text()
	
	var lines := plain_text.split("\n")
	var max_width := 0.0
	
	for line in lines:
		var w := font.get_string_size(
			line,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size
		).x
		max_width = max(max_width, w)
	
	var line_height := font.get_height(font_size)
	var total_height := line_height * lines.size()
	
	var content_size := Vector2(max_width, total_height)
	
	custom_minimum_size = content_size
	size = content_size
	
	update_minimum_size()
	
