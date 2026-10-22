extends NumeralSystem
class_name RomanNumeralSystem


#region Public API
func parse(text: String) -> float:
	var upper := text.to_upper()
	if not is_valid(upper):
		push_error("Invalid Roman numeral: " + text)
		return 0.0
	var total := 0
	var prev := 0
	for i in range(upper.length() - 1, -1, -1):
		var c := upper[i]
		var value := NumeralRules.Roman.SYMBOL_VALUES[c] as int
		if value < prev:
			total -= value
		else:
			total += value
			prev = value
	return float(total)


## Convert number to string representation
func format(value: float) -> String:
	var num := int(value)
	if num <= 0:
		push_error("Roman numerals do not support zero or negative numbers.")
		return ""
	var result := ""
	var table := NumeralRules.Roman.get_encoding_table()
	for pair in table:
		var symbol := pair[0] as String
		var val := pair[1] as float
		while num >= val:
			result += symbol
			num -= val
	return result
#endregion

#region Validation
func is_valid(text: String) -> bool:
	var upper := text.to_upper()
	var regex := RegEx.new()
	regex.compile("^M{0,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})$")
	return regex.search(upper) != null
#endregion
