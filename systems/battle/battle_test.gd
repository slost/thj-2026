extends Node2D

const _Overlay := preload("res://systems/battle/unit_debug_overlay.gd")
const _DebugMenu := preload("res://systems/battle/battle_debug_menu.gd")
const _ScriptDebug := preload("res://systems/battle/script_debug_panel.gd")
const _UNIT_SCENE := preload("res://systems/units/unit.tscn")

const _BLOCK_ATTACK_RANGE := "res://data/blocks/enemy_in_attack_range.tres"
const _BLOCK_DETECT_RANGE := "res://data/blocks/enemy_in_detect_range.tres"
const _BLOCK_ATTACK := "res://data/blocks/attack_target.tres"
const _BLOCK_MOVE := "res://data/blocks/move_to_target.tres"
const _BLOCK_AWAY := "res://data/blocks/move_away_from_target.tres"
const _BLOCK_WANDER := "res://data/blocks/wander.tres"
const _BLOCK_STAND := "res://data/blocks/stand_still.tres"
const _BLOCK_REMEMBER_HOSTILE := "res://data/blocks/remember_hostile.tres"
const _BLOCK_FORGET_FIRST_TARGET := "res://data/blocks/forget_first_target.tres"
const _BLOCK_HAS_TARGET := "res://data/blocks/has_remembered_target.tres"
const _BLOCK_NO_TARGET := "res://data/blocks/no_remembered_target.tres"
const _BLOCK_REMEMBERED_RANGE := "res://data/blocks/remembered_target_in_attack_range.tres"
const _BLOCK_REMEMBERED_DEAD := "res://data/blocks/remembered_target_dead.tres"

const _MINION_CELLS: Array[Vector2i] = [Vector2i(-4, -2), Vector2i(-4, 0), Vector2i(-4, 2)]
const _MINION_CPU: Array[int] = [1, 4, 2]
const _MINION_GPU: Array[int] = [4, 1, 2]
const _MINION_NAMES: Array[String] = ["Minion Brute", "Minion Tactician", "Minion Nested"]
const _MINION_TINTS: Array[Color] = [
	Color(0.45, 0.95, 0.4),
	Color(0.95, 0.88, 0.35),
	Color(0.72, 0.55, 0.95),
]
const _VILLAGER_CELLS: Array[Vector2i] = [Vector2i(2, -2), Vector2i(2, 0), Vector2i(2, 2)]
const _FLEE_CELLS: Array[Vector2i] = [Vector2i(6, -2), Vector2i(6, 0), Vector2i(6, 2)]

var _debug_visible := true
var _hunt_program: UnitProgram
var _stand_program: UnitProgram
var _flee_program: UnitProgram
var _spawn_serial := 0


func _enter_tree() -> void:
	var map := $TileMaps/Map as TileMapLayer
	var template := $Unit as Unit2D
	_hunt_program = _build_demo_program()
	_stand_program = _build_stand_program()
	_flee_program = _build_flee_program()
	var nested := _build_nested_program()
	var hunt := _hunt_program
	var dummy := _stand_program

	# Duplicate the clean scene instance first. A child added before duplicate()
	# is dropped, and the copy reports a missing node.
	var minions: Array[Unit2D] = [template]
	for index in range(1, _MINION_CELLS.size()):
		minions.append(template.duplicate() as Unit2D)
	var villagers: Array[Unit2D] = []
	for index in _VILLAGER_CELLS.size():
		villagers.append(template.duplicate() as Unit2D)
	var fleers: Array[Unit2D] = []
	for index in _FLEE_CELLS.size():
		fleers.append(template.duplicate() as Unit2D)

	for index in minions.size():
		var program := nested if index == 2 else hunt
		_setup_unit(minions[index], _MINION_NAMES[index], Unit2D.Team.MINION, program, _MINION_CPU[index], _MINION_GPU[index], map.map_to_local(_MINION_CELLS[index]), _MINION_TINTS[index])
		if minions[index] != template:
			add_child.call_deferred(minions[index])
	for index in villagers.size():
		_setup_unit(villagers[index], "Villager %d" % (index + 1), Unit2D.Team.VILLAGER, dummy, 1, 1, map.map_to_local(_VILLAGER_CELLS[index]), Color(1.0, 0.82, 0.65))
		add_child.call_deferred(villagers[index])
	for index in fleers.size():
		_setup_unit(fleers[index], "Villager Flee %d" % (index + 1), Unit2D.Team.VILLAGER, _flee_program, 1, 1, map.map_to_local(_FLEE_CELLS[index]), Color(0.7, 0.85, 1.0))
		add_child.call_deferred(fleers[index])


func _ready() -> void:
	var menu := _DebugMenu.new()
	menu.name = "BattleDebugMenu"
	$UI.add_child(menu)
	var script_panel := _ScriptDebug.new()
	script_panel.name = "ScriptDebugPanel"
	$UI.add_child(script_panel)


