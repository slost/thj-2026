extends Node
class_name FictionWorld
## Root of a text-based story world. Keeps an id -> Entity lookup for every
## Entity below it, so commands, saves and scripts refer to entities by id
## instead of NodePath. Moving an entity (reparent) inside the world keeps it
## registered.
##
## It also builds the parser [Vocabulary] from its commands (verbs) and
## entities (names, aliases and adjectives) and knows what an actor can
## currently refer to ([method get_scope]).


signal entity_registered(entity: Entity)
signal entity_unregistered(entity: Entity)
## The output language changed (see [method get_output_locale]), e.g. the
## player chose another language in the settings. New texts use it;
## [CommandSession] asks a pending question again.
signal output_locale_changed(locale: String)
## After [method run] ran a command that is not [member CommandDef.is_meta]
## (an action in the world, e.g. to advance time). [param events] is what happened.
signal action_performed(m: CommandMatch, actor: Entity, events: Array[FictionEvent])

@export var player: Entity ## Default actor for [method get_scope] and [method run].
## Commands the player can type. Their aliases become VERB words in
## [method get_vocabulary]. [method CommandDef.load_base_commands] gives the
## commands shipped with the module.
@export var commands: Array[CommandDef] = []:
	set(value):
		commands = value
		invalidate_vocabulary()

## Order of the exits from [method get_exits] (the look "Exits:" line, what
## lies beyond in "look north"). Directions not listed come last, in
## passage-tree order. A game with other directions (e.g. "fore", "aft")
## sets its own order here.
@export var direction_order: Array[StringName] = [
	&"north", &"northeast", &"east", &"southeast",
	&"south", &"southwest", &"west", &"northwest",
	&"up", &"down", &"in", &"out",
]

## World-wide values (story flags), the WORLD subject of [ValueCondition]s.
## Plain values only, so they can be saved.
@export var state: Dictionary = {}

## Texts of the parser and matcher (failures, questions, direction names).
## Empty uses the module's ([method FictionTexts.get_default]).
@export var texts: FictionTexts

## How many commands [method run] ran that are not [member CommandDef.is_meta].
var action_count := 0
var _output_locale := "" ## The last output language seen, for [signal output_locale_changed].

## Words that do not come from entities or [member commands] (directions,
## prepositions, fillers, extra verbs). They are
## copied into [method get_vocabulary] together with every entity's words.
var base_vocabulary: Vocabulary:
	set(value):
		base_vocabulary = value
		invalidate_vocabulary()

var _entities: Dictionary = {} ## StringName -> Entity
var _vocabulary := Vocabulary.new()
var _vocabulary_dirty := true
var _rebuild_queued := false

## Kinds that [method spawn] can create again when a save is loaded.
@export var blueprints: Array[FictionBlueprint] = []
## Where [method save_to_file] writes when no path is given.
@export var save_path := "user://lost_fiction_save.json"
## How many earlier states [method undo_last] can restore.
@export var undo_limit := 20

var _blueprint_by_id: Dictionary = {} ## String -> FictionBlueprint
var _undo_stack: Array[Dictionary] = []


func _ready() -> void:
	state = state.duplicate(true) # Not shared with other instances of the scene
	_output_locale = get_output_locale()
	_register_tree(self)
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	for blueprint in blueprints:
		if blueprint and blueprint.id != &"":
			_blueprint_by_id[String(blueprint.id)] = blueprint
	for problem in validate_passages():
		push_warning("FictionWorld: " + problem)


func get_entity(entity_id: StringName) -> Entity:
	var entity: Entity = _entities.get(entity_id)
	return entity if is_instance_valid(entity) else null


func has_entity(entity_id: StringName) -> bool:
	return get_entity(entity_id) != null


func get_entities() -> Array[Entity]:
	var result: Array[Entity] = []
	for entity in _entities.values():
		if is_instance_valid(entity):
			result.append(entity)
	return result


## Called automatically; call it yourself after changing an entity's id.
func register(entity: Entity) -> void:
	var entity_id := entity.get_id()
	var existing: Entity = _entities.get(entity_id)
	if existing == entity:
		return
	if is_instance_valid(existing):
		push_warning("FictionWorld: duplicate entity id '%s' (%s and %s)" % [entity_id, existing.get_path(), entity.get_path()])
	_entities[entity_id] = entity
	invalidate_vocabulary()
	entity_registered.emit(entity)


