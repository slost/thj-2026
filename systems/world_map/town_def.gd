extends DataDef
class_name TownDef


@export var max_restore_points := 100.0
@export var is_destroyed := false
## 1 is the easiest town. Higher numbers bring more villagers and richer rewards.
@export_range(1, 5, 1) var difficulty := 1
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
		rows.append({
			"race": int(row.race),
			"count": row.count,
			"max_hp": row.max_hp,
			"damage": row.damage,
			"flees": row.flees,
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