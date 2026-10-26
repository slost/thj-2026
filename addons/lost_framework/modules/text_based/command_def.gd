extends DataDef
class_name CommandDef
## One command the player can type (take, put, go...): the words for it and
## what it needs. [member DataDef.id] is the command id (e.g. &"take") and is
## also the VERB id in the [Vocabulary]; [member DataDef.name] is the verb
## used in questions ("What do you want to take?").
## [CommandMatcher] uses these fields to fill a [CommandMatch];
## [method execute] runs it (see [method FictionWorld.run]). Each base verb
## is a subclass (e.g. [TakeCommandDef]) that overrides [method execute].
## Commands are shared resources: [method execute] must keep no state of
## its own between runs.

## Whether the command needs an object or a target.
enum Requirement {
	NONE, ## Never takes one (e.g. inventory).
	OPTIONAL, ## May take one (e.g. look, look box).
	REQUIRED, ## Must take one; the player is asked when it is missing (e.g. take).
}

## Which entities an object or target may be.
enum Scope {
	VISIBLE, ## Anything the actor can refer to, the actor included (e.g. examine).
	NOT_CARRIED, ## In reach but not held by the actor, and not the actor (e.g. take).
	CARRIED, ## Held by the actor (directly or inside something it holds), not the actor (e.g. drop).
}

## Paths of the commands shipped with the module, see [method load_base_commands].
const BASE_COMMAND_PATHS: Array[String] = [
	"res://addons/lost_framework/modules/text_based/commands/take.tres",
	"res://addons/lost_framework/modules/text_based/commands/drop.tres",
	"res://addons/lost_framework/modules/text_based/commands/open.tres",
	"res://addons/lost_framework/modules/text_based/commands/close.tres",
	"res://addons/lost_framework/modules/text_based/commands/put.tres",
	"res://addons/lost_framework/modules/text_based/commands/look.tres",
	"res://addons/lost_framework/modules/text_based/commands/examine.tres",
	"res://addons/lost_framework/modules/text_based/commands/go.tres",
	"res://addons/lost_framework/modules/text_based/commands/inventory.tres",
	"res://addons/lost_framework/modules/text_based/commands/unlock.tres",
	"res://addons/lost_framework/modules/text_based/commands/lock.tres",
	"res://addons/lost_framework/modules/text_based/commands/help.tres",
	"res://addons/lost_framework/modules/text_based/commands/ask.tres",
	"res://addons/lost_framework/modules/text_based/commands/tell.tres",
	"res://addons/lost_framework/modules/text_based/commands/talk.tres",
	"res://addons/lost_framework/modules/text_based/commands/save.tres",
	"res://addons/lost_framework/modules/text_based/commands/undo.tres",
]

## Words players type for it in the source language ([constant LocaleText.SOURCE_LOCALE]),
## e.g. "take", "get". Other languages' words go in [member localizations].
@export var aliases: PackedStringArray = []

@export_group("Object")
@export var object_requirement := Requirement.NONE ## The thing acted on: "take [b]sword[/b]".
@export var object_scope := Scope.VISIBLE ## Which entities the object may be.
## When the player names an object, run this command instead, e.g. look
## has &"examine" so "look box" means "examine box". Empty means no redirect.
@export var with_object_command := &""

@export_group("Target")
@export var target_requirement := Requirement.NONE ## The thing after the preposition: "put sword in [b]box[/b]".
@export var target_scope := Scope.VISIBLE ## Which entities the target may be.
## Preposition ids allowed before the target, e.g. ["in"] for put (the
## vocabulary maps "into", "ลงใน" to the id "in"). The first one is used in
## the question when the target is missing. Empty allows any preposition.
@export var prepositions: PackedStringArray = []

@export_group("Direction")
@export var needs_direction := false ## True for go: "go north", or the player is asked "Which way?".
@export var accepts_direction := false ## True for look: "look north" keeps the direction, "look" is fine too.

