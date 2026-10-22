@tool
extends RichTextEffect
class_name FloatImpactTextEffect

var bbcode := "float_impact"

## ---- movement ----
@export var default_amplitude := 6.0
@export var default_speed := 7.0
@export var default_char_delay := 0.04
@export var default_fade_time := 0.6

## ---- squash ----
@export var default_squash_x := 1.25
@export var default_squash_y := 0.75
@export var default_squash_duration := 0.12


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var i := char_fx.relative_index
	var env := char_fx.env

	var amplitude := _get_param(env, "amp", default_amplitude)
	var speed := _get_param(env, "speed", default_speed)
	var delay := _get_param(env, "delay", default_char_delay)
	var fade_time := _get_param(env, "fade", default_fade_time)

	var squash_x := _get_param(env, "squash_x", default_squash_x)
	var squash_y := _get_param(env, "squash_y", default_squash_y)
	var squash_time := _get_param(env, "squash_time", default_squash_duration)

	# ---- time per glyph ----
	var t := char_fx.elapsed_time - i * delay
	if t < 0.0:
		return true

	# ---- wave movement ----
	var wave := sin(t * speed) * amplitude
	char_fx.offset.y -= wave

	# ---- squash & stretch ----
	if t < squash_time:
		var k := 1.0 - (t / squash_time)
		var sx := lerp(1.0, squash_x, k)
		var sy := lerp(1.0, squash_y, k)
		char_fx.transform = char_fx.transform.scaled(
			Vector2(sx, sy)
		)

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
