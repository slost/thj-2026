extends Button


@export var state : WorldMap.State

const HOVER_SCALE := Vector2(1.1, 1.1)
const NORMAL_SCALE := Vector2.ONE
const TWEEN_TIME := 0.15

var _hover_tween: Tween


func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)



func _on_pressed() -> void:
	Game.world_map.set_state(state)


func _on_mouse_entered() -> void:
	if Game.world_map.current_state != state:
		modulate = Color.GRAY
	_tween_scale(HOVER_SCALE)


func _on_mouse_exited() -> void:
	_tween_scale(NORMAL_SCALE)
	if _is_map_view(Game.world_map.current_state) and _is_map_view(state):
		modulate = Color.WHITE
		return
	if Game.world_map.current_state != state:
		modulate = Color.DIM_GRAY
		return
	modulate = Color.WHITE
	

func _is_map_view(value: WorldMap.State) -> bool:
	return value == WorldMap.State.MAP or value == WorldMap.State.PINNED or value == WorldMap.State.FOCUS


func _tween_scale(target: Vector2) -> void:
	# Stop the previous tween so quick hover in/out doesn't fight.
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", target, TWEEN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
