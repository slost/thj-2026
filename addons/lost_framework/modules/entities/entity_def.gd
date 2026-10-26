extends DataDef
class_name EntityDef
## Template data shared by every Entity made from it (name, words the player
## can use for it, descriptions). Values that change during play live on the
## Entity (its components or [member Entity.state]), never here.


@export var aliases: PackedStringArray = [] ## Other words for it, e.g. "sword", "blade".
@export var adjectives: PackedStringArray = [] ## Words that tell similar things apart, e.g. "old".


func _domain_id() -> StringName:
	return &"entity"


## Every word for it in any language: [member aliases] plus the
## comma-separated translations "entity.<id>.aliases" of every loaded
## locale, so players may type any language whatever the output language is.
func get_all_aliases() -> PackedStringArray:
	return _words_in_all_languages("aliases", aliases)


## Adjectives in any language, see [method get_all_aliases].
func get_all_adjectives() -> PackedStringArray:
	return _words_in_all_languages("adjectives", adjectives)


## The name in every language: [member DataDef.name] and the translations
## "<domain>.<id>.name" of every loaded locale, so players can type any of them.
func get_all_names() -> PackedStringArray:
	var result: PackedStringArray = []
	if not name.is_empty():
		result.append(name)
	for text in LocaleText.translate_all("%s.%s.name" % [_domain_id(), id]):
		if not text.is_empty() and not result.has(text):
			result.append(text)
	return result


func _words_in_all_languages(suffix: String, words: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray(words)
	for text in LocaleText.translate_all("%s.%s.%s" % [_domain_id(), id, suffix]):
		for word in LocaleText.split_words(text):
			if not result.has(word):
				result.append(word)
	return result
