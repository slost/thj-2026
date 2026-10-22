extends Resource
class_name LevelTextFormat


## Symbols that can be used in the level text format, and their corresponding object IDs.
@export var symbol_to_object_id: Dictionary = {}


func parse_rows(rows: Array) -> Array[GridObjectData]:
	var parsed := parse_map(rows)
	var objects_variant = parsed.get("objects", [])
	var objects: Array[GridObjectData] = []

	for object_data in objects_variant:
		if object_data is GridObjectData:
			objects.append(object_data)

	return objects


func parse_map(rows: Array) -> Dictionary:
	var objects: Array[GridObjectData] = []
	var walkable_cells: Array[Vector2i] = []
	var width := 0

	for y in rows.size():
		var row := str(rows[y])
		width = maxi(width, row.length())

		for x in row.length():
			var symbol := row.substr(x, 1)
			var cell := Vector2i(x, y)

			if is_cell_walkable(symbol, cell):
				walkable_cells.append(cell)

			var object_data := build_object_data(symbol, cell)
			if object_data == null:
				continue

			objects.append(object_data)

	return {
		"objects": objects,
		"walkable_cells": walkable_cells,
		"map_size": Vector2i(width, rows.size())
	}


func build_object_data(symbol: String, cell: Vector2i) -> GridObjectData:
	var object_data := GridObjectData.new()
	object_data.cell = cell

	var object_id := symbol_to_object_id.get(symbol, StringName())
	if object_id == StringName():
		return null

	object_data.object_id = object_id
	return object_data


func is_cell_walkable(_symbol: String, _cell: Vector2i) -> bool:
	return true
