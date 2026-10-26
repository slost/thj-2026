extends Component
class_name LocationComponent
## Marks its host Entity as a location (room, area, container space)
## that other entities can be in. Genre-agnostic.
## Reports the value "visited".


@export var visited := false ## True once an actor has arrived here (set by "go").
## How it looks from a neighbouring location ("look north"). Placeholders:
## {room} (its name), {direction}. Passed through [method Object.tr]. Empty
## uses the looker's own wording ("To the north you see the garden.").
@export_multiline var distant_description := ""
## Do not list what is here when seen from a neighbouring location.
@export var hide_contents_from_afar := false
## Nothing past this location can be seen from a neighbouring one.
@export var blocks_view := false


## [member distant_description] translated, with placeholders filled.
func get_distant_description(values: Dictionary = {}) -> String:
	return tr(distant_description).format(values) if not distant_description.is_empty() else ""


func _state_values() -> Dictionary:
	return {&"visited": visited}


func _set_state_value(key: StringName, value: Variant) -> bool:
	if key != &"visited":
		return false
	visited = bool(value)
	return true
