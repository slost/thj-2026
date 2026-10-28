## Drop remembered targets, queued actions, or both. Runs when the line is read.
extends ActionBlock
class_name ForgetMemory

enum Slot { TARGETS, ACTIONS, EVERYTHING }
enum Which { FIRST, LAST, ALL }

@export var slot: Slot = Slot.TARGETS
@export var which: Which = Which.FIRST


func _init() -> void:
	name = "ForgetMemory"


func runs_immediately() -> bool:
	return true


func execute(unit: Unit2D, _ctx: ExecContext) -> void:
	match slot:
		Slot.ACTIONS:
			unit.forget_actions(which)
		Slot.EVERYTHING:
			unit.forget_everything()
		_:
			unit.forget_targets(which)
