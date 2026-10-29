extends DataDef
class_name UnitDef


@export var team: Unit2D.Team
@export var race: Unit2D.Race
@export var max_hp: int = 30
@export var speed: float = 60.0
@export var damage: int = 5
@export var detect_range: int = 4 ## detect range in tiles
@export var attack_range: int = 2 ## attack range in tiles
@export var attack_cooldown: float = 1.0
@export var cpu: int = 1 ## Read speed, plus a small share of move speed.
@export var gpu: int = 1 ## Move speed and animation speed. 1 keeps the unit's base pace.
@export var ram: int = 8 ## Max RAM spent by blocks (Remembering As Monster)
@export var mb: int = 1 ## Monster Brain
@export var starting_program: UnitProgram
@export var allowed_events: Array[EventGraph.Event] = [EventGraph.Event.ON_UPDATE]
