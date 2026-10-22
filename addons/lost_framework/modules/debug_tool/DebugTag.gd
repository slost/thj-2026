## DebugTag is a class that helps to print debug messages with a tag.
class_name DebugTag


var name: String = ""
var enabled: bool = true


func _init(_name: String) -> void:
    self.name = _name


func get_tag() -> String:
    return "[%s] " % name


func set_enabled(value: bool) -> void:
    self.enabled = value


func print(message: Variant) -> void:
    if not enabled:
        return
    print(get_tag(), message)


func push_error(message: Variant) -> void:
    if not enabled:
        return
    push_error(get_tag(), message)


func push_warning(message: Variant) -> void:
    if not enabled:
        return
    push_warning(get_tag(), message)
