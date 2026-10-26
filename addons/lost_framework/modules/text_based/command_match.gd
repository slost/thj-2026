class_name CommandMatch
extends RefCounted
## What [CommandMatcher] made of one [ParsedCommand]: a command ready to run
## (READY), a question for the player (ASK), or why it cannot be understood
## (FAILED). An ASK match keeps what is filled so far; the answer fills the
## missing slot (see [method CommandMatcher.answer] and [CommandSession]).

enum Status {
	READY, ## [member def] with its objects, target and direction filled in.
	ASK, ## Something is missing or unclear; show [member question].
	FAILED, ## Cannot be understood; see [member failure] and [member message].
}

## What an ASK match is waiting for.
enum Ask {
	NONE,
	OBJECT, ## "What do you want to take?"
	TARGET, ## "What do you want to put the old sword in?"
	DIRECTION, ## "Which way?"
	WHICH_OBJECT, ## Several entities fit an object; see [member candidates].
	WHICH_TARGET, ## Several entities fit the target; see [member candidates].
}

## Why a match FAILED. [member failed_text] holds the words concerned.
enum Failure {
	NONE,
	UNKNOWN_WORDS, ## Words the vocabulary does not know: I don't understand "x".
	NO_VERB, ## No verb and no direction, e.g. just "sword".
	UNKNOWN_VERB, ## A VERB word with no [CommandDef] in the world.
	NOT_HERE, ## Something in the world fits, but not within reach.
	NOT_FOUND, ## Nothing in the world fits.
	SELF, ## Only the actor fits, and the command may not act on it ("take me").
	NO_OBJECT_EXPECTED, ## An object for a command that takes none ("inventory sword").
	NO_TARGET_EXPECTED, ## A target for a command that takes none.
	WRONG_PREPOSITION, ## A preposition the command does not allow ("put sword on box").
	NO_PRONOUN, ## "it" or "them" when nothing has been mentioned yet.
}

var status := Status.FAILED
var command: ParsedCommand ## The parsed input this match came from.
var def: CommandDef ## The command (after redirects such as look -> examine). Null when FAILED early.
var objects: Array[Entity] = [] ## Resolved objects, in typed order.
var target: Entity ## Resolved target, or null.
var preposition := &"" ## Preposition id before the target, e.g. &"in".
var direction := &"" ## Direction id, e.g. &"north".
## Objects or target that do not fit the command's scope but were kept
## because nothing else fits (e.g. "take sword" while holding the only
## sword). The command decides what to say ("You already have that.").
var out_of_scope: Array[Entity] = []
## What happened when it ran, if [CommandSession] ran it (see
## [member CommandSession.run_ready]). Empty otherwise.
var events: Array[FictionEvent] = []

## For a command with [member CommandDef.accepts_command] ("help take"):
## the id of the command named after the verb, or &"" if none was.
var argument_command := &""
## For a command with [member CommandDef.accepts_command]: the words after
## the verb as typed ("take", "xyzzy"), or "" when there were none.
var argument_text := ""
## The subject of ask, tell or talk ("the moth"). Empty is a greeting.
var topic := ""

## Language its texts (questions, failure, what the command says) are
## shown in, stamped by [CommandMatcher] from [method FictionWorld.get_output_locale].
var locale := ""
var texts: FictionTexts ## The world's parser texts, stamped by [CommandMatcher].

var ask := Ask.NONE
var question := "" ## The text to show when ASK.
var candidates: Array[Entity] = [] ## The choices for WHICH_OBJECT / WHICH_TARGET.

var failure := Failure.NONE
var failed_text := "" ## The offending words, e.g. the unknown word or the unmatched phrase.
var message := "" ## Text to show when FAILED.

# Progress, so an answer can continue where the question stopped.
var _object_phrases: Array[NounPhrase] = []
var _target_phrase: NounPhrase
var _pending: EntityResolver.Result ## The AMBIGUOUS result being asked about.
var _pending_out_of_scope := false ## True if [member _pending] holds only out-of-scope candidates.


func is_ready() -> bool:
	return status == Status.READY


func is_asking() -> bool:
	return status == Status.ASK


func is_failed() -> bool:
	return status == Status.FAILED


## The command id, or &"" when there is no command.
func command_id() -> StringName:
	return def.id if def else &""


## A shallow copy, so answering a question does not change the asked match.
func copy() -> CommandMatch:
	var other := CommandMatch.new()
	other.status = status
	other.command = command
	other.def = def
	other.objects = objects.duplicate()
	other.target = target
	other.preposition = preposition
	other.direction = direction
	other.locale = locale
	other.texts = texts
	other.argument_command = argument_command
	other.argument_text = argument_text
	other.topic = topic
	other.out_of_scope = out_of_scope.duplicate()
	other.events = events.duplicate()
	other.ask = ask
	other.question = question
	other.candidates = candidates.duplicate()
	other.failure = failure
	other.failed_text = failed_text
	other.message = message
	other._object_phrases = _object_phrases.duplicate()
	other._target_phrase = _target_phrase
	other._pending = _pending
	other._pending_out_of_scope = _pending_out_of_scope
	return other


## The text to show the player: the question, the failure message, or a
## short summary of a READY command such as "take old sword".
func get_text() -> String:
	match status:
		Status.ASK:
			return question
		Status.FAILED:
			return message
	var parts: PackedStringArray = [def.get_verb_text(locale) if def else ""]
	var names: PackedStringArray = []
	for entity in objects:
		names.append(entity.get_display_name(locale))
	if not names.is_empty():
		parts.append(", ".join(names))
	if target:
		if preposition != &"":
			parts.append(String(preposition))
		parts.append(target.get_display_name(locale))
	if direction != &"":
		parts.append(String(direction))
	return " ".join(parts)


func _to_string() -> String:
	match status:
		Status.ASK:
			var ids: PackedStringArray = []
			for entity in candidates:
				ids.append(String(entity.get_id()))
			return "ASK %s %s [%s]" % [command_id(), Ask.keys()[ask], ", ".join(ids)]
		Status.FAILED:
			return "FAILED %s \"%s\"" % [Failure.keys()[failure], failed_text]
	var parts: PackedStringArray = ["READY", String(command_id())]
	var ids: PackedStringArray = []
	for entity in objects:
		ids.append(String(entity.get_id()))
	if not ids.is_empty():
		parts.append("[%s]" % ", ".join(ids))
	if target:
		parts.append("%s %s" % [preposition if preposition != &"" else &"-", target.get_id()])
	if direction != &"":
		parts.append("dir=%s" % direction)
	if not out_of_scope.is_empty():
		parts.append("out_of_scope")
	return " ".join(parts)
