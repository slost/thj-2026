## A block that answers true/false.
class_name ConditionBlock
extends CodeBlock


## Override in subclasses. May write into ctx (e.g. ctx.target) for the action.
func check(_unit: Unit2D, _ctx: ExecContext) -> bool:
	return false
