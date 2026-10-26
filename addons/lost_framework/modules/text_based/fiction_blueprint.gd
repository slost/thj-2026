extends Resource
class_name FictionBlueprint
## A kind of entity that can be created while the story runs ([method FictionWorld.spawn]).
## [member reactions] are copied onto each instance, so every one shares the rules.


@export var id := &"" ## Used to spawn this kind again when a save is loaded.
@export var def: EntityDef
@export var reactions: Array[FictionReaction] = []
@export var portable := false
@export var container := false
@export var supporter := false
@export var openable := false
@export var starts_open := false
@export var lockable := false
@export var starts_locked := false
@export var key_id := &""
@export var mover := false
@export var location := false
