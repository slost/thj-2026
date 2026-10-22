extends SaveAdapter
class_name Node2DTransformSaveAdapter


#region Public API
func capture(target: Node) -> Dictionary:
	if not target is Node2D:
		return {}

	return {
		"position": {
			"__type": "Vector2",
			"x": target.global_position.x,
			"y": target.global_position.y
		},
		"rotation": target.global_rotation,
		"scale": {
			"__type": "Vector2",
			"x": target.scale.x,
			"y": target.scale.y
		}
	}


func apply(target: Node, data: Dictionary) -> void:
	if not target is Node2D:
		return

	var position_data: Dictionary = data.get("position", {})
	var scale_data: Dictionary = data.get("scale", {})

	target.global_position = Vector2(
		float(position_data.get("x", 0.0)),
		float(position_data.get("y", 0.0))
	)

	target.global_rotation = float(data.get("rotation", 0.0))

	target.scale = Vector2(
		float(scale_data.get("x", 1.0)),
		float(scale_data.get("y", 1.0))
	)
#endregion