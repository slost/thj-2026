extends CharacterBody2D
class_name Unit2D


signal spawned(unit: Unit2D)
signal damaged(unit: Unit2D, attacker: Node)
signal died(unit: Unit2D)

enum State { SPAWNING, IDLE, MOVING, ATTACKING, DEAD }
enum Team { NONE, MINION, VILLAGER } ## None is neutral, Minions are hostile to Villagers, Villagers are hostile to Minions

const GROUP := &"units"
const ARRIVE_RADIUS := 8.0
const STUCK_TIME := 1.0
const STUCK_DISTANCE := 4.0
const CORPSE_LINGER := 2.5
const CORPSE_FADE := 1.5
## Wider than the body so a unit behind starts turning before the circles lock.
const AVOID_RADIUS := 72.0
const AVOID_NEIGHBOR_DISTANCE := 320.0
## NavigationServer publishes the path a moment after target_position changes.
const PATH_SETTLE_TIME := 0.35

@export var def: UnitDef
@export var anim_player: AnimationPlayer
## Runtime team. When def is set, _ready copies def.team over this export.
## The export is only the fallback used by a unit placed without a definition.
@export var team: Team = Team.MINION

@onready var runner: ProgramRunner = $ProgramRunner
@onready var health: HealthComponent = $ComponentContainer/HealthComponent

var stats: UnitStats
var program: UnitProgram
var state := State.SPAWNING

var _cooldown_left: float = 0.0
var _attack_time_left: float = 0.0
var _attack_duration: float = 0.0
var _attack_waits_for_animation: bool = false
var _last_attacker: Node = null
var _dying: bool = false

var _move_goal: Vector2 = Vector2.ZERO
var _has_move_goal: bool = false
var _goal_cell: Vector2i = Vector2i.ZERO
var _goal_cell_valid: bool = false
var _path_wait: float = 0.0
## Cell the remembered target stood on when this approach was chosen.
var _approach_anchor: Vector2i = Vector2i.ZERO
var _approach_anchor_valid: bool = false
var _rejected_goals: Array[Vector2i] = []
var _no_route: bool = false
var _stuck_timer: float = 0.0
var _stuck_anchor: Vector2 = Vector2.ZERO
var _agent: NavigationAgent2D
var _avoidance_frames: int = 0
var _tint: Color = Color.WHITE
var _corpse_time: float = 0.0

## Remembered units. Only forget-commands remove entries.
var targets: Array[Unit2D] = []
## Actions read from the script, performed front to back.
var queue_actions: Array[ActionBlock] = []


func _ready() -> void:
	add_to_group(GROUP)
	motion_mode = MOTION_MODE_FLOATING
	_tint = modulate
	_ensure_agent()
	_apply_definition()
	_wire_health()
	_begin_spawn()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_tick_corpse(delta)
		return
	if is_ram_full():
		_freeze_overloaded()
		return
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var acting := state == State.IDLE or state == State.MOVING or state == State.ATTACKING
	if state == State.ATTACKING:
		_tick_attack(delta)
	if acting and runner:
		runner.tick(delta)
	if acting:
		_step_action_queue()
	if state == State.MOVING:
		_follow_goal(delta)
	else:
		velocity = Vector2.ZERO
	_face_velocity()
	move_and_slide()


func set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	if new_state != State.MOVING:
		velocity = Vector2.ZERO
	if new_state == State.DEAD:
		_has_move_goal = false
		_goal_cell_valid = false
		_no_route = false
		collision_layer = 0
		collision_mask = 0


#region Setup
func _apply_definition() -> void:
	if def:
		team = def.team
		stats = UnitStats.from_def(def)
		program = def.starting_program.clone() if def.starting_program else _empty_program()
	else:
		stats = UnitStats.new()
		program = _empty_program()
	_apply_gpu_animation()


func _empty_program() -> UnitProgram:
	var created := UnitProgram.new()
	created.event_graph = EventGraph.new()
	return created