func unregister(entity: Entity) -> void:
	var entity_id := entity.get_id()
	if _entities.get(entity_id) == entity:
		_entities.erase(entity_id)
		invalidate_vocabulary()
		entity_unregistered.emit(entity)


#region Commands
## The command with [param command_id] in [member commands], or null.
func get_command(command_id: StringName) -> CommandDef:
	for command in commands:
		if command and command.id == command_id:
			return command
	return null


## Runs a READY [param m] for [param actor] (null means [member player]) and
## returns what happened. [member CommandMatch.def] is already the redirected
## command (e.g. examine for "look box"), see [CommandMatcher].
## An ASK or FAILED match does nothing and returns an empty array; show its
## [method CommandMatch.get_text] instead. With no actor and no player it
## also returns an empty array.
##
## [FictionReaction]s of the objects, the target and the actor's location
## (see [method get_reactions]) take part: BEFORE ones run first (text and
## effects) and one with [member FictionReaction.stop] ends the command
## there; otherwise the command runs, and if it succeeded the AFTER ones run.
## A [member CommandDef.is_meta] command (help) only runs: no reactions,
## no [signal action_performed].
func run(m: CommandMatch, actor: Entity = null) -> Array[FictionEvent]:
	var result: Array[FictionEvent] = []
	if actor == null:
		actor = player
	if m == null or not m.is_ready() or m.def == null:
		return result
	if actor == null:
		push_warning("FictionWorld.run: no actor and no player")
		return result

	if m.def.is_meta: # About the game, not the world: no reactions, not an action
		result = m.def.execute(m, actor, self)
		_fill_events(result, m, actor)
		return result

	var before := capture_state()
	var reactions := get_reactions(m, actor)
	var stopped := false
	for found in reactions:
		if found.reaction.timing == FictionReaction.Timing.BEFORE and _fire_reaction(found, m, actor, result) and found.reaction.stop:
			stopped = true
			break # Later BEFORE reactions do not run either
	if not stopped:
		var events := m.def.execute(m, actor, self)
		result.append_array(events)
		for found in reactions:
			if found.reaction.timing == FictionReaction.Timing.AFTER and _succeeded_for(found, m, events):
				_fire_reaction(found, m, actor, result)

	_fill_events(result, m, actor)
	result.append_array(_tick_agendas(actor))
	var after := capture_state()
	if before != after:
		_push_undo(before)
	action_count += 1
	action_performed.emit(m, actor, result)
	return result


static func _fill_events(events: Array[FictionEvent], m: CommandMatch, actor: Entity) -> void:
	for event in events:
		if event.actor == null:
			event.actor = actor
		if event.command_id == &"":
			event.command_id = m.def.id


## The language IF texts are shown in: the [TranslationServer] locale as
## a language code ("th_TH" -> "th"). The Settings module sets it
## ([code]Settings.set_language()[/code]); words of every language are
## understood whatever it is.
func get_output_locale() -> String:
	return LocaleText.get_locale()


## The parser texts: [member texts], or the module's
## ([method FictionTexts.get_default]).
func get_texts() -> FictionTexts:
	return texts if texts else FictionTexts.get_default()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_check_output_locale()


## Emits [signal output_locale_changed] if the output language changed.
func _check_output_locale() -> void:
	var locale := get_output_locale()
	if locale == _output_locale:
		return
	_output_locale = locale
	invalidate_vocabulary() # Words from translation files may have changed
	output_locale_changed.emit(locale)


## A reaction found for a command, with the entity that has it.
class FoundReaction:
	extends RefCounted
	var reaction: FictionReaction
	var entity: Entity ## The entity whose [FictionReactionComponent] holds it.
	var index := -1 ## Position in that component's list (for "once").


