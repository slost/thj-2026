## Static grid configuration for the game
extends Resource
class_name GridConfig


## The size of the grid in terms of number of cells (width, height)
@export var grid_size: Vector2i = Vector2i(16, 16)
## The size of each cell in world units, used for converting between grid and world coordinates
@export var cell_size: Vector2 = Vector2(32, 32)
## The origin point of the grid in world coordinates, used for aligning the grid with the game world
@export var origin: Vector2 = Vector2.ZERO
## Whether to allow multiple objects to occupy the same cell, affecting how the grid manager handles object placement and movement
@export var allow_multi_occupancy: bool = false


func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y