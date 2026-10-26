class_name ParseToken
extends RefCounted
## One piece of parsed input: a known vocabulary word, a number, or a run of
## characters the vocabulary does not know.

enum Type {
	UNKNOWN,
	VERB,
	NOUN,
	PREPOSITION,
	DIRECTION,
	NUMBER,
	FILLER, ## Polite words and particles the parser can ignore (e.g. "please").
	CONJUNCTION, ## Joins commands in one line (e.g. "then", "แล้ว", ","). See [method CommandParser.parse_all].
	ADJECTIVE, ## Tells similar things apart (e.g. "old", "เก่า"). Its id is the normalized word.
	PRONOUN, ## "it" / "them" (and Thai equivalents). Its id is &"it" or &"them".
	QUANTIFIER, ## "all" / "ทั้งหมด". Its id is &"all".
	EXCEPT, ## Starts the list of things to leave out ("except", "ยกเว้น").
}


## True if any vocabulary entry for this token has [param p_type] (a word can
## be a noun for one entity and an adjective for another).
func can_be(p_type: Type) -> bool:
	if type == p_type:
		return true
	for entry: VocabularyEntry in matches:
		if entry.type == p_type:
			return true
	return false

var text: String ## The normalized text this token covers.
var type: Type = Type.UNKNOWN
var id: StringName ## Vocabulary id, e.g. &"open" for both "open" and Thai synonyms.
var number: int = -1 ## Value when type is NUMBER.
## Every vocabulary entry with this exact text, as [VocabularyEntry]. A word
## can mean more than one thing (e.g. a verb and a noun); [member type] and
## [member id] come from the first one.
var matches: Array = []


static func create(p_text: String, p_type: Type, p_id: StringName = &"") -> ParseToken:
	var token := ParseToken.new()
	token.text = p_text
	token.type = p_type
	token.id = p_id
	return token


func is_known() -> bool:
	return type != Type.UNKNOWN


func _to_string() -> String:
	var type_name: String = Type.keys()[type]
	if type == Type.NUMBER:
		return "[%s %d]" % [type_name, number]
	if id != &"":
		return "[%s %s \"%s\"]" % [type_name, id, text]
	return "[%s \"%s\"]" % [type_name, text]
