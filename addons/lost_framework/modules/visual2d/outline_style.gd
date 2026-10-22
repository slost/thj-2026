extends Resource
class_name OutlineStyle

## Color, thickness, and sample type for a [Visual2D] outline.
## [member type] [code]1[/code] samples 4 directions and [code]2[/code] samples 8.
## [method Visual2D.set_outline_style] raises values below [code]1[/code] because [code]0[/code] draws nothing.

@export var color := Color.WHITE
@export_range(0.0, 8.0, 0.05) var thickness := 1.0
@export_range(1, 2, 1) var type := 2
