extends RefCounted
## Choosing a way at random, shared by who walks and who drives: one of some options by their
## weights (Vehicle._choose_heading: straight on or a turn, the ways driven less often more
## likely) and options in a random order (Pedestrian._choose_next: the ways off a cell).
## The random numbers come from the caller's generator, so a seed gives the same choices.
##   const WayChoice = preload("res://scripts/pathfinding/way_choice.gd")

const RandomPick = preload("res://scripts/common/random_pick.gd")


## The index of the option chosen by `weights` (RandomPick.weighted).
static func weighted(random: RandomNumberGenerator, weights: Array) -> int:
	return RandomPick.weighted(random, weights)


## Puts `options` in a random order, in place (RandomPick.shuffle).
static func shuffle(random: RandomNumberGenerator, options: Array) -> void:
	RandomPick.shuffle(random, options)
