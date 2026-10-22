@tool
extends VBoxContainer

## One volume slider. Duplicate this scene, then set [member bus_name] and [member label_key].

@export var bus_name: String = "Master"
@export var label_key: String = "settings.master":
	set(value):
		label_key = value
		_apply_title()
@export var title_label: Label
@export var slider: HSlider
@export var value_label: Label


func _ready() -> void:
	_resolve_nodes()
	_apply_title()


func _resolve_nodes() -> void:
	if title_label == null:
		title_label = get_node_or_null("Header/TitleLabel") as Label
	if value_label == null:
		value_label = get_node_or_null("Header/ValueLabel") as Label
	if slider == null:
		slider = get_node_or_null("Slider") as HSlider


func _apply_title() -> void:
	var label := title_label if title_label != null else get_node_or_null("Header/TitleLabel") as Label
	if label == null or label_key.is_empty():
		return
	label.text = label_key
