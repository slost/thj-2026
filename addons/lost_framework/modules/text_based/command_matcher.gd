class_name CommandMatcher
extends RefCounted
## Matches a [ParsedCommand] to one of the world's [CommandDef]s and fills in
## its objects, target and direction, giving a [CommandMatch]. Objects and
## targets are resolved with [EntityResolver] and then narrowed to the
## command's [enum CommandDef.Scope]. If the scope leaves nothing but the
## resolver found something (other than the actor), those matches are kept
## and listed in [member CommandMatch.out_of_scope].
##
## A match that needs more from the player is ASK; pass the player's reply to
## [method answer] to continue it. [CommandSession] does this for whole lines.

var world: FictionWorld
var actor: Entity ## Who acts; null means the world's player.
var resolver: EntityResolver
var go_command := &"go" ## Command used for a bare direction ("north", "เหนือ").
## Command whose hint ("Type help for a list of commands.") is added when
## a line is not understood at all (see [method HelpCommandDef.get_unknown_hint]).
## &"" for no hint.
var help_command := &"help"
## When set, matches and their texts use this language instead of the world's.
var locale := ""
var mentioned_it: Entity ## The last single thing the actor named.
var mentioned_them: Array[Entity] = [] ## The last group the actor named.

## The [FictionTexts] key of each failure's message ({text}: the words
## concerned, {verb}). The texts come from [method FictionWorld.get_texts].
const FAILURE_KEYS := {
	CommandMatch.Failure.UNKNOWN_WORDS: &"unknown_words",
	CommandMatch.Failure.NO_VERB: &"no_verb",
	CommandMatch.Failure.UNKNOWN_VERB: &"unknown_verb",
	CommandMatch.Failure.NOT_HERE: &"not_here",
	CommandMatch.Failure.NOT_FOUND: &"not_found",
	CommandMatch.Failure.SELF: &"self",
	CommandMatch.Failure.NO_OBJECT_EXPECTED: &"no_object_expected",
	CommandMatch.Failure.NO_TARGET_EXPECTED: &"no_target_expected",
	CommandMatch.Failure.WRONG_PREPOSITION: &"wrong_preposition",
	CommandMatch.Failure.NO_PRONOUN: &"no_pronoun",
}


## The resolver's result after narrowing to a scope.
class ScopedResult:
	extends RefCounted
	var result: EntityResolver.Result
	var out_of_scope := false ## The matches do not fit the scope (kept as a fallback).
	var only_self := false ## Only the actor fits, and the scope excludes it.


func _init(p_world: FictionWorld = null, p_actor: Entity = null) -> void:
	world = p_world
	actor = p_actor
	resolver = EntityResolver.new(world, actor)


## Matches one parsed command. Never returns null.
func match_command(command: ParsedCommand) -> CommandMatch:
	var m := CommandMatch.new()
	m.command = command
	_stamp(m)
	var verb_def: CommandDef = world.get_command(command.verb_id()) if command.verb and world else null
	if command.verb and verb_def and verb_def.accepts_command and _match_argument(m, verb_def):
		return m
	if command.has_unknown() and (verb_def == null or not verb_def.accepts_topic):
		return _fail(m, CommandMatch.Failure.UNKNOWN_WORDS, _unknown_text(command))

	var def: CommandDef
	if command.verb:
		def = world.get_command(command.verb_id())
		if def == null:
			return _fail(m, CommandMatch.Failure.UNKNOWN_VERB, command.verb.text)
	elif command.direction:
		def = world.get_command(go_command) # A bare direction means go
	if def == null:
		return _fail(m, CommandMatch.Failure.NO_VERB, command.raw)

	if def.with_object_command != &"" and not command.direct_objects.is_empty():
		var redirect := world.get_command(def.with_object_command)
		if redirect:
			def = redirect
	m.def = def

	if (def.needs_direction or def.accepts_direction) and command.direction:
		m.direction = command.direction.id

	var object_phrases: Array[NounPhrase] = command.direct_objects.duplicate()
	var target_phrase: NounPhrase = command.indirect_objects[0] if not command.indirect_objects.is_empty() else null
	if command.preposition:
		var preposition_ok := def.allows_preposition(command.preposition.id)
		var topic_preposition := def.accepts_topic and preposition_ok
		if not topic_preposition and (def.target_requirement == CommandDef.Requirement.NONE or not preposition_ok):
			return _fail(m, CommandMatch.Failure.WRONG_PREPOSITION, command.preposition.text)
		if not def.accepts_topic:
			m.preposition = command.preposition.id
	elif def.target_requirement != CommandDef.Requirement.NONE and object_phrases.size() > 1:
		# No preposition (common in Thai, "ใส่ดาบกล่อง"): the last phrase is the target.
		target_phrase = object_phrases.pop_back()

	if def.object_requirement == CommandDef.Requirement.NONE and not object_phrases.is_empty():
		return _fail(m, CommandMatch.Failure.NO_OBJECT_EXPECTED, object_phrases[0].get_text())

	if def.accepts_topic:
		var shaped := _shape_topic(m, command, object_phrases)
		object_phrases = shaped
		target_phrase = null
	m._object_phrases = object_phrases
	m._target_phrase = target_phrase
	return _advance(m)


