## Store the nearest unit currently in detect range. Runs when the line is read.
extends ActionBlock
class_name RememberTarget

enum Seen { ANY, HOSTILE, ALLY }

@export var seen: Seen = Seen.HOSTILE


func _init() -> void:
	name = "RememberTarget"


func runs_immediately() -> bool:
	return true


func execute(unit: Unit2D, _ctx: ExecContext) -> void:
	var found: Unit2D = null
	match seen:
		Seen.HOSTILE:
			found = unit.find_preferred_enemy()
		Seen.ALLY:
			found = unit.find_nearest_ally()
		_:
			found = unit.find_nearest_unit()
	if found:
		unit.remember_target(found)
