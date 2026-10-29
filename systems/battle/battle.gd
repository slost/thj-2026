extends Node2D

enum State { FIELD, CODE }

const _INDICATOR_TEXTURE := preload("res://placeholders/tex_indicator.png")
const _Summoner := preload("res://systems/game/summoner.gd")
const _CodeBook := preload("res://systems/code_editor/code_book.gd")
const _SummonArea := preload("res://systems/battle/summon_area_overlay.gd")
const _UNIT_SCENE := preload("res://systems/units/unit.tscn")
const _SPAWN_CELLS: Array[Vector2i] = [
	Vector2i(-4, -3),
	Vector2i(-4, -1),
	Vector2i(-4, 1),
	Vector2i(-4, 3),
]

@onready var _camera: Camera2D = $Camera2D
@onready var _stage_end: Control = $CanvasLayer/StageEndScreen
@onready var _city_progress: ProgressBar = $CanvasLayer/CityProgress

## Cells the player may summon into. x -11..-4 and the full walkable height y -7..7.
@export var summon_area: Rect2i = Rect2i(-11, -7, 8, 15)
## The raid used to drop every spell on the field. The hotbar summons instead.
@export var spawn_raid_party_on_ready: bool = false
## When true, units stop moving and thinking while the book is open. The UI keeps running.
@export var pause_while_coding := false

@export var field_button: Button
@export var code_button: Button
@export var book: Node2D
## Node, not the editor script: that script reads Game, and a global class would compile too early.
@export var code_editor: Node

## Max HP of every villager that has entered this battle, kept after the body is gone.
var _villager_max: Dictionary = {}
var _stage_ended := false
var _party_spawned := false
var _army_spawned := false
var _raid_committed := false
var current_state: State = State.FIELD
var _summon_overlay: Node2D


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
	if _is_raid_scene():
		mount_raid_tools()
		if spawn_raid_party_on_ready:
			spawn_raid_party()
		else:
			spawn_army()
	if _stage_end:
		_stage_end.visible = false
	set_state(State.FIELD)
	_refresh_city_progress()


func _unhandled_input(event: InputEvent) -> void:
	if current_state != State.CODE or event is not InputEventKey:
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		set_state(State.FIELD)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if pause_while_coding and current_state == State.CODE:
		_set_units_paused(true)
	if _stage_ended:
		return
	var ratio := _refresh_city_progress()
	if _villager_max.is_empty():
		return
	if ratio <= 0.0:
		_open_stage_end()


func _on_retreat_pressed() -> void:
	var layer := get_node_or_null("CanvasLayer")
	if layer == null or layer.get_node_or_null("RetreatConfirm") != null:
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "RetreatConfirm"
	dialog.title = LocaleText.resolve("ui.battle.retreat_title", "Retreat?")
	dialog.dialog_text = LocaleText.resolve("ui.battle.retreat_body", "Abandon every minion and leave the raid?")
	dialog.ok_button_text = LocaleText.resolve("ui.battle.retreat_confirm", "Retreat")
	dialog.cancel_button_text = LocaleText.resolve("ui.battle.retreat_cancel", "Stay")
	dialog.min_size = Vector2i(560, 180)
	dialog.confirmed.connect(_confirm_retreat)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	layer.add_child(dialog)
	dialog.popup_centered()


func _confirm_retreat() -> void:
	var game := _game()
	if game and game.has_method("abandon_army"):
		game.abandon_army()
	_on_button_pressed()


func _on_button_pressed() -> void:
	commit_raid_outcome()
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
	# The bar is the raid's stake slice: full means none of it was lost this battle.
	if _city_progress:
		_city_progress.value = 1.0 - clampf(1.0 - ratio, 0.0, 1.0)
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


func _is_raid_scene() -> bool:
	var tree := get_tree()
	return tree != null and tree.current_scene == self


## Focus and the script panel for a raid started from the map.
## The debug battle keeps its own director and panel, so this stays off there.
func mount_raid_tools() -> void:
	var hover := _ensure_indicator("IndicatorSprite", 20)
	var pin := _ensure_indicator("PinIndicator", 19)
	var director := get_node_or_null("FocusDirector") as FocusDirector
	if director == null:
		director = FocusDirector.new()
		director.name = "FocusDirector"
		add_child(director)
	director.indicator = hover
	director.pin_indicator = pin
	var layer := get_node_or_null("CanvasLayer")
	if layer == null or layer.get_node_or_null("ScriptDebugPanel") != null:
		return
	var panel := ScriptDebugPanel.new()
	panel.name = "ScriptDebugPanel"
	layer.add_child(panel)


## Spawns one minion per raid slot. The unit gets a copy of the slot program.
func spawn_raid_party() -> void:
	if _party_spawned:
		return
	_party_spawned = true
	var game := _game()
	if game == null:
		return
	var roster: Array = game.get("spells")
	var indexes: Array = game.get("raid_slots")
	if indexes.is_empty():
		indexes = []
		for index in roster.size():
			indexes.append(index)
	var map := get_node_or_null("TileMaps/Map") as TileMapLayer
	var director := get_node_or_null("FocusDirector") as FocusDirector
	var first: Unit2D = null
	var spawned := 0
	var used: Array[int] = []
	for raw in indexes:
		var index := int(raw)
		if index < 0 or index >= roster.size() or used.has(index):
			continue
		used.append(index)
		var slot := roster[index] as SummonSpell
		if slot == null:
			continue
		var unit := _UNIT_SCENE.instantiate() as Unit2D
		if unit == null:
			continue
		unit.def = _def_for_slot(slot)
		unit.name = _party_name(slot, index)
		unit.position = _cell_position(map, _SPAWN_CELLS[spawned % _SPAWN_CELLS.size()])
		_Summoner.unit_container(self).add_child(unit)
		spawned += 1
		if first == null:
			first = unit
	if first == null or director == null:
		return
	var target := first.get_node_or_null("ComponentContainer/UnitFocusComponent") as FocusTargetComponent
	if target:
		director.select_target(target)


