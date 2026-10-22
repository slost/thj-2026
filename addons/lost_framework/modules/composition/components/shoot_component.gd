extends Component
class_name ShootComponent

#region Exports
@export var projectile_scene: PackedScene ## Projectile scene to spawn 
@export var projectile_damage := 100.0

@export var shoot_sound: String
@export var muzzle_path: NodePath ## Spawn point (optional)
@export var projectile_speed: float = 400.0 ## Projectile speed
#endregion


#region State
var _targeting: TargetingComponent
var _timer: TriggerIntervalComponent
var _muzzle: Node2D
#endregion


#region Setup
func _setup() -> void:
	super._setup()

	_targeting = get_host_component(TargetingComponent)
	_timer = get_host_component(TriggerIntervalComponent)

	if muzzle_path != NodePath():
		_muzzle = get_host().get_node_or_null(muzzle_path)
	else:
		_muzzle = get_host()

	if _timer:
		_timer.triggered.connect(_on_trigger)
#endregion


#region Shoot Logic
func _on_trigger() -> void:
	if not projectile_scene:
		return

	if not _targeting:
		return

	var target := _targeting.get_target()
	if not target:
		return

	_spawn_projectile(target)


func _spawn_projectile(target: Node2D) -> void:
	var projectile := projectile_scene.instantiate()
	if not projectile:
		return

	projectile.global_position = _muzzle.global_position

	var direction = (target.global_position - projectile.global_position).normalized()

	# 1. Set direction for projectile
	if "direction" in projectile:
		projectile.direction = direction

	# 2. Set speed via SpeedComponent
	var speed_comp: SpeedComponent = Utils.get_component(projectile, SpeedComponent)
	if speed_comp:
		speed_comp.base_speed = projectile_speed

	var hit_damage_comp: HitDamageComponent = Utils.get_component(projectile, HitDamageComponent)
	if hit_damage_comp:
		hit_damage_comp.damage = projectile_damage

	projectile.name = "Projectile"
	get_tree().current_scene.add_child(projectile)
	if shoot_sound:
		Audio.play_sfx(Assets.fetch(shoot_sound), randf_range(2,5))
#endregion