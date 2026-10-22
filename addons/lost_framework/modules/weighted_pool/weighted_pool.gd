## A resource representing a weighted pool of entries, allowing for random selection based on assigned weights.
@tool
extends Resource
class_name WeightedPool


@export var entries: Array[WeightedEntry] = [] ## The entries to choose from
@export var rolls: int = 1 ## Number of rolls to perform
@export var unique: bool = false ## Whether to return unique entries

var _total_weight: float = -1.0 ## The total weight of the entries
var _dirty: bool = true ## Flag to indicate that the total weight needs to be recalculated


## Returns the entry type stored in this pool. Override to lock the entries array to a WeightedEntry subclass.
## Return null to leave the exported array type unchanged.
## Return a Script for a WeightedEntry subclass, or a class name String / StringName.
func expected_entry_type() -> Variant:
    return TYPE_OBJECT


func _validate_property(property: Dictionary) -> void:
    if property.name != "entries":
        return

    var expected: Variant = expected_entry_type()
    if expected == null:
        return

    var type_name := WeightedEntry.resource_type_name(expected)
    if type_name.is_empty():
        return

    property.hint = PROPERTY_HINT_ARRAY_TYPE
    property.hint_string = "%d/%d:%s" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, type_name]


#region Lifecycle
func _set(property, value):
    if property == "entries":
        _dirty = true
        _warn_unexpected_entries(value)
    return false


func _warn_unexpected_entries(list: Variant) -> void:
    if typeof(list) != TYPE_ARRAY:
        return

    var expected_label := _expected_entry_label()
    if expected_label.is_empty():
        return

    for entry in list:
        if not (entry is WeightedEntry) or _entry_matches_expected(entry):
            continue
        push_warning("WeightedPool entries include %s, expected %s." % [_script_label(entry.get_script()), expected_label])
        return


func _entry_matches_expected(entry: WeightedEntry) -> bool:
    var expected: Variant = expected_entry_type()
    if expected == null:
        return true

    var script := entry.get_script()
    if expected is Script:
        return _script_chain_has(script, expected)
    if typeof(expected) == TYPE_STRING or typeof(expected) == TYPE_STRING_NAME:
        var wanted := String(expected)
        var current := script
        while current:
            if String(current.get_global_name()) == wanted or current.resource_path == wanted:
                return true
            current = current.get_base_script()
        return false
    return true


func _script_chain_has(script: Script, expected: Script) -> bool:
    var current := script
    while current:
        if current == expected:
            return true
        current = current.get_base_script()
    return false


func _expected_entry_label() -> String:
    var expected: Variant = expected_entry_type()
    if expected is Script:
        return _script_label(expected)
    return WeightedEntry.resource_type_name(expected)


func _script_label(script: Script) -> String:
    if script == null:
        return ""
    var global_name := String(script.get_global_name())
    if not global_name.is_empty():
        return global_name
    return script.resource_path


func _rebuild():
    _total_weight = 0.0
    for e in entries:
        if e and e.weight > 0:
            _total_weight += e.weight
    _dirty = false


func _ensure():
    if _dirty:
        _rebuild()

#endregion

#region Core Pick
func _pick_from(list: Array[WeightedEntry], rng: RandomNumberGenerator) -> WeightedEntry:
    if list.is_empty():
        return null

    var total := 0.0
    for e in list:
        if e and e.weight > 0:
            total += e.weight

    if total <= 0:
        return list.back()

    var r := rng.randf() * total
    var acc := 0.0

    for e in list:
        if e.weight <= 0:
            continue

        acc += e.weight
        if r <= acc:
            return e

    return list.back()

#endregion


#region Public Pick
func pick_one(rng: RandomNumberGenerator) -> WeightedEntry:
    return _pick_from(entries, rng)


func pick_value(rng: RandomNumberGenerator) -> Variant:
    var e := pick_one(rng)
    return e.value if e else null

#endregion


#region Rolls
func roll_entries(rng: RandomNumberGenerator) -> Array[WeightedEntry]:
    var result: Array[WeightedEntry] = []
    var temp := entries.duplicate()

    for i in rolls:
        if temp.is_empty():
            break

        var e := _pick_from(temp, rng)
        if e == null:
            break

        result.append(e)

        if unique:
            temp.erase(e)

    return result


func roll_values(rng: RandomNumberGenerator) -> Array:
    var out := []
    for e in roll_entries(rng):
        out.append(e.value)
    return out

#endregion


#region Deterministic
func pick_one_seeded(seed: int) -> WeightedEntry:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    return pick_one(rng)


func roll_values_seeded(seed: int) -> Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    return roll_values(rng)

#endregion

#region Filtered
func pick_filtered(rng: RandomNumberGenerator, predicate: Callable) -> WeightedEntry:
    var filtered: Array[WeightedEntry] = []
    for e in entries:
        if predicate.call(e):
            filtered.append(e)
    return _pick_from(filtered, rng)


func roll_filtered(rng: RandomNumberGenerator, predicate: Callable) -> Array[WeightedEntry]:
    var filtered: Array[WeightedEntry] = []
    for e in entries:
        if predicate.call(e):
            filtered.append(e)

    var result: Array[WeightedEntry] = []
    var temp := filtered.duplicate()

    for i in rolls:
        if temp.is_empty():
            break

        var e := _pick_from(temp, rng)
        result.append(e)

        if unique:
            temp.erase(e)

    return result

#endregion


#region Shuffle
func shuffled(rng: RandomNumberGenerator) -> Array[WeightedEntry]:
    var arr := entries.duplicate()
    arr.shuffle()
    return arr

func values_shuffled(rng: RandomNumberGenerator) -> Array:
    var out := []
    for e in shuffled(rng):
        out.append(e.value)
    return out

#endregion


#region Stats
func total_weight() -> float:
    _ensure()
    return _total_weight


func is_empty() -> bool:
    return entries.is_empty()


func size() -> int:
    return entries.size()

#endregion
