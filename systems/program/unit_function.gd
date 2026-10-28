## A named script: lines read from top to bottom.
class_name UnitFunction
extends Resource

@export var function_name: String = "New Function"
@export var lines: Array[ScriptLine] = []


## Sum of every block's RAM cost. Nested then_condition costs are included by the block.
func get_ram_cost() -> int:
	var total := 0
	for line in lines:
		if line and line.block:
			total += line.block.get_ram_cost()
	return total
