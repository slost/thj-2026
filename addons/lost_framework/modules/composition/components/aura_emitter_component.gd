extends Component
class_name AuraEmitterComponent

#region EXPORTS
## Groups that can be affected by this aura
@export var target_groups: Array[String] = []

## Optional Area2D used as aura sensor
@export var aura_area: Area2D
#endregion



#region STATE
var _range: RangeComponent
var _effects: Array[AuraEffectComponent] = []

var _collision_shape: CollisionShape2D
#endregion

#region LIFECYCLE
func _setup() -> void:
	super._setup()

	if not get_host() is Node2D:
		push_warning("AuraEmitterComponent host must be Node2D")
		return

	_range = Utils.get_component(get_host(), RangeComponent)

	_collect_effects()
	_bind_area()
#endregion

#region SETUP
func _collect_effects() -> void:
	_effects.clear()

	for child in get_host().get_children():
		if child is AuraEffectComponent:
			_effects.append(child)

func _bind_area() -> void:
	if not aura_area:
		push_warning("AuraEmitterComponent has no Area2D assigned")
		return

	# Cache first CollisionShape2D
	for child in aura_area.get_children():
		if child is CollisionShape2D:
			_collision_shape = child
			break

	if not _collision_shape:
		push_warning("AuraEmitterComponent AuraArea has no CollisionShape2D")
		return

	aura_area.body_entered.connect(_on_body_entered)
	aura_area.body_exited.connect(_on_body_exited)

	aura_area.area_entered.connect(_on_area_entered)
	aura_area.area_exited.connect(_on_area_exited)

#endregion

#region AURA LOGIC
func _on_body_entered(body: Node) -> void:
	if not _is_valid_target(body):
		return

	for effect in _effects:
		effect.apply_to(body)

func _on_body_exited(body: Node) -> void:
	if not _is_valid_target(body):
		return

	for effect in _effects:
		effect.remove_from(body)

#region AREA SIGNALS
func _on_area_entered(area: Area2D) -> void:
	var target: Node = _resolve_target_from_area(area)
	if not target:
		return

	if not _is_valid_target(target):
		return

	for effect in _effects:
		effect.apply_to(target)


func _on_area_exited(area: Area2D) -> void:
	var target: Node = _resolve_target_from_area(area)
	if not target:
		return

	if not _is_valid_target(target):
		return

	for effect in _effects:
		effect.remove_from(target)
#endregion

#endregion

#region INTERNAL
func _resolve_target_from_area(area: Area2D) -> Node:
	if not area:
		return null

	# Case 1: area belongs to an entity node
	if area:
		return area

	return null
#endregion


#region TARGET FILTER
func _is_valid_target(body: Node) -> bool:
	if target_groups.is_empty():
		return true

	for group in target_groups:
		if body.is_in_group(group):
			return true

	return false
#endregion


func _physics_process(_delta: float) -> void:
	_update_range_shape()


#region RANGE SYNC
func _update_range_shape() -> void:
	if not _range:
		return

	if not _collision_shape:
		return

	var circle: CircleShape2D = _collision_shape.shape as CircleShape2D
	if not circle:
		return

	if is_equal_approx(circle.radius, _range.range):
		return

	circle.radius = _range.range
#endregion
