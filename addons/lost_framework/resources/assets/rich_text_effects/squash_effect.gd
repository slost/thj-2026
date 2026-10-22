@tool
extends RichTextEffect
class_name SquashTextEffect

# BBCode tag name
var bbcode := "squash"


# --- Squash shape defaults ---
@export var default_squash_x: float = 1.35
@export var default_squash_y: float = 0.6


# --- Timing defaults ---
@export var default_duration: float = 0.12
@export var default_char_delay: float = 0.04


# --- Decay tuning ---
# Higher value = squash disappears faster (stronger impact)
@export var default_decay_strength: float = 6.0


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var env := char_fx.env
	var index := char_fx.relative_index

	# Read parameters (can be overridden via BBCode)
	var squash_x := _get_param(env, "x", default_squash_x)
	var squash_y := _get_param(env, "y", default_squash_y)
	var duration := _get_param(env, "time", default_duration)
	var delay := _get_param(env, "delay", default_char_delay)
	var decay := _get_param(env, "decay", default_decay_strength)

	# Time synchronized per glyph (important for wave + squash sync)
	var t := char_fx.elapsed_time - index * delay
	if t < 0.0 or t > duration:
		return true

	# Normalized time [0..1]
	var p := clamp(t / duration, 0.0, 1.0)

	# Exponential ease-out for strong initial impact
	# k starts near 1.0 and quickly decays to 0.0
	var k := exp(-p * decay)

	# Interpolate scale back to normal
	var sx := lerp(1.0, squash_x, k)
	var sy := lerp(1.0, squash_y, k)

	# Apply squash scaling
	char_fx.transform = char_fx.transform.scaled(
		Vector2(sx, sy)
	)

	return true


# Safely read a float parameter from BBCode environment
# Handles float, int, string, and null values
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
			return float(v)
		TYPE_STRING:
			return v.to_float()
		_:
			return default_value
