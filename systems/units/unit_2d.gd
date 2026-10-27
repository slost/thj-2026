extends CharacterBody2D
class_name Unit2D


signal spawned(unit: Unit2D)
signal damaged(unit: Unit2D, attacker: Node)
signal died(unit: Unit2D)

enum State { SPAWNING, IDLE, MOVING, ATTACKING, DEAD }
enum Team { NONE, MINION, VILLAGER } ## None is neutral, Minions are hostile to Villagers, Villagers are hostile to Minions

const GROUP := &"units"
const ARRIVE_RADIUS := 8.0
const REPATH_INTERVAL := 0.4
const STUCK_TIME := 1.0
const STUCK_DISTANCE := 4.0

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
var _last_attacker: Node = null
var _dying: bool = false

var _move_goal: Vector2 = Vector2.ZERO
var _has_move_goal: bool = false
var _waypoints: PackedVector2Array = PackedVector2Array()
var _waypoint_index: int = 0
var _repath_cooldown: float = 0.0
var _goal_cell: Vector2i = Vector2i.ZERO
var _goal_cell_valid: bool = false
var _stuck_timer: float = 0.0
var _stuck_anchor: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group(GROUP)
	motion_mode = MOTION_MODE_FLOATING
	_apply_definition()
	_wire_health()
	_begin_spawn()


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if state == State.IDLE or state == State.MOVING:
		if runner:
			runner.tick(delta)
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
		_waypoints = PackedVector2Array()
		_waypoint_index = 0
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
	died.emit(self)
	_notify_allies()


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


func _tile_size() -> float:
	var nav := _grid_nav()
	if nav:
		return float(nav.get_tile_size())
	return float(GridNav.TILE_SIZE_FALLBACK)


func _grid_nav() -> GridNav:
	var node := get_tree().get_first_node_in_group(GridNav.GROUP)
	return node as GridNav

#endregion


#region Commands (used by action blocks)
func can_attack() -> bool:
	return _cooldown_left <= 0.0 and state != State.DEAD and state != State.SPAWNING


func attack(target: Unit2D) -> void:
	if target == null or not is_instance_valid(target) or target.state == State.DEAD:
		return
	if not can_attack() or stats == null:
		return
	set_state(State.ATTACKING)
	_cooldown_left = stats.attack_cooldown
	target.take_damage(stats.damage, self)
	if state == State.DEAD or _dying:
		return
	if _has_move_goal:
		set_state(State.MOVING)
	else:
		set_state(State.IDLE)


func move_toward_target(target: Node2D) -> void:
	if target == null:
		return
	_set_move_goal(target.global_position)


func move_away_from(target: Node2D) -> void:
	if target == null:
		return
	var away := global_position - target.global_position
	if away.length_squared() < 1.0:
		away = Vector2.RIGHT
	_set_move_goal(global_position + away.normalized() * _tile_size() * 4.0)


func move_dir(direction: Vector2) -> void:
	if direction.length_squared() < 0.001:
		stop_moving()
		return
	_set_move_goal(global_position + direction.normalized() * _tile_size() * 2.0)


func stop_moving() -> void:
	_has_move_goal = false
	_waypoints = PackedVector2Array()
	_waypoint_index = 0
	velocity = Vector2.ZERO
	if state == State.MOVING:
		set_state(State.IDLE)

#endregion


#region Movement
func _set_move_goal(world_pos: Vector2) -> void:
	if state == State.DEAD or state == State.SPAWNING or _dying:
		return
	if not _has_move_goal:
		_stuck_anchor = global_position
		_stuck_timer = 0.0
	_move_goal = world_pos
	_has_move_goal = true
	if state == State.IDLE:
		set_state(State.MOVING)


func _follow_goal(delta: float) -> void:
	if not _has_move_goal or stats == null:
		velocity = Vector2.ZERO
		set_state(State.IDLE)
		return
	var nav := _grid_nav()
	var cell_changed := false
	if nav:
		var cell := nav.world_to_cell(_move_goal)
		if not _goal_cell_valid or cell != _goal_cell:
			cell_changed = true
	_repath_cooldown -= delta
	_stuck_timer += delta
	var stuck := false
	if _stuck_timer >= STUCK_TIME:
		stuck = global_position.distance_to(_stuck_anchor) < STUCK_DISTANCE
		_stuck_anchor = global_position
		_stuck_timer = 0.0
	if not _goal_cell_valid or cell_changed or _repath_cooldown <= 0.0 or stuck:
		_rebuild_path()
	_advance_waypoints()


func _rebuild_path() -> void:
	_repath_cooldown = REPATH_INTERVAL
	var nav := _grid_nav()
	if nav:
		_goal_cell = nav.world_to_cell(_move_goal)
		_goal_cell_valid = true
		_waypoints = nav.find_path_world(global_position, _move_goal)
	else:
		_goal_cell_valid = true
		_waypoints = PackedVector2Array([_move_goal])
	_waypoint_index = 0
	if nav and _waypoints.size() > 1:
		var skip_distance := float(nav.get_tile_size()) * 0.6
		if global_position.distance_to(_waypoints[0]) <= skip_distance:
			_waypoint_index = 1


func _advance_waypoints() -> void:
	if _waypoints.is_empty():
		velocity = Vector2.ZERO
		return
	while _waypoint_index < _waypoints.size() and global_position.distance_to(_waypoints[_waypoint_index]) <= ARRIVE_RADIUS:
		_waypoint_index += 1
	var destination := _move_goal
	if _waypoint_index < _waypoints.size():
		destination = _waypoints[_waypoint_index]
	elif global_position.distance_to(_move_goal) <= ARRIVE_RADIUS:
		stop_moving()
		return
	var to_point := destination - global_position
	if to_point.length_squared() < 0.001:
		velocity = Vector2.ZERO
		return
	velocity = to_point.normalized() * stats.speed


func _face_velocity() -> void:
	var sprite := get_node_or_null("HotSwapSprite") as Node2D
	if sprite == null:
		return
	if velocity.x < -1.0:
		sprite.scale.x = -absf(sprite.scale.x)
	elif velocity.x > 1.0:
		sprite.scale.x = absf(sprite.scale.x)

#endregion
