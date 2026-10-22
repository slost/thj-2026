extends Node
class_name GridManager

signal config_changed(config: GridConfig)
signal object_added(record: GridObjectRecord)
signal object_removed(record: GridObjectRecord)
signal object_moved(record: GridObjectRecord, from_cell: Vector2i, to_cell: Vector2i)

var config: GridConfig

#region Runtime
var _next_runtime_id: int = 1
var _records_by_id: Dictionary = {}
var _objects_by_cell: Dictionary = {}
var _walkable_cells: Dictionary = {}
#endregion


func setup(_config: GridConfig) -> void:
	config = _config
	clear()
	config_changed.emit(_config)


func clear() -> void:
	_next_runtime_id = 1
	_records_by_id.clear()
	_objects_by_cell.clear()
	_walkable_cells.clear()



func is_in_bounds(cell: Vector2i) -> bool:
	if config == null:
		return false

	return config.is_valid_cell(cell)


func cell_to_world(cell: Vector2i) -> Vector2:
	if config == null:
		return Vector2.ZERO

	return config.origin + Vector2(cell) * config.cell_size + (config.cell_size * 0.5)


func world_to_cell(world_position: Vector2) -> Vector2i:
	if config == null:
		return Vector2i.ZERO

	var local_pos := world_position - config.origin
	return Vector2i(
		floori(local_pos.x / config.cell_size.x),
		floori(local_pos.y / config.cell_size.y)
	)


func generate_runtime_id() -> int:
	var runtime_id := _next_runtime_id
	_next_runtime_id += 1
	return runtime_id


func set_walkable_cells(cells: Array[Vector2i]) -> void:
	_walkable_cells.clear()

	for cell in cells:
		_walkable_cells[cell] = true


func is_cell_walkable(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false

	if _walkable_cells.is_empty():
		return true

	return _walkable_cells.get(cell, false) as bool


func add_record(record: GridObjectRecord) -> bool:
	if record == null:
		return false

	if config == null:
		push_warning("GridManager.add_record failed: config is null.")
		return false

	if _records_by_id.has(record.runtime_id):
		push_warning("GridManager.add_record failed: runtime_id already exists.")
		return false

	if not is_in_bounds(record.cell):
		push_warning("GridManager.add_record failed: cell out of bounds.")
		return false

	if not can_place_at(record.cell, record.layer):
		return false

	_records_by_id[record.runtime_id] = record

	if not _objects_by_cell.has(record.cell):
		_objects_by_cell[record.cell] = []

	var cell_records: Array = _objects_by_cell[record.cell]
	cell_records.append(record)

	object_added.emit(record)
	return true


func remove_record(runtime_id: int) -> bool:
	var record := get_record(runtime_id)
	if record == null:
		return false

	var cell_records: Array = _objects_by_cell.get(record.cell, [])
	var index := cell_records.find(record)
	if index != -1:
		cell_records.remove_at(index)

	if cell_records.is_empty():
		_objects_by_cell.erase(record.cell)
	else:
		_objects_by_cell[record.cell] = cell_records

	_records_by_id.erase(runtime_id)

	object_removed.emit(record)
	return true


func move_record(runtime_id: int, to_cell: Vector2i) -> bool:
	var record := get_record(runtime_id)
	if record == null:
		return false

	if not is_in_bounds(to_cell):
		return false

	if record.cell == to_cell:
		return true

	if not can_move_to(record, to_cell):
		return false

	var from_cell := record.cell

	var from_records: Array = _objects_by_cell.get(from_cell, [])
	var from_index := from_records.find(record)
	if from_index != -1:
		from_records.remove_at(from_index)

	if from_records.is_empty():
		_objects_by_cell.erase(from_cell)
	else:
		_objects_by_cell[from_cell] = from_records

	if not _objects_by_cell.has(to_cell):
		_objects_by_cell[to_cell] = []

	var to_records: Array = _objects_by_cell[to_cell]
	to_records.append(record)

	record.cell = to_cell

	object_moved.emit(record, from_cell, to_cell)
	return true


func can_place_at(cell: Vector2i, layer: StringName = &"main") -> bool:
	if not is_in_bounds(cell):
		return false

	if config == null:
		return false

	if not is_cell_walkable(cell):
		return false

	if config.allow_multi_occupancy:
		return true

	var cell_records := get_records_at(cell)
	if cell_records.is_empty():
		return true

	for record in cell_records:
		if record is GridObjectRecord and record.layer == layer:
			return false

	return false


func can_move_to(record: GridObjectRecord, to_cell: Vector2i) -> bool:
	if record == null:
		return false

	if not is_in_bounds(to_cell):
		return false

	if config == null:
		return false

	if not is_cell_walkable(to_cell):
		return false

	if config.allow_multi_occupancy:
		return true

	var cell_records := get_records_at(to_cell)
	if cell_records.is_empty():
		return true

	for other in cell_records:
		if other == record:
			continue

		if other is GridObjectRecord and other.layer == record.layer:
			return false

	return false


func get_record(runtime_id: int) -> GridObjectRecord:
	return _records_by_id.get(runtime_id, null)


func has_record(runtime_id: int) -> bool:
	return _records_by_id.has(runtime_id)


func get_records() -> Array[GridObjectRecord]:
	var results: Array[GridObjectRecord] = []

	for value in _records_by_id.values():
		if value is GridObjectRecord:
			results.append(value)

	return results


func get_records_at(cell: Vector2i) -> Array:
	if not _objects_by_cell.has(cell):
		return []

	return (_objects_by_cell[cell] as Array).duplicate()


func get_first_record_at(cell: Vector2i, layer: StringName = &"") -> GridObjectRecord:
	var records := get_records_at(cell)

	for record in records:
		if not (record is GridObjectRecord):
			continue

		if layer.is_empty() or record.layer == layer:
			return record

	return null


func is_cell_empty(cell: Vector2i) -> bool:
	return get_records_at(cell).is_empty()


func find_records_by_object_id(object_id: StringName) -> Array[GridObjectRecord]:
	var results: Array[GridObjectRecord] = []

	for record in get_records():
		if record.object_id == object_id:
			results.append(record)

	return results


func find_records_by_tag(tag: StringName) -> Array[GridObjectRecord]:
	var results: Array[GridObjectRecord] = []

	for record in get_records():
		if record.has_tag(tag):
			results.append(record)

	return results


func get_neighbors(cell: Vector2i, include_diagonals: bool = false) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]

	if include_diagonals:
		offsets.append(Vector2i(-1, -1))
		offsets.append(Vector2i(1, -1))
		offsets.append(Vector2i(-1, 1))
		offsets.append(Vector2i(1, 1))

	var results: Array[Vector2i] = []

	for offset in offsets:
		var next_cell := cell + offset
		if is_in_bounds(next_cell):
			results.append(next_cell)

	return results
