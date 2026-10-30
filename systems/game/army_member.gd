## One summoned minion carried between camp and battle.
## def is the snapshot from summon time. hp is the runtime health worth keeping.
class_name ArmyMember
extends RefCounted


var def: UnitDef
var hp: int = -1
var unit: Unit2D
## What was spent to summon this minion. Rows of {type, amount}. Empty after a refund.
var paid: Array = []
## Index into Game.spells at summon time. -1 when this body is not from a slot.
var spell_slot := -1
