extends Node
class_name GridLevelLoader

#region References
@export var grid_manager: GridManager
@export var object_database: GridObjectDatabase
@export var visual_parent: Node
@export var visual_sync_system: GridVisualSync
#endregion


func load_level(level_data: LevelData) -> bool:
	if level_data == null:
		push_warning("GridLevelLoader.load_level failed: level_data is null.")
		return false

	if grid_manager == null:
		push_warning("GridLevelLoader.load_level failed: grid_manager is null.")
		return false

	if level_data.grid_config == null:
		push_warning("GridLevelLoader.load_level failed: level_data.grid_config is null.")
		return false

	var sync_system := _get_or_create_visual_sync_system()
	if sync_system != null:
		sync_system.clear_visuals()

	grid_manager.setup(level_data.grid_config)
	grid_manager.set_walkable_cells(level_data.walkable_cells)

	for object_data in level_data.objects:
		if object_data == null:
			continue

		_spawn_level_object(object_data)

	return true


func clear_visuals() -> void:
	var sync_system := _get_or_create_visual_sync_system()
	if sync_system != null:
		sync_system.clear_visuals()


func _spawn_level_object(object_data: GridObjectData) -> void:
	var definition := _get_definition(object_data.object_id)
	var runtime_id := grid_manager.generate_runtime_id()

	var record := GridObjectRecord.new()

	var layer := object_data.layer
	if layer.is_empty() and definition != null:
		layer = definition.default_layer

	var metadata := {}
	if definition != null:
		metadata = definition.default_metadata.duplicate(true)

	metadata.merge(object_data.metadata, true)

	var tags: Array[StringName] = []
	if definition != null:
		tags = definition.tags.duplicate()

	record.setup(
		runtime_id,
		object_data.object_id,
		object_data.cell,
		layer,
		object_data.rotation_steps,
		metadata,
		tags,
		definition,
		null
	)

	if not grid_manager.add_record(record):
		return


func _get_definition(object_id: StringName) -> GridObjectDefinition:
	if object_database == null:
		return null

	return object_database.get_definition(object_id)


func _get_or_create_visual_sync_system() -> GridVisualSync:
	if visual_sync_system == null:
		visual_sync_system = GridVisualSync.new()
		visual_sync_system.name = "GridVisualSync"
		add_child(visual_sync_system)

	visual_sync_system.configure(grid_manager, object_database, visual_parent)
	return visual_sync_system
