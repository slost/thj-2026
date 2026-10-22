extends Resource
class_name VisualState


@export_group("Sprite")
@export var texture: Texture2D ## Texture used for this state. Empty keeps the current texture.

@export_group("Sprite Sheet")
## When enabled, [member hframes], [member vframes], and [member frame] replace the sprite sheet. Disabled keeps the current sheet.
@export var apply_frames := false
@export var hframes := 1
@export var vframes := 1
@export var frame := 0

@export_group("Region")
## When enabled, [member region_enabled] and [member region_rect] replace the sprite region. Disabled keeps the current region.
@export var apply_region := false
@export var region_enabled := false
@export var region_rect := Rect2()

@export_group("Placement")
## When enabled, [member offset] replaces the sprite offset. Disabled keeps the current offset.
@export var apply_offset := false
@export var offset := Vector2.ZERO
## When enabled, [member flip_h] and [member flip_v] replace the sprite flip. Disabled keeps the current flip.
@export var apply_flip := false
@export var flip_h := false
@export var flip_v := false

@export_group("Color")
## When enabled, [member modulate] replaces the sprite modulate. Disabled keeps the current modulate.
@export var apply_modulate := false
@export var modulate := Color.WHITE
## Outline style for this state. Empty keeps the current outline.
@export var outline_style: OutlineStyle

@export_group("Playback")
## Animation played when [Visual2D] applies this state. Empty keeps the current animation.
@export var animation: StringName
## State applied when [member animation] finishes. Empty stays on this state.
## A looping clip never finishes, so it does not advance.
@export var next_state: StringName
