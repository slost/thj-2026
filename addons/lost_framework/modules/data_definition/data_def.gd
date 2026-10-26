extends Resource
class_name DataDef


## Value types that can be used as description placeholders and conditions.
const PLAIN_TYPES: Array[int] = [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]

@export var id := &""
@export var name := ""
@export_multiline var description := "" ## May contain placeholders like "{damage}".
## Checked in order: the first matching REPLACE variant replaces [member description],
## every matching APPEND variant adds its text after it.
@export var description_variants: Array[DescriptionVariant] = []


## Override this to change the domain id
func _domain_id() -> StringName:
	return &"data"


## The name in [param locale] (empty: the output language, see
## [LocaleText]): the translation "<domain>.<id>.name", else [member name].
func get_display_name(locale := "") -> String:
	return LocaleText.resolve("%s.%s.name" % [_domain_id(), id], name, locale)


## Returns the localized description with placeholders filled in.
## [param values] (e.g. current stats or state of an instance) override this
## definition's own exported values, and are also used to pick a variant.
## [param context] lets variant conditions read other subjects (see [ValueCondition]).
## Example: description "Damage {damage}" with [code]{"damage": 7}[/code] gives "Damage 7".
func get_display_description(values: Dictionary = {}, context: Object = null) -> String:
	var all_values := get_values()
	all_values.merge(values, true)
	return _pick_description(all_values, context).format(all_values)


## Returns this definition's own exported values of plain types, used as
## defaults for placeholders (e.g. an ItemDef with [code]@export var damage := 5[/code]).
func get_values() -> Dictionary:
	var result := {}
	for property in get_property_list():
		var usage: int = property["usage"]
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (usage & PROPERTY_USAGE_STORAGE):
			continue
		var value: Variant = get(property["name"])
		if typeof(value) in PLAIN_TYPES:
			result[property["name"]] = value
	return result


## The first matching REPLACE variant (or [member description]), followed by
## the text of every matching APPEND variant, separated by spaces.
func _pick_description(values: Dictionary, context: Object = null) -> String:
	var base := ""
	var replaced := false
	var appended: PackedStringArray = []
	for variant in description_variants:
		if variant == null or not variant.matches(values, context):
			continue
		var text := _localized("desc.%s" % variant.key, variant.text) if variant.key != &"" else variant.text
		if variant.mode == DescriptionVariant.Mode.APPEND:
			appended.append(text)
		elif not replaced:
			base = text
			replaced = true
	if not replaced:
		base = _localized("desc", description)
	for text in appended:
		if not text.is_empty():
			base = text if base.is_empty() else base + " " + text
	return base


## The translation "<domain>.<id>.<suffix>" in the output language, else
## [param fallback] (see [method LocaleText.resolve]).
func _localized(suffix: String, fallback: String, locale := "") -> String:
	return LocaleText.resolve("%s.%s.%s" % [_domain_id(), id, suffix], fallback, locale)
