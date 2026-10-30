extends SceneTree


const _Builder := preload("res://systems/ui/theme/flat_theme_builder.gd")


func _initialize() -> void:
	var error: Error = _Builder.save_all()
	if error != OK:
		push_error("flat theme save failed: %s" % error_string(error))
		quit(1)
		return
	print("flat theme written")
	quit(0)
