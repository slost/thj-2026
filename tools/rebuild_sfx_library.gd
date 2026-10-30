@tool
extends EditorScript


const _ROOT := "res://contents/audio/sfx"
## First time a cue appears. Later runs keep whatever is already saved on that cue.
const _NEW_CUE_INTERVAL := {
	"general.write": 0.12,
}
const _NEW_CUE_CONCURRENT := {
	"general.write": 2,
}


func _init() -> void:
	# File > Run calls _run() afterwards. A headless `--script` launch only constructs the script.
	if Engine.is_editor_hint():
		return
	rebuild()


func _run() -> void:
	rebuild()


static func rebuild() -> void:
	var grouped := {}
	var files := _scan(_ROOT, grouped)
	var previous: SfxLibrary = null
	if ResourceLoader.exists(SfxLibrary.PATH):
		previous = load(SfxLibrary.PATH) as SfxLibrary
	var library := SfxLibrary.build(grouped, previous)
	_tune_new_cues(library, previous)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/audio"))
	library.take_over_path(SfxLibrary.PATH)
	var err := ResourceSaver.save(library, SfxLibrary.PATH)
	if err != OK:
		push_error("SFX library save failed: %s" % error_string(err))
		return
	var ids: PackedStringArray = PackedStringArray()
	for cue in library.cues:
		if cue == null:
			continue
		ids.append("%s: %d" % [cue.id, cue.streams.size()])
	ids.sort()
	print("SFX library: %d cues, %d files -> %s" % [library.cues.size(), files, SfxLibrary.PATH])
	for line in ids:
		print("  %s" % line)


static func _tune_new_cues(library: SfxLibrary, previous: SfxLibrary) -> void:
	for cue_id in _NEW_CUE_INTERVAL:
		if previous != null and previous.get_cue(cue_id) != null:
			continue
		var cue := library.get_cue(cue_id)
		if cue == null:
			continue
		cue.min_interval = float(_NEW_CUE_INTERVAL[cue_id])
		if _NEW_CUE_CONCURRENT.has(cue_id):
			cue.max_concurrent = int(_NEW_CUE_CONCURRENT[cue_id])


static func _scan(path: String, grouped: Dictionary) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("SFX folder missing: %s" % path)
		return 0
	var count := 0
	for sub in dir.get_directories():
		if sub.begins_with("."):
			continue
		count += _scan(path.path_join(sub), grouped)
	for file_name in dir.get_files():
		if file_name.get_extension().to_lower() != "ogg":
			continue
		var cue_id := SfxLibrary.parse_cue_id(file_name)
		if cue_id.is_empty():
			push_warning("SFX name not recognized: %s" % file_name)
			continue
		var stream := load(path.path_join(file_name)) as AudioStream
		if stream == null:
			push_warning("SFX failed to load: %s" % file_name)
			continue
		if not grouped.has(cue_id):
			grouped[cue_id] = []
		(grouped[cue_id] as Array).append(stream)
		count += 1
	return count
