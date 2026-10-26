extends CommandDef
class_name InventoryCommandDef
## "inventory", "i": lists what the actor carries.


func _default_messages() -> Dictionary:
	var result := super()
	result.merge({
		&"carrying": "You are carrying: {list}.",
		&"empty_handed": "You are empty-handed.",
	}, true)
	return result


func execute(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	var result: Array[FictionEvent] = []
	result.append(carried_event(self, m, actor))
	return result


## "You are carrying: ..." or "You are empty-handed." with the messages of
## [param command] (keys &"carrying" and &"empty_handed").
static func carried_event(command: CommandDef, m: CommandMatch, actor: Entity) -> FictionEvent:
	var carried: Array[Entity] = []
	if actor:
		carried = actor.get_contents()
	if carried.is_empty():
		return command._event(&"empty_handed", m, actor, true)
	return command._event(&"carrying", m, actor, true, null, {"list": _list_names(carried, _locale_of(m))})
