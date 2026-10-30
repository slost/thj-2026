extends Node2D

signal move_order_issued(unit: Unit2D)
signal battle_won

enum State { FIELD, CODE }

const _INDICATOR_TEXTURE := preload("res://placeholders/tex_indicator.png")
const _Summoner := preload("res://systems/game/summoner.gd")
const _CodeBook := preload("res://systems/code_editor/code_book.gd")
const _SummonArea := preload("res://systems/battle/summon_area_overlay.gd")
const _MapGenerator := preload("res://systems/battle/map_generator.gd")
const _OrderMove := preload("res://systems/blocks/order_move.gd")
const _OrderAttack := preload("res://systems/blocks/order_attack.gd")
const _VillagerBrain := preload("res://systems/units/villager_brain.gd")
const _UNIT_SCENE := preload("res://systems/units/unit.tscn")
const _SPAWN_CELLS: Array[Vector2i] = [
	Vector2i(-4, -3),
	Vector2i(-4, -1),
	Vector2i(-4, 1),
	Vector2i(-4, 3),
]
## Right side of the map, opposite the summon band.
const _DEFENDER_CELLS: Array[Vector2i] = [
	Vector2i(6, -4), Vector2i(6, -2), Vector2i(6, 0), Vector2i(6, 2), Vector2i(6, 4),
	Vector2i(8, -3), Vector2i(8, -1), Vector2i(8, 1), Vector2i(8, 3),
	Vector2i(10, -4), Vector2i(10, -2), Vector2i(10, 0), Vector2i(10, 2), Vector2i(10, 4),
]

@onready var _camera: Camera2D = $Camera2D
@onready var _stage_end: Control = $CanvasLayer/StageEndScreen

## Cells the player may summon into. x -11..-4 and the full walkable height y -7..7.
@export var summon_area: Rect2i = Rect2i(-11, -7, 8, 15)
## The raid used to drop every spell on the field. The hotbar summons instead.
@export var spawn_raid_party_on_ready: bool = false
## When true, units stop moving and thinking while the book is open. The UI keeps running.
@export var pause_while_coding := false
## Click a pinned minion's destination or an enemy to queue a move or an attack.
## Turn this off to leave commands entirely to the written scripts.
@export var direct_orders := true
## The tutorial scene reuses this battle. It does not spawn a town or end before villagers exist.
@export var tutorial_mode := false
## How many spell buttons the hotbar shows while tutorial_mode is on.
var tutorial_visible_spells := 8
## How many of those buttons can be used. The rest stay visible and locked.
var tutorial_unlocked_spells := 8
## -1 means unlimited. Counts successful summons while tutorial_mode is on.
var tutorial_summon_cap := -1
## -1 means unlimited. Counts move and attack orders while tutorial_mode is on.
var tutorial_order_cap := -1
## The first taught move ignores the click and walks a couple of cells.
var tutorial_short_move := false
## While set, the field flag and Escape cannot leave the book.
var tutorial_lock_field := false
var _tutorial_summons := 0
var _tutorial_orders := 0

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
var _defenders_spawned := false
var _raid_committed := false
var current_state: State = State.FIELD
var _summon_overlay: Node2D
var _field_zoom := Vector2.ZERO
var _field_camera_position := Vector2.ZERO
var _camera_saved := false


func _ready() -> void:
	var game := _game()
	if game:
		game.change_stage(self)
	if _camera:
		_camera.make_current()
	_generate_map()
	_ensure_grid()
	var hover := _ensure_indicator("IndicatorSprite", 20)
	var pin := _ensure_indicator("PinIndicator", 19)
	_wire_focus(hover, pin)
	if _is_raid_scene() or tutorial_mode:
		mount_raid_tools()
	if _is_raid_scene() and not tutorial_mode:
		spawn_town_defenders()
		if spawn_raid_party_on_ready:
			spawn_raid_party()
		else:
			spawn_army()
	if tutorial_mode:
		_prepare_tutorial_shell()
	if _stage_end:
		_stage_end.visible = false
	set_state(State.FIELD)
	_set_city_chrome(true)
	_refresh_city_progress()
	if _is_raid_scene() and not tutorial_mode:
		declare_victory_if_clear()


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
	if current_state == State.CODE:
		_sync_unit_bars()
	if _stage_ended:
		return
	var ratio := _refresh_city_progress()
	if _villager_max.is_empty():
		return
	if ratio <= 0.0:
		_open_stage_end()


