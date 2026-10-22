## This component is used to play a squash and stretch impact effect on a visual node when a body enters an area.
## @tags: visual, impact, animation, squash, stretch
extends Component
class_name ImpactEffectComponent


signal impact_played(impact_strength: float)
signal impact_finished()

@export var target_groups: Array[StringName] = [&"impactable"]

@export_category("References")
@export var visual: Node2D ## Required, the visual node to apply the impact effect to
@export var sensor: Area2D ## Optional, you can call play_impact directly from the component

@export_category("Impact")
@export_range(0.0, 1.0) var strength: float = 0.08 ## The maximum strength of the impact effect
@export_range(0.0, 1.0) var rebound_strength: float = 0.35 ## The rebound strength relative to the impact
@export_range(0.0, 1.0) var randomness: float = 0.1 ## Random variation applied to the impact strength
@export var impact_duration: float = 0.05 ## The duration of the impact effect
@export var recovery_duration: float = 0.25 ## The duration of the recovery effect

var _tween: Tween
var _base_scale: Vector2


#region Public API
## Plays the impact squash and stretch effect.
func play_impact(impact_strength: float = 1.0) -> void:
	if not is_enabled() or not visual:
		return

	var effect_strength := _calculate_effect_strength(impact_strength)
	if effect_strength <= 0.0:
		return

	if _tween:
		_tween.kill()

	var squash_scale := Vector2(
		1.0 + effect_strength,
		1.0 - effect_strength
	)

	var settle_strength := effect_strength * rebound_strength
	var settle_scale := Vector2(
		1.0 - settle_strength,
		1.0 + settle_strength
	)

	_tween = create_tween()
	_tween.tween_property(
		visual,
		"scale",
		_base_scale * squash_scale,
		impact_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_tween.tween_property(
		visual,
		"scale",
		_base_scale * settle_scale,
		impact_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_tween.tween_property(
		visual,
		"scale",
		_base_scale,
		recovery_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_tween.finished.connect(_on_impact_finished)

	impact_played.emit(impact_strength)

#endregion


#region Internal Logic
func _calculate_effect_strength(impact_strength: float) -> float:
	var normalized_strength := clampf(impact_strength, 0.0, 1.0)
	var random_factor := randf_range(
		1.0 - randomness,
		1.0 + randomness
	)
	return normalized_strength * strength * random_factor


func _is_target(body: Node2D) -> bool:
	for group in target_groups:
		if body.is_in_group(group):
			return true
	return false


func _on_body_entered(body: Node2D) -> void:
	if not _is_target(body):
		return

	play_impact(1.0)


func _on_impact_finished() -> void:
	impact_finished.emit()
	_tween = null

#endregion


#region Overridable Hooks
func _setup() -> void:
	if sensor and not sensor.body_entered.is_connected(_on_body_entered):
		sensor.body_entered.connect(_on_body_entered)

	if visual:
		_base_scale = visual.scale

#endregion