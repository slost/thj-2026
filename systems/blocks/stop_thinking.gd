extends ActionBlock
class_name StopThinking


func _init() -> void:
	name = "StopThinking"


func runs_immediately() -> bool:
	return true


func execute(_unit: Unit2D, ctx: ExecContext) -> void:
	ctx.stop_reading = true