## A raid with nobody left to fight is already won. The town takes no stake damage.
func declare_victory_if_clear() -> void:
	if _stage_ended or _living_enemy():
		return
	_open_stage_end(false)


func _living_enemy() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for node in tree.get_nodes_in_group(Unit2D.GROUP):
		var unit := node as Unit2D
		if unit == null or unit.state == Unit2D.State.DEAD:
			continue
		if unit.team == Unit2D.Team.VILLAGER:
			return true
	return false


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
	_open_stage_end(false, Game.BGM_BATTLE_RETREAT)


func _on_button_pressed() -> void:
	if tutorial_mode:
		var tutor := _game()
		if tutor and tutor.has_method("finish_tutorial"):
			tutor.finish_tutorial()
		return
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


func _exit_tree() -> void:
	_set_city_chrome(false)
	if tutorial_mode:
		_show_sacrifice_button(true)


func _open_stage_end(city_fallen := true, sting_key := "") -> void:
	if _stage_ended:
		return
	_stage_ended = true
	var game := _game()
	if game and game.has_method("play_battle_sting"):
		var key := sting_key if sting_key != "" else Game.BGM_BATTLE_WIN
		game.play_battle_sting(key)
		if key == Game.BGM_BATTLE_WIN:
			Sfx.play_laugh(1.0, true)
	var bar := _city_bar()
	if city_fallen and bar:
		bar.value = 0.0
	if _stage_end:
		_stage_end.visible = true
		var reveal := _stage_end.get_node_or_null("RewardReveal")
		if reveal and reveal.has_method("play"):
			reveal.call("play", _received_rewards())
	if sting_key != Game.BGM_BATTLE_RETREAT:
		battle_won.emit()
	get_tree().paused = true


## Amounts this raid pays. Same split the map grants when the battle closes.
func _received_rewards() -> Array:
	var game := _game()
	if game == null:
		return []
	var lost := clampf(1.0 - _villager_ratio(), 0.0, 1.0)
	var source: Array = game.get("raid_rewards")
	var lines: Array = []
	for entry in source:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var amount := Formular.raid_reward_payout(int(entry.get("amount", 0)), lost)
		if amount <= 0:
			continue
		lines.append({
			"resource_type": int(entry.get("resource_type", 0)),
			"amount": amount,
		})
	return lines


func _city_bar() -> ProgressBar:
	if GUI == null:
		return null
	return GUI.get_node_or_null("CityProgress") as ProgressBar


func _set_city_chrome(show: bool) -> void:
	if GUI == null:
		return
	for node_name in ["CityLabel", "CityProgress"]:
		var node := GUI.get_node_or_null(node_name) as CanvasItem
		if node:
			node.visible = show


func _refresh_city_progress() -> float:
	var ratio := _villager_ratio()
	# The bar is the raid's stake slice: full means none of it was lost this battle.
	var bar := _city_bar()
	if bar:
		bar.value = 1.0 - clampf(1.0 - ratio, 0.0, 1.0)
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
		unit.spell_slot = index
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
	var ok := summon_area.has_point(cell) and grid.is_walkable_cell(cell) and not _cell_has_unit(cell)
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
	if tutorial_mode and tutorial_lock_field and current_state == State.CODE and new_state != State.CODE:
		return
	var entering_code := new_state == State.CODE and current_state != State.CODE
	current_state = new_state
	_CodeBook.set_open(book, code_editor, current_state == State.CODE)
	_update_state_buttons()
	_set_field_pointer(current_state == State.FIELD)
	_set_units_paused(pause_while_coding and current_state == State.CODE)
	_frame_code_camera(current_state == State.CODE)
	_sync_unit_bars()
	if current_state != State.FIELD:
		set_summon_preview(false)
	if GUI:
		GUI.update_portrait()
	if entering_code:
		Sfx.play_ui("general.page_turn")


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
	game.set("pending_raid_lost_ratio", lost)


func _update_state_buttons() -> void:
	if field_button:
		field_button.disabled = tutorial_mode and tutorial_lock_field
		field_button.modulate = Color.WHITE if current_state == State.FIELD and not field_button.disabled else Game.DISABLED_COLOR
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


## World map opens the book at camera zoom 1. Match that while coding, then restore the battle view.
func _frame_code_camera(open: bool) -> void:
	if _camera == null:
		return
	if book:
		book.scale = Vector2.ONE
	if open:
		if not _camera_saved:
			_field_zoom = _camera.zoom
			_field_camera_position = _camera.position
			_camera_saved = true
		_camera.zoom = Vector2.ONE
		_camera.position = book.global_position if book != null else Vector2.ZERO
		return
	if not _camera_saved:
		return
	_camera.zoom = _field_zoom
	_camera.position = _field_camera_position
	_camera_saved = false


