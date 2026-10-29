## One summoned minion carried between camp and battle.
## def is the snapshot from summon time. hp is the runtime health worth keeping.
class_name ArmyMember
extends RefCounted


var def: UnitDef
var hp: int = -1
var unit: Unit2D
