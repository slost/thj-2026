@tool

extends Button
class_name UIButton


func _ready() -> void:
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)    


func _on_mouse_entered() -> void:
	return
	# AudioManager.play_ui_sfx(Refs.SFX_UI_HOVER)


func _on_pressed() -> void:
	return
	# AudioManager.play_ui_sfx(Refs.SFX_UI_ACCEPTED)


