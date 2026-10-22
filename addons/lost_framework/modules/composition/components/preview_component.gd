extends Component
class_name PreviewComponent

#region Config
@export var preview_alpha: float = 0.5
@export var disable_process: bool = true
@export var disable_collision: bool = true
@export var block_group: String
@export var valid_color: Color = Color(1, 1, 1, 1)
@export var invalid_color: Color = Color(1, 0.2, 0.2, 1)

#endregion

#region State
var _is_valid_cache: bool = true
var is_preview: bool = false
#endregion

var _area


func _physics_process(_delta: float) -> void:
	if not is_preview:
		return

	update_preview_feedback()


func _setup() -> void:
	super._setup()
	if get_host() is Area2D:
		_area = get_host()


func set_preview_mode(enabled: bool) -> void:
	is_preview = enabled
	_apply_logic(enabled)


func update_preview_feedback() -> void:
	if not is_preview:
		return

	var valid: bool = is_valid_placement()
	if valid == _is_valid_cache:
		return

	_is_valid_cache = valid

	var color := valid_color if valid else invalid_color
	_apply_color_recursive(get_host(), color, preview_alpha)


func _apply_color_recursive(node: Node, color: Color, alpha: float) -> void:
	if node is CanvasItem:
		var c := color
		c.a = alpha
		node.modulate = c

	for child in node.get_children():
		_apply_color_recursive(child, color, alpha)



func is_valid_placement() -> bool:
	if not _area:
		return true

	var overlaps: Array = _area.get_overlapping_bodies()
	overlaps.append_array(_area.get_overlapping_areas())

	for o in overlaps:
		if o == get_host():
			continue

		if o.is_in_group("component"):
			return true
			
		if o.is_in_group(block_group):
			return false

	return true



func _apply_logic(enabled: bool) -> void:
	if not get_host():
		return

	for child in get_host().get_children():
		if child == self:
			continue

		if child is Component:
			if enabled and not child.supports_preview():
				child.set_process(false)
				child.set_physics_process(false)
			else:
				child.set_process(true)
				child.set_physics_process(true)

	if disable_collision:
		_toggle_collision(get_host(), not enabled)



func _toggle_collision(node: Node, enabled: bool) -> void:
	if node is CollisionShape2D:
		node.disabled = not enabled

	for child in node.get_children():
		_toggle_collision(child, enabled)


#endregion


func is_preview_active() -> bool:
	return is_preview
