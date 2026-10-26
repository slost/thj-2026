class_name NounPhrase
extends RefCounted
## A noun with the adjectives typed around it, e.g. "old sword" or "ดาบเก่า".
## Either part may be missing: "take old" has only an adjective. Turning a
## phrase into entities is done by [EntityResolver].

var noun: ParseToken ## The NOUN token, or null.
var adjectives: Array[ParseToken] = [] ## ADJECTIVE tokens, in typed order.
var tokens: Array[ParseToken] = [] ## Noun and adjectives in typed order.
var pronoun := &"" ## &"it" or &"them" when this phrase is a pronoun.
var quantifier := &"" ## &"all" when this phrase means everything in scope.


func has_noun() -> bool:
	return noun != null


func is_empty() -> bool:
	return tokens.is_empty()


## What the player typed for this phrase, e.g. "ดาบ เก่า".
func get_text() -> String:
	var texts: PackedStringArray = []
	for token in tokens:
		texts.append(token.text)
	return " ".join(texts)


## Ids of every entity the noun can name. One word can name several
## entities ("ดาบ" for two swords), so this can hold more than one id.
func get_noun_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if noun == null:
		return ids
	for entry: VocabularyEntry in noun.matches:
		if entry.type == ParseToken.Type.NOUN and not ids.has(entry.id):
			ids.append(entry.id)
	if ids.is_empty() and noun.id != &"":
		ids.append(noun.id)
	return ids


## Normalized adjective words, e.g. ["old"] or ["เก่า"].
func get_adjective_texts() -> PackedStringArray:
	var texts: PackedStringArray = []
	for token in adjectives:
		texts.append(token.text)
	return texts


func _to_string() -> String:
	var parts: PackedStringArray = []
	for token in adjectives:
		parts.append(String(token.id))
	var ids := get_noun_ids()
	if not ids.is_empty():
		parts.append(String(ids[0]))
	return " ".join(parts)