func _sync_unit_bars() -> void:
	var show := current_state == State.FIELD
	for node in find_children("*", "Unit2D", true, false):
		if node.has_method("set_status_bars_visible"):
			node.call("set_status_bars_visible", show)


func _generate_map() -> void:
	var map := get_node_or_null("TileMaps/Map") as TileMapLayer
	var decor := get_node_or_null("TileMaps/Decor") as TileMapLayer
	_MapGenerator.generate(map, decor)


func _cell_has_unit(cell: Vector2i) -> bool:
	var grid := get_node_or_null("GridNav") as GridNav
	var tree := get_tree()
	if grid == null or tree == null:
		return false
	for node in tree.get_nodes_in_group(Unit2D.GROUP):
		var unit := node as Unit2D
		if unit == null or unit.state == Unit2D.State.DEAD:
			continue
		if grid.world_to_cell(unit.global_position) == cell:
			return true
	return false


## Queues a walk to the clicked cell. False when orders are off or the cell cannot be a goal.
func issue_move_order(unit: Unit2D, world_pos: Vector2) -> bool:
	if not _can_order(unit) or not allows_order():
		return false
	var grid := get_node_or_null("GridNav") as GridNav
	if grid == null:
		return false
	var cell := grid.world_to_cell(world_pos)
	if tutorial_mode and tutorial_short_move:
		cell = _short_move_cell(grid, unit)
	if not grid.is_walkable_cell(cell):
		return false
	var order = _OrderMove.new()
	order.goal = cell
	unit.enqueue_order(order)
	note_order()
	move_order_issued.emit(unit)
	return true


## Queues an attack on one enemy. False when that unit is not an enemy of the pinned minion.
func issue_attack_order(unit: Unit2D, enemy: Unit2D) -> bool:
	if not _can_order(unit) or not allows_order() or enemy == null or not unit.is_enemy(enemy):
		return false
	if enemy.state == Unit2D.State.DEAD:
		return false
	var order = _OrderAttack.new()
	order.target = enemy
	unit.enqueue_order(order)
	note_order()
	return true


## World point of the short lesson walk. The tutorial arrow sits on this cell.
func tutorial_move_marker() -> Vector2:
	var grid := get_node_or_null("GridNav") as GridNav
	var unit := _tutorial_minion()
	if grid == null or unit == null:
		return Vector2.INF
	return grid.cell_to_world(_short_move_cell(grid, unit))


func _tutorial_minion() -> Unit2D:
	var tree := get_tree()
	if tree == null:
		return null
	for node in tree.get_nodes_in_group(Unit2D.GROUP):
		var unit := node as Unit2D
		if unit != null and unit.team == Unit2D.Team.MINION and unit.state != Unit2D.State.DEAD:
			return unit
	return null


## A couple of walkable cells from the unit, so the first lesson does not cross the map.
func _short_move_cell(grid: GridNav, unit: Unit2D) -> Vector2i:
	var origin := grid.world_to_cell(unit.global_position)
	var steps: Array[Vector2i] = [
		Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2),
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]
	for step in steps:
		var cell := origin + step
		if cell != origin and grid.is_walkable_cell(cell):
			return cell
	return origin


func _can_order(unit: Unit2D) -> bool:
	return (
		direct_orders
		and current_state == State.FIELD
		and unit != null
		and unit.team == Unit2D.Team.MINION
		and unit.state != Unit2D.State.DEAD
	)


func shows_spell(index: int) -> bool:
	if not tutorial_mode:
		return true
	return index >= 0 and index < tutorial_visible_spells


func allows_spell(index: int) -> bool:
	if not tutorial_mode:
		return true
	return index >= 0 and index < tutorial_unlocked_spells


func allows_summon(index: int) -> bool:
	if not allows_spell(index):
		return false
	if not tutorial_mode or tutorial_summon_cap < 0:
		return true
	return _tutorial_summons < tutorial_summon_cap


func allows_order() -> bool:
	if not tutorial_mode or tutorial_order_cap < 0:
		return true
	return _tutorial_orders < tutorial_order_cap


func note_summon() -> void:
	_tutorial_summons += 1


func note_order() -> void:
	_tutorial_orders += 1


func reset_order_count() -> void:
	_tutorial_orders = 0


