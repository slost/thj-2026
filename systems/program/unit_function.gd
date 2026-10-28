## A named list of rules, evaluated top to bottom.
class_name UnitFunction
extends Resource

@export var function_name: String = "New Function"
@export var rules: Array[ProgramRule] = []

## Set by run() when a rule acts. Read by ProgramRunner for rule_executed.
var last_executed_rule: ProgramRule = null


## Runs the first matching rule. Returns true if an action was executed.
func run(unit: Unit2D, ctx: ExecContext) -> bool:
	last_executed_rule = null
	for rule in rules:
		if rule == null or not rule.matches(unit, ctx):
			continue
		last_executed_rule = rule
		rule.action.execute(unit, ctx)
		return true
	return false


## Used by the editor to enforce the unit's RAM limit.
func get_line_count() -> int:
	return rules.size()
