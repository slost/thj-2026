## NumeralRules
## Defines constant rules and symbol mappings for various numeral systems.
## This script only contains rule classes (no parsing or formatting logic).
## Each inner class represents one numeral language.

class_name NumeralRules


class Roman:
	## Mapping of Roman symbols to numeric values
	const SYMBOL_VALUES: Dictionary = {
		"I": 1,
		"V": 5,
		"X": 10,
		"L": 50,
		"C": 100,
		"D": 500,
		"M": 1000,
	}


	## Encoding table for converting numbers to Roman numerals
	static func get_encoding_table() -> Array:
		return [
			["M", SYMBOL_VALUES["M"]],
			["CM", SYMBOL_VALUES["M"] - SYMBOL_VALUES["C"]],
			["D", SYMBOL_VALUES["D"]],
			["CD", SYMBOL_VALUES["D"] - SYMBOL_VALUES["C"]],
			["C", SYMBOL_VALUES["C"]],
			["XC", SYMBOL_VALUES["C"] - SYMBOL_VALUES["X"]],
			["L", SYMBOL_VALUES["L"]],
			["XL", SYMBOL_VALUES["L"] - SYMBOL_VALUES["X"]],
			["X", SYMBOL_VALUES["X"]],
			["IX", SYMBOL_VALUES["X"] - SYMBOL_VALUES["I"]],
			["V", SYMBOL_VALUES["V"]],
			["IV", SYMBOL_VALUES["V"] - SYMBOL_VALUES["I"]],
			["I", SYMBOL_VALUES["I"]],
		]


class Binary:
	## Valid binary digits
	const DIGITS: Array = ["0", "1"]


class Abbreviation:
	## Mapping of abbreviation suffix to its definition
	## `name`  = human-readable name
	## `power` = power of 10
	const SUFFIX_MAP: Dictionary = {
		"": { "name": "Unit", "power": 0 },

		"K": { "name": "Thousand", "power": 3 },
		"M": { "name": "Million", "power": 6 },
		"B": { "name": "Billion", "power": 9 },
		"T": { "name": "Trillion", "power": 12 },

		"Qa": { "name": "Quadrillion", "power": 15 },
		"Qi": { "name": "Quintillion", "power": 18 },
		"Sx": { "name": "Sextillion", "power": 21 },
		"Sp": { "name": "Septillion", "power": 24 },
		"Oc": { "name": "Octillion", "power": 27 },
		"No": { "name": "Nonillion", "power": 30 },
		"De": { "name": "Decillion", "power": 33 },

		"Und": { "name": "Undecillion", "power": 36 },
		"Dod": { "name": "Duodecillion", "power": 39 },
		"Trd": { "name": "Tredecillion", "power": 42 },
		"Qad": { "name": "Quattuordecillion", "power": 45 },
		"Qid": { "name": "Quindecillion", "power": 48 },
		"Sxd": { "name": "Sexdecillion", "power": 51 },
		"Spd": { "name": "Septendecillion", "power": 54 },
		"Ocd": { "name": "Octodecillion", "power": 57 },
		"Nod": { "name": "Novemdecillion", "power": 60 },

		"Vg": { "name": "Vigintillion", "power": 63 },
		"Uncentillion": { "name": "Uncentillion", "power": 303 },
	}
