extends Node
class_name Formular


const TILE_SIZE: int = 128


## Pixels per second. GPU sets the pace. Each CPU above 1 adds a small bonus.
static func calculate_move_speed(gpu: int, cpu: int) -> float:
	var from_gpu := (TILE_SIZE / 4.0) + TILE_SIZE * (float(gpu) - 1.0)
	var from_cpu := (TILE_SIZE / 16.0) * float(maxi(cpu, 1) - 1)
	return from_gpu + from_cpu


## AnimationPlayer speed_scale. 1.0 plays a clip for its authored length.
static func calculate_animation_speed(gpu: int, cpu: int = 1) -> float:
	return 0.3 + (float(maxi(gpu, 1)) * 0.2)


## Seconds spent in ATTACKING when the unit has no attack clip.
static func calculate_attack_duration(gpu: int) -> float:
	return 1.0 / float(maxi(gpu, 1))


## Seconds spent reading one script line. A higher CPU reaches the next line sooner.
static func calculate_think_interval(cpu: int) -> float:
	return 0.5 / float(maxi(cpu, 1))


## RAM added by one remembered target or one queued action.
static func memory_slot_cost() -> int:
	return 1