## The reactions to [param m]: those of each object (role OBJECT), the target
## (role TARGET) and the actor's location (role ANY), in that order. Each
## reaction is listed once even if its entity fills several roles. Their
## [member FictionReaction.when] conditions are checked when they fire.
func get_reactions(m: CommandMatch, actor: Entity) -> Array[FoundReaction]:
	var result: Array[FoundReaction] = []
	var seen := {} # FictionReaction -> Array of entities already listed for it
	var command_id := m.def.id if m.def else &""
	for object in m.objects:
		_add_reactions(object, FictionReaction.Role.OBJECT, command_id, result, seen)
	if m.target:
		_add_reactions(m.target, FictionReaction.Role.TARGET, command_id, result, seen)
	var location := actor.get_location() if actor else null
	if location:
		_add_reactions(location, FictionReaction.Role.ANY, command_id, result, seen)
	if actor:
		_add_reactions(actor, FictionReaction.Role.ACTOR, command_id, result, seen)
	return result


static func _add_reactions(entity: Entity, role: FictionReaction.Role, command_id: StringName, result: Array[FoundReaction], seen: Dictionary) -> void:
	for component in entity.get_components():
		if not (component is FictionReactionComponent) or not component.is_enabled():
			continue
		var reactions: Array[FictionReaction] = component.reactions
		for i in reactions.size():
			var reaction := reactions[i]
			if reaction == null or not reaction.reacts_to(command_id, role):
				continue
			var hosts: Array = seen.get(reaction, [])
			if hosts.has(entity):
				continue
			hosts.append(entity)
			seen[reaction] = hosts
			var found := FoundReaction.new()
			found.reaction = reaction
			found.entity = entity
			found.index = i
			result.append(found)


## Fires [param found] if its conditions hold (and, if once, it has not
## fired yet): adds its text to [param events] and applies its effects.
## Returns true if it fired.
func _fire_reaction(found: FoundReaction, m: CommandMatch, actor: Entity, events: Array[FictionEvent]) -> bool:
	var reaction := found.reaction
	var done_key := reaction.get_done_key(found.index)
	if reaction.once and found.entity.get_value(done_key, false):
		return false
	if not reaction.conditions_met(found.entity, make_condition_context_for(found.entity, actor)):
		return false
	if reaction.once:
		found.entity.set_value(done_key, true)
	var values := _reaction_values(m, actor, found.entity)
	var locale := m.locale if m and not m.locale.is_empty() else LocaleText.get_locale()
	var source := LocaleText.translate(reaction.text, locale)
	if source.is_empty():
		source = reaction.text
	var text := source.format(values) if not source.is_empty() else ""
	if not text.is_empty():
		var event := FictionEvent.new(text, actor, true, &"reaction", m.def.id)
		event.template = reaction.text
		event.values = values
		event.locale = locale
		event.visibility = FictionEvent.Visibility.ROOM
		var here := actor.get_location() if actor else null
		event.location_id = here.get_id() if here else &""
		events.append(event)
	for effect in reaction.effects:
		if effect:
			effect.apply(m, actor, self, found.entity)
	return true


## Placeholder values for a reaction's text. {object} is [param host] (the
## reacting entity) when it is one of the objects, so in "take coin and gem"
## the gem's reaction names the gem; otherwise it is the first object.
static func _reaction_values(m: CommandMatch, actor: Entity, host: Entity = null) -> Dictionary:
	var object: Entity = null
	if host and m.objects.has(host):
		object = host
	elif not m.objects.is_empty():
		object = m.objects[0]
	return {
		"actor": actor.get_display_name() if actor else "",
		"object": object.get_display_name() if object else "",
		"target": m.target.get_display_name() if m.target else "",
		"direction": String(m.direction),
		"verb": m.def.get_verb_text() if m.def else "",
	}


## Whether the command succeeded for [param found]. A reaction of one of
## several objects needs that object's own event to be a success; any other
## reaction uses [method _succeeded].
static func _succeeded_for(found: FoundReaction, m: CommandMatch, events: Array[FictionEvent]) -> bool:
	if m.objects.size() > 1 and m.objects.has(found.entity):
		for event in events:
			if event.object == found.entity:
				return event.success
	return _succeeded(events)


## A command succeeded if it reported nothing, or if any event is a success
## (with several objects, at least one worked).
static func _succeeded(events: Array[FictionEvent]) -> bool:
	if events.is_empty():
		return true
	for event in events:
		if event.success:
			return true
	return false

