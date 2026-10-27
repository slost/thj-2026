## Runtime stats for a unit. UnitDef is used to create a UnitStats instance.
extends Resource
class_name UnitStats


var max_hp: int = 30
var hp: int = 30
var speed: float = 60.0
var damage: int = 5
var attack_range: int = 2 ## tiles
var attack_cooldown: float = 1.0
var detect_range: int = 4 ## tiles
var cpu: float = 1.0
var ram: int = 3
var mb: int = 1


static func from_def(def: UnitDef) -> UnitStats:
	var stats := UnitStats.new()
	stats.max_hp = def.max_hp
	stats.hp = def.max_hp
	stats.speed = def.speed
	stats.damage = def.damage
	stats.attack_range = def.attack_range
	stats.attack_cooldown = def.attack_cooldown
	stats.detect_range = def.detect_range
	stats.cpu = def.cpu
	stats.ram = def.ram
	stats.mb = def.mb
	return stats
