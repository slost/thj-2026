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
	return 4.0 / float(maxi(cpu, 1))


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


## Whole resources paid for one reward line. lost_ratio 0 pays nothing, 1 pays the full amount.
## Halves round away from zero.
static func raid_reward_payout(amount: int, lost_ratio: float) -> int:
	if amount <= 0:
		return 0
	var scaled := float(amount) * clampf(lost_ratio, 0.0, 1.0)
	return maxi(roundi(scaled), 0)


## Spec tunables. Corpse is the brain and raises CPU. Gore is the body and raises GPU.
## Each CPU step above the race base adds 4 RAM. Each GPU step above the race base adds 2 RAM.
## The first of each ingredient is included in the race's base. Each one after that adds the per-step below.
static func spec_min_ingredient() -> int:
	return 1


static func spec_max_ingredient() -> int:
	return 5


static func spec_cpu_per_corpse() -> int:
	return 1


static func spec_gpu_per_gore() -> int:
	return 1


## RAM gained for one CPU step, and for one GPU step, above the race base.
static func spec_ram_per_cpu() -> int:
	return 4


static func spec_ram_per_gpu() -> int:
	return 2


## base_cpu plus one step for every corpse above the first. corpse_amount is clamped to the spec range.
static func spec_cpu(base_cpu: int, corpse_amount: int) -> int:
	var corpse := clampi(corpse_amount, spec_min_ingredient(), spec_max_ingredient())
	return base_cpu + (corpse - 1) * spec_cpu_per_corpse()


## base_gpu plus one step for every gore above the first. gore_amount is clamped to the spec range.
static func spec_gpu(base_gpu: int, gore_amount: int) -> int:
	var gore := clampi(gore_amount, spec_min_ingredient(), spec_max_ingredient())
	return base_gpu + (gore - 1) * spec_gpu_per_gore()


## Slot RAM after the race bonus, plus 4 per extra CPU and 2 per extra GPU. Never below 1.
static func spec_ram(base_ram: int, corpse_amount: int, gore_amount: int) -> int:
	var corpse := clampi(corpse_amount, spec_min_ingredient(), spec_max_ingredient())
	var gore := clampi(gore_amount, spec_min_ingredient(), spec_max_ingredient())
	var extra_cpu := (corpse - 1) * spec_cpu_per_corpse()
	var extra_gpu := (gore - 1) * spec_gpu_per_gore()
	var adjusted := base_ram + extra_cpu * spec_ram_per_cpu() + extra_gpu * spec_ram_per_gpu()
	return maxi(1, adjusted)