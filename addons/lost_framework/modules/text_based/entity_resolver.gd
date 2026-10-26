class_name EntityResolver
extends RefCounted
## Turns a [NounPhrase] into the entity the player means, looking only at what
## the actor can refer to right now (see [method FictionWorld.get_scope]).
## When several things fit ("ดาบ" with two swords around) the result is
## AMBIGUOUS, and [method choose] narrows it with the player's answer.

enum Status {
	FOUND, ## Exactly one entity fits.
	AMBIGUOUS, ## Several fit; ask the player which one.
	NOT_HERE, ## Something in the world fits, but not within reach.
	NOT_FOUND, ## Nothing in the world fits.
}


class Result:
	extends RefCounted
	var status: Status = Status.NOT_FOUND
	var phrase: NounPhrase
	var entities: Array[Entity] = [] ## The match (FOUND) or the candidates (AMBIGUOUS).

	func get_entity() -> Entity:
		return entities[0] if status == Status.FOUND else null

	func _to_string() -> String:
		var names: PackedStringArray = []
		for entity in entities:
			names.append(String(entity.get_id()))
		return "%s [%s]" % [Status.keys()[status], ", ".join(names)]


var world: FictionWorld
var actor: Entity ## Whose scope to use; null means the world's player.


func _init(p_world: FictionWorld = null, p_actor: Entity = null) -> void:
	world = p_world
	actor = p_actor


func resolve(phrase: NounPhrase) -> Result:
	var scope := world.get_scope(actor)
	var matches := filter(phrase, scope)
	if matches.is_empty():
		var status := Status.NOT_HERE if not filter(phrase, world.get_entities()).is_empty() else Status.NOT_FOUND
		return _make(status, phrase, [])
	return _make(Status.FOUND if matches.size() == 1 else Status.AMBIGUOUS, phrase, matches)


## Narrows an AMBIGUOUS [param result] with the player's [param answer]: a
## number (1-based position in the candidates, e.g. "2" or "อันที่ 2") or words
## that fit fewer candidates (e.g. "เก่า", "the silver one"). Returns a new
## result; if the answer fits none of the candidates, returns [param result].
func choose(result: Result, answer: ParsedCommand) -> Result:
	if result.status != Status.AMBIGUOUS:
		return result
	if not answer.numbers.is_empty():
		var index := answer.numbers[0] - 1
		if index >= 0 and index < result.entities.size():
			return _make(Status.FOUND, result.phrase, [result.entities[index]])
		return result
	for phrase in answer.get_noun_phrases():
		var narrowed := filter(phrase, result.entities)
		if not narrowed.is_empty():
			return _make(Status.FOUND if narrowed.size() == 1 else Status.AMBIGUOUS, result.phrase, narrowed)
	return result


## Entities in [param entities] that [param phrase] can mean: the noun names
## them (if there is a noun) and they have every adjective (if any).
static func filter(phrase: NounPhrase, entities: Array[Entity]) -> Array[Entity]:
	var result: Array[Entity] = []
	if phrase == null or phrase.is_empty():
		return result
	var noun_ids := phrase.get_noun_ids()
	var adjectives := phrase.get_adjective_texts()
	for entity in entities:
		if phrase.has_noun() and not noun_ids.has(entity.get_id()):
			continue
		if not _has_adjectives(entity, adjectives):
			continue
		result.append(entity)
	return result


static func _has_adjectives(entity: Entity, adjectives: PackedStringArray) -> bool:
	if adjectives.is_empty():
		return true
	if entity.def == null:
		return false
	var own: PackedStringArray = []
	for word in entity.def.get_all_adjectives():
		own.append(TextNormalizer.normalize(word))
	for word in adjectives:
		if not own.has(word):
			return false
	return true


static func _make(status: Status, phrase: NounPhrase, entities: Array[Entity]) -> Result:
	var result := Result.new()
	result.status = status
	result.phrase = phrase
	result.entities = entities
	return result