## Remembers objects and the target so a later "it" / "them" can refer to them.
func remember(m: CommandMatch) -> void:
	if m == null:
		return
	if m.objects.size() == 1:
		mentioned_it = m.objects[0]
		mentioned_them = []
	elif m.objects.size() > 1:
		mentioned_them = m.objects.duplicate()
		mentioned_it = m.objects[m.objects.size() - 1]
	if m.target:
		mentioned_it = m.target


## The person is the first noun; every other noun and unknown word is the topic.
func _shape_topic(m: CommandMatch, command: ParsedCommand, object_phrases: Array[NounPhrase]) -> Array[NounPhrase]:
	var parts: PackedStringArray = []
	var objects: Array[NounPhrase] = object_phrases.duplicate()
	var indirect: Array[NounPhrase] = command.indirect_objects.duplicate()
	if objects.is_empty() and not indirect.is_empty():
		objects.append(indirect.pop_front())
	elif objects.size() > 1:
		for i in range(1, objects.size()):
			parts.append(objects[i].get_text())
		objects = [objects[0]]
	for phrase in indirect:
		parts.append(phrase.get_text())
	for token in command.unknown:
		parts.append(token.text)
	m.topic = " ".join(parts)
	return objects


## For a command with [member CommandDef.accepts_command]: if words follow
## the verb, fills [member CommandMatch.argument_text] (and
## [member CommandMatch.argument_command] when one of them is a command
## word), makes [param m] READY and returns true. Returns false when nothing
## follows the verb (matched as usual).
func _match_argument(m: CommandMatch, def: CommandDef) -> bool:
	var tokens := m.command.tokens
	var start := tokens.find(m.command.verb) + 1
	var texts: PackedStringArray = []
	var argument := &""
	for i in range(start, tokens.size()):
		var token := tokens[i]
		if token.type == ParseToken.Type.FILLER:
			continue
		texts.append(token.text)
		if argument == &"" and token.can_be(ParseToken.Type.VERB):
			argument = _command_id_of(token)
	if texts.is_empty():
		return false
	m.def = def
	m.argument_command = argument
	m.argument_text = " ".join(texts)
	m.status = CommandMatch.Status.READY
	return true


## The id of a command in the world that [param token] names, or &"".
func _command_id_of(token: ParseToken) -> StringName:
	if token.type == ParseToken.Type.VERB and world.get_command(token.id):
		return token.id
	for entry: VocabularyEntry in token.matches:
		if entry.type == ParseToken.Type.VERB and world.get_command(entry.id):
			return entry.id
	return &""


