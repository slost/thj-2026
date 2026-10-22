@tool
extends VBoxContainer

const AUTOLOADS_PATH := "res://addons/lost_framework/core/autoloads/"


func _ready() -> void:
	_build()


func _build() -> void:
	_clear_children()

	var dir := DirAccess.open(AUTOLOADS_PATH)
	if not dir:
		var label := Label.new()
		label.text = "No autoloads folder found."
		add_child(label)
		return

	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".gd"):
			var label := Label.new()
			label.text = file.get_basename()
			add_child(label)
		file = dir.get_next()

	dir.list_dir_end()


func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
