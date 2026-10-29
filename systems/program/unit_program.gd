## Everything one minion knows: its function library + event wiring.
class_name UnitProgram
extends Resource

@export var functions: Array[UnitFunction] = []
@export var event_graph: EventGraph = EventGraph.new()


## Total MB spent by every block in the program.
func get_mb_cost() -> int:
	var total := 0
	for fn in functions:
		if fn:
			total += fn.get_mb_cost()
	return total


## Deep copy so each unit can edit its own program.
func clone() -> UnitProgram:
	return duplicate(true) as UnitProgram
