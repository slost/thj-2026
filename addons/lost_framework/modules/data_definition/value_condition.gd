extends Resource
class_name ValueCondition
## One test on a value, e.g. "the door's open is true" or "the actor
## carries the key". Used by [member DescriptionVariant.conditions] and other
## systems that need "only when ...". Comparing values of unrelated types
## (a String with a bool) is simply false, never a script error; int and
## float compare as numbers, String and StringName as text.
##
## SELF values are passed in directly (a Dictionary). Other subjects need a
## [i]context[/i]: any Object with these two methods (duck-typed, so this
## module does not depend on entities or worlds):
## [codeblock]
## func get_condition_values(subject: ValueCondition.Subject, entity_id: StringName) -> Variant
##     # Dictionary of values, or null when the subject is unknown
## func condition_carries(subject: ValueCondition.Subject, entity_id: StringName, item_id: StringName) -> bool
## [/codeblock]
## Without a context only SELF works; other subjects never match.


## Whose value is tested.
enum Subject {
	SELF, ## The thing being described or reacting.
	ENTITY, ## Another entity, by [member entity_id].
	ACTOR, ## Who acts (the player for descriptions).
	WORLD, ## World-wide values (story flags).
}

enum Op {
	EQ, ## value == [member value]
	NE, ## value != [member value] (a value of an unrelated type does not match NE either).
	LT, ## value < [member value]. LT, LE, GT and GE only hold for numbers or text.
	LE, ## value <= [member value]
	GT, ## value > [member value]
	GE, ## value >= [member value]
	EXISTS, ## The value is set (any value).
	NOT_EXISTS, ## The value is not set.
	CARRIES, ## The subject holds the entity whose id is [member value] (directly or inside something it holds). [member key] is not used.
	NOT_CARRIES, ## The opposite of CARRIES.
}

const NUMBER_TYPES: Array[int] = [TYPE_INT, TYPE_FLOAT]
const TEXT_TYPES: Array[int] = [TYPE_STRING, TYPE_STRING_NAME]

@export var subject := Subject.SELF
@export var entity_id := &"" ## For [constant Subject.ENTITY].
@export var key := &"" ## The value name, e.g. &"open".
@export var op := Op.EQ
@export var value: Variant = true


## True if the condition holds. [param self_values] are the SELF values;
## [param context] resolves the other subjects (see the class description).
func evaluate(self_values: Dictionary, context: Object = null) -> bool:
	if op == Op.CARRIES or op == Op.NOT_CARRIES:
		var carries := false
		if context and context.has_method("condition_carries"):
			carries = context.condition_carries(subject, entity_id, StringName(str(value)))
		return carries if op == Op.CARRIES else not carries

	var values: Variant = self_values
	if subject != Subject.SELF:
		values = context.get_condition_values(subject, entity_id) if context and context.has_method("get_condition_values") else null
	if not (values is Dictionary):
		return op == Op.NOT_EXISTS
	var has := (values as Dictionary).has(key)
	match op:
		Op.EXISTS:
			return has
		Op.NOT_EXISTS:
			return not has
	if not has:
		return false
	var actual: Variant = values[key]
	if op in [Op.LT, Op.LE, Op.GT, Op.GE] and not is_ordered(actual, value):
		return false # Only numbers and text have an order
	var order: Variant = compare(actual, value)
	if order == null:
		return false # Unrelated types: never matches
	match op:
		Op.EQ:
			return order == 0
		Op.NE:
			return order != 0
		Op.LT:
			return order < 0
		Op.LE:
			return order <= 0
		Op.GT:
			return order > 0
		Op.GE:
			return order >= 0
	return false


## -1, 0 or 1 when [param a] and [param b] can be compared, else null.
## Numbers (int, float) and text (String, StringName) are ordered; other
## values of the same type are only equal (0) or not (1).
static func compare(a: Variant, b: Variant) -> Variant:
	var type_a := typeof(a)
	var type_b := typeof(b)
	if type_a in NUMBER_TYPES and type_b in NUMBER_TYPES:
		var x := float(a)
		var y := float(b)
		return 0 if x == y else (-1 if x < y else 1)
	if type_a in TEXT_TYPES and type_b in TEXT_TYPES:
		var s := String(a)
		var t := String(b)
		return 0 if s == t else (-1 if s < t else 1)
	if type_a != type_b:
		return null
	return 0 if a == b else 1


## True if [param a] and [param b] are both numbers or both text, so
## LT, LE, GT and GE can compare them.
static func is_ordered(a: Variant, b: Variant) -> bool:
	return (typeof(a) in NUMBER_TYPES and typeof(b) in NUMBER_TYPES) or (typeof(a) in TEXT_TYPES and typeof(b) in TEXT_TYPES)


## True if [param a] equals [param b] by [method compare] (false for unrelated types).
static func same_value(a: Variant, b: Variant) -> bool:
	return compare(a, b) == 0


## True if every name in [param when] has an equal value in [param values]
## (the older Dictionary form of conditions). A missing value does not match.
static func when_matches(when: Dictionary, values: Dictionary) -> bool:
	for value_name in when:
		var name_key := StringName(value_name)
		if not values.has(name_key):
			return false
		if not same_value(values[name_key], when[value_name]):
			return false
	return true


## True if every condition in [param conditions] holds (an empty list holds).
static func all_hold(conditions: Array, self_values: Dictionary, context: Object = null) -> bool:
	for condition in conditions:
		if condition and not condition.evaluate(self_values, context):
			return false
	return true
