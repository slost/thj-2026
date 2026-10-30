## How many of each block .tres the player owns.
## Keys are resource paths, so counts stack on the shared asset and never copy it.
class_name BlockInventory
extends RefCounted

signal changed

const BLOCK_DIR := "res://data/blocks"
const SEED_COUNT := 3

var _counts: Dictionary = {}
var _blocks: Dictionary = {}


static func block_title(block: CodeBlock) -> String:
	if block == null:
		return "rune"
	var title := block.get_display_name("en")
	if title.is_empty():
		return block.get_block_label()
	return title


## Code blocks stay in English even when the game language is Thai.
static func block_description(block: CodeBlock) -> String:
	if block == null:
		return ""
	var text := LocaleText.translate("code.%s.desc" % str(block.id), "en")
	if text.is_empty():
		text = block.description
	return text.format(_percent_values(block.get_values()))


static func _percent_values(values: Dictionary) -> Dictionary:
	var shown := {}
	for key in values.keys():
		var value: Variant = values[key]
		if value is float and float(value) >= 0.0 and float(value) <= 1.0:
			shown[key] = "%d%%" % int(round(float(value) * 100.0))
		else:
			shown[key] = value
	return shown


func add(block: CodeBlock, amount: int = 1) -> void:
	if not _put(block, amount):
		return
	changed.emit()


## Returns false when the inventory does not hold enough copies.
func remove(block: CodeBlock, amount: int = 1) -> bool:
	if block == null or amount <= 0:
		return false
	var key := _key(block)
	var have := int(_counts.get(key, 0))
	if have < amount:
		return false
	_counts[key] = have - amount
	changed.emit()
	return true


func get_count(block: CodeBlock) -> int:
	if block == null:
		return 0
	return int(_counts.get(_key(block), 0))


## Every known block, including ones with a count of zero, sorted by title.
func get_all() -> Array[CodeBlock]:
	var result: Array[CodeBlock] = []
	for key in _blocks.keys():
		var block := _blocks[key] as CodeBlock
		if block:
			result.append(block)
	result.sort_custom(func(a: CodeBlock, b: CodeBlock) -> bool:
		return block_title(a).nocasecmp_to(block_title(b)) < 0
	)
	return result


## Zeros every count and keeps the known runes, so the palette can show an empty stock.
func clear_counts() -> void:
	if _counts.is_empty():
		seed_if_empty()
	for key in _counts.keys():
		_counts[key] = 0
	changed.emit()


## Gives the player one rune by its file id, for example "attack_target".
func grant_id(id: String, amount: int = 1) -> void:
	var block := load("%s/%s.tres" % [BLOCK_DIR, id]) as CodeBlock
	add(block, amount)


## Replaces the stock with the normal new-game pile of every rune.
func fill_starter() -> void:
	_counts.clear()
	seed_if_empty()


## Fills the inventory with every block .tres when nothing has been added yet.
func seed_if_empty() -> void:
	if not _counts.is_empty():
		return
	var dir := DirAccess.open(BLOCK_DIR)
	if dir == null:
		push_warning("BlockInventory: missing %s" % BLOCK_DIR)
		return
	var names := dir.get_files()
	names.sort()
	var seen := {}
	for file_name in names:
		var resource_name := str(file_name)
		if resource_name.ends_with(".remap"):
			resource_name = resource_name.trim_suffix(".remap")
		if not resource_name.ends_with(".tres"):
			continue
		if seen.has(resource_name):
			continue
		seen[resource_name] = true
		var path := BLOCK_DIR.path_join(resource_name)
		var block := load(path) as CodeBlock
		if block == null:
			push_warning("BlockInventory: %s is not a CodeBlock" % path)
			continue
		_put(block, SEED_COUNT)
	changed.emit()


func _put(block: CodeBlock, amount: int) -> bool:
	if block == null or amount <= 0:
		return false
	var canonical := _canonical(block)
	var key := _key(canonical)
	_blocks[key] = canonical
	_counts[key] = int(_counts.get(key, 0)) + amount
	return true


func _canonical(block: CodeBlock) -> CodeBlock:
	if block.resource_path.is_empty():
		return block
	var loaded := load(block.resource_path) as CodeBlock
	if loaded == null:
		return block
	return loaded


func _key(block: CodeBlock) -> String:
	var canonical := _canonical(block)
	if not canonical.resource_path.is_empty():
		return canonical.resource_path
	return "instance:%d" % canonical.get_instance_id()