#endregion


#region Conditions
func get_world_value(key: StringName, default: Variant = null) -> Variant:
	return state.get(key, default)


func set_world_value(key: StringName, value: Variant) -> void:
	state[key] = value


## A [ValueCondition] context for [param entity] (SELF): ENTITY looks up ids
## in this world, ACTOR is [param actor] (null means [member player]), WORLD
## is [member state]. [method Entity.get_description] uses it.
func make_condition_context_for(entity: Entity, actor: Entity = null) -> EntityConditionContext:
	return EntityConditionContext.new(entity, actor if actor else player, self, state)

#endregion


#region Vocabulary
## The words of the whole world. Always the same object, rebuilt in place when
## entities are added or removed, so a [CommandParser] can keep a reference.
func get_vocabulary() -> Vocabulary:
	if _vocabulary_dirty:
		_rebuild_vocabulary()
	return _vocabulary


## Marks the vocabulary for a rebuild at the end of the frame (or on the next
## [method get_vocabulary]). Call it after changing names, aliases or the language.
func invalidate_vocabulary() -> void:
	_vocabulary_dirty = true
	if not _rebuild_queued and is_inside_tree():
		_rebuild_queued = true
		_rebuild_vocabulary.call_deferred()


## Adds [param entity]'s name (in every language) and aliases as NOUN words (id = entity id) and
## its adjectives as ADJECTIVE words (id = the normalized adjective).
static func add_entity_words(vocabulary: Vocabulary, entity: Entity) -> void:
	var entity_id := entity.get_id()
	vocabulary.add_word(entity.get_display_name(), ParseToken.Type.NOUN, entity_id)
	if entity.def == null:
		return
	for display_name in entity.def.get_all_names():
		vocabulary.add_word(display_name, ParseToken.Type.NOUN, entity_id)
	for alias in entity.def.get_all_aliases():
		vocabulary.add_word(alias, ParseToken.Type.NOUN, entity_id)
	for adjective in entity.def.get_all_adjectives():
		vocabulary.add_word(adjective, ParseToken.Type.ADJECTIVE, StringName(TextNormalizer.normalize(adjective)))


func _rebuild_vocabulary() -> void:
	_rebuild_queued = false
	if not _vocabulary_dirty:
		return
	_vocabulary.clear()
	if base_vocabulary:
		_vocabulary.add_from(base_vocabulary)
	CommandDef.add_all_to_vocabulary(_vocabulary, commands)
	for entity in get_entities():
		if is_named(entity) or entity.get_component(PassageComponent) == null:
			add_entity_words(_vocabulary, entity) # Unnamed passages have no words
	_vocabulary_dirty = false

#endregion


#region Passages
## The ways out of the location [param room_id], one per passage side that
## starts there (see [PassageComponent]). Computed from the passages each
## call, nothing is cached. Disabled passage components are skipped.
## Every caller (go, look, scope) goes through here, so a different source
## of exits (e.g. rooms caching their passages) only changes this method.
## Sorted by [member direction_order]; exits with the same direction keep
## passage-tree order, so [method get_exit] still finds the first passage.
func get_exits(room_id: StringName) -> Array[FictionExit]:
	var result: Array[FictionExit] = []
	if room_id == &"":
		return result
	for passage in get_passages():
		var component := passage.get_component(PassageComponent) as PassageComponent
		if component.a_id == room_id and component.a_direction != &"":
			result.append(FictionExit.new(component.a_direction, component.b_id, passage))
		if component.b_id == room_id and component.b_direction != &"":
			result.append(FictionExit.new(component.b_direction, component.a_id, passage))
	return sort_exits(result)


## [param exits] sorted by [member direction_order], unknown directions
## last. Stable: exits that rank the same keep their order.
func sort_exits(exits: Array[FictionExit]) -> Array[FictionExit]:
	var keyed: Array = [] # [rank, index, exit]
	for i in exits.size():
		var rank := direction_order.find(exits[i].direction)
		keyed.append([rank if rank >= 0 else direction_order.size(), i, exits[i]])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var result: Array[FictionExit] = []
	for entry in keyed:
		result.append(entry[2])
	return result


