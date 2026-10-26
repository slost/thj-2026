extends CommandDef
class_name HelpCommandDef
## help: lists the world's commands by [member CommandDef.help_category];
## "help take" shows one command. Built from [member FictionWorld.commands],
## so commands a team adds appear on their own (unless
## [member CommandDef.show_in_help] is false).
## Everything is in the output language ([method FictionWorld.get_output_locale],
## chosen in the settings): a command is shown as its id followed by its
## words in that language only ("take (get)", "take (หยิบ, เก็บ)"), then its
## help text (see [method CommandDef.get_help_text]). Words of every
## language are still understood.
## Category names are messages "category_<name in snake_case>" (e.g.
## category_movement); a category without one shows its own name.


## Categories listed first, in this order; others follow in the order
## their first command appears in [member FictionWorld.commands].
@export var category_order: PackedStringArray = ["Movement", "Objects", "Info", "Conversation", "Meta"]
## Add [method get_unknown_hint] to replies when a line is not understood
## (see [member CommandMatcher.help_command]).
@export var hint_on_unknown := true


func _default_messages() -> Dictionary:
	var result := super()
	result.merge({
		&"category": "{category}:",
		&"list_line": "  {names}: {summary}",
		&"list_line_bare": "  {names}", # A command without help text
		&"list_hint": "Type \"help <command>\" for details.",
		&"examples": "Examples:",
		&"example_line": "  {example}",
		&"unknown_command": "There is no command \"{text}\". Type \"help\" for a list of commands.",
		&"unknown_hint": "Type \"help\" for a list of commands.", # Added to replies the parser does not understand
		&"category_movement": "Movement",
		&"category_objects": "Objects",
		&"category_info": "Info",
		&"category_conversation": "Conversation",
		&"category_meta": "Meta",
		&"category_other": "Other", # Commands without a help_category
	}, true)
	return result


func execute(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	var locale := _locale_of(m)
	if m.argument_text.is_empty():
		return _events([FictionEvent.new(get_list_text(world.commands if world else [] as Array[CommandDef], locale), actor, true, &"list", id)])
	var command := world.get_command(m.argument_command) if world and m.argument_command != &"" else null
	if command == null or not command.show_in_help:
		var text := get_message(&"unknown_command", "", {"text": m.argument_text}, locale)
		return _events([FictionEvent.new(text, actor, false, &"unknown_command", id)])
	return _events([FictionEvent.new(get_details_text(command, locale), actor, true, &"details", id)])


## The command list, grouped by category, then the hint.
func get_list_text(commands: Array[CommandDef], locale: String) -> String:
	var groups := {} # Category -> Array[CommandDef]
	var order: Array[String] = []
	for category in category_order:
		order.append(category)
	for command in commands:
		if command == null or not command.show_in_help:
			continue
		var category := command.help_category
		if not groups.has(category):
			groups[category] = []
			if not order.has(category):
				order.append(category)
		groups[category].append(command)

	var lines: PackedStringArray = []
	for category in order:
		if not groups.has(category):
			continue
		lines.append(get_message(&"category", "", {"category": get_category_name(category, locale)}, locale))
		for command: CommandDef in groups[category]:
			var summary := command.get_help_summary(locale)
			var values := {"names": get_names(command, locale), "summary": summary}
			lines.append(get_message(&"list_line" if not summary.is_empty() else &"list_line_bare", "", values, locale))
	lines.append(get_message(&"list_hint", "", {}, locale))
	return "\n".join(lines)


## One command: names, help text and examples.
func get_details_text(command: CommandDef, locale: String) -> String:
	var lines: PackedStringArray = [get_names(command, locale)]
	var text := command.get_help_text(locale).strip_edges()
	if not text.is_empty():
		lines.append(text)
	var examples := command.get_help_examples(locale)
	if not examples.is_empty():
		lines.append(get_message(&"examples", "", {}, locale))
		for example in examples:
			lines.append(get_message(&"example_line", "", {"example": example}, locale))
	return "\n".join(lines)


## The display name of [param category] in [param locale]: the message
## "category_<snake_case>", or the category itself.
func get_category_name(category: String, locale: String) -> String:
	var key := StringName("category_" + (category.to_snake_case() if not category.is_empty() else "other"))
	return get_message(key, category, {}, locale)


## "take (get)" in English, "take (หยิบ, เก็บ)" in Thai: the id, then the
## command's words in [param locale] that are not the id
## ([method CommandDef.get_display_aliases]).
static func get_names(command: CommandDef, locale := "") -> String:
	var others: PackedStringArray = []
	for alias in command.get_display_aliases(locale):
		if alias != String(command.id) and not others.has(alias):
			others.append(alias)
	return String(command.id) if others.is_empty() else "%s (%s)" % [command.id, ", ".join(others)]


## The hint added to replies that were not understood, in [param locale],
## or "" when [member hint_on_unknown] is off.
func get_unknown_hint(locale: String) -> String:
	return get_message(&"unknown_hint", "", {}, locale) if hint_on_unknown else ""
