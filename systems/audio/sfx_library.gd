extends Resource
class_name SfxLibrary


const PATH := "res://data/audio/sfx_library.tres"

@export var cues: Array[SfxCue] = []


func get_cue(id: String) -> SfxCue:
	for cue in cues:
		if cue != null and cue.id == id:
			return cue
	return null


## "sfx_zombie_spawn.ogg" -> "zombie.spawn".
## "sfx_skeleton_spawn_02.ogg" -> "skeleton.spawn".
## "sfx_necromancer_laugh_soft_01.ogg" -> "necromancer.laugh_soft".
## A trailing "_NN" index is a variation, not part of the action. Empty when the name does not match.
static func parse_cue_id(file_name: String) -> String:
	var base := file_name.get_file().get_basename()
	if not base.begins_with("sfx_"):
		return ""
	var parts := base.substr(4).split("_")
	if parts.size() < 2:
		return ""
	var end := parts.size()
	if parts.size() >= 3 and parts[end - 1].is_valid_int():
		end -= 1
	if end < 2:
		return ""
	var folder := parts[0]
	if folder.is_empty():
		return ""
	var action := ""
	for index in range(1, end):
		if parts[index].is_empty():
			return ""
		if not action.is_empty():
			action += "_"
		action += parts[index]
	if action.is_empty():
		return ""
	return "%s.%s" % [folder, action]


## Groups are cue id -> Array of AudioStream. Settings on [param previous] are copied onto matching ids.
static func build(grouped: Dictionary, previous: SfxLibrary) -> SfxLibrary:
	var library := SfxLibrary.new()
	var ids: Array = grouped.keys()
	ids.sort()
	for id in ids:
		var cue_id := str(id)
		var cue := SfxCue.new()
		cue.id = cue_id
		var old := previous.get_cue(cue_id) if previous != null else null
		if old != null:
			cue.volume = old.volume
			cue.pitch_range = old.pitch_range
			cue.max_concurrent = old.max_concurrent
			cue.min_interval = old.min_interval
		var streams: Array[AudioStream] = []
		var raw: Array = grouped[id]
		raw = raw.duplicate()
		raw.sort_custom(func(a: AudioStream, b: AudioStream) -> bool:
			return a.resource_path < b.resource_path
		)
		for item in raw:
			var stream := item as AudioStream
			if stream != null:
				streams.append(stream)
		cue.streams = streams
		library.cues.append(cue)
	return library