## The exit of [param room_id] in [param direction], or null. If several
## passages use the same direction from a room (a warning at ready, see
## [method validate_passages]), the first one found is used.
func get_exit(room_id: StringName, direction: StringName) -> FictionExit:
	for exit in get_exits(room_id):
		if exit.direction == direction:
			return exit
	return null


## Every entity in the world with an enabled [PassageComponent].
func get_passages() -> Array[Entity]:
	var result: Array[Entity] = []
	for entity in get_entities():
		var component := entity.get_component(PassageComponent)
		if component and component.is_enabled():
			result.append(entity)
	return result


## Problems in the passages: a missing [member PassageComponent.a_direction],
## a side naming an id that does not exist or is not a location, two ways out of one
## room in the same direction. Called at ready (each problem is a warning).
func validate_passages() -> PackedStringArray:
	var problems: PackedStringArray = []
	var used := {} # "room_id/direction" -> passage id
	for passage in get_passages():
		var component := passage.get_component(PassageComponent) as PassageComponent
		var passage_id := passage.get_id()
		if component.a_direction == &"":
			problems.append("passage '%s' has no a_direction" % passage_id)
		for side in [[&"a_id", component.a_id], [&"b_id", component.b_id]]:
			if side[1] == &"":
				problems.append("passage '%s' has no %s" % [passage_id, side[0]])
			elif not has_entity(side[1]):
				problems.append("passage '%s': %s '%s' is not an entity in the world" % [passage_id, side[0], side[1]])
			elif get_entity(side[1]).get_component(LocationComponent) == null:
				problems.append("passage '%s': %s '%s' is not a location" % [passage_id, side[0], side[1]])
		for side in [[component.a_id, component.a_direction], [component.b_id, component.b_direction]]:
			if side[0] == &"" or side[1] == &"":
				continue
			var used_key := "%s/%s" % side
			if used.has(used_key):
				problems.append("room '%s' has two passages going '%s': '%s' and '%s'" % [side[0], side[1], used[used_key], passage_id])
			else:
				used[used_key] = passage_id
	return problems


## True if [param entity] has a name players can use (a [member Entity.def]
## with a display name). Unnamed passages are plain connections, not things.
static func is_named(entity: Entity) -> bool:
	return entity != null and entity.def != null and not entity.def.get_display_name().is_empty()

#endregion


#region Scope
## Entities [param actor] can refer to right now: its location, everything in
## it, what the actor carries, the contents of open containers, and the
## named passages (doors) of the location's exits (see [method get_exits]),
## from either side. Unnamed passages are not in scope. Things in
## a closed [OpenableComponent] or inside another location are hidden. The
## actor itself is included (for "look at me"); commands that must not act on
## the actor exclude it (see [enum CommandDef.Scope]). Uses [member player]
## when [param actor] is null; with no actor at all, returns every entity.
func get_scope(actor: Entity = null) -> Array[Entity]:
	if actor == null:
		actor = player
	if actor == null:
		return get_entities()
	var result: Array[Entity] = []
	var location := actor.get_location()
	if location:
		result.append(location)
		_collect_visible(location, result, actor)
	else:
		_collect_visible(actor, result, actor)
	if not result.has(actor):
		result.append(actor)
	if location:
		for exit in get_exits(location.get_id()):
			if is_named(exit.passage) and not result.has(exit.passage):
				result.append(exit.passage)
	return result


func _collect_visible(container: Entity, result: Array[Entity], actor: Entity) -> void:
	for entity in container.get_contents():
		result.append(entity)
		if entity.get_component(LocationComponent):
			continue # Another place: visible itself, contents are not
		if entity.get_component(MoverComponent) and entity != actor:
			continue # Another person: visible, what they carry is not
		var openable := entity.get_component(OpenableComponent) as OpenableComponent
		if openable and not openable.is_open:
			continue
		_collect_visible(entity, result, actor)

#endregion


func _register_tree(node: Node) -> void:
	for child in node.get_children():
		if child is Entity:
			register(child)
		_register_tree(child)


func _on_node_added(node: Node) -> void:
	if node is Entity and is_ancestor_of(node):
		register(node)


func _on_node_removed(node: Node) -> void:
	if node is Entity and is_ancestor_of(node):
		unregister(node)


