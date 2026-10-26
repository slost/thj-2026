class_name TextNormalizer
extends RefCounted
## Normalizes player input and vocabulary so the same word always has the
## same code points. Thai text can be typed in several visually identical
## ways (e.g. SARA AM as one char or NIKHAHIT + SARA AA), so both the
## vocabulary and the input must go through [method normalize].

const ZERO_WIDTH_CHARS: Array[String] = [
	"\u200B", # Zero width space
	"\u200C", # Zero width non-joiner
	"\u200D", # Zero width joiner
	"\u2060", # Word joiner
	"\uFEFF", # BOM / zero width no-break space
]

const SPACE_LIKE_CHARS: Array[String] = [
	"\u00A0", # No-break space
	"\u3000", # Ideographic space
	"\t", "\r", "\n",
]

const NIKHAHIT := 0x0E4D
const SARA_AA := 0x0E32
const SARA_AM := 0x0E33


## Returns a normalized copy of [param text]: Thai fixes, no zero-width
## characters, single spaces, lowercase, trimmed.
static func normalize(text: String) -> String:
	var result := text
	for c in ZERO_WIDTH_CHARS:
		result = result.replace(c, "")
	for c in SPACE_LIKE_CHARS:
		result = result.replace(c, " ")

	result = _normalize_thai(result)
	result = result.to_lower()

	while result.contains("  "):
		result = result.replace("  ", " ")
	return result.strip_edges()


## Fixes the common Thai input variants:
## - NIKHAHIT + SARA AA -> SARA AM
## - SARA AM (or NIKHAHIT) typed before a tone mark -> tone mark first
## - tone mark typed before an upper vowel -> upper vowel first
static func _normalize_thai(text: String) -> String:
	var chars: Array[int] = []
	for i in text.length():
		chars.append(text.unicode_at(i))

	# NIKHAHIT (+ optional tone mark) + SARA AA -> (tone mark) + SARA AM
	var merged: Array[int] = []
	var i := 0
	while i < chars.size():
		var c := chars[i]
		if c == NIKHAHIT:
			if i + 1 < chars.size() and chars[i + 1] == SARA_AA:
				merged.append(SARA_AM)
				i += 2
				continue
			if i + 2 < chars.size() and is_tone_mark(chars[i + 1]) and chars[i + 2] == SARA_AA:
				merged.append(chars[i + 1])
				merged.append(SARA_AM)
				i += 3
				continue
		merged.append(c)
		i += 1

	# Reorder pairs until stable (sequences are at most a few chars long).
	var changed := true
	while changed:
		changed = false
		for j in merged.size() - 1:
			var a := merged[j]
			var b := merged[j + 1]
			var swap := false
			if a == SARA_AM and is_tone_mark(b):
				swap = true
			elif is_tone_mark(a) and is_upper_vowel(b):
				swap = true
			if swap:
				merged[j] = b
				merged[j + 1] = a
				changed = true

	var out := ""
	for c in merged:
		out += String.chr(c)
	return out


static func is_tone_mark(c: int) -> bool:
	return c >= 0x0E48 and c <= 0x0E4B


static func is_upper_vowel(c: int) -> bool:
	return c == 0x0E31 or (c >= 0x0E34 and c <= 0x0E37)


## True for Thai characters that can never begin a word: following vowels,
## upper/lower vowels, tone marks and other marks that attach to the previous
## consonant. A word must never end right before one of these.
static func cannot_start_word(c: int) -> bool:
	return (c >= 0x0E30 and c <= 0x0E3A) or c == 0x0E45 or (c >= 0x0E47 and c <= 0x0E4E)


## True for Thai leading vowels (เ แ โ ใ ไ), which belong to the following
## consonant, so a word can never end with one.
static func is_leading_vowel(c: int) -> bool:
	return c >= 0x0E40 and c <= 0x0E44


static func is_ascii_alnum(c: int) -> bool:
	return (c >= 0x30 and c <= 0x39) or (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A)


## Returns the digit value for ASCII or Thai digits, or -1.
static func digit_value(c: int) -> int:
	if c >= 0x30 and c <= 0x39:
		return c - 0x30
	if c >= 0x0E50 and c <= 0x0E59:
		return c - 0x0E50
	return -1
