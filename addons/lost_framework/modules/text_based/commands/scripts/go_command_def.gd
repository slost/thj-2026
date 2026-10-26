extends CommandDef
class_name GoCommandDef
## "go north", "north": moves the actor through the passage that leaves its
## location in that direction ([method FictionWorld.get_exit]), unless the
## passage is closed (a closed door). Then marks the
## new location visited and runs the world's "look" command to describe it.


func _default_messages() -> Dictionary:
	var result := super()
	result.merge({
		&"no_exit": "You can't go that way.",
		&"door_closed": "The {door} is closed.",
		&"door_locked": "The {door} is locked.",
		&"leaves": "{actor} leaves {direction}.",
		&"arrives": "{actor} arrives.",
	}, true)
	return result


func execute(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	var result: Array[FictionEvent] = []
	var here := actor.get_location() if actor else null
	var exit := world.get_exit(here.get_id(), m.direction) if here and world else null
	var destination := world.get_entity(exit.destination_id) if exit else null
	if destination == null:
		if exit:
			push_warning("GoCommandDef: passage '%s' leads from '%s' to unknown entity '%s'" % [exit.passage.get_id(), here.get_id(), exit.destination_id])
		result.append(_event(&"no_exit", m, actor, false))
		return result

	if exit.is_closed():
		var key := &"door_locked" if exit.is_locked() else &"door_closed"
		result.append(_event(key, m, actor, false, null, {"door": exit.passage.get_display_name(_locale_of(m))}))
		return result

	var left := _movement_event(&"leaves", m, actor, here)
	var arrived := _movement_event(&"arrives", m, actor, destination)
	actor.reparent(destination)
	result.append(left)
	result.append(arrived)
	result.append_array(_describe_location(m, actor, world))
	destination.set_value(&"visited", true)
	return result


## A room announcement the actor does not hear. [param room] is who hears it.
func _movement_event(key: StringName, m: CommandMatch, actor: Entity, room: Entity) -> FictionEvent:
	var event := _event(key, m, actor, true)
	event.visibility = FictionEvent.Visibility.ROOM
	event.include_actor = false
	event.location_id = room.get_id() if room else &""
	return event


## The output of the world's "look" command, or just the location's name.
func _describe_location(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	var look := world.get_command(&"look") if world else null
	if look and look != self:
		var look_match := CommandMatch.new()
		look_match.status = CommandMatch.Status.READY
		look_match.command = m.command
		look_match.def = look
		look_match.locale = m.locale
		look_match.texts = m.texts
		return look.execute(look_match, actor, world)
	var result: Array[FictionEvent] = []
	var here := actor.get_location()
	if here:
		result.append(FictionEvent.new(here.get_display_name(_locale_of(m)), actor, true, &"room", id))
	return result
