extends Button


## State value passed to the current stage's set_state. World map and battle use different enums.
@export var state: int = 0

const HOVER_SCALE := Vector2(1.1, 1.1)
const NORMAL_SCALE := Vector2.ONE
const TWEEN_TIME := 0.15

var _hover_tween: Tween


func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_pressed() -> void:
	var stage := _stage()
	if stage == null:
		return
	stage.set_state(state)


func _on_mouse_entered() -> void:
	if not _highlights(_current_state()):
		modulate = Color.GRAY
	_tween_scale(HOVER_SCALE)


func _on_mouse_exited() -> void:
	_tween_scale(NORMAL_SCALE)
	if _highlights(_current_state()):
		modulate = Color.WHITE
		return
	modulate = Color.DIM_GRAY


func _stage() -> Node:
	var stage := Game.current_stage
	if _is_state_stage(stage):
		return stage
	if _is_state_stage(Game.world_map):
		return Game.world_map
	return null


func _is_state_stage(stage: Node) -> bool:
	if stage == null or not is_instance_valid(stage) or not stage.has_method("set_state"):
		return false
	# 0 is a real state (the map, and the battle field), so a null check is not enough.
	for property in stage.get_property_list():
		if str(property.get("name", "")) == "current_state":
			return true
	return false


func _current_state() -> int:
	var stage := _stage()
	if stage == null:
		return -1
	return int(stage.get("current_state"))


## Map, pinned, and focus all light the map button. Other stages match the button value.
func _highlights(current: int) -> bool:
	if _stage() is WorldMap and _is_map_view(current) and _is_map_view(state):
		return true
	return current == state


func _is_map_view(value: int) -> bool:
	return value == WorldMap.State.MAP or value == WorldMap.State.PINNED or value == WorldMap.State.FOCUS


func _tween_scale(target: Vector2) -> void:
	# Stop the previous tween so quick hover in/out doesn't fight.
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", target, TWEEN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
