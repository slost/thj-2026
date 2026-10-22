extends Component
class_name TargetingComponent

signal target_changed(old_target: Node2D, new_target: Node2D)

#region Exports
## Group used to search for targets
@export var target_group: String
#endregion

#region State
var target: Node2D
var _range_comp: RangeComponent
#endregion


func _setup() -> void:
	super._setup()
	_range_comp = get_host_component(RangeComponent)


func _physics_process(_delta: float) -> void:
	update_target()


func get_target() -> Node2D:
	return target


func update_target() -> void:
	var new_target: Node2D = _find_nearest_target()

	if new_target == target:
		return

	var old_target: Node2D = target
	target = new_target
	target_changed.emit(old_target, target)


#region Internal Logic
func _find_nearest_target() -> Node2D:
	if not get_host():
		return null

	var targets: Array = get_tree().get_nodes_in_group(target_group)
	if targets.is_empty():
		return null

	var nearest: Node2D = null
	var min_distance: float = INF
	var host_pos: Vector2 = get_host().global_position

	for t in targets:
		if not t is Node2D:
			continue

		if not _is_valid_target(t):
			continue

		## Range check (optional)
		if _range_comp:
			if not _range_comp.is_in_range(host_pos, t.global_position):
				continue

		var dist: float = host_pos.distance_to(t.global_position)
		if dist < min_distance:
			min_distance = dist
			nearest = t

	return nearest
#endregion


func supports_preview() -> bool:
	return true


func _is_valid_target(node: Node2D) -> bool:
	var current: Node = node

	while current:
		var preview: PreviewComponent = Utils.get_component(current, PreviewComponent)
		if preview and preview.is_preview_active():
			return false

		current = current.get_parent()

	return true