#region Audience
## Lines of [param events] that [param observer] hears, rendered in
## [param locale] (empty: each event's own language).
func present(events: Array, observer: Entity, locale := "") -> PackedStringArray:
	var lines: PackedStringArray = []
	for event in events:
		if event == null or not (event is FictionEvent) or not event.hears(observer, self):
			continue
		var line: String = event.render(self, observer, locale)
		if not line.is_empty():
			lines.append(line)
	return lines

#endregion


#region Agendas
func _tick_agendas(actor: Entity) -> Array[FictionEvent]:
	var result: Array[FictionEvent] = []
	for entity in get_entities():
		var component := entity.get_component(FictionAgendaComponent) as FictionAgendaComponent
		if component == null or not component.is_enabled():
			continue
		for i in component.agendas.size():
			var agenda := component.agendas[i]
			if agenda:
				var event := _tick_agenda(agenda, i, entity, actor)
				if event:
					result.append(event)
	return result


func _tick_agenda(agenda: FictionAgenda, index: int, host: Entity, actor: Entity) -> FictionEvent:
	var done_key := agenda.done_key(index)
	if agenda.once and host.get_value(done_key, false):
		return null
	var wait_key := agenda.wait_key(index)
	if not host.has_value(wait_key):
		var initial := agenda.delay if agenda.delay > 0 else (agenda.every if agenda.every > 0 else 1)
		host.set_value(wait_key, initial)
	var left := int(host.get_value(wait_key)) - 1
	if left > 0:
		host.set_value(wait_key, left)
		return null
	if not agenda.conditions.is_empty() and not ValueCondition.all_hold(agenda.conditions, host.get_values(), make_condition_context_for(host, actor)):
		host.set_value(wait_key, agenda.every if agenda.every > 0 else 1)
		return null
	if agenda.once or agenda.every <= 0:
		host.set_value(done_key, true)
	else:
		host.set_value(wait_key, agenda.every)
	for effect in agenda.effects:
		if effect:
			effect.apply(null, actor, self, host)
	if agenda.text.is_empty():
		return null
	var locale := get_output_locale()
	var source := LocaleText.translate(agenda.text, locale)
	if source.is_empty():
		source = agenda.text
	var values := {"actor": actor.get_display_name(locale) if actor else ""}
	var event := FictionEvent.new(source.format(values), actor, true, &"agenda", &"")
	event.template = agenda.text
	event.values = values
	event.locale = locale
	event.visibility = agenda.visibility
	event.include_actor = true
	if host.get_component(LocationComponent):
		event.location_id = host.get_id()
	elif host.get_location():
		event.location_id = host.get_location().get_id()
	return event

#endregion


#region Spawn and save
## Creates an entity from [param blueprint] inside [param destination_id].
## Reactions on the blueprint are copied, so later edits of the blueprint
## do not change what was already created. Remembers the blueprint by id
## so a save can create it again.
func spawn(blueprint: FictionBlueprint, destination_id: StringName, entity_id: StringName = &"") -> Entity:
	if blueprint == null:
		push_warning("FictionWorld.spawn: no blueprint")
		return null
	var destination := get_entity(destination_id)
	if destination == null:
		push_warning("FictionWorld.spawn: unknown destination '%s'" % destination_id)
		return null
	if blueprint.id != &"":
		_blueprint_by_id[String(blueprint.id)] = blueprint
	var created := Entity.new()
	var base := String(blueprint.def.id) if blueprint.def and blueprint.def.id != &"" else (String(blueprint.id) if blueprint.id != &"" else "entity")
	created.id = entity_id if entity_id != &"" else _fresh_id(base)
	created.name = String(created.id)
	created.def = blueprint.def
	created.set_meta(&"fiction_spawned", true)
	created.set_meta(&"fiction_blueprint", String(blueprint.id))
	if blueprint.location:
		created.add_child(LocationComponent.new())
	if blueprint.mover:
		created.add_child(MoverComponent.new())
	if blueprint.portable:
		created.add_child(PortableComponent.new())
	if blueprint.container:
		created.add_child(ContainerComponent.new())
	if blueprint.supporter:
		created.add_child(SupporterComponent.new())
	if blueprint.openable:
		var openable := OpenableComponent.new()
		openable.is_open = blueprint.starts_open
		created.add_child(openable)
	if blueprint.lockable:
		var lockable := LockableComponent.new()
		lockable.is_locked = blueprint.starts_locked
		lockable.key_id = blueprint.key_id
		created.add_child(lockable)
	if not blueprint.reactions.is_empty():
		var reactions := FictionReactionComponent.new()
		for reaction in blueprint.reactions:
			if reaction:
				reactions.reactions.append(reaction.duplicate(true))
		created.add_child(reactions)
	destination.add_child(created)
	return created


