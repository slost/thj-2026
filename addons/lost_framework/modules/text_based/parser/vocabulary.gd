class_name Vocabulary
extends RefCounted
## The set of words a game understands. Built once when a story loads (from
## command definitions and entity names) and then shared by the parser.

## First character (unicode) -> Array of VocabularyEntry, longest first.
var _by_first_char: Dictionary = {}
## Normalized text -> Array of VocabularyEntry.
var _by_text: Dictionary = {}


## Adds a word or phrase. [param text] is normalized here, so callers can pass
## raw designer input. Returns false if the text is empty after normalizing.
func add_word(text: String, type: ParseToken.Type, id: StringName) -> bool:
	var normalized := TextNormalizer.normalize(text)
	if normalized.is_empty():
		return false

	var existing: Array = _by_text.get(normalized, [])
	for entry: VocabularyEntry in existing:
		if entry.type == type and entry.id == id:
			return true # Already known

	var entry := VocabularyEntry.new(normalized, type, id)
	existing.append(entry)
	_by_text[normalized] = existing

	var key := normalized.unicode_at(0)
	var bucket: Array = _by_first_char.get(key, [])
	bucket.append(entry)
	bucket.sort_custom(_longer_first)
	_by_first_char[key] = bucket
	return true


## Adds several synonyms for the same id, e.g.
## [code]add_words(["open", "เปิด", "แง้ม"], ParseToken.Type.VERB, &"open")[/code].
func add_words(texts: Array, type: ParseToken.Type, id: StringName) -> void:
	for t in texts:
		add_word(str(t), type, id)


## Adds every entry of [param other] (e.g. base verbs into a world vocabulary).
func add_from(other: Vocabulary) -> void:
	for entries: Array in other._by_text.values():
		for entry: VocabularyEntry in entries:
			add_word(entry.text, entry.type, entry.id)


func clear() -> void:
	_by_first_char.clear()
	_by_text.clear()


func size() -> int:
	return _by_text.size()


## Entries whose text starts with the character [param first_char], longest first.
func candidates_for(first_char: int) -> Array:
	return _by_first_char.get(first_char, [])


## All entries with exactly this normalized text.
func lookup(normalized_text: String) -> Array:
	return _by_text.get(normalized_text, [])


static func _longer_first(a: VocabularyEntry, b: VocabularyEntry) -> bool:
	return a.text.length() > b.text.length()