@export_group("Questions")
## These are in the source language; other languages use the
## [member localizations] messages "question_object", "question_target" and
## "question_direction". Empty uses the world's [FictionTexts]
## (object_question, target_question, direction_question).
## Asked when a REQUIRED object is missing. Placeholders: {verb}.
@export var object_question := ""
## Asked when a REQUIRED target is missing. Placeholders: {verb}, {object}
## (e.g. "the old sword"), {preposition}.
@export var target_question := ""
## Asked when [member needs_direction] and no direction was typed.
@export var direction_question := ""

@export_group("Help")
## What the command does, for help in the source language (English for the
## base commands). The first line is the summary shown in the command list.
## Other languages: [member localizations] or a translation file
## ("command.<id>.help"), see [method get_help_text].
@export_multiline var help_text := ""
@export var help_examples: Array[String] = [] ## What a player can type, e.g. "take sword".
## Group in the help list, e.g. "Movement", "Objects", "Info". Teams may
## use their own names. Empty is "Other". The help command shows a
## translation of the name (see [HelpCommandDef]).
@export var help_category := ""
@export var show_in_help := true ## False keeps it out of the help list (e.g. debug commands).

@export_group("Meta")
## A command about the game itself (help), not an action in the world:
## [method FictionWorld.run] skips reactions and does not count it in
## [member FictionWorld.action_count].
@export var is_meta := false
## The word after the verb may be another command ("help take"): the
## matcher puts it in [member CommandMatch.argument_command] and
## [member CommandMatch.argument_text] instead of reading objects, and
## words it does not know are not an error.
@export var accepts_command := false
## Words that are not an object are a subject ("ask guard about the moth").
## Unknown words are kept as [member CommandMatch.topic] instead of failing.
@export var accepts_topic := false

@export_group("Languages")
## Help and message texts in other languages, edited in the Inspector. See
## [CommandLocalization]; a translation file can be used instead.
@export var localizations: Array[CommandLocalization] = []

@export_group("Messages")
## Texts that replace the defaults of this command, by key (e.g. &"taken").
## The keys a command uses and their default text are in [method _default_messages].
@export var messages: Array[CommandMessage] = []:
	set(value):
		messages = value
		_message_cache_size = -1

var _message_cache := {} ## StringName key -> CommandMessage, built from [member messages].
var _message_cache_size := -1 ## [member messages] size when the cache was built; -1 = rebuild.


func _domain_id() -> StringName:
	return &"command"


## The verb used in messages in [param locale] (empty: the output
## language): see [method get_display_name]; the id when there is no name.
func get_verb_text(locale := "") -> String:
	var text := get_display_name(locale)
	return text if not text.is_empty() else String(id)


## The verb in [param locale] (empty: the output language): a translation
## "command.<id>.name", then the [member localizations] entry's name, then
## [member DataDef.name].
func get_display_name(locale := "") -> String:
	if locale.is_empty():
		locale = LocaleText.get_locale()
	var key := "%s.%s.name" % [_domain_id(), id]
	var text := LocaleText.translate(key, locale)
	if text.is_empty():
		var localization := get_localization(locale)
		text = localization.name if localization else ""
	if text.is_empty():
		text = LocaleText.source_text(key, name, locale)
	return text


## The words for the command in [param locale] only (empty: the output
## language), for help: [member aliases] for the source language, else the
## [member localizations] entry's aliases, plus a translation
## "command.<id>.aliases" (comma-separated) in that locale.
func get_display_aliases(locale := "") -> PackedStringArray:
	if locale.is_empty():
		locale = LocaleText.get_locale()
	var result: PackedStringArray = []
	if LocaleText.is_source(locale):
		result.append_array(aliases)
	var localization := get_localization(locale)
	if localization:
		result.append_array(localization.aliases)
	for word in LocaleText.split_words(LocaleText.translate("%s.%s.aliases" % [_domain_id(), id], locale)):
		if not result.has(word):
			result.append(word)
	return result