func _wire_health() -> void:
	if health == null or stats == null:
		push_error("Unit2D requires a HealthComponent.")
		return
	health.set_max_health(float(stats.max_hp), true)
	stats.hp = int(round(health.get_health()))
	if not health.damaged.is_connected(_on_health_damaged):
		health.damaged.connect(_on_health_damaged)
	if not health.died.is_connected(_on_health_died):
		health.died.connect(_on_health_died)


func _begin_spawn() -> void:
	if anim_player and anim_player.has_animation(&"spawn"):
		if not anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.connect(_on_animation_finished)
		anim_player.play(&"spawn")
		return
	_on_spawn_finished()


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"spawn":
		_on_spawn_finished()
	elif anim_name == &"attack":
		_finish_attack()


func _on_spawn_finished() -> void:
	if state != State.SPAWNING:
		return
	set_state(State.IDLE)
	if runner:
		runner.fire(EventGraph.Event.ON_SPAWN)
	spawned.emit(self)

#endregion


#region Damage
func take_damage(amount: int, attacker: Node = null) -> void:
	if state == State.DEAD or _dying or amount <= 0:
		return
	_last_attacker = attacker
	if health:
		health.apply_damage(float(amount))
		return
	stats.hp = maxi(stats.hp - amount, 0)
	damaged.emit(self, attacker)
	if runner:
		runner.fire(EventGraph.Event.ON_HIT, attacker)
	if stats.hp <= 0:
		die()


func _on_health_damaged(_amount: float, current_health: float) -> void:
	if stats:
		stats.hp = int(round(current_health))
	var attacker := _last_attacker
	damaged.emit(self, attacker)
	if state != State.DEAD and not _dying and runner:
		runner.fire(EventGraph.Event.ON_HIT, attacker)


func _on_health_died() -> void:
	die()


func die() -> void:
	if state == State.DEAD or _dying:
		return
	_dying = true
	if runner:
		runner.fire(EventGraph.Event.ON_DEATH)
	set_state(State.DEAD)
	_hide_dead_chrome()
	died.emit(self)
	_notify_allies()


func _tick_corpse(delta: float) -> void:
	_corpse_time += delta
	if _corpse_time <= CORPSE_LINGER:
		return
	var fade := clampf((_corpse_time - CORPSE_LINGER) / CORPSE_FADE, 0.0, 1.0)
	var color := _tint
	color.a = 1.0 - fade
	modulate = color
	if fade >= 1.0:
		queue_free()


## Health bar, think bar, animation bar, and the per-unit debug label stay off after death.
func _hide_dead_chrome() -> void:
	_hide_visuals(get_node_or_null("ComponentContainer/HealthBarComponent"))
	_hide_visuals(get_node_or_null("ComponentContainer/ThinkBarComponent"))
	_hide_visuals(get_node_or_null("ComponentContainer/AnimationBarComponent"))
	var overlay := get_node_or_null("DebugOverlay") as CanvasItem
	if overlay:
		overlay.visible = false


func _hide_visuals(node: Node) -> void:
	if node == null:
		return
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	for child in node.get_children():
		_hide_visuals(child)


func _notify_allies() -> void:
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Unit2D
		if other == null or other == self or other.state == State.DEAD or other._dying:
			continue
		if other.team != team or other.runner == null:
			continue
		other.runner.fire(EventGraph.Event.ON_ALLY_DIED, self)

#endregion


#region Senses (used by condition blocks)
## max_tiles < 0 uses stats.detect_range. Distance is euclidean, in tiles.
func find_nearest_enemy(max_tiles: int = -1) -> Unit2D:
	return _find_nearest(true, max_tiles)


func find_nearest_ally(max_tiles: int = -1) -> Unit2D:
	return _find_nearest(false, max_tiles)


## Nearest other living unit in detect range, hostile or not.
func find_nearest_unit(max_tiles: int = -1) -> Unit2D:
	var limit := max_tiles
	if limit < 0:
		limit = stats.detect_range if stats else 0
	var max_dist := float(limit) * _tile_size()
	var best: Unit2D = null
	var best_dist := max_dist
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Unit2D
		if other == null or other == self or not is_instance_valid(other):
			continue
		if other.state == State.DEAD or other.state == State.SPAWNING:
			continue
		var dist := global_position.distance_to(other.global_position)
		if dist > max_dist:
			continue
		if best == null or dist < best_dist:
			best = other
			best_dist = dist
	return best


