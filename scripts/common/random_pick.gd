extends RefCounted
## Picking at random with the caller's generator, so a seed gives the same picks every time
## (Array.shuffle() and Array.pick_random() take no seed): one of some options by their
## weights, and a list put in a random order. Shared by everything that draws lots: the ways
## of who walks and drives (scripts/pathfinding/way_choice.gd), the cells traffic appears on,
## the shelves on offer in a supermarket, the seats taken in a snack bar, the bins with a can
## in them, where a find lies on the streets and what a coin is worth.
##   const RandomPick = preload("res://scripts/common/random_pick.gd")


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


## Puts `items` in a random order, in place (Fisher-Yates).
static func shuffle(random: RandomNumberGenerator, items: Array) -> void:
	for index in range(items.size() - 1, 0, -1):
		var other := random.randi_range(0, index)
		var kept: Variant = items[index]
		items[index] = items[other]
		items[other] = kept
