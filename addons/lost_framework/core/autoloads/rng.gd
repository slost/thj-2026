## An autoload script for random number generation.
## Provides a general purpose random number generator and a pool of random number generators for different purposes
extends Node
class_name RNGManager


var seed: String = ""
static var rng_general: RandomNumberGenerator = RandomNumberGenerator.new() ## General purpose random number generator
var test_seed: String = "" ## For testing purposes
var pools: Dictionary ## Pools of random number generators for different purposes


func _init():
    if test_seed != "":
        seed = test_seed
    else:
        seed = generate_seed()

    rng_general.randomize()
    set_rng_seed(seed)


#region RNG Pool Management
## Creates a new random number generator and adds it to the pool.
func create_and_add_rng(name := "rng",_seed := "") -> RandomNumberGenerator:
    if name in pools:
        push_error("RNG pool already exists: %s" % name)
        return null
    
    var rng: RandomNumberGenerator = create_rng(_seed)
    pools[name] = rng

    return rng


## Creates a new random number generator and sets the seed.
func create_rng(_seed := "") -> RandomNumberGenerator:
    var rng = RandomNumberGenerator.new()
    if _seed != "":
        rng.seed = _seed.hash()
    else:
        rng.seed = generate_seed().hash()

    return rng


## Gets a random number generator from the pool.
func get_rng(name := "rng") -> RandomNumberGenerator:
    if not pools.has(name):
        push_error("RNG pool not found: %s" % name)
        return null

    return pools[name]


## Removes a random number generator from the pool.
func remove_rng(name := "rng") -> void:
    if not pools.has(name):
        push_error("RNG pool not found: %s" % name)
        return
    pools.erase(name)

#endregion


#region Seed Generation
static func generate_seed() -> String:
    # Generate a random seed with random characters and numbers
    var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    var new_seed = ""
    for i in range(16):
        new_seed += chars[randi() % chars.length()]
    print("Generated seed: %s" % new_seed)
    return new_seed


static func set_rng_seed(new_seed: String, _rng: RandomNumberGenerator = rng_general) -> void:
    _rng.seed = new_seed.hash()
    print("%s is set to seed: %s" % [_rng, new_seed])

#endregion


#region Dice Rolling
## Rolls dice asynchronously
static func roll_dice_async(dice: String, _rng: RandomNumberGenerator = rng_general) -> void:
    # TODO: Change dice from string variable to a class
    var parsed = parse_dice(dice, _rng)
    var num_dice = parsed["num_dice"]
    var num_sides = parsed["num_sides"]
    var total = 0
    var sum = []
    
    for i in range(num_dice):
        var result = _rng.randi_range(1, num_sides)
        sum.append(result)
        total += result

        if i % 10000 == 0:
            await Engine.get_singleton("Engine").process_frame

    print("Rolled %s: %s" % [dice, total])


## Parses a dice string into a dictionary of the number of dice and sides
static func parse_dice(dice: String, _rng: RandomNumberGenerator = rng_general) -> Dictionary:
    var parts = dice.split("d")
    if parts.size() != 2:
        push_error("Invalid dice format: %s" % dice)
        return {}
    var num_dice = int(parts[0])
    var num_sides = int(parts[1])
    if num_dice <= 0 or num_sides <= 0:
        push_error("Number of dice and sides must be positive: %s" % dice)
        return {}
    return {"num_dice": num_dice, "num_sides": num_sides}

#endregion


#region Colors
static func random_color(_rng: RandomNumberGenerator = rng_general) -> Color:
    return Color(_rng.randf(), _rng.randf(), _rng.randf())

#endregion


#region Utilities
## Shuffles an array with the fisher-yates algorithm.
func shuffle_array(array: Array, _rng: RandomNumberGenerator = rng_general) -> void:
    for i in range(array.size() - 1, 0, -1):
        var j = _rng.randi_range(0, i)
        var temp = array[i]
        array[i] = array[j]
        array[j] = temp

#endregion