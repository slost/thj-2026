class_name TextLocalization
extends Resource
## Texts in one language, filled in the Inspector: message texts by key
## that replace the source-language ones. [CommandLocalization] adds the
## words and help of a command. A translation file (Godot CSV) can give the
## same texts by key and wins over these entries.


@export var locale := "" ## Language, e.g. "th" ("th_TH" works too; only the language is compared).
## Message texts in this language, by key (same keys and placeholders as
## the source-language messages).
@export var messages: Array[CommandMessage] = []

static var _placeholder: RegEx ## Matches "{name}" placeholders.


## The text of message [param key] in this language, or "" if not set here.
func get_message_text(key: StringName) -> String:
	for message in messages:
		if message and message.key == key and not message.text.is_empty():
			return message.text
	return ""


## True if this entry is for the language of [param p_locale].
func matches_locale(p_locale: String) -> bool:
	return LocaleText.same_language(locale, p_locale)


## The entry of [param localizations] for [param p_locale] (empty: the
## output language), or null.
static func find(localizations: Array, p_locale := "") -> TextLocalization:
	if p_locale.is_empty():
		p_locale = LocaleText.get_locale()
	for localization in localizations:
		if localization and localization.matches_locale(p_locale):
			return localization
	return null


## One lookup for every message text: the translation [param translation_key]
## in [param p_locale], then the [param localizations] entry, then
## [param source_text] translated when a translation uses it as its key,
## then the [constant LocaleText.SOURCE_LOCALE] translation of
## [param translation_key], then [param source_text] itself (the Inspector
## or default text). A missing translation in another
## language than the source warns once (see [method LocaleText.warn_missing]).
static func resolve_message(translation_key: String, key: StringName, p_locale: String, localizations: Array, source_text: String) -> String:
	if p_locale.is_empty():
		p_locale = LocaleText.get_locale()
	var text := LocaleText.translate(translation_key, p_locale)
	if not text.is_empty():
		return text
	var localization := find(localizations, p_locale)
	text = localization.get_message_text(key) if localization else ""
	if not text.is_empty():
		return text
	if not source_text.is_empty():
		text = LocaleText.translate(source_text, p_locale)
		if not text.is_empty():
			return text
	if not LocaleText.is_source(p_locale):
		text = LocaleText.translate(translation_key, LocaleText.SOURCE_LOCALE)
		if not text.is_empty():
			LocaleText.warn_missing(translation_key, p_locale)
			return text
	if source_text.is_empty():
		return ""
	if not _is_language_neutral(source_text):
		LocaleText.warn_missing(translation_key, p_locale)
	return source_text


## True if [param text] has no letters outside its {placeholders}, e.g.
## "{room}\n{description}": the same in every language.
static func _is_language_neutral(text: String) -> bool:
	if _placeholder == null:
		_placeholder = RegEx.create_from_string("\\{[^}]*\\}")
	var rest := _placeholder.sub(text, "", true)
	for i in rest.length():
		var c := rest[i]
		if c.to_upper() != c.to_lower() or rest.unicode_at(i) > 0x7F:
			return false
	return true
