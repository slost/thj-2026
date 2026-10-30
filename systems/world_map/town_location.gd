extends Area2D
class_name TownLocation


const _WHOLE: Array[Texture2D] = [
	preload("res://contents/assets/tex_village_1.png"),
	preload("res://contents/assets/tex_village_2.png"),
	preload("res://contents/assets/tex_village_3.png"),
	preload("res://contents/assets/tex_village_4.png"),
	preload("res://contents/assets/tex_village_5.png"),
]
const _RUINED: Array[Texture2D] = [
	preload("res://contents/assets/tex_village_destroyed_1.png"),
	preload("res://contents/assets/tex_village_destroyed_2.png"),
	preload("res://contents/assets/tex_village_destroyed_3.png"),
	preload("res://contents/assets/tex_village_destroyed_4.png"),
	preload("res://contents/assets/tex_village_destroyed_5.png"),
]
const _CAPITAL := preload("res://contents/assets/tex_capital.png")
const _CAPITAL_RUINED := preload("res://contents/assets/tex_capital_destroyed.png")

@export var def: TownDef
@export var required_locations: Array[Area2D] # The locations that are required to be completed before the village can be unlocked.

@onready var _dtag := DebugTag.new(def.name)
@onready var _squash: SquashAnimationComponent = $SquashAnimation

var restore_points := 100.0 ## The amount of restore points the village has.
var has_been_destroyed: bool = false
var _visual_ready := false
var _was_ruined := false


func _enter_tree() -> void:
	_bind_save_key()


func _ready() -> void:
	if def == null:
		def = TownDef.new()
		def.id = &"village"
		def.name = "Village"
		def.description = "A village is a place where people live."
		def.is_destroyed = false
		_bind_save_key()

	restore_points = def.max_restore_points
	sync_destroyed_state()
	_update_visual()


## SaveParticipant lives on this scene. Its key comes from the TownDef placed in the world map.
func _bind_save_key() -> void:
	var participant := get_node_or_null("SaveParticipant") as SaveParticipantComponent
	if participant == null:
		push_warning("TownLocation '%s' is missing SaveParticipant" % name)
		return

	if not participant.get_save_key().is_empty():
		return

	if def != null and not String(def.id).strip_edges().is_empty():
		participant.save_key = String(def.id)
		return

	participant.save_key = name


func get_save_key() -> String:
	var participant := get_node_or_null("SaveParticipant") as SaveParticipantComponent
	if participant == null:
		return name

	var key := participant.get_save_key()
	if key.is_empty():
		return name

	return key


func unlock() -> void:
	def.is_destroyed = false
	_update_visual()


func take_damage(amount: float) -> void:
	restore_points -= amount
	sync_destroyed_state()
	_update_visual()


## Adds restore points, never past the town's max.
func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	var ceiling := restore_points
	if def != null:
		ceiling = def.max_restore_points
	restore_points = minf(restore_points + amount, ceiling)
	_update_visual()


## Damage stays on the town until it falls below the destroyed line. Then the clear is kept and points refill.
func sync_destroyed_state() -> void:
	if def == null or restore_points >= _destroyed_threshold():
		return

	has_been_destroyed = true
	restore_points = def.max_restore_points


func reset_progress() -> void:
	has_been_destroyed = false
	if def != null:
		restore_points = def.max_restore_points


func _destroyed_threshold() -> float:
	return Game.DESTROYED_RATIO * def.max_restore_points


func is_destroyed() -> bool:
	if def == null:
		return false

	return restore_points < _destroyed_threshold()


func is_locked() -> bool:
	for location in required_locations:
		var town := location as TownLocation
		if town == null or not town.has_been_destroyed:
			return true
	return false


func lock_reason() -> String:
	if not is_locked():
		return ""
	if def != null and def.is_capital:
		return LocaleText.resolve("ui.town.capital_locked", "Destroy every other town.")
	return LocaleText.resolve("ui.town.locked_reason", "Clear the earlier towns first.")


func refresh_visual() -> void:
	_update_visual()


## Ruined art. A fallen town refills its points, so has_been_destroyed is the usual case.
func shows_ruined() -> bool:
	if has_been_destroyed:
		return true
	var maximum := def.max_restore_points if def != null else 0.0
	if maximum <= 0.0:
		return false
	return restore_points / maximum <= Formular.town_ruined_ratio()


func _update_visual() -> void:
	var ruined := shows_ruined()
	var sprite := _sprite()
	var tint_fallback := false
	if sprite != null:
		if sprite is HotSwapSprite:
			(sprite as HotSwapSprite).asset_id = ""
		if def != null and def.is_capital:
			if ruined and _CAPITAL_RUINED != null:
				sprite.texture = _CAPITAL_RUINED
			else:
				sprite.texture = _CAPITAL
				tint_fallback = ruined
		else:
			sprite.texture = _village_texture(ruined)
	if is_locked() or tint_fallback:
		modulate = UiPalette.dim(Color.WHITE)
	else:
		modulate = Color.WHITE
	if _visual_ready and ruined and not _was_ruined:
		_play_ruin_feedback()
	_was_ruined = ruined
	_visual_ready = true


func _sprite() -> Sprite2D:
	var sprite := get_node_or_null("Visual/HotSwapSprite") as Sprite2D
	if sprite != null:
		return sprite
	return get_node_or_null("Visual/PlaceholderSprite") as Sprite2D


func _village_texture(ruined: bool) -> Texture2D:
	var index := 0
	if def != null:
		index = clampi(def.art_variant, 1, 5) - 1
	if ruined:
		return _RUINED[index]
	return _WHOLE[index]


func _play_ruin_feedback() -> void:
	if _squash != null and is_instance_valid(_squash):
		_squash.play()
		var tree := get_tree()
		if tree != null:
			tree.create_timer(0.34).timeout.connect(_release_ruin_squash)


func _release_ruin_squash() -> void:
	if _squash != null and is_instance_valid(_squash):
		_squash.release()
	var library := Sfx.library
	if library != null and library.get_cue("general.dust") != null:
		Sfx.play("general.dust")


#region Signals
func _on_mouse_entered() -> void:
	_squash.play()
	var map := _world_map()
	if map != null and not is_locked():
		map.focus_location_on(self)


func _on_mouse_exited() -> void:
	var map := _world_map()
	if map != null and map.focus_location == self and not map.is_location_selected():
		map.unfocus_location()
	_squash.release()


func _world_map() -> WorldMap:
	var tree := get_tree()
	if tree == null:
		return null
	var game := tree.root.get_node_or_null(^"Game")
	if game == null:
		return null
	return game.get("world_map") as WorldMap


