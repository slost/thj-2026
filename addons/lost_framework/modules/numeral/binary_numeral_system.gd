extends NumeralSystem
class_name BinaryNumeralSystem


#region Public API
func parse(text: String) -> float:
	var upper := text.strip_edges()
	if not is_valid(upper):
		push_error("Invalid binary numeral: " + text)
		return 0.0
	var total := 0
	for c in upper:
		total = total * 2 + int(c)
	return float(total)


func format(value: float) -> String:
	var num := int(value)
	if num < 0:
		push_error("Binary numerals do not support negative numbers.")
		return ""
	if num == 0:
		return "0"
	var result := ""
	while num > 0:
		result = str(num % 2) + result
		num /= 2
	return result
#endregion

#region Validation
func is_valid(text: String) -> bool:
	if text.is_empty():
		return false
	for c in text:
		if c != "0" and c != "1":
			return false
	return true
#endregion
