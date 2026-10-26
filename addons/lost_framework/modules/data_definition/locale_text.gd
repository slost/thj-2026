class_name LocaleText
extends RefCounted
## Text lookup in the output language. The output language is the
## [TranslationServer] locale, which the Settings module sets
## ([code]Settings.set_language()[/code]); nothing else chooses it.
## Locales are compared by language only ("th_TH" and "th" are the same).
## Texts written in the Inspector are in [constant SOURCE_LOCALE]; for any
## other language a missing translation falls back to the
## [constant SOURCE_LOCALE] translation, then to them, and is reported
## once with [method @GlobalScope.push_warning] (see [method warn_missing]).


const SOURCE_LOCALE := "en" ## The language of texts written in the Inspector.

static var _warned := {} ## "<language>|<key>" -> true


## The output language as a language code, e.g. "th" for "th_TH".
static func get_locale() -> String:
	return language_of(TranslationServer.get_locale())


## The language part of [param locale]: "th_TH" -> "th", "en" -> "en".
static func language_of(locale: String) -> String:
	return locale.get_slice("_", 0).get_slice("-", 0).to_lower()


## True if [param locale] is the language of the Inspector texts.
static func is_source(locale: String) -> bool:
	return language_of(locale) == SOURCE_LOCALE


## True if [param a] and [param b] are the same language.
static func same_language(a: String, b: String) -> bool:
	return not a.is_empty() and not b.is_empty() and language_of(a) == language_of(b)


## The translation of [param key] in [param locale] (empty: the output
## language), or "" when there is none. Every loaded [Translation] of that
## language is searched (e.g. the framework's and the game's CSV files),
## those for exactly [param locale] first. Other languages are never used:
## a key that only the project's fallback language has is missing here
## (see [method source_text]).
static func translate(key: String, locale := "") -> String:
	if key.is_empty():
		return ""
	if locale.is_empty():
		locale = get_locale()
	for translation in translations_for(locale):
		var text := String(translation.get_message(key))
		if not text.is_empty():
			return text
	return ""


## The loaded translations of the language of [param locale], those whose
## locale is exactly [param locale] first.
static func translations_for(locale: String) -> Array[Translation]:
	var language := language_of(locale)
	var exact: Array[Translation] = []
	var others: Array[Translation] = []
	for translation in _loaded_translations():
		if translation == null or language_of(translation.locale) != language:
			continue
		if translation.locale == locale:
			exact.append(translation)
		else:
			others.append(translation)
	exact.append_array(others)
	return exact


## Every [Translation] of the main translation domain.
## [code]TranslationServer.get_translations()[/code] lists all of them;
## without it (older Godot versions) only the best match of each loaded
## locale is found.
static func _loaded_translations() -> Array[Translation]:
	var result: Array[Translation] = []
	if TranslationServer.has_method(&"get_translations"):
		result.assign(TranslationServer.call(&"get_translations"))
		return result
	for loaded in TranslationServer.get_loaded_locales():
		var translation := TranslationServer.call(&"get_translation_object", loaded) as Translation
		if translation and not result.has(translation):
			result.append(translation)
	return result


## [param key] translated for [param locale], else the source-language
## text (see [method source_text]).
static func resolve(key: String, fallback: String, locale := "") -> String:
	if locale.is_empty():
		locale = get_locale()
	var text := translate(key, locale)
	return text if not text.is_empty() else source_text(key, fallback, locale)


## The text for [param key] when [param locale] has no translation of it:
## the [constant SOURCE_LOCALE] translation, else [param fallback] (the
## Inspector text). Outside the source language this is reported once (see
## [method warn_missing]) unless the result is empty.
static func source_text(key: String, fallback: String, locale := "") -> String:
	if locale.is_empty():
		locale = get_locale()
	var text := translate(key, SOURCE_LOCALE) if not is_source(locale) else ""
	if text.is_empty():
		text = fallback
	if not text.is_empty():
		warn_missing(key, locale)
	return text


## The translations of [param key] in every loaded locale (for words the
## player may type in any language).
static func translate_all(key: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var seen := {}
	for locale in TranslationServer.get_loaded_locales():
		var language := language_of(locale)
		if seen.has(language):
			continue
		seen[language] = true
		var text := translate(key, locale)
		if not text.is_empty():
			result.append(text)
	return result


## Splits a comma-separated word list ("หยิบ, เก็บ"), dropping empty words.
static func split_words(text: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for word in text.split(","):
		var trimmed := word.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result


## Reports a missing translation of [param key] in [param locale] once per
## key and language. Nothing for the source language.
static func warn_missing(key: String, locale: String) -> void:
	if is_source(locale) or locale.is_empty():
		return
	var warned_id := "%s|%s" % [language_of(locale), key]
	if _warned.has(warned_id):
		return
	_warned[warned_id] = true
	push_warning("Missing '%s' translation for \"%s\"; using the %s text." % [language_of(locale), key, SOURCE_LOCALE])


## True if a missing [param key] in [param locale] was reported.
static func was_warned(key: String, locale: String) -> bool:
	return _warned.has("%s|%s" % [language_of(locale), key])


## Forgets the reported keys (tests).
static func clear_warnings() -> void:
	_warned.clear()
