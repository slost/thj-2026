
## Numeral utility class
extends RefCounted
class_name Numeral


#region Internal Logic
## Cached numeral system instances (stateless)
static var _roman_system := RomanNumeralSystem.new()
static var _binary_system := BinaryNumeralSystem.new()
#endregion


#region Roman Numeral API
## Parse Roman numeral string to number
static func parse_roman(text: String) -> float:
	return _roman_system.parse(text)


## Format number to Roman numeral string
static func format_roman(value: float) -> String:
	return _roman_system.format(value)
#endregion


#region Binary Numeral API
## Parse binary string to number
static func parse_binary(text: String) -> float:
	return _binary_system.parse(text)


## Format number to binary string
static func format_binary(value: float) -> String:
	return _binary_system.format(value)
#endregion
