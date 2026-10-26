extends DataDef
class_name TownDef


@export var max_restore_points := 100.0
@export var is_destroyed := false


func _domain_id() -> StringName:
	return "location"