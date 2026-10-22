extends Resource
class_name VisualDef


@export_group("States")
@export var states: Dictionary[StringName, VisualState]

@export_group("Playback")
## Clips installed on [Visual2D] when this definition is applied.
## A state can name a clip here without a slash. Names that already exist on the player win.
@export var animation_library: AnimationLibrary


## Returns the state stored under [param state_name].
## Looks up [StringName] first, then the same text as a [String].
## Returns null when the state is missing. It does not substitute [code]default[/code].
func get_visual_state(state_name: StringName = &"default") -> VisualState:
	if states.has(state_name):
		return states[state_name]
	var key := String(state_name)
	if states.has(key):
		return states[key]
	return null
