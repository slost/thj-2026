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


## Share of a town's max restore points that one raid can take.
static func raid_stake_ratio() -> float:
	return 0.3


## Restore points lost from one raid.
## lost_ratio is 0 when every villager is still up, and 1 when all of them are down.
static func raid_damage(town_max_points: float, lost_ratio: float) -> float:
	return town_max_points * raid_stake_ratio() * clampf(lost_ratio, 0.0, 1.0)


## Lowest share of max restore points another town regains after a raid.
static func town_recover_min_ratio() -> float:
	return 0.10


## Highest share of max restore points another town regains after a raid.
static func town_recover_max_ratio() -> float:
	return 0.15


## Random heal for a town that was not the one just raided.
## The roll includes both town_recover_min_ratio and town_recover_max_ratio.
static func town_recover_amount(town_max_points: float, rng: RandomNumberGenerator) -> float:
	var ratio := rng.randf_range(town_recover_min_ratio(), town_recover_max_ratio())
	return town_max_points * ratio