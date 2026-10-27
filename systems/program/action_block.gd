## A block that does one thing. Executing an action ends the current think.
## Actions only call the Unit2D API; animations/timing live in Unit2D.
extends CodeBlock
class_name ActionBlock


## Return false to make the runner skip this rule (e.g. no target).
func can_execute(_unit: Unit2D, _ctx: ExecContext) -> bool:
	return true


## Override in subclasses.
func execute(_unit: Unit2D, _ctx: ExecContext) -> void:
	pass
