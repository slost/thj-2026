## One summon spell: a unit template, that spell's own program, and later its summon cost.
## The program is cloned from def.starting_program the first time it is asked for.
class_name SummonSpell
extends RefCounted

var def: UnitDef
var program: UnitProgram


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


func display_name() -> String:
	if def == null:
		return "Spell"
	var title := def.get_display_name()
	if title.is_empty():
		return "Spell"
	return title


func ram_max() -> int:
	if def == null:
		return 0
	return maxi(def.ram, 0)


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
