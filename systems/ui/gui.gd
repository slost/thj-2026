extends Node


@export var portrait: HotSwapSprite


var _fullscreen_requested := false


func _ready() -> void:
	update_portrait()
	if _fullscreen_requested or not OS.has_feature("web"):
		return

	_fullscreen_requested = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func get_portrait() -> HotSwapSprite:
	return portrait if portrait else HotSwapSprite.new()


func update_portrait() -> void:
	var texture_id := ""
	if Game.current_stage is WorldMap:
		var state := (Game.current_stage as WorldMap).current_state
		match state:
			WorldMap.State.MAP:
				texture_id = "tex_portrait_idle"
			WorldMap.State.FOCUS:
				texture_id = "tex_portrait_point"
			WorldMap.State.CAMP:
				texture_id = "tex_portrait_evil"
			WorldMap.State.CODE:
				texture_id = "tex_portrait_write"
	else:
		texture_id = "tex_portrait_evil" # TODO: add more portrait states for battle

	set_portrait(texture_id)


func set_portrait(texture_id: String) -> void:
	if portrait:
		portrait.set("asset_id", texture_id)


