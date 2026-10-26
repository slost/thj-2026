extends CommandDef
class_name LookCommandDef
## "look": describes the actor's location, what is in it and its exits.
## Exits come from [method FictionWorld.get_exits]; a passage that is a door
## shows its state on the exits line ("north (a locked door)"). Passages are
## never in the list of things.
## "look box" is redirected to examine by [member CommandDef.with_object_command].
## [GoCommandDef] runs this command after moving to show the new room.
## "look north" ([member CommandDef.accepts_direction]) looks into the next
## location that way (see [method _look_toward]) and says what lies beyond
## it, see [member beyond].


## What "look north" says about the way past the next location.
enum Beyond {
	SAME_DIRECTION, ## Only the next location's exit in the same direction.
	ALL_EXITS, ## Every exit of the next location except the way back.
	NONE, ## Nothing.
}

@export var beyond := Beyond.SAME_DIRECTION


func _default_messages() -> Dictionary:
	var result := super()
	result.merge({
		&"room": "{room}\n{description}", # {room}: the location's name; {description}: its description
		&"you_see": "You see: {list}.",
		&"exits": "Exits: {list}.",
		&"exit_door": "{direction} ({door_state})", # One exit with a door; {door_state} is one of the four below
		&"door_open": "an open {door}",
		&"door_closed": "a closed {door}",
		&"door_locked": "a locked {door}",
		&"door_unlocked": "an unlocked {door}", # A lock with nothing to open
		&"no_exits": "There is no obvious way out.",
		&"nowhere": "You are nowhere.",
		# "look north"
		&"nothing_that_way": "You see nothing special that way.",
		&"view_blocked": "To the {direction} there is {door_state}.", # {door_state}: one of the door_* texts
		&"view_room": "To the {direction} you see the {room}.", # Unless the room has a distant_description
		&"view_contents": "There you see: {list}.",
		&"beyond": "Beyond it {list}.", # {list}: beyond_part texts joined with "; "
		&"beyond_part": "to the {direction}, {what}", # {what}: a door_* text, another_room or known_room
		&"another_room": "another room",
		&"known_room": "the {room}", # A room the actor has visited
	}, true)
	return result


