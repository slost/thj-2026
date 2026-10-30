## One summon race: combat stats, the spec's CPU/GPU bases, the unlock price,
## and the extra materials every summon of this race costs.
## Files live in data/races. Corpse and gore amounts are not stored here;
## Formular turns those into CPU, GPU, and RAM on top of the race bases.
class_name RaceProfile
extends Resource

@export var race: Unit2D.Race = Unit2D.Race.ZOMBIE
## LocaleText key, for example "ui.race.zombie".
@export var display_name_key: String = ""
@export var max_hp: int = 30
@export var damage: int = 5
@export var attack_range: int = 1
@export var detect_range: int = 4
@export var attack_cooldown: float = 1.0
@export var base_cpu: int = 1
@export var base_gpu: int = 1
## Added to the spell slot's base RAM. May be negative. The result is at least 1.
@export var ram_bonus: int = 0
@export var unlock_costs: Array[SummonCost] = []
## Paid on every summon, after the spell's corpse and gore. Zombie has none.
@export var summon_extras: Array[SummonCost] = []
@export var starts_unlocked: bool = false
## Idle frame from the race sheet. Used as the spec portrait and the slot icon.
@export var icon: Texture2D


func display_name() -> String:
	return LocaleText.resolve(display_name_key, _fallback_name())


func _fallback_name() -> String:
	match race:
		Unit2D.Race.ZOMBIE:
			return "Zombie"
		Unit2D.Race.SKELETON_MELEE:
			return "Skeleton"
		Unit2D.Race.SKELETON_RANGED:
			return "Skeleton archer"
		Unit2D.Race.DIRE_WOLF:
			return "Dire wolf"
		_:
			return "Minion"