func _find_nearest(want_enemy: bool, max_tiles: int) -> Unit2D:
	var limit := max_tiles
	if limit < 0:
		limit = stats.detect_range if stats else 0
	var max_dist := float(limit) * _tile_size()
	var best: Unit2D = null
	var best_dist := max_dist
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Unit2D
		if other == null or other == self or not is_instance_valid(other):
			continue
		if other.state == State.DEAD or other.state == State.SPAWNING:
			continue
		if want_enemy:
			if not is_enemy(other):
				continue
		elif other.team != team:
			continue
		var dist := global_position.distance_to(other.global_position)
		if dist > max_dist:
			continue
		if best == null or dist < best_dist:
			best = other
			best_dist = dist
	return best


## Grid distance, counting a diagonal step as 1.
func chebyshev_cells_to(world_pos: Vector2) -> int:
	var here := _cell_of(global_position)
	var there := _cell_of(world_pos)
	return maxi(absi(here.x - there.x), absi(here.y - there.y))


func is_in_attack_range(target: Node2D) -> bool:
	if target == null or stats == null:
		return false
	var max_dist := float(stats.attack_range) * _tile_size()
	return global_position.distance_to(target.global_position) <= max_dist


func is_enemy(other: Unit2D) -> bool:
	if other == null or other == self:
		return false
	if team == Team.NONE or other.team == Team.NONE:
		return false
	return other.team != team


func _cell_of(world_pos: Vector2) -> Vector2i:
	var nav := _grid_nav()
	if nav:
		return nav.world_to_cell(world_pos)
	var tile := _tile_size()
	return Vector2i(floori(world_pos.x / tile), floori(world_pos.y / tile))


func _tile_size() -> float:
	var nav := _grid_nav()
	if nav:
		return float(nav.get_tile_size())
	return float(GridNav.TILE_SIZE_FALLBACK)


func _grid_nav() -> GridNav:
	var node := get_tree().get_first_node_in_group(GridNav.GROUP)
	return node as GridNav

#endregion


#region Memory
func remember_target(target: Unit2D) -> void:
	if target == null or target == self or not is_instance_valid(target):
		return
	if target.state == State.DEAD or targets.has(target):
		return
	targets.append(target)


## First living remembered unit. Dead entries stay until a forget command removes them.
func get_primary_target() -> Unit2D:
	for target in targets:
		if target == null or not is_instance_valid(target):
			continue
		if target.state == State.DEAD or target._dying:
			continue
		return target
	return null


func forget_targets(which: ForgetMemory.Which) -> void:
	if targets.is_empty():
		return
	match which:
		ForgetMemory.Which.LAST:
			targets.pop_back()
		ForgetMemory.Which.ALL:
			targets.clear()
		_:
			targets.pop_front()


func forget_actions(which: ForgetMemory.Which) -> void:
	if queue_actions.is_empty():
		return
	var drop_front := which != ForgetMemory.Which.LAST or queue_actions.size() == 1
	match which:
		ForgetMemory.Which.LAST:
			queue_actions.pop_back()
		ForgetMemory.Which.ALL:
			queue_actions.clear()
		_:
			queue_actions.pop_front()
	if drop_front:
		stop_moving()


func forget_everything() -> void:
	targets.clear()
	queue_actions.clear()
	stop_moving()


func enqueue_action(action: ActionBlock) -> void:
	if action == null or _queue_has_same(action):
		return
	var copy := action.duplicate() as ActionBlock
	if copy == null:
		return
	queue_actions.append(copy)


func _queue_has_same(action: ActionBlock) -> bool:
	var source: Script = action.get_script()
	for queued in queue_actions:
		if queued != null and queued.get_script() == source:
			return true
	return false