## Every word players may type for the command, in every language: the id,
## [member aliases], every [member localizations] entry's aliases and the
## translations "command.<id>.aliases" of every loaded locale.
func get_all_aliases() -> PackedStringArray:
	var result: PackedStringArray = []
	var words: Array = [String(id)] + Array(aliases)
	for localization in localizations:
		if localization:
			words.append_array(Array(localization.aliases))
	for text in LocaleText.translate_all("%s.%s.aliases" % [_domain_id(), id]):
		words.append_array(Array(LocaleText.split_words(text)))
	for word in words:
		if not word.is_empty() and not result.has(word):
			result.append(word)
	return result


## Asked when a REQUIRED object is missing, in [param locale]. Without a
## question of this command in that language, [param texts]' generic one
## (default: [method FictionTexts.get_default]).
func get_object_question(locale := "", texts: FictionTexts = null) -> String:
	return _question(&"object", object_question, &"object_question", locale, texts).format({"verb": get_verb_text(locale)})


## Asked when a REQUIRED target is missing. [param object_text] names the
## object(s) (e.g. "the old sword", see [method FictionTexts.get_object_text]);
## [param preposition_text] is the preposition as shown (e.g. "in").
func get_target_question(object_text: String, preposition_text: String, locale := "", texts: FictionTexts = null) -> String:
	var text := _question(&"target", target_question, &"target_question", locale, texts)
	return text.format({"verb": get_verb_text(locale), "object": object_text, "preposition": preposition_text}).replace("  ", " ").replace(" ?", "?")


func get_direction_question(locale := "", texts: FictionTexts = null) -> String:
	return _question(&"direction", direction_question, &"direction_question", locale, texts)


## This command's question [param kind] in [param locale]: a translation
## "command.<id>.question.<kind>", the [member localizations] message
## "question_<kind>", or [param own] (source language only); else the
## generic [param texts_key] of [param texts].
func _question(kind: StringName, own: String, texts_key: StringName, locale: String, texts: FictionTexts) -> String:
	if locale.is_empty():
		locale = LocaleText.get_locale()
	var text := LocaleText.translate("%s.%s.question.%s" % [_domain_id(), id, kind], locale)
	if text.is_empty():
		var localization := get_localization(locale)
		text = localization.get_message_text(StringName("question_%s" % kind)) if localization else ""
	if text.is_empty() and LocaleText.is_source(locale):
		text = own
	if text.is_empty():
		text = (texts if texts else FictionTexts.get_default()).get_text(texts_key, {}, locale)
	return text


## True if [param preposition_id] may come before the target.
func allows_preposition(preposition_id: StringName) -> bool:
	return prepositions.is_empty() or prepositions.has(String(preposition_id))


## Adds this command's aliases to [param vocabulary] as VERB words with id = [member DataDef.id].
func add_to_vocabulary(vocabulary: Vocabulary) -> void:
	if id == &"":
		push_warning("CommandDef without id: %s" % resource_path)
		return
	vocabulary.add_words(Array(get_all_aliases()), ParseToken.Type.VERB, id)


## Adds the aliases of every command in [param commands], see [method add_to_vocabulary].
static func add_all_to_vocabulary(vocabulary: Vocabulary, commands: Array[CommandDef]) -> void:
	for command in commands:
		if command:
			command.add_to_vocabulary(vocabulary)


## Loads the commands shipped with the module (take, drop, open, close, put,
## look, examine, go, inventory, unlock, lock, help, ask, tell, talk, save, undo).
## Each call returns the shared resources.
static func load_base_commands() -> Array[CommandDef]:
	var result: Array[CommandDef] = []
	for path in BASE_COMMAND_PATHS:
		var command := load(path) as CommandDef
		if command:
			result.append(command)
		else:
			push_error("CommandDef: cannot load base command '%s'" % path)
	return result


#region Languages
## The help text in [param locale] (empty: the output language): a
## translation "command.<id>.help", then the [member localizations] entry,
## then [member help_text] (with a warning outside the source language).
func get_help_text(locale := "") -> String:
	if locale.is_empty():
		locale = LocaleText.get_locale()
	var key := "%s.%s.help" % [_domain_id(), id]
	var text := LocaleText.translate(key, locale)
	if text.is_empty():
		var localization := get_localization(locale)
		text = localization.help_text if localization else ""
	if text.is_empty():
		text = LocaleText.source_text(key, help_text, locale)
	return text


