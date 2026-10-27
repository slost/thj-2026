## Base class for every block. Blocks are shared .tres assets:
## never store per-unit runtime state in here (use ExecContext or Unit2D).
extends DataDef
class_name CodeBlock


enum Rarity { COMMON, UNCOMMON, RARE, CURSED }

@export var rarity: Rarity = Rarity.COMMON


func _domain_id() -> StringName:
	return "code"