func is_ram_full() -> bool:
	if stats == null:
		return false
	return get_ram_used() >= stats.ram


func _freeze_overloaded() -> void:
	velocity = Vector2.ZERO
	if state == State.MOVING:
		stop_moving()
	if anim_player and anim_player.is_playing():
		anim_player.pause()


func get_ram_used() -> int:
	var program_cost := 0
	if program:
		program_cost = program.get_ram_cost()
	var slots := targets.size() + queue_actions.size()
	return program_cost + slots * Formular.memory_slot_cost()


func _step_action_queue() -> void:
	if queue_actions.is_empty():
		return
	var action := queue_actions[0]
	if action == null:
		queue_actions.pop_front()
		return
	var ctx := ExecContext.new(self, EventGraph.Event.ON_UPDATE, null)
	ctx.target = get_primary_target()
	var result := action.step(self, ctx)
	if result == ActionBlock.StepResult.RUNNING:
		return
	queue_actions.pop_front()

#endregion


#region Commands (used by action blocks)
func can_attack() -> bool:
	return (
		_cooldown_left <= 0.0
		and state != State.DEAD
		and state != State.SPAWNING
		and state != State.ATTACKING
	)


func get_attack_cooldown_left() -> float:
	return _cooldown_left


func attack(target: Unit2D) -> void:
	if target == null or not is_instance_valid(target) or target.state == State.DEAD:
		return
	if not can_attack() or stats == null:
		return
	_face_toward(target.global_position)
	set_state(State.ATTACKING)
	_cooldown_left = stats.attack_cooldown
	_begin_attack_hold()
	target.take_damage(stats.damage, self)


## Stay in ATTACKING for the attack animation, or for Formular.calculate_attack_duration.
func _begin_attack_hold() -> void:
	if anim_player and anim_player.has_animation(&"attack"):
		_attack_waits_for_animation = true
		_attack_duration = 0.0
		_attack_time_left = 0.0
		anim_player.play(&"attack")
		return
	_attack_waits_for_animation = false
	_attack_duration = Formular.calculate_attack_duration(get_gpu())
	_attack_time_left = _attack_duration


func _tick_attack(delta: float) -> void:
	if _attack_waits_for_animation:
		return
	_attack_time_left -= delta
	if _attack_time_left <= 0.0:
		_finish_attack()


func _finish_attack() -> void:
	if state != State.ATTACKING:
		return
	_attack_waits_for_animation = false
	_attack_duration = 0.0
	_attack_time_left = 0.0
	if _has_move_goal:
		set_state(State.MOVING)
	else:
		set_state(State.IDLE)


func move_toward_target(target: Node2D) -> void:
	if target == null or state == State.DEAD or state == State.SPAWNING or _dying:
		return
	var target_cell := _cell_of(target.global_position)
	if _has_move_goal and _approach_anchor_valid and _approach_anchor == target_cell and not _no_route:
		return
	if not _approach_anchor_valid or _approach_anchor != target_cell:
		_approach_anchor = target_cell
		_approach_anchor_valid = true
		_rejected_goals.clear()
		_no_route = false
	_commit_stand_cell(target_cell)


func path_failed() -> bool:
	return _no_route


## Cell this unit is walking toward, or null when it is standing still.
func get_move_goal_cell() -> Variant:
	if _has_move_goal and _goal_cell_valid:
		return _goal_cell
	return null


func move_away_from(target: Node2D) -> void:
	if target == null:
		return
	var away := global_position - target.global_position
	if away.length_squared() < 1.0:
		away = Vector2.RIGHT
	_begin_free_move(global_position + away.normalized() * _tile_size() * 4.0)


func move_dir(direction: Vector2) -> void:
	if direction.length_squared() < 0.001:
		stop_moving()
		return
	_begin_free_move(global_position + direction.normalized() * _tile_size() * 2.0)


