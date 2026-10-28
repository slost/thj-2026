## One line in a function: [condition AND condition ...] <action>
## Empty conditions = always true ("otherwise").
class_name ProgramRule
extends Resource

@export var conditions: Array[ConditionBlock] = []
@export var action: ActionBlock


## True if every condition passes and the action can run.
func matches(unit: Unit2D, ctx: ExecContext) -> bool:
	if action == null:
		return false
	for condition in conditions:
		if condition == null or not condition.check(unit, ctx):
			return false
	return action.can_execute(unit, ctx)


func get_action_label() -> String:
	if action == null:
		return "-"
	return action.get_block_label()


func get_ram_cost() -> int:
	var total := 0
	for condition in conditions:
		if condition:
			total += condition.get_ram_cost()
	if action:
		total += action.get_ram_cost()
	return total


func get_label() -> String:
	var parts := PackedStringArray()
	if conditions.is_empty():
		parts.append("otherwise")
	else:
		for condition in conditions:
			var label := "condition" if condition == null else condition.get_block_label()
			parts.append("[%s]" % label)
	return "%s <%s>" % [" ".join(parts), get_action_label()]
