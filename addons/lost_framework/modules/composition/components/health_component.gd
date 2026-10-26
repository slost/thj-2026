extends Component
class_name HealthComponent


signal damaged(amount: float, current_health: float)
signal healed(amount: float, current_health: float)
signal health_changed(current_health: float, max_health: float)
signal died

@export var max_health: float = 10.0 ## Maximum health
@export var start_full: bool = true ## Start with full health

var current_health: float


func _setup() -> void:
	super._setup()

	if start_full:
		current_health = max_health
	else:
		current_health = clamp(current_health, 0.0, max_health)

	health_changed.emit(current_health, max_health)


#region Read-only API
func get_health() -> float:
	return current_health


func get_max_health() -> float:
	return max_health


func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return current_health / max_health


func is_alive() -> bool:
	return current_health > 0.0

#endregion


#region Gameplay API
func apply_damage(amount: float) -> void:
	if amount <= 0.0:
		return

	if not is_alive():
		return

	current_health -= amount
	current_health = max(current_health, 0.0)

	damaged.emit(amount, current_health)
	health_changed.emit(current_health, max_health)

	if current_health <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if amount <= 0.0:
		return

	if not is_alive():
		return

	current_health += amount
	current_health = min(current_health, max_health)

	healed.emit(amount, current_health)
	health_changed.emit(current_health, max_health)


func set_max_health(value: float, keep_ratio: bool = true) -> void:
	if value <= 0.0:
		return

	var ratio := get_health_ratio()

	max_health = value

	if keep_ratio:
		current_health = max_health * ratio
	else:
		current_health = min(current_health, max_health)

	health_changed.emit(current_health, max_health)

#endregion
