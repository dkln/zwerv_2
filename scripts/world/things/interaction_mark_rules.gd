extends RefCounted
## The rules of the arrow bobbing over something you can use (logic; docs/CODE_LAGEN.md;
## interaction_mark.gd): from how far it shows and how high its point stands as it bobs.
##   const InteractionMarkRules = preload("res://scripts/world/things/interaction_mark_rules.gd")

## From how far the arrow shows (metres).
const MARK_FROM := 22.0
## How it bobs: once up and down in BOB_SECONDS.
const BOB_SECONDS := 1.2


## Whether the arrow shows: it is `allowed`, there is a player and the arrow is in the
## world (`present`), and the player is less than MARK_FROM metres away.
static func shows(allowed: bool, present: bool, distance: float) -> bool:
	return allowed and present and distance < MARK_FROM


## How high the point of the arrow stands after `clock` seconds of bobbing between `bottom`
## and `top`.
static func height(bottom: float, top: float, clock: float) -> float:
	var swing := 0.5 + 0.5 * sin(clock * TAU / BOB_SECONDS)
	return lerpf(bottom, top, swing)
