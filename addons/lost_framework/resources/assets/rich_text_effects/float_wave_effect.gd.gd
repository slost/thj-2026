@tool
extends RichTextEffect
class_name FloatWaveEffect

var bbcode := "float_wave"

@export var default_amplitude := 6.0
@export var default_speed := 7.0
@export var default_char_delay := 0.04
@export var default_fade_time := 0.6


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var i := char_fx.relative_index
	var env := char_fx.env

	var amp := _get_param(env, "amp", default_amplitude)
	var speed := _get_param(env, "speed", default_speed)
	var delay := _get_param(env, "delay", default_char_delay)
	var fade_time := _get_param(env, "fade", default_fade_time)

	var t := char_fx.elapsed_time - i * delay
	if t < 0.0:
		return true

	# ---- wave movement ----
	char_fx.offset.y -= sin(t * speed) * amp

	# ---- fade ----
	var alpha := 1.0 - (t / fade_time)
	char_fx.color.a *= clamp(alpha, 0.0, 1.0)

	return true


func _get_param(env: Dictionary, key: String, default_value: float) -> float:
	if not env.has(key):
		return default_value
	var v = env[key]
	if v == null:
		return default_value
	match typeof(v):
		TYPE_FLOAT:
			return v
		TYPE_INT:
			return float(v)
		TYPE_STRING:
			return v.to_float()
		_:
			return default_value
