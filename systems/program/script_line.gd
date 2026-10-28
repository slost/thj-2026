## One line of a unit script. indent is how deep this line sits inside conditions above it.
class_name ScriptLine
extends Resource

@export var indent: int = 0
@export var block: CodeBlock


func get_label() -> String:
	if block == null:
		return "..."
	var text := block.get_block_label()
	if block is ConditionBlock:
		return "[%s]" % text
	return "<%s>" % text
