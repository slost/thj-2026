class_name ParsedCommand
extends RefCounted
## The structured result of parsing one line: the first verb, the noun
## phrases around an optional preposition, and any leftovers. Matching
## against command patterns (e.g. "put {obj} in {container}") happens later,
## in the command system.

var raw: String ## Exactly what the player typed.
var tokens: Array[ParseToken] = []

var verb: ParseToken ## First VERB token, or null.
var direction: ParseToken ## First DIRECTION token, or null ("go north", or just "north").
var direct_objects: Array[NounPhrase] = [] ## Noun phrases before the preposition.
var preposition: ParseToken ## First PREPOSITION token, or null.
var indirect_objects: Array[NounPhrase] = [] ## Noun phrases after the preposition.
var numbers: Array[int] = [] ## For disambiguation answers like "2".
var unknown: Array[ParseToken] = [] ## Text the vocabulary did not recognize.
var except_objects: Array[NounPhrase] = [] ## Noun phrases after "except" / "ยกเว้น".
var _excepting := false ## While parsing, noun phrases go to [member except_objects].


## Groups tokens into a command. A noun phrase is a run of NOUN and ADJECTIVE
## tokens (fillers like "the" may sit inside it); adjectives may come before
## the noun (English) or after it (Thai). A second noun starts a new phrase.
static func from_tokens(p_raw: String, p_tokens: Array[ParseToken]) -> ParsedCommand:
	var cmd := ParsedCommand.new()
	cmd.raw = p_raw
	cmd.tokens = p_tokens

	var phrase: NounPhrase = null
	for i in p_tokens.size():
		var token := p_tokens[i]
		if token.type == ParseToken.Type.PRONOUN or token.type == ParseToken.Type.QUANTIFIER:
			phrase = cmd._phrase_or_new(null)
			if token.type == ParseToken.Type.PRONOUN:
				phrase.pronoun = token.id
			else:
				phrase.quantifier = token.id
			phrase.tokens.append(token)
			continue
		if token.type == ParseToken.Type.NOUN or token.type == ParseToken.Type.ADJECTIVE:
			var as_noun := token.can_be(ParseToken.Type.NOUN)
			var as_adjective := token.can_be(ParseToken.Type.ADJECTIVE)
			# "silver sword": a word that can be either is an adjective when a noun follows.
			if as_noun and as_adjective and _next_can_be_noun(p_tokens, i):
				as_noun = false
			if as_noun and (phrase == null or not phrase.has_noun()):
				phrase = cmd._phrase_or_new(phrase)
				phrase.noun = token
			elif as_adjective:
				phrase = cmd._phrase_or_new(phrase)
				phrase.adjectives.append(token)
			else: # Second noun: a new phrase
				phrase = cmd._phrase_or_new(null)
				phrase.noun = token
			phrase.tokens.append(token)
			continue

		match token.type:
			ParseToken.Type.FILLER:
				continue # Fillers do not end a phrase ("the old the sword")
			ParseToken.Type.VERB:
				if cmd.verb == null:
					cmd.verb = token
			ParseToken.Type.DIRECTION:
				if cmd.direction == null:
					cmd.direction = token
			ParseToken.Type.PREPOSITION:
				if cmd.preposition == null:
					cmd.preposition = token
			ParseToken.Type.EXCEPT:
				cmd._excepting = true
			ParseToken.Type.NUMBER:
				cmd.numbers.append(token.number)
			ParseToken.Type.UNKNOWN:
				cmd.unknown.append(token)
		phrase = null
	return cmd


static func _next_can_be_noun(p_tokens: Array[ParseToken], index: int) -> bool:
	for j in range(index + 1, p_tokens.size()):
		var next := p_tokens[j]
		if next.type == ParseToken.Type.FILLER:
			continue
		return next.can_be(ParseToken.Type.NOUN)
	return false


## Returns [param phrase], or a new phrase added to the direct or indirect list.
func _phrase_or_new(phrase: NounPhrase) -> NounPhrase:
	if phrase:
		return phrase
	var created := NounPhrase.new()
	if _excepting:
		except_objects.append(created)
	elif preposition == null:
		direct_objects.append(created)
	else:
		indirect_objects.append(created)
	return created


## Every noun phrase, direct objects first.
func get_noun_phrases() -> Array[NounPhrase]:
	var result: Array[NounPhrase] = []
	result.append_array(direct_objects)
	result.append_array(indirect_objects)
	return result


func is_empty() -> bool:
	return tokens.is_empty()


func has_unknown() -> bool:
	return not unknown.is_empty()


func verb_id() -> StringName:
	return verb.id if verb else &""


func _to_string() -> String:
	var parts: PackedStringArray = []
	parts.append("verb=%s" % (verb.id if verb else "-"))
	if direction:
		parts.append("dir=%s" % direction.id)
	if not direct_objects.is_empty():
		parts.append("obj=%s" % _ids(direct_objects))
	if preposition:
		parts.append("prep=%s" % preposition.id)
	if not indirect_objects.is_empty():
		parts.append("target=%s" % _ids(indirect_objects))
	if not numbers.is_empty():
		parts.append("num=%s" % str(numbers))
	if not unknown.is_empty():
		var texts: PackedStringArray = []
		for t in unknown:
			texts.append("\"%s\"" % t.text)
		parts.append("unknown=[%s]" % ", ".join(texts))
	return "{ %s }" % ", ".join(parts)


static func _ids(list: Array[NounPhrase]) -> String:
	var texts: PackedStringArray = []
	for phrase in list:
		texts.append(str(phrase))
	return "[%s]" % ", ".join(texts)
