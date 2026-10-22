@tool
extends RichTextEffect
class_name FloatChaosTextEffect

var bbcode := "float_chaos"

@export var default_rise_speed := 28.0
@export var default_fade_time := 0.8
@export var default_spacing := 6.0
@export var default_noise := 2.0
@export var default_scale_min := 0.9
@export var default_scale_max := 1.1


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var t := char_fx.elapsed_time
	var i := char_fx.relative_index
	var env := char_fx.env

	var rise_speed := _get_param(env, "rise", default_rise_speed)
	var fade_time := _get_param(env, "fade", default_fade_time)
	var spacing := _get_param(env, "spacing", default_spacing)
	var noise := _get_param(env, "noise", default_noise)
	var scale_min := _get_param(env, "scale_min", default_scale_min)
	var scale_max := _get_param(env, "scale_max", default_scale_max)

	# ---- deterministic random per glyph ----
	var rng := RandomNumberGenerator.new()
	rng.seed = i * 7919

	var rand_x := rng.randf_range(-noise, noise)
	var rand_y := rng.randf_range(-noise, noise * 0.5)
	var rand_scale := rng.randf_range(scale_min, scale_max)

	# ---- index-based horizontal separation (THIS IS THE FIX) ----
	var center := (char_fx.glyph_count - 1) * 0.5
	var base_x := (i - center) * spacing

	# ---- movement ----
	char_fx.offset.x += base_x + rand_x
	char_fx.offset.y -= rise_speed * t
	char_fx.offset.y += rand_y

	# ---- scale ----
	char_fx.transform = char_fx.transform.scaled(
		Vector2.ONE * rand_scale
	)

	# ---- fade ----
	var alpha := 1.0 - (t / fade_time)
	char_fx.color.a *= clamp(alpha, 0.0, 1.0)

	return true


func _get_param(env: Dictionary, key: String, default_value) -> float:
	if not env.has(key):
		return default_value

	var v = env[key]
	if v == null:
		return default_value

	match typeof(v):
		TYPE_FLOAT:
			return v
		TYPE_INT:
			return float(v) # ← อันนี้ Godot อนุญาต (int → float)
		TYPE_STRING:
			return v.to_float()
		_:
			return default_value


