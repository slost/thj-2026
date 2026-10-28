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


func get_label() -> String:
	var parts := PackedStringArray()
	if conditions.is_empty():
		parts.append("otherwise")
	else:
		for condition in conditions:
			var label := "condition" if condition == null or condition.name.is_empty() else condition.name
			parts.append("[%s]" % label)
	var action_label := "action" if action == null or action.name.is_empty() else action.name
	return "%s <%s>" % [" ".join(parts), action_label]
