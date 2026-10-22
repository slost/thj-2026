@tool
extends RichTextEffect
class_name FloatFadeTextEffect


var bbcode := "float"

## Speed at which the text rises (pixels per second).
@export var rise_speed := 30.0

## Time it takes for the text to fully fade out (in seconds).
@export var fade_time := 1.0


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var t := char_fx.elapsed_time

	char_fx.offset.y -= rise_speed * t

	var alpha := 1.0 - (t / fade_time)
	alpha = clamp(alpha, 0.0, 1.0)

	char_fx.color.a *= alpha

	return true
