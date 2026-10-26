class_name FictionTexts
extends Resource
## Texts of the parser and matcher that do not belong to one command: why a
## line was not understood, the questions, how objects, directions and
## prepositions are named in them. Set on [member FictionWorld.texts]; the
## module ships [constant DEFAULT_PATH] (English, with Thai). Lookup is the
## same as for command messages: a translation "fiction.message.<key>", then
## the [member localizations] entry, then [member messages], then the
## default (see [method TextLocalization.resolve_message]).
## Directions and prepositions are messages "direction_<id>" and
## "preposition_<id>"; one without a message shows its id.


const DEFAULT_PATH := "res://addons/lost_framework/modules/text_based/fiction_texts.tres"

## Replace the default texts (source language), by key.
@export var messages: Array[CommandMessage] = []
## The texts in other languages.
@export var localizations: Array[TextLocalization] = []

static var _default: FictionTexts


## The texts shipped with the module.
static func get_default() -> FictionTexts:
	if _default == null:
		_default = load(DEFAULT_PATH) as FictionTexts
		if _default == null:
			push_error("FictionTexts: cannot load '%s'" % DEFAULT_PATH)
			_default = FictionTexts.new()
	return _default


## Every key with its default (English) text.
func _default_messages() -> Dictionary:
	return {
		# Why a line was not understood ({text}: the words concerned, {verb})
		&"unknown_words": "I don't understand \"{text}\".",
		&"no_verb": "I don't know what you want to do with \"{text}\".",
		&"unknown_verb": "I don't know how to \"{text}\".",
		&"not_here": "You don't see \"{text}\" here.",
		&"not_found": "Nothing here matches \"{text}\".",
		&"self": "You can't {verb} yourself.",
		&"no_object_expected": "I only understood you as far as wanting to {verb}.",
		&"no_target_expected": "I only understood you as far as wanting to {verb}.",
		&"wrong_preposition": "You can't {verb} something \"{text}\" that.",
		&"no_pronoun": "You have not mentioned that yet.",
		# Questions
		&"which": "Which \"{text}\" do you mean? {choices}",
		&"choice": "{number}) {name}",
		&"choice_separator": "  ",
		&"object_question": "What do you want to {verb}?",
		&"target_question": "What do you want to {verb} {object} {preposition}?",
		&"direction_question": "Which way?",
		# Naming objects in questions: "the old sword", "it", "the box and the key"
		&"object_name": "the {name}",
		&"object_it": "it",
		&"object_and": " and ",
		# Directions and prepositions as shown in texts
		&"direction_north": "north",
		&"direction_northeast": "northeast",
		&"direction_east": "east",
		&"direction_southeast": "southeast",
		&"direction_south": "south",
		&"direction_southwest": "southwest",
		&"direction_west": "west",
		&"direction_northwest": "northwest",
		&"direction_up": "up",
		&"direction_down": "down",
		&"direction_in": "in",
		&"direction_out": "out",
		&"preposition_in": "in",
		&"preposition_with": "with",
		&"preposition_on": "on",
	}


## The text of [param key] in [param locale] (empty: the output language),
## with placeholders filled from [param values]. [param default_text] is
## used for a key without a default.
func get_text(key: StringName, values := {}, locale := "", default_text := "") -> String:
	var source := default_text
	for message in messages:
		if message and message.key == key and not message.text.is_empty():
			source = message.text
			break
	if source.is_empty():
		source = _default_messages().get(key, "")
	var text := TextLocalization.resolve_message("fiction.message.%s" % key, key, locale, localizations, source)
	return text.format(values)


## How [param direction] is named, e.g. "north" or "เหนือ".
func get_direction_name(direction: StringName, locale := "") -> String:
	if direction == &"":
		return ""
	return get_text(StringName("direction_%s" % direction), {}, locale, String(direction))


## How the preposition [param preposition] is named, e.g. "in" or "ลงใน".
func get_preposition_name(preposition: StringName, locale := "") -> String:
	if preposition == &"":
		return ""
	return get_text(StringName("preposition_%s" % preposition), {}, locale, String(preposition))


## How [param entities] are named in a question: "the old sword", "it"
## (none), "the box and the key".
func get_object_text(entities: Array[Entity], locale := "") -> String:
	if entities.is_empty():
		return get_text(&"object_it", {}, locale)
	var names: PackedStringArray = []
	for entity in entities:
		names.append(get_text(&"object_name", {"name": entity.get_display_name(locale)}, locale))
	return get_text(&"object_and", {}, locale).join(names)
