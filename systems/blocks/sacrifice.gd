## Give this minion up. Half of what was spent to summon them comes back, picked at random.
extends ActionBlock


const _Summoner := preload("res://systems/game/summoner.gd")


func _init() -> void:
	name = "Sacrifice"


func step(unit: Unit2D, _ctx: ExecContext) -> StepResult:
	if unit == null or unit.state == Unit2D.State.DEAD:
		return StepResult.CANCELLED
	if unit.state == Unit2D.State.SPAWNING:
		return StepResult.RUNNING
	_Summoner.refund_unit(unit)
	unit.die()
	return StepResult.DONE
