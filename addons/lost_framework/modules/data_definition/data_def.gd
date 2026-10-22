extends Resource
class_name DataDef


@export var id := ""
@export var name := ""
@export_multiline var description := ""


## Override this to change the domain id
func _domain_id() -> String:
	return "data"


func get_display_name() -> String:
	var key := "%s.%s.name" % [_domain_id(), id]
	var localized := tr(key)
	return localized if localized != key else name


func get_display_description() -> String:
	var key := "%s.%s.desc" % [_domain_id(), id]
	var localized := tr(key)
	return localized if localized != key else description
