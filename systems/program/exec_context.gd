## Data passed between blocks during a single think. Created fresh each time.
class_name ExecContext
extends RefCounted

var self_unit: Unit2D
var event: EventGraph.Event
var event_source: Node   ## e.g. attacker for ON_HIT, corpse for ON_ALLY_DIED
var target: Node         ## set by conditions, used by actions


func _init(p_unit: Unit2D, p_event: EventGraph.Event, p_source: Node = null) -> void:
	self_unit = p_unit
	event = p_event
	event_source = p_source
	target = p_source
