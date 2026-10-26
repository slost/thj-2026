extends HBoxContainer


@export var resource_type: Game.ResourceType
@export var resource_icon: TextureRect
@export var resource_label: Label


func _ready() -> void:
	resource_icon.set("asset_id", Game.resource_icon_id(resource_type))
	Game.resource_changed.connect(self._on_resource_changed)


func _on_resource_changed() -> void:
	var amount: int = Game.get_resource(resource_type)
	resource_label.text = str(amount)
