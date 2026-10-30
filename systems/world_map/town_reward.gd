## One resource a town can pay out. resource_type is a Game.ResourceType value.
class_name TownReward
extends Resource


@export var resource_type: int = 0
@export var amount: int = 1


func inspector_line() -> String:
	var who := LocaleText.resolve(_name_key(), _name_fallback())
	return LocaleText.resolve("ui.town.reward_line", "{name} x{count}").format({
		"name": who,
		"count": maxi(amount, 0),
	})


func _name_key() -> String:
	match resource_type:
		1:
			return "ui.resource.bone"
		2:
			return "ui.resource.weapon"
		3:
			return "ui.resource.collar"
		4:
			return "ui.resource.gore"
		_:
			return "ui.resource.corpse"


func _name_fallback() -> String:
	match resource_type:
		1:
			return "Bone"
		2:
			return "Weapon"
		3:
			return "Collar"
		4:
			return "Gore"
		_:
			return "Corpse"