## Continues an ASK [param pending] with the player's [param reply] (a line
## without a verb: a noun phrase, an adjective, a number, or a direction).
## Returns a new match; [param pending] is not changed. A reply that does not
## answer the question returns the same question again.
func answer(pending: CommandMatch, reply: ParsedCommand) -> CommandMatch:
	if pending == null or pending.status != CommandMatch.Status.ASK:
		return pending
	var m := pending.copy()
	_stamp(m) # The language may have changed since the question
	if reply.has_unknown():
		return _fail(m, CommandMatch.Failure.UNKNOWN_WORDS, _unknown_text(reply))

	match m.ask:
		CommandMatch.Ask.DIRECTION:
			if reply.direction == null:
				return m
			m.direction = reply.direction.id
			return _advance(m)

		CommandMatch.Ask.OBJECT:
			var phrases := reply.get_noun_phrases()
			if phrases.is_empty():
				return m
			m._object_phrases = phrases
			return _advance(m)

		CommandMatch.Ask.TARGET:
			var phrases := reply.get_noun_phrases()
			if phrases.is_empty():
				return m
			if reply.preposition:
				if not m.def.allows_preposition(reply.preposition.id):
					return _fail(m, CommandMatch.Failure.WRONG_PREPOSITION, reply.preposition.text)
				m.preposition = reply.preposition.id
			m._target_phrase = reply.indirect_objects[0] if not reply.indirect_objects.is_empty() else phrases[0]
			return _advance(m)

		CommandMatch.Ask.WHICH_OBJECT, CommandMatch.Ask.WHICH_TARGET:
			var chosen := resolver.choose(m._pending, reply)
			if chosen.status == EntityResolver.Status.FOUND:
				var entity := chosen.get_entity()
				if m.ask == CommandMatch.Ask.WHICH_OBJECT:
					m.objects.append(entity)
				else:
					m.target = entity
				if m._pending_out_of_scope:
					m.out_of_scope.append(entity)
				return _advance(m)
			if chosen.entities.size() < m.candidates.size():
				m._pending = chosen # Narrowed but still several: ask again among fewer
				return _ask_which(m, chosen, m.ask)
			return m
	return m


## Sets the language and parser texts of [param m] from the world
## (with [param only_missing], only those not set yet).
func _stamp(m: CommandMatch, only_missing := false) -> void:
	if not only_missing or m.locale.is_empty():
		if not locale.is_empty():
			m.locale = LocaleText.language_of(locale)
		else:
			m.locale = world.get_output_locale() if world else LocaleText.get_locale()
	if not only_missing or m.texts == null:
		m.texts = world.get_texts() if world else FictionTexts.get_default()


## The question of an ASK [param m] in its language ([member CommandMatch.locale]).
## [CommandSession] uses it to ask again after the output language changed.
func render_question(m: CommandMatch) -> String:
	_stamp(m, true)
	var def := m.def
	match m.ask:
		CommandMatch.Ask.DIRECTION:
			return def.get_direction_question(m.locale, m.texts)
		CommandMatch.Ask.OBJECT:
			return def.get_object_question(m.locale, m.texts)
		CommandMatch.Ask.TARGET:
			return def.get_target_question(m.texts.get_object_text(m.objects, m.locale), m.texts.get_preposition_name(m.preposition, m.locale), m.locale, m.texts)
		CommandMatch.Ask.WHICH_OBJECT, CommandMatch.Ask.WHICH_TARGET:
			var choices: PackedStringArray = []
			for i in m.candidates.size():
				choices.append(m.texts.get_text(&"choice", {"number": i + 1, "name": m.candidates[i].get_display_name(m.locale)}, m.locale))
			var phrase_text := m._pending.phrase.get_text() if m._pending and m._pending.phrase else ""
			return m.texts.get_text(&"which", {"text": phrase_text, "choices": m.texts.get_text(&"choice_separator", {}, m.locale).join(choices)}, m.locale)
	return m.question


