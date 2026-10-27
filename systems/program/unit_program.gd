## Everything one minion knows: its function library + event wiring.
class_name UnitProgram
extends Resource

@export var functions: Array[UnitFunction] = []
@export var event_graph: EventGraph = EventGraph.new()


## Total rule lines across all functions (compare with UnitData.ram).
func get_total_lines() -> int:
	var total := 0
	for fn in functions:
		if fn:
			total += fn.get_line_count()
	return total


## Deep copy so each unit can edit its own program.
func clone() -> UnitProgram:
	return duplicate(true) as UnitProgram
