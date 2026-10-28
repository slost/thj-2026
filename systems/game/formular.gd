extends Node
class_name Formular


const TILE_SIZE: int = 128


## Pixels per second. Edit the multiplier to retune every unit at once.
static func calculate_move_speed(gpu: int) -> float:
	return (TILE_SIZE/4.0) + TILE_SIZE * (float(gpu) - 1.0)


## AnimationPlayer speed_scale. 1.0 plays a clip for its authored length.
static func calculate_animation_speed(gpu: int) -> float:
	return float(maxi(gpu, 1)) * 0.5


## Seconds spent in ATTACKING when the unit has no attack clip.
static func calculate_attack_duration(gpu: int) -> float:
	return 1.0 / float(maxi(gpu, 1))


## Seconds between program loops. A higher CPU thinks more often.
static func calculate_think_interval(cpu: int) -> float:
	return 0.5 / float(maxi(cpu, 1))