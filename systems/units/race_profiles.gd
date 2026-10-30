## Loads the four summon races from data/races.
class_name RaceProfiles
extends RefCounted

const _FILES: Array[String] = [
	"res://data/races/zombie.tres",
	"res://data/races/skeleton_melee.tres",
	"res://data/races/skeleton_range.tres",
	"res://data/races/dire_wolf.tres",
]

static var _loaded := false
static var _list: Array[RaceProfile] = []
static var _by_race: Dictionary = {}


static func all() -> Array[RaceProfile]:
	_ensure()
	return _list


static func get_profile(race: Unit2D.Race) -> RaceProfile:
	_ensure()
	return _by_race.get(race, null) as RaceProfile


## Portrait filling a spell-slot button. [param bottom_inset] leaves room for a cost row.
static func mount_slot_icon(button: Button, race: Unit2D.Race, bottom_inset: float = 8.0) -> void:
	if button == null:
		return
	var icon := button.get_node_or_null(^"RaceIcon") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "RaceIcon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(icon)
		button.clip_contents = true
	icon.anchor_left = 0.0
	icon.anchor_top = 0.0
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.offset_left = 8.0
	icon.offset_top = 8.0
	icon.offset_right = -8.0
	icon.offset_bottom = -bottom_inset
	var profile := get_profile(race)
	icon.texture = profile.icon if profile != null else null
	icon.visible = icon.texture != null


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	for path in _FILES:
		var profile := load(path) as RaceProfile
		if profile == null:
			push_error("RaceProfiles: missing %s" % path)
			continue
		_list.append(profile)
		_by_race[profile.race] = profile
