## Numeral system base class
extends RefCounted
class_name NumeralSystem


#region Public API
## Convert string representation to number
func parse(text: String) -> float:
	push_error("NumeralSystem.parse() is not implemented.")
	return 0.0


## Convert number to string representation
func format(value: float) -> String:
	push_error("NumeralSystem.format() is not implemented.")
	return ""

## Optional: Parse string to BigNumber
func parse_big(text: String) -> BigNumber:
	return BigNumber.new().from_float(parse(text))

## Optional: Format BigNumber to string
func format_big(big: BigNumber) -> String:
	return format(big.to_float())
#endregion

#region Validation
## Optional: check if text is valid for this numeral system
func is_valid(text: String) -> bool:
	return true
#endregion