extends Area2D
class_name TownLocation


@export var def: TownDef
@export var required_locations: Array[Area2D] # The locations that are required to be completed before the village can be unlocked.

@onready var _dtag := DebugTag.new(def.name)
@onready var _squash: SquashAnimationComponent = $SquashAnimation

var restore_points := 100.0 ## The amount of restore points the village has.
var has_been_destroyed: bool = false


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


func refresh_visual() -> void:
	_update_visual()


func _update_visual() -> void:
	if is_locked():
		modulate = Color.LIGHT_GRAY
	elif is_destroyed():
		modulate = Color.RED
	else:
		modulate = Color.WHITE


#region Signals
func _on_mouse_entered() -> void:
	_squash.play()
	if not is_locked():
		Game.world_map.focus_location_on(self)


func _on_mouse_exited() -> void:
	if Game.world_map.focus_location == self and not Game.world_map.is_location_selected():
		Game.world_map.unfocus_location()
	_squash.release()