func stop_moving() -> void:
	_has_move_goal = false
	_goal_cell_valid = false
	_path_wait = 0.0
	_no_route = false
	_approach_anchor_valid = false
	_rejected_goals.clear()
	velocity = Vector2.ZERO
	if _agent:
		_agent.velocity = Vector2.ZERO
		_agent.target_position = global_position
	if state == State.MOVING:
		set_state(State.IDLE)

#endregion


#region Movement
func _begin_free_move(world_pos: Vector2) -> void:
	_approach_anchor_valid = false
	_rejected_goals.clear()
	_no_route = false
	_set_move_goal(world_pos)


func _commit_stand_cell(target_cell: Vector2i) -> void:
	var nav := _grid_nav()
	var stand: Variant = _pick_stand_cell(target_cell)
	if nav and stand is Vector2i:
		_no_route = false
		_set_move_goal(nav.cell_to_world(stand))
		return
	_no_route = true


## Prefer a free neighbor of the target. Fall back to any neighbor that is not rejected.
func _pick_stand_cell(target_cell: Vector2i) -> Variant:
	var nav := _grid_nav()
	if nav == null:
		return null
	var hard: Array[Vector2i] = []
	hard.append_array(_rejected_goals)
	hard.append_array(_crowd_cells(false))
	var soft: Array[Vector2i] = []
	soft.append_array(hard)
	soft.append_array(_crowd_cells(true))
	var picked: Variant = nav.find_alternate_cell(global_position, target_cell, soft)
	if picked is Vector2i:
		return picked
	return nav.find_alternate_cell(global_position, target_cell, hard)


## Cells other units stand on. Goals are included when another mover has already claimed a side.
func _crowd_cells(include_goals: bool) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Unit2D
		if other == null or other == self or other.state == State.DEAD or other._dying:
			continue
		var occupied := _cell_of(other.global_position)
		if not cells.has(occupied):
			cells.append(occupied)
		if not include_goals:
			continue
		var goal: Variant = other.get_move_goal_cell()
		if goal is Vector2i and not cells.has(goal):
			cells.append(goal)
	return cells


func _set_move_goal(world_pos: Vector2) -> void:
	if state == State.DEAD or state == State.SPAWNING or _dying:
		return
	if not _has_move_goal:
		_stuck_anchor = global_position
		_stuck_timer = 0.0
	var nav := _grid_nav()
	if nav:
		var cell := nav.world_to_cell(world_pos)
		world_pos = nav.cell_to_world(cell)
		if not _goal_cell_valid or cell != _goal_cell:
			_goal_cell = cell
			_goal_cell_valid = true
			_path_wait = 0.0
	_move_goal = world_pos
	_has_move_goal = true
	_no_route = false
	var agent := _ensure_agent()
	agent.target_position = world_pos
	agent.max_speed = get_move_speed()
	if state == State.IDLE:
		set_state(State.MOVING)


func _follow_goal(delta: float) -> void:
	if not _has_move_goal or stats == null:
		velocity = Vector2.ZERO
		set_state(State.IDLE)
		return
	var nav := _grid_nav()
	if nav and _goal_cell_valid and nav.world_to_cell(global_position) == _goal_cell:
		stop_moving()
		return
	if nav == null and global_position.distance_to(_move_goal) <= ARRIVE_RADIUS:
		stop_moving()
		return
	_stuck_timer += delta
	var stuck := false
	if _stuck_timer >= STUCK_TIME:
		stuck = global_position.distance_to(_stuck_anchor) < STUCK_DISTANCE
		_stuck_anchor = global_position
		_stuck_timer = 0.0
	_path_wait += delta
	var agent := _ensure_agent()
	var path := agent.get_current_navigation_path()
	var mesh_ready := nav != null and nav.navigation_vertex_count() > 0
	if stuck or (mesh_ready and _path_wait >= PATH_SETTLE_TIME and path.is_empty()):
		_retarget_around()
		if _no_route or not _has_move_goal:
			return
	var next := agent.get_next_path_position()
	var to_next := next - global_position
	if to_next.length_squared() < 1.0:
		agent.velocity = Vector2.ZERO
		return
	var speed := get_move_speed()
	agent.max_speed = speed
	agent.avoidance_priority = _avoidance_priority()
	var desired := to_next.normalized() * speed
	agent.velocity = desired
	# The avoidance callback replaces this once NavigationServer has answered.
	if _avoidance_frames == 0:
		velocity = desired


