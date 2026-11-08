extends RefCounted
## The blinking of something about to go, as in old games: in its last SECONDS it blinks,
## slowly at first (START_RATE blinks a second) and ever faster (up to END_RATE) until it
## is gone. Wrecks in the town (vehicle.gd, before they are towed) and behind the menu
## (main_menu.gd) use it.

const SECONDS := 2.5
const START_RATE := 3.0
const END_RATE := 16.0


## Whether it shows now, `seconds_left` before it goes.
static func shown(seconds_left: float) -> bool:
	if seconds_left >= SECONDS:
		return true
	var into := clampf(SECONDS - seconds_left, 0.0, SECONDS)
	# the blinks so far: the rate rises evenly, so their count is its integral
	var blinks := START_RATE * into + (END_RATE - START_RATE) * into * into / (2.0 * SECONDS)
	return fmod(blinks, 1.0) < 0.5
