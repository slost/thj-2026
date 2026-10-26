## Plays a squash and stretch scale animation on a visual node when its API is called.
## play() grows the visual and holds the enlarged scale. release() returns it to the base scale.
## @tags: visual, animation, squash, stretch
extends Component
class_name SquashAnimationComponent


signal squash_played(amount: float)
signal squash_finished()
signal release_finished()

@export_category("References")
@export var visual: Node2D ## Required, the visual node to scale

@export_category("Squash")
@export_range(1.0, 2.0, 0.01) var enlarged_scale: float = 1.22 ## Uniform scale held after play()
@export_range(0.0, 1.0) var strength: float = 0.14 ## The maximum squash and stretch amount
@export_range(0.0, 1.0) var rebound_strength: float = 0.45 ## Opposite-axis rebound relative to the squash
@export var squash_duration: float = 0.06 ## Duration of the squash
@export var rebound_duration: float = 0.09 ## Duration of the stretch rebound
@export var settle_duration: float = 0.14 ## Duration of the settle


var _tween: Tween
var _base_scale: Vector2 = Vector2.ONE
var _has_base_scale := false


#region Public API
## Grows the visual with a squash and stretch, then holds the enlarged scale.
func play(amount: float = 1.0) -> void:
	if not is_enabled() or not _ready_visual():
		return

	var normalized := clampf(amount, 0.0, 1.0)
	var effect := normalized * strength
	var held := _base_scale * lerpf(1.0, enlarged_scale, normalized)
	var squash_scale := Vector2(1.0 + effect, 1.0 - effect)
	var rebound_scale := Vector2(
		1.0 - effect * rebound_strength,
		1.0 + effect * rebound_strength
	)

	var tween := _begin_tween()
	tween.tween_property(
		visual,
		"scale",
		_scaled(held, squash_scale),
		squash_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		visual,
		"scale",
		_scaled(held, rebound_scale),
		rebound_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		visual,
		"scale",
		held,
		settle_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.finished.connect(_on_squash_finished.bind(tween))
	squash_played.emit(normalized)


## Returns the visual to the scale it had when this component was set up.
func release() -> void:
	if not is_enabled() or not _ready_visual():
		return

	var effect := strength * rebound_strength
	var squash_scale := Vector2(1.0 + effect, 1.0 - effect)

	var tween := _begin_tween()
	tween.tween_property(
		visual,
		"scale",
		_scaled(_base_scale, squash_scale),
		squash_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		visual,
		"scale",
		_base_scale,
		settle_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.finished.connect(_on_release_finished.bind(tween))

#endregion


#region Internal Logic
func _ready_visual() -> bool:
	if is_instance_valid(visual):
		_capture_base_scale()
		return true

	var owner_node := host_node if host_node else get_parent()
	if owner_node == null:
		return false

	visual = owner_node.get_node_or_null("Visual") as Node2D
	if visual == null:
		return false

	_capture_base_scale()
	return true


func _capture_base_scale() -> void:
	if _has_base_scale or visual == null:
		return

	_base_scale = visual.scale
	_has_base_scale = true


func _scaled(scale: Vector2, factors: Vector2) -> Vector2:
	return Vector2(scale.x * factors.x, scale.y * factors.y)


func _begin_tween() -> Tween:
	if _tween:
		_tween.kill()

	_tween = create_tween()
	return _tween


func _on_squash_finished(tween: Tween) -> void:
	if _tween != tween:
		return

	_tween = null
	squash_finished.emit()


func _on_release_finished(tween: Tween) -> void:
	if _tween != tween:
		return

	_tween = null
	release_finished.emit()

#endregion


#region Overridable Hooks
func _setup() -> void:
	_ready_visual()


func _teardown() -> void:
	if _tween:
		_tween.kill()
		_tween = null

#endregion
