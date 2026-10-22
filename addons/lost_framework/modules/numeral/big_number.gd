extends RefCounted
class_name BigNumber


#region Variables
var mantissa: float = 0.0
var exponent: int = 0
#endregion


#region Public API
## Constructor
func _init(m: float = 0.0, e: int = 0) -> void:
	mantissa = m
	exponent = e
	_normalize()

## Create BigNumber from float
func from_float(value: float) -> BigNumber:
	if value == 0.0:
		mantissa = 0.0
		exponent = 0
		return self
	exponent = int(floor(log(abs(value)) / log(10.0)))
	mantissa = value / pow(10.0, exponent)
	_normalize()
	return self


## Convert BigNumber to float (may lose precision for very large numbers)
func to_float() -> float:
	return mantissa * pow(10.0, exponent)


## Set value directly
func set_value(m: float, e: int) -> BigNumber:
	mantissa = m
	exponent = e
	_normalize()
	return self


## Add another BigNumber
func add(other: BigNumber) -> BigNumber:
	if mantissa == 0.0:
		return other.clone()
	if other.mantissa == 0.0:
		return clone()
	var diff: int = exponent - other.exponent
	if abs(diff) > 15:
		return clone() if diff > 0 else other.clone()
	var result: BigNumber = BigNumber.new()
	if diff >= 0:
		result.exponent = exponent
		result.mantissa = mantissa + other.mantissa / pow(10.0, diff)
	else:
		result.exponent = other.exponent
		result.mantissa = mantissa / pow(10.0, -diff) + other.mantissa
	result._normalize()
	return result


## Multiply another BigNumber
func multiply(other: BigNumber) -> BigNumber:
	var result: BigNumber = BigNumber.new()
	result.mantissa = mantissa * other.mantissa
	result.exponent = exponent + other.exponent
	result._normalize()
	return result


## Compare with another BigNumber (-1, 0, 1)
func compare(other: BigNumber) -> int:
	if exponent > other.exponent:
		return 1
	if exponent < other.exponent:
		return -1
	if mantissa > other.mantissa:
		return 1
	if mantissa < other.mantissa:
		return -1
	return 0


## Clone this BigNumber
func clone() -> BigNumber:
	var copy: BigNumber = BigNumber.new()
	copy.mantissa = mantissa
	copy.exponent = exponent
	return copy
#endregion


#region Internal Helpers
func _normalize() -> void:
	if mantissa == 0.0:
		exponent = 0
		return
	while abs(mantissa) >= 10.0:
		mantissa /= 10.0
		exponent += 1
	while abs(mantissa) < 1.0:
		mantissa *= 10.0
		exponent -= 1
#endregion
