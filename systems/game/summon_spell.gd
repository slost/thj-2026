## One summon spell: a unit template, that spell's own program, and a spec.
## The program is cloned from def.starting_program the first time it is asked for.
## Spec edits change future summons. A summoned body keeps the def copied at summon time.
class_name SummonSpell
extends RefCounted

## Why set_race did or did not change the spell.
enum RaceChange { APPLIED, REFUSED_LOCKED, REFUSED_RAM }

## Resource indexes match Game.ResourceType.
const _CORPSE := 0
const _GORE := 4

var def: UnitDef
var program: UnitProgram
var race: Unit2D.Race = Unit2D.Race.ZOMBIE
var corpse_amount: int = 1
var gore_amount: int = 1
## Slot RAM before the race bonus. Seeded from Game's per-slot RAM table.
var base_ram: int = 8


static func blank_program() -> UnitProgram:
	var function := UnitFunction.new()
	function.function_name = "ON_UPDATE"
	var lines: Array[ScriptLine] = []
	function.lines = lines
	var functions: Array[UnitFunction] = []
	functions.append(function)
	var graph := EventGraph.new()
	# Exported Resource defaults are shared across instances. Always replace them.
	graph.links = {}
	graph.connect_function(EventGraph.Event.ON_UPDATE, function)
	var created := UnitProgram.new()
	created.functions = functions
	created.event_graph = graph
	return created


## Corpse and gore from the spec, then that race's extra summon materials.
## This is the only price summoner reads.
func get_costs() -> Array[SummonCost]:
	var rows: Array[SummonCost] = []
	rows.append(_cost(_CORPSE, _clamped(corpse_amount)))
	rows.append(_cost(_GORE, _clamped(gore_amount)))
	var profile := RaceProfiles.get_profile(race)
	if profile == null:
		return rows
	for extra in profile.summon_extras:
		if extra == null or extra.amount <= 0:
			continue
		rows.append(_cost(int(extra.resource_type), extra.amount))
	return rows


func display_name() -> String:
	var profile := RaceProfiles.get_profile(race)
	if profile != null:
		return profile.display_name()
	if def != null:
		var title := def.get_display_name()
		if not title.is_empty():
			return title
	return "Spell"


func ram_max() -> int:
	return ram_for(race)


## Slot base RAM, that race's bonus, and the current corpse/gore adjustment. Never below 1.
func ram_for(which: Unit2D.Race) -> int:
	var profile := RaceProfiles.get_profile(which)
	var bonus := profile.ram_bonus if profile != null else 0
	return Formular.spec_ram(base_ram + bonus, corpse_amount, gore_amount)


## Returns false when the new amount would shrink RAM below the program already written.
func set_corpse_amount(amount: int) -> bool:
	var next := _clamped(amount)
	if not _fits(next, gore_amount):
		return false
	corpse_amount = next
	build_def()
	return true


func set_gore_amount(amount: int) -> bool:
	var next := _clamped(amount)
	if not _fits(corpse_amount, next):
		return false
	gore_amount = next
	build_def()
	return true


## Locked races and a program that would no longer fit are left unchanged.
func set_race(next: Unit2D.Race) -> RaceChange:
	if not _is_unlocked(next):
		return RaceChange.REFUSED_LOCKED
	if next == race:
		build_def()
		return RaceChange.APPLIED
	if get_update_function().get_mb_cost() > ram_for(next):
		return RaceChange.REFUSED_RAM
	race = next
	build_def()
	return RaceChange.APPLIED


## Writes the current spec onto def. The live program is not replaced.
func build_def() -> UnitDef:
	if def == null:
		def = UnitDef.new()
	corpse_amount = _clamped(corpse_amount)
	gore_amount = _clamped(gore_amount)
	var profile := RaceProfiles.get_profile(race)
	def.team = Unit2D.Team.MINION
	def.race = race
	def.ram = ram_max()
	def.name = display_name()
	if profile != null:
		def.max_hp = profile.max_hp
		def.damage = profile.damage
		def.attack_range = profile.attack_range
		def.detect_range = profile.detect_range
		def.attack_cooldown = profile.attack_cooldown
		def.cpu = Formular.spec_cpu(profile.base_cpu, corpse_amount)
		def.gpu = Formular.spec_gpu(profile.base_gpu, gore_amount)
	return def


func get_program() -> UnitProgram:
	if program != null:
		return program
	if def != null and def.starting_program != null:
		program = def.starting_program.clone()
		_share_blocks(def.starting_program, program)
	else:
		program = blank_program()
	return program


## The ON_UPDATE function edits write into. Created and linked when missing.
func get_update_function() -> UnitFunction:
	var owned := get_program()
	if owned.event_graph == null:
		var graph := EventGraph.new()
		graph.links = {}
		owned.event_graph = graph
	_drop_foreign_update_links(owned)
	for entry in owned.event_graph.get_functions(EventGraph.Event.ON_UPDATE):
		var found := entry as UnitFunction
		if found and owned.functions.has(found):
			return found
	for existing in owned.functions:
		if existing == null:
			continue
		owned.event_graph.connect_function(EventGraph.Event.ON_UPDATE, existing)
		return existing
	var created := UnitFunction.new()
	created.function_name = "ON_UPDATE"
	var lines: Array[ScriptLine] = []
	created.lines = lines
	owned.functions.append(created)
	owned.event_graph.connect_function(EventGraph.Event.ON_UPDATE, created)
	return created


func _fits(corpse: int, gore: int) -> bool:
	return get_update_function().get_mb_cost() <= Formular.spec_ram(base_ram + _race_bonus(), corpse, gore)


func _race_bonus() -> int:
	var profile := RaceProfiles.get_profile(race)
	return profile.ram_bonus if profile != null else 0


func _clamped(amount: int) -> int:
	return clampi(amount, Formular.spec_min_ingredient(), Formular.spec_max_ingredient())


func _cost(type_value: int, amount: int) -> SummonCost:
	var cost := SummonCost.new()
	cost.resource_type = type_value
	cost.amount = amount
	return cost


func _is_unlocked(next: Unit2D.Race) -> bool:
	var game := _game_node()
	if game == null:
		return false
	return bool(game.call(&"is_race_unlocked", next))


static func _game_node() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"Game")


## Deep copy duplicates blocks. Point the copy back at the shared .tres.
static func _share_blocks(source: UnitProgram, copy: UnitProgram) -> void:
	var functions := mini(source.functions.size(), copy.functions.size())
	for function_index in functions:
		var src := source.functions[function_index]
		var dst := copy.functions[function_index]
		if src == null or dst == null:
			continue
		var line_count := mini(src.lines.size(), dst.lines.size())
		for line_index in line_count:
			var src_line := src.lines[line_index]
			var dst_line := dst.lines[line_index]
			if src_line == null or dst_line == null or src_line.block == null:
				continue
			if src_line.block.resource_path.is_empty():
				continue
			dst_line.block = src_line.block


func _drop_foreign_update_links(owned: UnitProgram) -> void:
	var graph := owned.event_graph
	var foreign: Array[UnitFunction] = []
	for entry in graph.get_functions(EventGraph.Event.ON_UPDATE):
		var fn := entry as UnitFunction
		if fn and not owned.functions.has(fn):
			foreign.append(fn)
	for fn in foreign:
		graph.disconnect_function(EventGraph.Event.ON_UPDATE, fn)
