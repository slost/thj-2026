extends Component
class_name PassageComponent
## Makes its host Entity a passage between two locations: a doorway, a path,
## a door (add an [OpenableComponent] and maybe a [LockableComponent]).
## One passage is the only record of a connection, for both directions.
## Locations are referred to by entity id, never by NodePath.
## Passages are usually kept under a plain node outside the rooms (e.g.
## "Connectors"), so they belong to neither side.
## Genre-agnostic.


@export var a_id := &"" ## Entity id of one location.
@export var a_direction := &"" ## Direction id that leads from [member a_id] to [member b_id], e.g. &"north".
@export var b_id := &"" ## Entity id of the other location.
## Direction id that leads from [member b_id] back to [member a_id], e.g.
## &"south" (any direction, not forced to be the opposite). Empty makes the
## passage one-way, from a to b only.
@export var b_direction := &""


func is_one_way() -> bool:
	return b_direction == &""
