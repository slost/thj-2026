class_name VocabularyEntry
extends RefCounted
## One word or phrase the parser knows. Several entries can share an id
## (synonyms), and several entries can share a text (homonyms).

var text: String ## Normalized text.
var type: ParseToken.Type
var id: StringName


func _init(p_text: String = "", p_type: ParseToken.Type = ParseToken.Type.UNKNOWN, p_id: StringName = &"") -> void:
	text = p_text
	type = p_type
	id = p_id
