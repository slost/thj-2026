class_name FictionExit
extends RefCounted
## One way out of a location, as seen from that location: a direction, where
## it leads and the passage it goes through. Made on demand by
## [method FictionWorld.get_exits] from the [PassageComponent]s of the world;
## keep it only as long as you need it.


var direction := &"" ## Direction id, e.g. &"north".
var destination_id := &"" ## Entity id of the location it leads to.
var passage: Entity ## The passage entity (with a [PassageComponent]).


func _init(p_direction := &"", p_destination_id := &"", p_passage: Entity = null) -> void:
	direction = p_direction
	destination_id = p_destination_id
	passage = p_passage


## True if the passage can be opened and closed (a door), see [method is_closed].
func has_door() -> bool:
	return passage != null and (passage.get_component(OpenableComponent) != null or passage.get_component(LockableComponent) != null)


## True if the passage blocks the way: a closed [OpenableComponent], or a
## locked [LockableComponent] on a passage that cannot be opened.
func is_closed() -> bool:
	if passage == null:
		return false
	var openable := passage.get_component(OpenableComponent) as OpenableComponent
	if openable:
		return not openable.is_open
	return is_locked()


func is_locked() -> bool:
	var lockable := passage.get_component(LockableComponent) as LockableComponent if passage else null
	return lockable != null and lockable.is_locked


func _to_string() -> String:
	return "%s -> %s" % [direction, destination_id]