func _setup_unit(unit: Unit2D, unit_name: String, team: Unit2D.Team, program: UnitProgram, cpu: int, gpu: int, pos: Vector2, tint: Color) -> void:
	unit.name = unit_name
	unit.def = _build_def(team, program, cpu, gpu)
	unit.position = pos
	unit.modulate = tint
	var overlay := _Overlay.new()
	overlay.name = "DebugOverlay"
	unit.add_child(overlay)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_F1:
			set_debug_overlay_visible(not _debug_visible)
			get_viewport().set_input_as_handled()


func set_debug_overlay_visible(shown: bool) -> void:
	_debug_visible = shown
	get_tree().call_group(UnitDebugOverlay.GROUP, &"set_overlay_visible", shown)


func is_unit_debug_visible() -> bool:
	return _debug_visible


func toggle_unit_debug() -> bool:
	set_debug_overlay_visible(not _debug_visible)
	return _debug_visible


func delete_selected_unit() -> void:
	var director := $FocusDirector as FocusDirector
	if director == null:
		return
	var unit := director.get_selected_unit()
	if unit == null:
		return
	director.clear_selection()
	unit.queue_free()


func spawn_minion() -> Unit2D:
	_spawn_serial += 1
	return _spawn_unit("Minion %d" % _spawn_serial, Unit2D.Team.MINION, _hunt_program, 2, 2, Color(0.65, 0.95, 0.65))


func spawn_villager() -> Unit2D:
	_spawn_serial += 1
	return _spawn_unit("Villager Flee %d" % (3 + _spawn_serial), Unit2D.Team.VILLAGER, _flee_program, 1, 1, Color(0.7, 0.85, 1.0))


func toggle_pause() -> bool:
	get_tree().paused = not get_tree().paused
	return get_tree().paused


func situation_in_attack_range() -> void:
	_place_enemy_tiles(1)


func situation_in_detect_range() -> void:
	var unit := _pinned_unit()
	var gap := 4
	if unit != null and unit.stats != null:
		gap = unit.stats.attack_range + 2
	_place_enemy_tiles(gap)


func situation_out_of_range() -> void:
	var unit := _pinned_unit()
	var gap := 12
	if unit != null and unit.stats != null:
		gap = unit.stats.detect_range + 3
	_place_enemy_tiles(gap)


func situation_low_hp() -> void:
	var unit := _pinned_unit()
	if unit == null or unit.health == null:
		return
	var goal := maxf(1.0, unit.health.max_health * 0.2)
	if unit.health.current_health > goal:
		unit.health.apply_damage(unit.health.current_health - goal)


func situation_full_hp() -> void:
	var unit := _pinned_unit()
	if unit == null or unit.health == null:
		return
	unit.health.heal(unit.health.max_health)


func situation_clear_memory() -> void:
	var unit := _pinned_unit()
	if unit == null:
		return
	unit.forget_everything()


func _pinned_unit() -> Unit2D:
	var director := $FocusDirector as FocusDirector
	if director == null:
		return null
	return director.get_selected_unit()


func _place_enemy_tiles(tiles: int) -> void:
	var unit := _pinned_unit()
	if unit == null:
		return
	var other := _nearest_other(unit)
	var nav := _grid()
	if other == null or nav == null:
		return
	var origin := nav.world_to_cell(unit.global_position)
	var steps: Array[Vector2i] = [
		Vector2i(tiles, 0),
		Vector2i(-tiles, 0),
		Vector2i(0, tiles),
		Vector2i(0, -tiles),
		Vector2i(tiles, tiles),
		Vector2i(-tiles, tiles),
	]
	for step in steps:
		var cell := origin + step
		if cell == origin or not nav.is_walkable_cell(cell):
			continue
		other.set_state(Unit2D.State.IDLE)
		other.global_position = nav.cell_to_world(cell)
		return


func _nearest_other(unit: Unit2D) -> Unit2D:
	var best: Unit2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(Unit2D.GROUP):
		var other := node as Unit2D
		if other == null or other == unit or other.state == Unit2D.State.DEAD:
			continue
		if not unit.is_enemy(other):
			continue
		var dist := unit.global_position.distance_squared_to(other.global_position)
		if best == null or dist < best_dist:
			best = other
			best_dist = dist
	return best


func _grid() -> GridNav:
	for node in get_tree().get_nodes_in_group(GridNav.GROUP):
		return node as GridNav
	return null


func _spawn_unit(unit_name: String, team: Unit2D.Team, program: UnitProgram, cpu: int, gpu: int, tint: Color) -> Unit2D:
	var unit := _UNIT_SCENE.instantiate() as Unit2D
	_setup_unit(unit, unit_name, team, program, cpu, gpu, _random_walkable_position(), tint)
	add_child(unit)
	return unit