func execute(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	if m.direction != &"":
		return _look_toward(m, actor, world)
	var result: Array[FictionEvent] = []
	var here := actor.get_location() if actor else null
	if here == null:
		result.append(_event(&"nowhere", m, actor, false))
		return result
	var room_event := _event(&"room", m, actor, true, null, {
		"room": here.get_display_name(_locale_of(m)).capitalize(),
		"description": here.get_description(),
	})
	room_event.text = room_event.text.strip_edges()
	result.append(room_event)

	var seen := _things_in(here, actor)
	if not seen.is_empty():
		result.append(_event(&"you_see", m, actor, true, null, {"list": _list_names(seen, _locale_of(m))}))

	var directions: PackedStringArray = []
	var exits: Array[FictionExit] = []
	if world:
		exits = world.get_exits(here.get_id())
	var shown := {} # Direction -> true
	for exit in exits:
		if shown.has(exit.direction):
			continue # Same direction twice (warned at ready); go uses the first one
		shown[exit.direction] = true
		if exit.has_door():
			directions.append(get_message(&"exit_door", "", {
				"direction": _direction_name(exit.direction, m),
				"door_state": _door_state(exit.passage, m),
			}))
		else:
			directions.append(_direction_name(exit.direction, m))
	if directions.is_empty():
		if here.get_component(LocationComponent) and _has_any_exits(world):
			result.append(_event(&"no_exits", m, actor, true))
	else:
		result.append(_event(&"exits", m, actor, true, null, {"list": ", ".join(directions)}))
	return result


## "look <direction>": the next location that way, unless a closed passage
## (door) is in between; what is in it (unless
## [member LocationComponent.hide_contents_from_afar]); and what lies beyond
## it (unless [member LocationComponent.blocks_view]).
func _look_toward(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	var result: Array[FictionEvent] = []
	var here := actor.get_location() if actor else null
	if here == null:
		result.append(_event(&"nowhere", m, actor, false))
		return result
	var exit := world.get_exit(here.get_id(), m.direction) if world else null
	var there := world.get_entity(exit.destination_id) if exit else null
	if there == null:
		result.append(_event(&"nothing_that_way", m, actor, false))
		return result
	if exit.is_closed(): # Like nothing_that_way, not a success: AFTER reactions do not fire
		result.append(_event(&"view_blocked", m, actor, false, null, {
			"door_state": _door_state(exit.passage, m),
			"door": exit.passage.get_display_name(_locale_of(m)),
		}))
		return result

	var location := there.get_component(LocationComponent) as LocationComponent
	var values := {"room": there.get_display_name(_locale_of(m)), "direction": _direction_name(m.direction, m)}
	var distant := location.get_distant_description(values) if location else ""
	if not distant.is_empty():
		result.append(FictionEvent.new(distant, actor, true, &"distant_description", id))
	else:
		result.append(_event(&"view_room", m, actor, true, null, values))

	if not (location and location.hide_contents_from_afar):
		var seen := _things_in(there, actor)
		if not seen.is_empty():
			result.append(_event(&"view_contents", m, actor, true, null, {"list": _list_names(seen, _locale_of(m))}))

	if beyond != Beyond.NONE and not (location and location.blocks_view):
		var parts := _beyond_parts(here, there, m, world)
		if not parts.is_empty():
			result.append(_event(&"beyond", m, actor, true, null, {"list": "; ".join(parts)}))
	return result


## One beyond_part text per way on from [param there] (not back to [param here]).
func _beyond_parts(here: Entity, there: Entity, m: CommandMatch, world: FictionWorld) -> PackedStringArray:
	var direction := m.direction
	var locale := _locale_of(m)
	var parts: PackedStringArray = []
	if world == null:
		return parts
	var shown := {} # Direction -> true
	for exit in world.get_exits(there.get_id()):
		if beyond == Beyond.SAME_DIRECTION and exit.direction != direction:
			continue
		if exit.destination_id == here.get_id() or shown.has(exit.direction):
			continue
		shown[exit.direction] = true
		var what := ""
		if exit.has_door():
			what = _door_state(exit.passage, m)
		else:
			var far := world.get_entity(exit.destination_id)
			var far_location := far.get_component(LocationComponent) as LocationComponent if far else null
			if far_location and far_location.visited:
				what = get_message(&"known_room", "", {"room": far.get_display_name(locale)}, locale)
			else:
				what = get_message(&"another_room", "", {}, locale)
		parts.append(get_message(&"beyond_part", "", {"direction": _direction_name(exit.direction, m), "what": what}, locale))
	return parts


## What is listed as being in [param place]: its contents except [param actor] and passages.
static func _things_in(place: Entity, actor: Entity) -> Array[Entity]:
	var result: Array[Entity] = []
	for entity in place.get_contents():
		if entity != actor and entity.get_component(PassageComponent) == null:
			result.append(entity)
	return result


## "a locked door", "a closed door", "an open door", or "an unlocked door"
## for a lock with no [OpenableComponent].
func _door_state(door: Entity, m: CommandMatch = null) -> String:
	var key := &"door_open"
	var lockable := door.get_component(LockableComponent) as LockableComponent
	var openable := door.get_component(OpenableComponent) as OpenableComponent
	if lockable and lockable.is_locked:
		key = &"door_locked"
	elif openable and not openable.is_open:
		key = &"door_closed"
	elif openable == null:
		key = &"door_unlocked"
	return get_message(key, "", {"door": door.get_display_name(_locale_of(m))}, _locale_of(m))


## True if the world uses exits at all, so a world without any does not say
## "There is no obvious way out." in every room.
static func _has_any_exits(world: FictionWorld) -> bool:
	if world == null:
		return false
	return not world.get_passages().is_empty()
