extends Resource
class_name DescriptionVariant
## An alternative description used when its conditions hold, e.g.
## [code]{"open": true}[/code] -> "The door stands open.". With [member mode]
## APPEND its text is added after the description instead of replacing it.


enum Mode {
	REPLACE, ## Used instead of the description (the first matching REPLACE variant wins).
	APPEND, ## Added after the description; every matching APPEND variant adds its text, in order.
}

@export var key := &"" ## Optional localization suffix: "<domain>.<id>.desc.<key>".
## Value name -> required value (equality). Empty always matches. Kept for
## simple cases; [member conditions] can do more.
@export var when: Dictionary = {}
## Every condition must hold too. Other subjects than SELF (another entity,
## the actor, the world) need a context, see [ValueCondition].
@export var conditions: Array[ValueCondition] = []
@export var mode := Mode.REPLACE
@export_multiline var text := "" ## May contain placeholders like "{hp}".


## True if [member when] and every one of [member conditions] hold.
## [param values] are the SELF values; [param context] resolves other subjects.
func matches(values: Dictionary, context: Object = null) -> bool:
	return ValueCondition.when_matches(when, values) and ValueCondition.all_hold(conditions, values, context)
