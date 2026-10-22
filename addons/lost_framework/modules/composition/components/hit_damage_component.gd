extends Component
class_name HitDamageComponent

#region EXPORTS

## Base damage dealt on hit
@export var damage: float = 1.0

## Damage multiplier applied by projectile speed
@export var speed_damage_scale: float = 0.01

## Groups that can be damaged
@export var target_groups: Array[StringName] = []

## Destroy host after successful hit
@export var destroy_on_hit: bool = true

#endregion


#region HIT API

## impact_power: usually projectile speed or derived value
func try_hit(target: Node, impact_power: float = 1.0) -> bool:
	if not target:
		return false

	if not _can_hit(target):
		return false

	_apply_damage(target, impact_power)

	if destroy_on_hit and get_host():
		get_host().queue_free()

	return true

#endregion


#region INTERNAL LOGIC

func _can_hit(target: Node) -> bool:
	if target_groups.is_empty():
		return true

	for group_name: StringName in target_groups:
		if target.is_in_group(group_name):
			return true

	return false


func _apply_damage(target: Node, impact_power: float) -> void:
	var health: HealthComponent = Utils.get_component(target, HealthComponent)
	if not health:
		return

	var final_damage: float = damage + (impact_power * speed_damage_scale)
	health.apply_damage(final_damage)

#endregion