func summon_spot(world_pos: Vector2) -> Dictionary:
	var grid := get_node_or_null("GridNav") as GridNav
	if grid == null:
		return {"ok": false, "pos": world_pos}
	var cell := grid.world_to_cell(world_pos)
	var pos := grid.cell_to_world(cell)
	var ok := summon_area.has_point(cell) and grid.is_walkable_cell(cell)
	return {"ok": ok, "pos": pos}


func _cell_position(map: TileMapLayer, cell: Vector2i) -> Vector2:
	if map == null:
		return Vector2.ZERO
	return to_local(map.to_global(map.map_to_local(cell)))


func _cell_global(map: TileMapLayer, cell: Vector2i) -> Vector2:
	if map == null:
		return global_position
	return map.to_global(map.map_to_local(cell))


func _party_name(slot: SummonSpell, index: int) -> String:
	var title := slot.display_name().replace("/", " ").replace(":", " ")
	if title.is_empty():
		title = "Minion"
	return "%s %d" % [title, index + 1]


func _def_for_slot(slot: SummonSpell) -> UnitDef:
	return _Summoner.copy_def(slot)


## Spawns the camp army from each member's snapshot, inside the summon area.
func spawn_army() -> void:
	if _army_spawned:
		return
	_army_spawned = true
	var game := _game()
	if game == null:
		return
	var members: Array = game.get("army")
	var map := get_node_or_null("TileMaps/Map") as TileMapLayer
	var director := get_node_or_null("FocusDirector") as FocusDirector
	var cells := _summon_cells()
	var first: Unit2D = null
	var spawned := 0
	for entry in members:
		var member := entry as ArmyMember
		if member == null:
			continue
		var cell := cells[spawned % cells.size()] if not cells.is_empty() else Vector2i.ZERO
		var unit := _Summoner.spawn_member(member, self, _cell_global(map, cell))
		if unit == null:
			continue
		spawned += 1
		if first == null:
			first = unit
	if first == null or director == null:
		return
	var target := first.get_node_or_null("ComponentContainer/UnitFocusComponent") as FocusTargetComponent
	if target:
		director.select_target(target)


func _summon_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _SPAWN_CELLS:
		if summon_area.has_point(cell):
			cells.append(cell)
	var grid := get_node_or_null("GridNav") as GridNav
	for y in range(summon_area.position.y, summon_area.position.y + summon_area.size.y):
		for x in range(summon_area.position.x, summon_area.position.x + summon_area.size.x):
			var cell := Vector2i(x, y)
			if cells.has(cell):
				continue
			if grid != null and not grid.is_walkable_cell(cell):
				continue
			cells.append(cell)
	if cells.is_empty():
		cells.append_array(_SPAWN_CELLS)
	return cells


func is_coding() -> bool:
	return current_state == State.CODE


func allows_summon_bar() -> bool:
	return current_state == State.FIELD and not _stage_ended


func accepts_field_pointer() -> bool:
	return current_state == State.FIELD


func set_state(new_state: State = State.FIELD) -> void:
	current_state = new_state
	_CodeBook.set_open(book, code_editor, current_state == State.CODE)
	_update_state_buttons()
	_set_field_pointer(current_state == State.FIELD)
	_set_units_paused(pause_while_coding and current_state == State.CODE)
	if current_state != State.FIELD:
		set_summon_preview(false)
	if GUI:
		GUI.update_portrait()


func set_summon_preview(active: bool) -> void:
	var overlay := _ensure_summon_overlay()
	if not active or current_state != State.FIELD:
		overlay.hide_area()
		return
	overlay.show_area(get_node_or_null("GridNav") as GridNav, summon_area)


## Stores this battle's stake damage once. Retreat and the stage-end exit both come through here.
func commit_raid_outcome() -> void:
	if _raid_committed:
		return
	var game := _game()
	if game == null or not bool(game.get("raid_outcome_pending")):
		return
	_raid_committed = true
	var max_points := float(game.get("raid_target_max_points"))
	var lost := clampf(1.0 - _villager_ratio(), 0.0, 1.0)
	game.set("pending_raid_damage", Formular.raid_damage(max_points, lost))


func _update_state_buttons() -> void:
	if field_button:
		field_button.modulate = Color.WHITE if current_state == State.FIELD else Game.DISABLED_COLOR
	if code_button:
		code_button.modulate = Color.WHITE if current_state == State.CODE else Game.DISABLED_COLOR


func _set_field_pointer(open: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group(FocusDirector.GROUP):
		var director := node as FocusDirector
		if director:
			director.set_accepts_pointer(open)


func _set_units_paused(paused: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var mode := Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	for node in tree.get_nodes_in_group(Unit2D.GROUP):
		var unit := node as Node
		if unit:
			unit.process_mode = mode


func _ensure_summon_overlay() -> Node2D:
	if _summon_overlay != null and is_instance_valid(_summon_overlay):
		return _summon_overlay
	var overlay := _SummonArea.new() as Node2D
	overlay.name = "SummonArea"
	add_child(overlay)
	_summon_overlay = overlay
	return overlay
