## One group of villagers that defend a town during a raid.
class_name TownGarrison
extends Resource


@export var race: Unit2D.Race = Unit2D.Race.VILLAGER_MELEE
@export var count: int = 1
@export var max_hp: int = 16
@export var damage: int = 3
## Runs away instead of walking up to fight.
@export var flees: bool = false


func inspector_line() -> String:
	var who := LocaleText.resolve(_name_key(), _name_fallback())
	var line := LocaleText.resolve("ui.town.unit_line", "{name} x{count}").format({
		"name": who,
		"count": maxi(count, 0),
	})
	var manner_key := "ui.town.flees" if flees else "ui.town.fights"
	var manner_fallback := "flees" if flees else "fights"
	return "%s (%s)" % [line, LocaleText.resolve(manner_key, manner_fallback)]


func unit_name_key() -> String:
	return _name_key()


func _name_key() -> String:
	match race:
		Unit2D.Race.VILLAGER_RANGED:
			return "ui.town.villager_ranged"
		Unit2D.Race.WARDOG:
			return "unit.wardog"
		Unit2D.Race.HERO_MELEE:
			return "unit.hero_melee"
		Unit2D.Race.HERO_RANGED:
			return "unit.hero_ranged"
		_:
			return "ui.town.villager"


func _name_fallback() -> String:
	match race:
		Unit2D.Race.VILLAGER_RANGED:
			return "Ranged villager"
		Unit2D.Race.WARDOG:
			return "War dog"
		Unit2D.Race.HERO_MELEE:
			return "Hero"
		Unit2D.Race.HERO_RANGED:
			return "Hero archer"
		_:
			return "Villager"
