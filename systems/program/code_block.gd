## Base class for every block. Blocks are shared .tres assets:
## never store per-unit runtime state in here (use ExecContext or Unit2D).
extends DataDef
class_name CodeBlock


enum Rarity { COMMON, UNCOMMON, RARE, CURSED }

@export var rarity: Rarity = Rarity.COMMON
## How many MB of the unit's RAM this block uses. Nested blocks add their own cost.
@export var mb_cost: int = 1


func _domain_id() -> StringName:
	return "code"


func get_block_label() -> String:
	return name if not name.is_empty() else "block"


func get_mb_cost() -> int:
	return maxi(mb_cost, 0)