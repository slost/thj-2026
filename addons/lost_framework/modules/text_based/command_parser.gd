class_name CommandParser
extends RefCounted
## Turns a line of player input (Thai, English, or mixed) into tokens and a
## [ParsedCommand]. Thai is written without spaces between words, so each
## run of text is segmented against the game's own [Vocabulary].
##
## Segmentation picks, among all ways to cut the text, the one with the
## fewest unknown characters, then the fewest tokens. This avoids the classic
## greedy mistake where a long word swallows the start of the next one.

var vocabulary: Vocabulary


func _init(p_vocabulary: Vocabulary = null) -> void:
	vocabulary = p_vocabulary if p_vocabulary else Vocabulary.new()


## Parses one line of input. Never returns null.
func parse(raw_input: String) -> ParsedCommand:
	var tokens := tokenize(raw_input)
	return ParsedCommand.from_tokens(raw_input, tokens)


## Parses a line that may hold several commands joined by CONJUNCTION words,
## e.g. "หยิบดาบแล้วเปิดประตู" gives two commands. Empty parts are skipped.
func parse_all(raw_input: String) -> Array[ParsedCommand]:
	var commands: Array[ParsedCommand] = []
	var part: Array[ParseToken] = []
	for token in tokenize(raw_input):
		if token.type == ParseToken.Type.CONJUNCTION:
			_append_part(commands, part)
			part = []
		else:
			part.append(token)
	_append_part(commands, part)
	return commands


static func _append_part(commands: Array[ParsedCommand], part: Array[ParseToken]) -> void:
	if part.is_empty():
		return
	var texts: PackedStringArray = []
	for token in part:
		texts.append(token.text)
	commands.append(ParsedCommand.from_tokens(" ".join(texts), part))


## Normalizes and segments [param raw_input] into tokens. Spaces are optional
## for Thai and act only as hints; English words must match whole words.
func tokenize(raw_input: String) -> Array[ParseToken]:
	var text := TextNormalizer.normalize(raw_input)
	var tokens: Array[ParseToken] = []
	if text.is_empty():
		return tokens

	var n := text.length()
	var codes: PackedInt32Array = []
	codes.resize(n)
	for i in n:
		codes[i] = text.unicode_at(i)

	# best_cost[i] = [unknown_chars, token_count] for the best cut of text[0, i).
	# step[i] describes how we reached i: { "from": int, "kind": String, "entry"/"value" }.
	var inf := 1 << 30
	var best_unknown := PackedInt32Array()
	var best_tokens := PackedInt32Array()
	best_unknown.resize(n + 1)
	best_tokens.resize(n + 1)
	best_unknown.fill(inf)
	best_tokens.fill(inf)
	var step: Array = []
	step.resize(n + 1)
	best_unknown[0] = 0
	best_tokens[0] = 0

	for i in n:
		if best_unknown[i] == inf:
			continue
		var cu := best_unknown[i]
		var ct := best_tokens[i]
		var c := codes[i]

		# Spaces separate words and cost nothing.
		if c == 0x20:
			_relax(best_unknown, best_tokens, step, i + 1, cu, ct, {"from": i, "kind": "space"})
			continue

		# Numbers (ASCII or Thai digits) for answers like "2" or "๒".
		if TextNormalizer.digit_value(c) >= 0 and _starts_word(codes, i):
			var j := i
			var value := 0
			while j < n and TextNormalizer.digit_value(codes[j]) >= 0:
				value = value * 10 + TextNormalizer.digit_value(codes[j])
				j += 1
			if _ends_word(codes, j):
				_relax(best_unknown, best_tokens, step, j, cu, ct + 1, {"from": i, "kind": "number", "value": value})

		# Known vocabulary.
		for entry: VocabularyEntry in vocabulary.candidates_for(c):
			var length := entry.text.length()
			if i + length > n:
				continue
			if not _matches_at(codes, i, entry.text):
				continue
			if not _valid_boundaries(codes, i, i + length):
				continue
			_relax(best_unknown, best_tokens, step, i + length, cu, ct + 1, {"from": i, "kind": "word", "entry": entry})

		# Fallback: treat one character as unknown. Consecutive unknown
		# characters are merged into a single token afterwards, so count the
		# token only when this starts a new unknown run.
		var prev: Variant = step[i]
		var continues_unknown: bool = prev != null and prev["kind"] == "unknown"
		_relax(best_unknown, best_tokens, step, i + 1, cu + 1, ct + (0 if continues_unknown else 1), {"from": i, "kind": "unknown"})

	# Walk back from the end to rebuild the chosen path.
	var path: Array = []
	var pos := n
	while pos > 0:
		var s: Dictionary = step[pos]
		path.push_front(s.merged({"to": pos}))
		pos = s["from"]

	var unknown_start := -1
	for s: Dictionary in path:
		var kind: String = s["kind"]
		if kind == "unknown":
			if unknown_start < 0:
				unknown_start = s["from"]
			continue
		if unknown_start >= 0:
			tokens.append(ParseToken.create(text.substr(unknown_start, s["from"] - unknown_start), ParseToken.Type.UNKNOWN))
			unknown_start = -1
		match kind:
			"word":
				tokens.append(_token_for_word(text.substr(s["from"], s["to"] - s["from"])))
			"number":
				var token := ParseToken.create(text.substr(s["from"], s["to"] - s["from"]), ParseToken.Type.NUMBER)
				token.number = s["value"]
				tokens.append(token)
			_:
				pass # space
	if unknown_start >= 0:
		tokens.append(ParseToken.create(text.substr(unknown_start, n - unknown_start), ParseToken.Type.UNKNOWN))

	return tokens


func _token_for_word(word: String) -> ParseToken:
	var entries := vocabulary.lookup(word)
	var first: VocabularyEntry = entries[0]
	var token := ParseToken.create(word, first.type, first.id)
	token.matches = entries.duplicate()
	return token


static func _relax(best_unknown: PackedInt32Array, best_tokens: PackedInt32Array, step: Array, to: int, unknown: int, token_count: int, how: Dictionary) -> void:
	if unknown < best_unknown[to] or (unknown == best_unknown[to] and token_count < best_tokens[to]):
		best_unknown[to] = unknown
		best_tokens[to] = token_count
		step[to] = how


static func _matches_at(codes: PackedInt32Array, start: int, word: String) -> bool:
	for k in word.length():
		if codes[start + k] != word.unicode_at(k):
			return false
	return true


## English words must not start or end inside another English word, and a
## word may not split a Thai syllable (end before a vowel or tone mark that
## belongs to it, or end with a leading vowel).
static func _valid_boundaries(codes: PackedInt32Array, start: int, end: int) -> bool:
	if TextNormalizer.is_ascii_alnum(codes[start]) and not _starts_word(codes, start):
		return false
	if TextNormalizer.is_ascii_alnum(codes[end - 1]) and not _ends_word(codes, end):
		return false
	if end < codes.size() and TextNormalizer.cannot_start_word(codes[end]):
		return false
	if TextNormalizer.is_leading_vowel(codes[end - 1]):
		return false
	return true


static func _starts_word(codes: PackedInt32Array, i: int) -> bool:
	return i == 0 or not TextNormalizer.is_ascii_alnum(codes[i - 1])


static func _ends_word(codes: PackedInt32Array, end: int) -> bool:
	return end >= codes.size() or not TextNormalizer.is_ascii_alnum(codes[end])
