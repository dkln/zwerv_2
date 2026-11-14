extends RefCounted
## Choosing a way at random, shared by who walks and who drives: one of some options by their
## weights (Vehicle._choose_heading: straight on or a turn, the ways driven less often more
## likely) and options in a random order (Pedestrian._choose_next: the ways off a cell).
## The random numbers come from the caller's generator, so a seed gives the same choices.
##   const WayChoice = preload("res://scripts/pathfinding/way_choice.gd")


## The index of the option chosen by `weights` (one per option, each >= 0: its share of the
## chance); the last one when they are all 0, -1 when there are none.
static func weighted(random: RandomNumberGenerator, weights: Array) -> int:
	if weights.is_empty():
		return -1
	var total := 0.0
	for weight: float in weights:
		total += weight
	var pick := random.randf() * total
	for index in weights.size():
		pick -= float(weights[index])
		if pick <= 0.0:
			return index
	return weights.size() - 1


## Puts `options` in a random order, in place (Fisher-Yates).
static func shuffle(random: RandomNumberGenerator, options: Array) -> void:
	for index in range(options.size() - 1, 0, -1):
		var other := random.randi_range(0, index)
		var kept: Variant = options[index]
		options[index] = options[other]
		options[other] = kept