func present_tutorial_ending(text: String) -> void:
	var back := get_node_or_null("CanvasLayer/StageEndScreen/BackButton") as Button
	if back:
		back.text = LocaleText.resolve("ui.tutorial.back", "Back to world")
	var screen := get_node_or_null("CanvasLayer/StageEndScreen") as Control
	if screen == null:
		return
	var label := screen.get_node_or_null("TutorialEnding") as RichTextLabel
	if label == null:
		label = RichTextLabel.new()
		label.name = "TutorialEnding"
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		label.offset_left = -560.0
		label.offset_top = 16.0
		label.offset_right = 560.0
		label.offset_bottom = 220.0
		screen.add_child(label)
	label.text = text


func _prepare_tutorial_shell() -> void:
	tutorial_visible_spells = 8
	tutorial_unlocked_spells = 1
	tutorial_summon_cap = 1
	tutorial_order_cap = 0
	var retreat := get_node_or_null("CanvasLayer/RetreatButton") as CanvasItem
	if retreat:
		retreat.visible = false
	if code_button:
		code_button.disabled = true
	_show_sacrifice_button(false)


func _show_sacrifice_button(show: bool) -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var button := tree.root.get_node_or_null("GUI/SacrificeButton") as CanvasItem
	if button:
		button.visible = show


## Spawns a few weak melee villagers with the same garrison spawner the raids use.
func spawn_practice_villagers(count: int) -> void:
	var row := {
		"race": Unit2D.Race.VILLAGER_MELEE,
		"count": maxi(count, 0),
		"max_hp": 8,
		"damage": 1,
		"flees": false,
	}
	var rows: Array = [row]
	_spawn_garrison_rows(rows)


## Spawns the raided town's villagers on the right side. Safe to call once.
func spawn_town_defenders() -> void:
	if _defenders_spawned:
		return
	_defenders_spawned = true
	var game := _game()
	if game == null:
		return
	var rows: Array = game.get("raid_garrison")
	if rows.is_empty():
		return
	_spawn_garrison_rows(rows)


func _spawn_garrison_rows(rows: Array) -> void:
	var map := get_node_or_null("TileMaps/Map") as TileMapLayer
	var grid := get_node_or_null("GridNav") as GridNav
	var cursor := 0
	var serial := 1
	for entry in rows:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry
		var count := maxi(int(row.get("count", 0)), 0)
		var race: Unit2D.Race = int(row.get("race", Unit2D.Race.VILLAGER_MELEE))
		var flees := bool(row.get("flees", false))
		for _n in count:
			var spot := _defender_cell(grid, cursor)
			cursor = int(spot.get("next", cursor))
			if not bool(spot.get("ok", false)):
				return
			var unit := _UNIT_SCENE.instantiate() as Unit2D
			if unit == null:
				continue
			unit.def = _defender_def(row, race, flees)
			unit.name = "Villager %d" % serial
			serial += 1
			var cell := spot.get("cell", Vector2i.ZERO) as Vector2i
			unit.position = _cell_position(map, cell)
			_Summoner.unit_container(self).add_child(unit)


func _defender_cell(grid: GridNav, start: int) -> Dictionary:
	for index in range(start, _DEFENDER_CELLS.size()):
		var cell := _DEFENDER_CELLS[index]
		if grid == null or grid.is_walkable_cell(cell):
			return {"ok": true, "cell": cell, "next": index + 1}
	return {"ok": false, "cell": Vector2i.ZERO, "next": _DEFENDER_CELLS.size()}


func _defender_def(row: Dictionary, race: Unit2D.Race, flees: bool) -> UnitDef:
	var def := UnitDef.new()
	def.team = Unit2D.Team.VILLAGER
	def.race = race
	def.max_hp = maxi(int(row.get("max_hp", 16)), 1)
	def.damage = maxi(int(row.get("damage", 3)), 0)
	def.speed = 110.0 if flees else 80.0
	def.detect_range = 7
	def.attack_range = 4 if race == Unit2D.Race.VILLAGER_RANGED else 1
	def.cpu = 2
	def.gpu = 2
	def.ram = 12
	def.starting_program = _VillagerBrain.program(flees)
	var events: Array[EventGraph.Event] = []
	events.append(EventGraph.Event.ON_UPDATE)
	def.allowed_events = events
	return def


func _ensure_summon_overlay() -> Node2D:
	if _summon_overlay != null and is_instance_valid(_summon_overlay):
		return _summon_overlay
	var overlay := _SummonArea.new() as Node2D
	overlay.name = "SummonArea"
	add_child(overlay)
	_summon_overlay = overlay
	return overlay
