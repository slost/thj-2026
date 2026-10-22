extends UIComponent
class_name HoverIntentComponent


signal hover_started(component: HoverIntentComponent)
signal hover_intent_started(component: HoverIntentComponent)
signal hover_ended(component: HoverIntentComponent)

@export var intent_delay: float = 0.45

var _timer: Timer
var _hovering := false
var _intent_active := false


func _setup() -> void:
	call_deferred("_post_setup")


func _post_setup() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = intent_delay
	add_child(_timer)

	_timer.timeout.connect(_on_intent_timeout)

	host_node.mouse_entered.connect(_on_mouse_entered)
	host_node.mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	if not enabled:
		return

	_hovering = true
	_intent_active = false
	hover_started.emit(self)
	_timer.start()


func _on_mouse_exited() -> void:
	_hovering = false
	_timer.stop()

	if _intent_active:
		_intent_active = false

	hover_ended.emit(self)


func _on_intent_timeout() -> void:
	if not _hovering:
		return

	_intent_active = true
	hover_intent_started.emit(self)