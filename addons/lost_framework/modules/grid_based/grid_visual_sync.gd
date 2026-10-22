extends Node
class_name GridVisualSync


@export var grid_manager: GridManager
@export var object_database: GridObjectDatabase
@export var visual_parent: Node

var _is_connected: bool = false


func _ready() -> void:
	_refresh_connections()
	sync_all()


func configure(
	p_grid_manager: GridManager,
	p_object_database: GridObjectDatabase,
	p_visual_parent: Node
) -> void:
	if grid_manager != p_grid_manager and _is_connected and grid_manager != null:
		_disconnect_grid_manager()

	grid_manager = p_grid_manager
	object_database = p_object_database
	visual_parent = p_visual_parent

	_refresh_connections()


func clear_visuals() -> void:
	if grid_manager != null:
		for record in grid_manager.get_records():
			free_visual(record)

	if visual_parent == null:
		return

	for child in visual_parent.get_children():
		child.queue_free()


func ensure_visual(record: GridObjectRecord) -> Node2D:
	if record == null:
		return null

	if is_instance_valid(record.visual_node):
		return record.visual_node

	var definition := record.definition
	if definition == null:
		definition = _get_definition(record.object_id)
		record.definition = definition

	var visual_node := _create_visual_node(definition)
	record.visual_node = visual_node

	if visual_node != null and visual_parent != null:
		visual_parent.add_child(visual_node)

	return visual_node


func free_visual(record: GridObjectRecord) -> void:
	if record == null:
		return

	if is_instance_valid(record.visual_node):
		record.visual_node.queue_free()

	record.visual_node = null


func sync_record(record: GridObjectRecord) -> void:
	if record == null or grid_manager == null:
		return

	var visual_node := ensure_visual(record)
	if visual_node == null:
		return

	var world_position := grid_manager.cell_to_world(record.cell)
	var rotation_radians := deg_to_rad(float(record.rotation_steps) * 90.0)

	if visual_node is GridObjectNode:
		var grid_object_node := visual_node as GridObjectNode
		grid_object_node.runtime_id = record.runtime_id
		grid_object_node.sync_to_world_position(world_position)
	else:
		visual_node.global_position = world_position

	visual_node.rotation = rotation_radians

	if visual_node.has_method("apply_grid_record"):
		visual_node.call("apply_grid_record", record)


func sync_all() -> void:
	if grid_manager == null:
		return

	for record in grid_manager.get_records():
		sync_record(record)


func _refresh_connections() -> void:
	if grid_manager == null:
		_is_connected = false
		return

	if _is_connected:
		return

	grid_manager.config_changed.connect(_on_config_changed)
	grid_manager.object_added.connect(_on_object_added)
	grid_manager.object_moved.connect(_on_object_moved)
	grid_manager.object_removed.connect(_on_object_removed)
	_is_connected = true


func _disconnect_grid_manager() -> void:
	if grid_manager == null:
		_is_connected = false
		return

	if grid_manager.config_changed.is_connected(_on_config_changed):
		grid_manager.config_changed.disconnect(_on_config_changed)

	if grid_manager.object_added.is_connected(_on_object_added):
		grid_manager.object_added.disconnect(_on_object_added)

	if grid_manager.object_moved.is_connected(_on_object_moved):
		grid_manager.object_moved.disconnect(_on_object_moved)

	if grid_manager.object_removed.is_connected(_on_object_removed):
		grid_manager.object_removed.disconnect(_on_object_removed)

	_is_connected = false


func _get_definition(object_id: StringName) -> GridObjectDefinition:
	if object_database == null:
		return null

	return object_database.get_definition(object_id)


func _create_visual_node(definition: GridObjectDefinition) -> Node2D:
	if definition == null:
		return null

	if definition.visual_scene != null:
		var instance := definition.visual_scene.instantiate()
		if instance is Node2D:
			return instance

	var node := GridObjectNode.new()

	if definition.default_texture != null:
		var sprite := Sprite2D.new()
		node.add_child(sprite)
		node.sprite = sprite
		node.set_texture(definition.default_texture)

	return node


func _on_config_changed(_config: GridConfig) -> void:
	sync_all()


func _on_object_added(record: GridObjectRecord) -> void:
	sync_record(record)


func _on_object_moved(record: GridObjectRecord, _from_cell: Vector2i, _to_cell: Vector2i) -> void:
	sync_record(record)


func _on_object_removed(record: GridObjectRecord) -> void:
	free_visual(record)