## Fills the slots that are still empty, in order: direction, objects, target.
func _advance(m: CommandMatch) -> CommandMatch:
	m.status = CommandMatch.Status.READY
	m.ask = CommandMatch.Ask.NONE
	m.question = ""
	m.candidates = []
	m._pending = null
	m._pending_out_of_scope = false
	var def := m.def

	if def.needs_direction and m.direction == &"":
		return _ask(m, CommandMatch.Ask.DIRECTION)

	var pending_phrases: Array[NounPhrase] = []
	for phrase in m._object_phrases:
		if phrase.quantifier == &"all":
			if not _fill_all(m, def.object_scope):
				return m
		elif phrase.pronoun != &"":
			if not _fill_pronoun(m, phrase):
				return m
		else:
			pending_phrases.append(phrase)
	m._object_phrases = pending_phrases
	# Pop before resolving: an answer continues with _advance, and the phrase
	# that was already asked about must not be resolved a second time.
	while not m._object_phrases.is_empty():
		var phrase: NounPhrase = m._object_phrases.pop_front()
		if not _take(m, phrase, _resolve(phrase, def.object_scope), CommandMatch.Ask.WHICH_OBJECT):
			return m
	if def.object_requirement == CommandDef.Requirement.REQUIRED and m.objects.is_empty() and m._object_phrases.is_empty():
		return _ask(m, CommandMatch.Ask.OBJECT)

	if def.target_requirement != CommandDef.Requirement.NONE and m.target == null:
		if m._target_phrase:
			if not _take(m, m._target_phrase, _resolve(m._target_phrase, def.target_scope), CommandMatch.Ask.WHICH_TARGET):
				return m
		elif def.target_requirement == CommandDef.Requirement.REQUIRED:
			if m.preposition == &"" and not def.prepositions.is_empty():
				m.preposition = StringName(def.prepositions[0])
			return _ask(m, CommandMatch.Ask.TARGET)
	return m


## Stores a resolved object or target in [param m]. Returns false if [param m]
## became ASK (several fit) or FAILED.
func _take(m: CommandMatch, phrase: NounPhrase, scoped: ScopedResult, which: CommandMatch.Ask) -> bool:
	var result := scoped.result
	match result.status:
		EntityResolver.Status.FOUND:
			var entity := result.get_entity()
			if which == CommandMatch.Ask.WHICH_OBJECT:
				m.objects.append(entity)
			else:
				m.target = entity
			if scoped.out_of_scope:
				m.out_of_scope.append(entity)
			return true
		EntityResolver.Status.AMBIGUOUS:
			m._pending = result
			m._pending_out_of_scope = scoped.out_of_scope
			_ask_which(m, result, which)
			return false
		EntityResolver.Status.NOT_HERE:
			_fail(m, CommandMatch.Failure.NOT_HERE, phrase.get_text())
			return false
	_fail(m, CommandMatch.Failure.SELF if scoped.only_self else CommandMatch.Failure.NOT_FOUND, phrase.get_text())
	return false


## Resolves [param phrase] and keeps the matches that fit [param scope].
func _resolve(phrase: NounPhrase, scope: CommandDef.Scope) -> ScopedResult:
	var scoped := ScopedResult.new()
	var result := resolver.resolve(phrase)
	scoped.result = result
	if result.entities.is_empty() or scope == CommandDef.Scope.VISIBLE:
		return scoped
	var who := get_actor()
	var fitting: Array[Entity] = []
	var not_self: Array[Entity] = []
	for entity in result.entities:
		if entity == who:
			continue
		not_self.append(entity)
		if fits_scope(entity, scope, who):
			fitting.append(entity)
	if fitting.is_empty():
		if not_self.is_empty():
			scoped.only_self = true
			scoped.result = _result(EntityResolver.Status.NOT_FOUND, phrase, not_self)
			return scoped
		scoped.out_of_scope = true
		fitting = not_self
	scoped.result = _result(EntityResolver.Status.FOUND if fitting.size() == 1 else EntityResolver.Status.AMBIGUOUS, phrase, fitting)
	return scoped


func get_actor() -> Entity:
	return actor if actor else world.player


## Puts every in-scope entity that fits [param scope_kind] into [param m],
## minus the command's "except" phrases. Returns false if the match failed.
func _fill_all(m: CommandMatch, scope_kind: CommandDef.Scope) -> bool:
	var excluded: Array[Entity] = []
	for phrase in m.command.except_objects:
		var scoped := _resolve(phrase, CommandDef.Scope.VISIBLE)
		match scoped.result.status:
			EntityResolver.Status.FOUND:
				excluded.append(scoped.result.get_entity())
			EntityResolver.Status.AMBIGUOUS:
				m._pending = scoped.result
				_ask_which(m, scoped.result, CommandMatch.Ask.WHICH_OBJECT)
				return false
			_:
				_fail(m, CommandMatch.Failure.NOT_FOUND if scoped.result.status == EntityResolver.Status.NOT_FOUND else CommandMatch.Failure.NOT_HERE, phrase.get_text())
				return false
	var who := get_actor()
	var found: Array[Entity] = []
	for entity in world.get_scope(who):
		if entity == who or excluded.has(entity):
			continue
		if entity.get_component(LocationComponent) or entity.get_component(MoverComponent):
			continue
		if not fits_scope(entity, scope_kind, who):
			continue
		found.append(entity)
	if found.is_empty():
		_fail(m, CommandMatch.Failure.NOT_FOUND, "all")
		return false
	m.objects.append_array(found)
	return true


