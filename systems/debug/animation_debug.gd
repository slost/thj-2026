extends Node2D

const _CLIPS: Array[StringName] = [&"spawn", &"idle", &"walk", &"attack", &"hurt", &"dead"]

@onready var _preview: Node2D = $Preview
@onready var _race_option: OptionButton = $UI/Panel/Margin/Column/RaceOption
@onready var _clip_option: OptionButton = $UI/Panel/Margin/Column/ClipOption
@onready var _sequence_button: Button = $UI/Panel/Margin/Column/SequenceButton
@onready var _loop_check: CheckBox = $UI/Panel/Margin/Column/LoopCheck
@onready var _gpu_spin: SpinBox = $UI/Panel/Margin/Column/GpuSpin
@onready var _cpu_spin: SpinBox = $UI/Panel/Margin/Column/CpuSpin
@onready var _speed_label: Label = $UI/Panel/Margin/Column/SpeedLabel
@onready var _status_label: Label = $UI/Panel/Margin/Column/StatusLabel

var _player: AnimationPlayer
var _visual: Node2D
var _sequence := false
var _sequence_index := 0


func _ready() -> void:
	for race_name in Unit2D.Race.keys():
		_race_option.add_item(race_name)
	for clip in _CLIPS:
		_clip_option.add_item(String(clip))
	_race_option.select(0)
	_clip_option.select(0)
	_gpu_spin.value = 1
	_race_option.item_selected.connect(_on_race_selected)
	_clip_option.item_selected.connect(_on_clip_selected)
	_sequence_button.pressed.connect(_on_sequence_pressed)
	_loop_check.toggled.connect(_on_loop_toggled)
	_gpu_spin.value_changed.connect(_on_gpu_changed)
	_cpu_spin.value_changed.connect(_on_cpu_changed)
	_mount_race(0)
	_apply_speed()
	_play_selected()


func _on_race_selected(index: int) -> void:
	var sequencing := _sequence
	_mount_race(index)
	_apply_speed()
	if sequencing:
		_start_sequence()
	else:
		_play_selected()


func _on_clip_selected(_index: int) -> void:
	_play_selected()


func _on_sequence_pressed() -> void:
	_start_sequence()


func _on_loop_toggled(_enabled: bool) -> void:
	if _sequence:
		return
	_play_selected()


func _on_gpu_changed(_value: float) -> void:
	_apply_speed()


func _on_cpu_changed(_value: float) -> void:
	_apply_speed()


func _on_animation_finished(anim_name: StringName) -> void:
	if not _sequence or _sequence_index < 0 or _sequence_index >= _CLIPS.size():
		return
	if anim_name != _CLIPS[_sequence_index]:
		return
	_advance_sequence()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://systems/debug/debug_rooms.tscn")


func _mount_race(index: int) -> void:
	if _visual != null:
		_visual.free()
		_visual = null
		_player = null
	var race := index as Unit2D.Race
	var scene := load(Unit2D.scene_path_for_race(race)) as PackedScene
	if scene == null:
		_status_label.text = "Missing scene for %s" % Unit2D.Race.keys()[index]
		return
	var visual := scene.instantiate() as Node2D
	if visual == null:
		_status_label.text = "Scene for %s is not a Node2D" % Unit2D.Race.keys()[index]
		return
	visual.name = "Visual"
	_preview.add_child(visual)
	_visual = visual
	_player = visual.get_node_or_null("AnimationPlayer") as AnimationPlayer
	_own_animation_library()
	if _player != null and not _player.animation_finished.is_connected(_on_animation_finished):
		_player.animation_finished.connect(_on_animation_finished)
	if Unit2D.is_villager_race(race):
		Unit2D.randomize_villager_sprites(visual)
	_status_label.text = ""


func _play_selected() -> void:
	_sequence = false
	if _player == null:
		return
	var clip := _selected_clip()
	if not _player.has_animation(clip):
		_status_label.text = "No clip '%s'" % clip
		return
	_status_label.text = ""
	_apply_loop(clip, _loop_check.button_pressed)
	_player.play(clip)


func _start_sequence() -> void:
	_sequence = true
	_sequence_index = -1
	_advance_sequence()


func _advance_sequence() -> void:
	if _player == null:
		_sequence = false
		return
	var checked := 0
	while checked < _CLIPS.size():
		_sequence_index += 1
		if _sequence_index >= _CLIPS.size():
			if not _loop_check.button_pressed:
				_sequence = false
				_status_label.text = ""
				return
			_sequence_index = 0
		checked += 1
		var clip := _CLIPS[_sequence_index]
		if not _player.has_animation(clip):
			continue
		_status_label.text = "Sequence: %s" % clip
		_apply_loop(clip, false)
		_player.play(clip)
		return
	_sequence = false
	_status_label.text = "No clips to play"


func _apply_speed() -> void:
	var gpu := int(_gpu_spin.value)
	var cpu := int(_cpu_spin.value)
	var speed := Formular.calculate_animation_speed(gpu, cpu)
	if _player != null:
		_player.speed_scale = speed
	_speed_label.text = "speed_scale %.2f" % speed


## The packed scene shares its library. Copy it before changing loop mode.
func _own_animation_library() -> void:
	if _player == null:
		return
	var source := _player.get_animation_library(&"")
	if source == null:
		return
	var copy := source.duplicate(true) as AnimationLibrary
	if copy == null:
		return
	_player.remove_animation_library(&"")
	_player.add_animation_library(&"", copy)


func _apply_loop(clip: StringName, should_loop: bool) -> void:
	if _player == null or not _player.has_animation(clip):
		return
	var anim := _player.get_animation(clip)
	if anim == null:
		return
	anim.loop_mode = Animation.LOOP_LINEAR if should_loop else Animation.LOOP_NONE


func _selected_clip() -> StringName:
	var index := _clip_option.selected
	if index < 0 or index >= _CLIPS.size():
		return &"idle"
	return _CLIPS[index]
