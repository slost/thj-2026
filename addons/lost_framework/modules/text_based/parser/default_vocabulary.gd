class_name DefaultVocabulary
extends RefCounted
## Words every story understands: polite fillers and words that join several
## commands in one line ("take sword then open door").


const FILLERS: Array[String] = [
	"please", "the", "a", "an", "one", "and",
	"ช่วย", "หน่อย", "ที", "ครับ", "ค่ะ", "คะ", "นะ", "จ้ะ", "จ้า", "เถอะ",
	"อัน", "อันที่", "และ", # For answers like "the old one", "อันเก่า", "อันที่ 2"
]

const PRONOUNS_IT: Array[String] = ["it", "that", "มัน", "นั้น"]
const PRONOUNS_THEM: Array[String] = ["them", "those", "พวกมัน", "พวกนั้น"]
const QUANTIFIERS: Array[String] = ["all", "everything", "ทั้งหมด"]
const EXCEPTIONS: Array[String] = ["except", "but", "ยกเว้น"]
const TOPIC_PREPOSITIONS: Array = [
	["about", "เกี่ยวกับ"],
	["to", "กับ"],
]

const CONJUNCTIONS: Array[String] = [
	"then", "and then", ",", ";", ".",
	"แล้ว", "แล้วก็", "จากนั้น", "หลังจากนั้น",
]


static func add_to(vocabulary: Vocabulary) -> void:
	vocabulary.add_words(FILLERS, ParseToken.Type.FILLER, &"filler")
	vocabulary.add_words(CONJUNCTIONS, ParseToken.Type.CONJUNCTION, &"then")
	vocabulary.add_words(PRONOUNS_IT, ParseToken.Type.PRONOUN, &"it")
	vocabulary.add_words(PRONOUNS_THEM, ParseToken.Type.PRONOUN, &"them")
	vocabulary.add_words(QUANTIFIERS, ParseToken.Type.QUANTIFIER, &"all")
	vocabulary.add_words(EXCEPTIONS, ParseToken.Type.EXCEPT, &"except")
	for group in TOPIC_PREPOSITIONS:
		vocabulary.add_words(group, ParseToken.Type.PREPOSITION, StringName(group[0]))
