extends UIComponent


enum KeyEnum {ANY, ACCEPT}
@export var key_to_start = KeyEnum.ANY


func _process(delta):
	match key_to_start:
		KeyEnum.ANY:
			if Utils.is_anything_pressed_except_mouse():
				_on_pressed()
		KeyEnum.ACCEPT:
			if Input.is_action_just_pressed("ui_accept"):
				_on_pressed()


func _on_pressed():
	print("Pressed, going to Main Menu")
	SignalBus.request_scene_change.emit("Main Menu")
	Audio.play_sfx(Assets.fetch("sfx_start_game"))
