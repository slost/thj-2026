extends DataDef
class_name TownDef


@export var max_restore_points := 100.0
@export var is_destroyed := false
## 1 is the easiest town. Higher numbers bring more defenders and richer rewards.
@export_range(1, 5, 1) var difficulty := 1
## Which tex_village_N / tex_village_destroyed_N pair this town shows. The capital ignores this.
@export_range(1, 5, 1) var art_variant := 1
## The last town. Clearing it wins the game.
@export var is_capital := false
@export var garrison: Array[TownGarrison] = []
@export var rewards: Array[TownReward] = []


func _domain_id() -> StringName:
	return "location"


func unit_count() -> int:
	var total := 0
	for row in garrison:
		if row != null:
			total += maxi(row.count, 0)
	return total


func garrison_snapshot() -> Array:
	var rows: Array = []
	for row in garrison:
		if row == null or row.count <= 0:
			continue
		var race := row.race
		var flees := row.flees and not Unit2D.race_never_flees(race)
		rows.append({
			"race": int(race),
			"count": row.count,
			"max_hp": Formular.garrison_hp(race, difficulty),
			"damage": Formular.garrison_damage(race, difficulty),
			"flees": flees,
		})
	return rows


func reward_snapshot() -> Array:
	var rows: Array = []
	for reward in rewards:
		if reward == null or reward.amount <= 0:
			continue
		rows.append({
			"resource_type": reward.resource_type,
			"amount": reward.amount,
		})
	return rows