## Puts the remembered "it" or "them" into [param m]. Returns false if the match failed.
func _fill_pronoun(m: CommandMatch, phrase: NounPhrase) -> bool:
	var remembered: Array[Entity] = []
	if phrase.pronoun == &"them":
		remembered = mentioned_them.duplicate()
	elif mentioned_it:
		remembered = [mentioned_it]
	if remembered.is_empty():
		_fail(m, CommandMatch.Failure.NO_PRONOUN, phrase.get_text())
		return false
	var scope := world.get_scope(get_actor())
	var here: Array[Entity] = []
	for entity in remembered:
		if scope.has(entity):
			here.append(entity)
	if here.is_empty():
		_fail(m, CommandMatch.Failure.NOT_HERE, phrase.get_text())
		return false
	m.objects.append_array(here)
	return true


## True if [param entity] fits [param scope] for [param who].
static func fits_scope(entity: Entity, scope: CommandDef.Scope, who: Entity) -> bool:
	match scope:
		CommandDef.Scope.NOT_CARRIED:
			return entity != who and not is_carried(entity, who)
		CommandDef.Scope.CARRIED:
			return entity != who and is_carried(entity, who)
	return true


## True if [param who] holds [param entity], directly or inside something it holds.
static func is_carried(entity: Entity, who: Entity) -> bool:
	return who != null and who.is_ancestor_of(entity)


func _ask(m: CommandMatch, what: CommandMatch.Ask) -> CommandMatch:
	m.status = CommandMatch.Status.ASK
	m.ask = what
	m.question = render_question(m)
	return m


func _ask_which(m: CommandMatch, result: EntityResolver.Result, which: CommandMatch.Ask) -> CommandMatch:
	m.candidates = result.entities.duplicate()
	m._pending = result
	return _ask(m, which)


func _fail(m: CommandMatch, failure: CommandMatch.Failure, text: String) -> CommandMatch:
	m.status = CommandMatch.Status.FAILED
	m.ask = CommandMatch.Ask.NONE
	m.question = ""
	m.candidates = []
	m.failure = failure
	m.failed_text = text
	_stamp(m, true)
	var key: StringName = FAILURE_KEYS.get(failure, &"unknown_words")
	m.message = m.texts.get_text(key, {"text": text, "verb": m.def.get_verb_text(m.locale) if m.def else ""}, m.locale)
	var hint := _unknown_hint(m)
	if not hint.is_empty():
		m.message += " " + hint
	return m


## The help hint for a line that was not understood at all: an unknown
## verb, no verb, or unknown words where the line has no verb. "" otherwise
## or when [member help_command] is empty or not a [HelpCommandDef].
func _unknown_hint(m: CommandMatch) -> String:
	if help_command == &"" or world == null or m.command == null:
		return ""
	match m.failure:
		CommandMatch.Failure.UNKNOWN_VERB, CommandMatch.Failure.NO_VERB:
			pass
		CommandMatch.Failure.UNKNOWN_WORDS:
			if m.command.verb or m.command.direction:
				return ""
		_:
			return ""
	var help := world.get_command(help_command) as HelpCommandDef
	return help.get_unknown_hint(m.locale) if help else ""


static func _unknown_text(command: ParsedCommand) -> String:
	var words: PackedStringArray = []
	for token in command.unknown:
		words.append(token.text)
	return " ".join(words)


static func _result(status: EntityResolver.Status, phrase: NounPhrase, entities: Array[Entity]) -> EntityResolver.Result:
	var result := EntityResolver.Result.new()
	result.status = status
	result.phrase = phrase
	result.entities = entities
	return result
