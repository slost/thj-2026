## Which functions run for each event, in order.
## The node editor UI only reads/writes this data.
class_name EventGraph
extends Resource

enum Event { ON_SPAWN, ON_UPDATE, ON_HIT, ON_ALLY_DIED, ON_DEATH }

## Event (int) -> Array[UnitFunction]
@export var links: Dictionary = {}


func get_functions(event: Event) -> Array:
	var value: Variant = links.get(event, [])
	if value is Array:
		return value
	return []


func connect_function(event: Event, fn: UnitFunction) -> void:
	if fn == null:
		return
	var list := _list(event)
	if list.has(fn):
		return
	list.append(fn)


func disconnect_function(event: Event, fn: UnitFunction) -> void:
	if fn == null or not links.has(event):
		return
	var existing: Variant = links[event]
	if existing is Array:
		existing.erase(fn)


func _list(event: Event) -> Array:
	if links.has(event) and links[event] is Array:
		return links[event]
	var created: Array[UnitFunction] = []
	links[event] = created
	return created