func _retarget_around() -> void:
	if not _approach_anchor_valid:
		stop_moving()
		return
	if _goal_cell_valid and not _rejected_goals.has(_goal_cell):
		_rejected_goals.append(_goal_cell)
	var stand: Variant = _pick_stand_cell(_approach_anchor)
	var nav := _grid_nav()
	if nav and stand is Vector2i:
		_set_move_goal(nav.cell_to_world(stand))
		return
	_no_route = true
	_has_move_goal = false
	velocity = Vector2.ZERO
	if state == State.MOVING:
		set_state(State.IDLE)


## Units already close to the target keep their line. Units behind yield and arc around.
func _avoidance_priority() -> float:
	var focus := _move_goal
	var nav := _grid_nav()
	if _approach_anchor_valid and nav:
		focus = nav.cell_to_world(_approach_anchor)
	var span := _tile_size() * 8.0
	var closeness := 1.0 - clampf(global_position.distance_to(focus) / span, 0.0, 1.0)
	return lerpf(0.15, 1.0, closeness)


func get_debug_waypoints() -> PackedVector2Array:
	if _agent == null:
		return PackedVector2Array()
	return _agent.get_current_navigation_path()


func _ensure_agent() -> NavigationAgent2D:
	if _agent != null and is_instance_valid(_agent):
		return _agent
	var agent := NavigationAgent2D.new()
	agent.name = "NavigationAgent2D"
	agent.avoidance_enabled = true
	agent.radius = AVOID_RADIUS
	agent.neighbor_distance = AVOID_NEIGHBOR_DISTANCE
	agent.max_neighbors = 10
	agent.time_horizon_agents = 1.6
	agent.time_horizon_obstacles = 0.4
	agent.path_desired_distance = 24.0
	agent.target_desired_distance = 16.0
	agent.path_max_distance = 200.0
	add_child(agent)
	agent.velocity_computed.connect(_on_navigation_velocity)
	_agent = agent
	return agent


func _on_navigation_velocity(safe_velocity: Vector2) -> void:
	_avoidance_frames += 1
	if state == State.MOVING and _has_move_goal:
		velocity = safe_velocity
	else:
		velocity = Vector2.ZERO


func get_gpu() -> int:
	if stats == null:
		return 1
	return maxi(stats.gpu, 1)


func get_cpu() -> int:
	if stats == null:
		return 1
	return maxi(stats.cpu, 1)


func get_move_speed() -> float:
	return Formular.calculate_move_speed(get_gpu(), get_cpu())


## 0 at the start of the playing clip, 1 when it finishes.
## An attack pose with no clip uses the same scale over its hold time.
func get_animation_ratio() -> float:
	if anim_player != null and anim_player.is_playing():
		var anim_name := anim_player.current_animation
		if anim_name != &"" and anim_player.has_animation(anim_name):
			var length := anim_player.get_animation(anim_name).length
			if length > 0.0:
				return clampf(anim_player.current_animation_position / length, 0.0, 1.0)
	if state == State.ATTACKING and _attack_duration > 0.0:
		return clampf(1.0 - _attack_time_left / _attack_duration, 0.0, 1.0)
	return 0.0


func _apply_gpu_animation() -> void:
	if anim_player:
		anim_player.speed_scale = Formular.calculate_animation_speed(get_gpu())


func _face_velocity() -> void:
	if absf(velocity.x) > 1.0:
		_face_toward(global_position + velocity)


func _face_toward(world_pos: Vector2) -> void:
	var sprite := get_node_or_null("HotSwapSprite") as Node2D
	if sprite == null:
		return
	var dx := world_pos.x - global_position.x
	if dx < -1.0:
		sprite.scale.x = -absf(sprite.scale.x)
	elif dx > 1.0:
		sprite.scale.x = absf(sprite.scale.x)

#endregion