func _random_walkable_position() -> Vector2:
	var map := $TileMaps/Map as TileMapLayer
	var rect := map.get_used_rect()
	var cell := Vector2i(
		randi_range(rect.position.x, rect.position.x + rect.size.x - 1),
		randi_range(rect.position.y, rect.position.y + rect.size.y - 1)
	)
	return map.map_to_local(cell)


func _build_def(team: Unit2D.Team, program: UnitProgram, cpu: int, gpu: int) -> UnitDef:
	var def := UnitDef.new()
	def.team = team
	def.speed = 160.0
	def.detect_range = 8
	def.cpu = cpu
	def.gpu = gpu
	def.ram = 16
	def.starting_program = program
	var events: Array[EventGraph.Event] = []
	events.append(EventGraph.Event.ON_SPAWN)
	events.append(EventGraph.Event.ON_UPDATE)
	events.append(EventGraph.Event.ON_HIT)
	events.append(EventGraph.Event.ON_ALLY_DIED)
	events.append(EventGraph.Event.ON_DEATH)
	def.allowed_events = events
	return def


## [Detect]
##     <Remember>
##     [InAttackRange]
##         <Attack>
##     <Move>
## [NoTarget]
##     <Wander>
func _build_nested_program() -> UnitProgram:
	var lines: Array[ScriptLine] = []
	lines.append_array(_forget_dead_lines())
	lines.append(_line(_condition(_BLOCK_DETECT_RANGE), 0))
	lines.append(_line(_action(_BLOCK_REMEMBER_HOSTILE), 1))
	lines.append(_line(_condition(_BLOCK_REMEMBERED_RANGE), 1))
	lines.append(_line(_action(_BLOCK_ATTACK), 2))
	lines.append(_line(_action(_BLOCK_MOVE), 1))
	lines.append(_line(_condition(_BLOCK_NO_TARGET), 0))
	lines.append(_line(_action(_BLOCK_WANDER), 1))
	return _program_with("NestedHunt", lines)


## Remember a hostile, then attack from memory or walk toward them.
func _build_demo_program() -> UnitProgram:
	var lines: Array[ScriptLine] = []
	lines.append_array(_forget_dead_lines())
	lines.append(_line(_condition(_BLOCK_DETECT_RANGE), 0))
	lines.append(_line(_action(_BLOCK_REMEMBER_HOSTILE), 1))
	lines.append(_line(_condition(_BLOCK_HAS_TARGET), 0))
	lines.append(_line(_condition(_BLOCK_REMEMBERED_RANGE), 1))
	lines.append(_line(_action(_BLOCK_ATTACK), 2))
	lines.append(_line(_action(_BLOCK_MOVE), 1))
	lines.append(_line(_condition(_BLOCK_NO_TARGET), 0))
	lines.append(_line(_action(_BLOCK_WANDER), 1))
	return _program_with("Hunt", lines)


func _build_flee_program() -> UnitProgram:
	var lines: Array[ScriptLine] = []
	lines.append_array(_forget_dead_lines())
	lines.append(_line(_condition(_BLOCK_DETECT_RANGE), 0))
	lines.append(_line(_action(_BLOCK_REMEMBER_HOSTILE), 1))
	lines.append(_line(_action(_BLOCK_AWAY), 1))
	lines.append(_line(_condition(_BLOCK_NO_TARGET), 0))
	lines.append(_line(_action(_BLOCK_WANDER), 1))
	return _program_with("Flee", lines)


func _build_stand_program() -> UnitProgram:
	var lines: Array[ScriptLine] = []
	lines.append(_line(_action(_BLOCK_STAND), 0))
	return _program_with("Dummy", lines)


func _forget_dead_lines() -> Array[ScriptLine]:
	var lines: Array[ScriptLine] = []
	lines.append(_line(_condition(_BLOCK_REMEMBERED_DEAD), 0))
	lines.append(_line(_action(_BLOCK_FORGET_FIRST_TARGET), 1))
	return lines


func _program_with(function_name: String, lines: Array[ScriptLine]) -> UnitProgram:
	var brain := UnitFunction.new()
	brain.function_name = function_name
	brain.lines = lines
	var graph := EventGraph.new()
	graph.connect_function(EventGraph.Event.ON_UPDATE, brain)
	var program := UnitProgram.new()
	program.event_graph = graph
	var functions: Array[UnitFunction] = []
	functions.append(brain)
	program.functions = functions
	return program


func _line(block: CodeBlock, indent: int) -> ScriptLine:
	var line := ScriptLine.new()
	line.indent = indent
	line.block = block
	return line


func _condition(path: String) -> ConditionBlock:
	var block := load(path) as ConditionBlock
	if block == null:
		push_error("Missing condition block: %s" % path)
		return null
	return block.duplicate() as ConditionBlock


func _action(path: String) -> ActionBlock:
	var block := load(path) as ActionBlock
	if block == null:
		push_error("Missing action block: %s" % path)
	return block
