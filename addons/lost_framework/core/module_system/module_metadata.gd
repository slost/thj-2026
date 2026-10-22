# Module Metadata Resource
extends Resource
class_name ModuleMetadata


enum Type {
    RUNTIME,
    PASSIVE
}

enum Role {
    CORE,
    EXTENSION,
    TOOLING
}


@export var id: String = "undefined_module"
@export var name: String = "Unnamed Module"
@export var version: String = "0.0.1"
@export var type: Type = Type.PASSIVE
@export var role: Role = Role.EXTENSION
@export var description: String = ""

@export var is_autoload: bool = false
@export var category: String = ""


func load_from_json(data: Dictionary) -> void:
    id = data.get("id", "")
    name = data.get("name", name)
    version = data.get("version", version)
    description = data.get("description", description)
    is_autoload = data.get("autoload", is_autoload)
    category = data.get("category", category)