## The first line of [method get_help_text].
func get_help_summary(locale := "") -> String:
	return get_help_text(locale).strip_edges().get_slice("\n", 0).strip_edges()


## The examples in [param locale]: a translation "command.<id>.help_examples"
## (one per line), then the [member localizations] entry, then the
## [constant LocaleText.SOURCE_LOCALE] translation, then [member help_examples].
func get_help_examples(locale := "") -> Array[String]:
	if locale.is_empty():
		locale = LocaleText.get_locale()
	var key := "%s.%s.help_examples" % [_domain_id(), id]
	var text := LocaleText.translate(key, locale)
	if not text.is_empty():
		return _lines(text)
	var localization := get_localization(locale)
	if localization and not localization.help_examples.is_empty():
		return localization.help_examples
	return _lines(LocaleText.source_text(key, "\n".join(help_examples), locale))


## The non-empty lines of [param text], trimmed.
static func _lines(text: String) -> Array[String]:
	var result: Array[String] = []
	for line in text.split("\n"):
		if not line.strip_edges().is_empty():
			result.append(line.strip_edges())
	return result


## The [member localizations] entry for the language of [param locale]
## (empty: the output language), or null.
func get_localization(locale := "") -> CommandLocalization:
	return TextLocalization.find(localizations, locale) as CommandLocalization

#endregion


