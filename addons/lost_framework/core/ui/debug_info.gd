extends Control

var button_pressed: bool = false
var previous_mouse_position: Vector2 = Vector2.ZERO


func _process(delta: float) -> void:
    if button_pressed:
        var current_mouse_position = get_viewport().get_mouse_position()
        var mouse_delta = current_mouse_position - previous_mouse_position
        position += mouse_delta
        previous_mouse_position = current_mouse_position


func _on_drag_button_button_down() -> void:
    button_pressed = true
    previous_mouse_position = get_viewport().get_mouse_position()


func _on_drag_button_button_up() -> void:
    button_pressed = false
