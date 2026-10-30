extends Resource
class_name SfxCue


## Cue id, such as "zombie.attack" or "general.page_turn".
@export var id: String = ""
@export var streams: Array[AudioStream] = []
## Linear loudness, 0 to 1, before the caller's scale.
@export var volume: float = 1.0
@export var pitch_range: Vector2 = Vector2(0.92, 1.08)
@export var max_concurrent: int = 3
## Skip a new play when the previous one started more recently than this.
@export var min_interval: float = 0.05