#region Execution
## Runs the command for [param actor] on a READY [param m] and returns what
## happened. Override in subclasses; this one only says "You can't do that.".
## Use [method FictionWorld.run] instead of calling it directly.
func execute(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	return _events([_event(&"cant_do", m, actor, false)])


## Every message key this command uses, with its default English text.
## Subclasses merge their keys into [code]super()[/code]. An editor
## validator can use it to list the keys [member messages] may override.
func _default_messages() -> Dictionary:
	return {&"cant_do": "You can't do that."}


## Sentences other people in the room see, keyed as "<key>_seen"
## ("{actor} takes the {object}."). Not listed in [member messages]; the
## English text lives here and other languages in [member localizations].
func _seen_messages() -> Dictionary:
	return {}


## The text for [param key] in [param locale] (empty: the output
## language), with placeholders filled from [param values]. Lookup: a
## translation "command.<id>.message.<key>", then the [member localizations]
## entry, then the source-language text (the [CommandMessage] with that key
## in [member messages], then [param default_text], then
## [method _default_messages]), see [method TextLocalization.resolve_message].
func get_message(key: StringName, default_text := "", values := {}, locale := "") -> String:
	var source := default_text
	var override := _find_message(key)
	if override and not override.text.is_empty():
		source = override.text
	if source.is_empty():
		source = _default_messages().get(key, "")
	if source.is_empty():
		source = _seen_messages().get(key, "")
	var translation_key := "%s.%s.message.%s" % [_domain_id(), id, key]
	return TextLocalization.resolve_message(translation_key, key, locale, localizations, source).format(values)


## Call after changing a [CommandMessage] key in [member messages] in place
## (adding, removing or replacing messages is noticed on its own).
func invalidate_messages() -> void:
	_message_cache_size = -1


func _find_message(key: StringName) -> CommandMessage:
	var message: CommandMessage = _message_cache.get(key) if _message_cache_size == messages.size() else null
	if message and message.key == key:
		return message
	if _message_cache_size == messages.size() and message == null:
		return null
	_message_cache.clear()
	for candidate in messages:
		if candidate and not _message_cache.has(candidate.key):
			_message_cache[candidate.key] = candidate
	_message_cache_size = messages.size()
	return _message_cache.get(key)


## Placeholder values for messages, in the language of [param m]:
## {actor}, {object}, {target}, {direction} and {verb}. [param object] is
## the object this message is about (defaults to the first object of [param m]).
func _message_values(m: CommandMatch, actor: Entity, object: Entity = null) -> Dictionary:
	var locale := _locale_of(m)
	if object == null and m and not m.objects.is_empty():
		object = m.objects[0]
	return {
		"actor": actor.get_display_name(locale) if actor else "",
		"object": object.get_display_name(locale) if object else "",
		"target": m.target.get_display_name(locale) if m and m.target else "",
		"direction": _direction_name(m.direction, m) if m else "",
		"verb": get_verb_text(locale),
	}


## The language texts for [param m] are shown in: [member CommandMatch.locale],
## or the output language.
static func _locale_of(m: CommandMatch) -> String:
	return m.locale if m and not m.locale.is_empty() else LocaleText.get_locale()


## The parser texts for [param m] (its world's), or the module's.
static func _texts_of(m: CommandMatch) -> FictionTexts:
	return m.texts if m and m.texts else FictionTexts.get_default()


## [param direction] as shown in the language of [param m], e.g. "เหนือ".
static func _direction_name(direction: StringName, m: CommandMatch) -> String:
	return _texts_of(m).get_direction_name(direction, _locale_of(m))


## Placeholder values for [param event] in [param locale], with names looked up again.
func rebuild_values(event: FictionEvent, locale: String) -> Dictionary:
	var rebuilt: Dictionary = event.values.duplicate()
	if event.actor:
		rebuilt["actor"] = event.actor.get_display_name(locale)
	if event.object:
		rebuilt["object"] = event.object.get_display_name(locale)
	if event.target:
		rebuilt["target"] = event.target.get_display_name(locale)
	rebuilt["verb"] = get_verb_text(locale)
	if event.direction_id != &"" and event.texts:
		rebuilt["direction"] = event.texts.get_direction_name(event.direction_id, locale)
	return rebuilt


## An event with the text of message [param key]. [param extra] adds or
## overrides placeholder values (e.g. {"door": "door"}). A success that has a
## "<key>_seen" sentence is heard in the actor's room as well.
func _event(key: StringName, m: CommandMatch, actor: Entity, success := true, object: Entity = null, extra := {}) -> FictionEvent:
	var values := _message_values(m, actor, object)
	values.merge(extra, true)
	var locale := _locale_of(m)
	var event := FictionEvent.new(get_message(key, "", values, locale), actor, success, key, id)
	event.object = object
	event.target = m.target if m else null
	event.values = values
	event.locale = locale
	event.direction_id = m.direction if m else &""
	event.texts = _texts_of(m)
	var seen := StringName("%s_seen" % key)
	if _seen_messages().has(seen):
		event.seen_key = seen
		if success:
			event.visibility = FictionEvent.Visibility.ROOM
			var here := actor.get_location() if actor else null
			event.location_id = here.get_id() if here else &""
	return event


## Runs [method _execute_object] for each object of [param m]. With several
## objects, each text starts with the object's name ("box: Taken.").
func _execute_each_object(m: CommandMatch, actor: Entity, world: FictionWorld) -> Array[FictionEvent]:
	var result: Array[FictionEvent] = []
	for object in m.objects:
		var event := _execute_object(object, m, actor, world)
		if event == null:
			continue
		if m.objects.size() > 1:
			event.group_name = true
			event.text = "%s: %s" % [object.get_display_name(_locale_of(m)), event.text]
		result.append(event)
	return result


## Override for commands that act on each object on its own (take, drop, open...).
func _execute_object(object: Entity, m: CommandMatch, actor: Entity, world: FictionWorld) -> FictionEvent:
	return _event(&"cant_do", m, actor, false, object)


## Display names (in [param locale], empty: the output language) joined with ", ".
static func _list_names(entities: Array[Entity], locale := "") -> String:
	var names: PackedStringArray = []
	for entity in entities:
		names.append(entity.get_display_name(locale))
	return ", ".join(names)


static func _events(list: Array) -> Array[FictionEvent]:
	var result: Array[FictionEvent] = []
	for event in list:
		if event:
			result.append(event)
	return result

#endregion
