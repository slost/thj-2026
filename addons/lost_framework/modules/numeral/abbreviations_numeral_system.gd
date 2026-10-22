extends NumeralSystem
class_name AbbreviationsNumeralSystem

## Mapping of abbreviation suffix to its power of 10
var suffix_map: Dictionary = NumeralRules.Abbreviation.SUFFIX_MAP
## Decimal precision for formatting
var _precision: int = 2


#region Public API
func parse(text: String) -> float:
	var trimmed: String = text.strip_edges()
	if not is_valid(trimmed):
		push_error("Invalid abbreviated numeral: " + text)
		return 0.0
	var upper: String = trimmed.to_upper()
	var suffix: String = _extract_suffix(upper)
	var number_part: String = upper.substr(0, upper.length() - suffix.length())
	if suffix == "":
		number_part = upper
	var power: int = suffix_map[suffix]
	return number_part.to_float() * pow(10.0, power)


func format(value: float) -> String:
	if value < 0.0:
		push_error("Abbreviated numerals do not support negative numbers.")
		return ""
	var abs_value: float = abs(value)
	var chosen_suffix: String = ""
	var chosen_power: int = 0
	for key in suffix_map.keys():
		var power: int = suffix_map[key]["power"]
		if abs_value >= pow(10.0, power) and power >= chosen_power:
			chosen_suffix = key
			chosen_power = power
	var divisor: float = pow(10.0, chosen_power)
	var num: float = value / divisor
	var fmt: String = "%." + str(_precision) + "f"
	var text: String = fmt % num
	text = _trim_trailing_zeros(text)
	return text + chosen_suffix
#endregion


#region Validation
func is_valid(text: String) -> bool:
	if text.is_empty():
		return false
	var upper: String = text.to_upper()
	var regex := RegEx.new()
	regex.compile("^[0-9]+(\\.[0-9]+)?(" + _suffix_regex() + ")?$")
	return regex.search(upper) != null
#endregion


#region Internal Helpers
func _extract_suffix(text: String) -> String:
	for key in suffix_map.keys():
		if key != "" and text.ends_with(key.to_upper()):
			return key
	return ""


func _suffix_regex() -> String:
	var parts: Array = []
	for key in suffix_map.keys():
		if key != "":
			parts.append(key.to_upper())
	return "(" + "|".join(parts) + ")"


func _trim_trailing_zeros(text: String) -> String:
	if "." not in text:
		return text
	while text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return text
#endregion
