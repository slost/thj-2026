## A block that answers true/false.
## Script nesting is indentation on ScriptLine. then_condition is only used by check().
class_name ConditionBlock
extends CodeBlock

@export var then_condition: ConditionBlock


## Outer test, then the nested if. Subclasses implement evaluate().
func check(unit: Unit2D, ctx: ExecContext) -> bool:
	if not evaluate(unit, ctx):
		return false
	if then_condition == null:
		return true
	return then_condition.check(unit, ctx)


## Override in subclasses. May write into ctx (e.g. ctx.target) for the action.
func evaluate(_unit: Unit2D, _ctx: ExecContext) -> bool:
	return false


func get_block_label() -> String:
	var label := super.get_block_label()
	if then_condition == null:
		return label
	return "%s then [%s]" % [label, then_condition.get_block_label()]


func get_mb_cost() -> int:
	var total := super.get_mb_cost()
	if then_condition:
		total += then_condition.get_mb_cost()
	return total
