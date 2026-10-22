extends RefCounted
class_name JsonSaveSerializer


#region Public API
func serialize(payload: Dictionary) -> String:
	return JSON.stringify(payload, "\t")


func deserialize(raw: String) -> Dictionary:
	var json := JSON.new()
	var error: Error = json.parse(raw)

	if error != OK:
		push_error("JsonSaveSerializer: failed to parse JSON")
		return {}

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("JsonSaveSerializer: parsed data is not a Dictionary")
		return {}

	return json.data
#endregion