func _fresh_id(base: String) -> StringName:
	var candidate := StringName(base)
	var number := 2
	while has_entity(candidate):
		candidate = StringName("%s_%d" % [base, number])
		number += 1
	return candidate


## Plain values of the world and every entity (component values, story flags,
## and which entity is the parent). Spawned entities remember their blueprint id.
func capture_state() -> Dictionary:
	var entities := {}
	for entity in get_entities():
		var parent := entity.get_parent_entity()
		var values := {}
		var current := entity.get_values()
		for key in current:
			values[String(key)] = _plain_value(current[key])
		entities[String(entity.get_id())] = {
			"parent": String(parent.get_id()) if parent else "",
			"spawned": bool(entity.get_meta(&"fiction_spawned", false)),
			"blueprint": String(entity.get_meta(&"fiction_blueprint", "")),
			"values": values,
		}
	var world_state := {}
	for key in state:
		world_state[String(key)] = _plain_value(state[key])
	return {"world": world_state, "entities": entities}


static func _plain_value(value: Variant) -> Variant:
	if value is StringName:
		return String(value)
	return value


## Restores a state from [method capture_state]. Entities created by
## [method spawn] that are not in [param data] are removed; missing ones
## are created from the blueprint they were spawned with.
func apply_state(data: Dictionary) -> void:
	var world_state: Dictionary = data.get("world", {})
	state = world_state.duplicate(true)
	var saved: Dictionary = data.get("entities", {})
	var removed: Array[Entity] = []
	for entity in get_entities():
		if bool(entity.get_meta(&"fiction_spawned", false)) and not saved.has(String(entity.get_id())):
			removed.append(entity)
	for entity in removed:
		unregister(entity)
		entity.free()
	for id in saved:
		var record: Dictionary = saved[id]
		if get_entity(StringName(id)) == null and record.get("spawned", false):
			var blueprint: FictionBlueprint = _blueprint_by_id.get(String(record.get("blueprint", "")), null)
			var parent_id := StringName(String(record.get("parent", "")))
			if blueprint and parent_id != &"":
				spawn(blueprint, parent_id, StringName(id))
	for id in saved:
		var entity := get_entity(StringName(id))
		if entity == null:
			continue
		var record: Dictionary = saved[id]
		var parent_id := String(record.get("parent", ""))
		if parent_id != "":
			var parent := get_entity(StringName(parent_id))
			if parent and entity.get_parent() != parent and not entity.is_ancestor_of(parent):
				entity.reparent(parent)
		entity.state.clear()
		var values: Dictionary = record.get("values", {})
		for key in values:
			entity.set_value(StringName(String(key)), values[key])


func save_to_file(path := "") -> bool:
	var file := FileAccess.open(path if not path.is_empty() else save_path, FileAccess.WRITE)
	if file == null:
		push_warning("FictionWorld.save_to_file: cannot write '%s'" % path)
		return false
	file.store_string(JSON.stringify(capture_state()))
	return true


func load_from_file(path := "") -> bool:
	var used := path if not path.is_empty() else save_path
	if not FileAccess.file_exists(used):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(used))
	if not parsed is Dictionary:
		return false
	apply_state(parsed)
	return true


func _push_undo(snapshot: Dictionary) -> void:
	_undo_stack.append(snapshot)
	while undo_limit > 0 and _undo_stack.size() > undo_limit:
		_undo_stack.pop_front()


## Restores the state from before the last change. Returns false when there
## is nothing to restore.
func undo_last() -> bool:
	if _undo_stack.is_empty():
		return false
	apply_state(_undo_stack.pop_back())
	return true

#endregion
