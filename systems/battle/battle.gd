extends Node2D

const _INDICATOR_TEXTURE := preload("res://placeholders/tex_indicator.png")

@onready var _camera: Camera2D = $Camera2D
@onready var _stage_end: Control = $CanvasLayer/StageEndScreen
@onready var _city_progress: ProgressBar = $CanvasLayer/CityProgress

## Max HP of every villager that has entered this battle, kept after the body is gone.
var _villager_max: Dictionary = {}
var _stage_ended := false


func _ready() -> void:
	var game := _game()
	if game:
		game.change_stage(self)
	if _camera:
		_camera.make_current()
	_ensure_grid()
	var hover := _ensure_indicator("IndicatorSprite", 20)
	var pin := _ensure_indicator("PinIndicator", 19)
	_wire_focus(hover, pin)
	if _stage_end:
		_stage_end.visible = false
	_refresh_city_progress()


func _process(_delta: float) -> void:
	if _stage_ended:
		return
	var ratio := _refresh_city_progress()
	if _villager_max.is_empty():
		return
	if ratio <= 0.0:
		_open_stage_end()


func _on_button_pressed() -> void:
	if get_tree().paused:
		get_tree().paused = false
	var game := _game()
	if game:
		game.back_to_map()


func _game() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("Game")


func _open_stage_end() -> void:
	if _stage_ended:
		return
	_stage_ended = true
	if _city_progress:
		_city_progress.value = 0.0
	if _stage_end:
		_stage_end.visible = true
	get_tree().paused = true


func _refresh_city_progress() -> float:
	var ratio := _villager_ratio()
	if _city_progress:
		_city_progress.value = ratio
	return ratio


## Living villager HP over the max HP of every villager seen in this battle.
func _villager_ratio() -> float:
	var tree := get_tree()
	if tree == null:
		return 1.0
	var current := 0.0
	for node in tree.get_nodes_in_group(Unit2D.GROUP):
		var unit := node as Unit2D
		if unit == null or unit.team != Unit2D.Team.VILLAGER:
			continue
		var id := unit.get_instance_id()
		if not _villager_max.has(id):
			_villager_max[id] = _max_hp_of(unit)
		if unit.state != Unit2D.State.DEAD:
			current += _current_hp_of(unit)
	var total := 0.0
	for value in _villager_max.values():
		total += float(value)
	if total <= 0.0:
		return 1.0
	return clampf(current / total, 0.0, 1.0)


func _max_hp_of(unit: Unit2D) -> float:
	if unit.health:
		return maxf(unit.health.get_max_health(), 1.0)
	if unit.stats:
		return float(maxi(unit.stats.max_hp, 1))
	return 1.0


func _current_hp_of(unit: Unit2D) -> float:
	if unit.health:
		return maxf(unit.health.get_health(), 0.0)
	if unit.stats:
		return float(maxi(unit.stats.hp, 0))
	return 0.0


func _ensure_grid() -> void:
	if get_node_or_null("GridNav") != null:
		return
	var grid := GridNav.new()
	grid.name = "GridNav"
	add_child(grid)


func _ensure_indicator(node_name: String, z_index: int) -> Sprite2D:
	var existing := get_node_or_null(node_name) as Sprite2D
	if existing:
		return existing
	var sprite := HotSwapSprite.new()
	sprite.name = node_name
	sprite.z_index = z_index
	sprite.visible = false
	sprite.texture = _INDICATOR_TEXTURE
	sprite.asset_id = "tex_indicator"
	add_child(sprite)
	return sprite


func _wire_focus(hover: Sprite2D, pin: Sprite2D) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var director := parent.get_node_or_null("FocusDirector") as FocusDirector
	if director == null:
		return
	director.indicator = hover
	director.pin_indicator = pin
