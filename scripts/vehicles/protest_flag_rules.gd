extends RefCounted
## How the protest flag of a tractor waves (logic; docs/CODE_LAGEN.md): the turn of its cloth
## round the pole at a moment, and the moment each flag starts at so they do not wave as one.
## Pure: the clock is protest_flag.gd's.
##   const ProtestFlagRules = preload("res://scripts/vehicles/protest_flag_rules.gd")

## The waving: degrees to each side round the pole, and how fast (radians per second).
const WAVE_DEGREES := 12.0
const WAVE_SPEED := 3.1
## The slow wave and the quick one on top of it: their shares, and how much quicker.
const SLOW_SHARE := 0.7
const QUICK_SHARE := 0.3
const QUICK_FACTOR := 2.3
## The seconds a flag is ahead of the clock: its instance id, wrapped, times this.
const OFFSET_WRAP := 997
const OFFSET_STEP := 0.37


## The seconds the flag with `instance_id` is ahead of the clock.
static func wave_offset(instance_id: int) -> float:
	return float(instance_id % OFFSET_WRAP) * OFFSET_STEP


## The turn of the cloth round the pole (radians) at `seconds`.
static func cloth_turn(seconds: float) -> float:
	return deg_to_rad(WAVE_DEGREES) * (sin(seconds * WAVE_SPEED) * SLOW_SHARE + sin(seconds * WAVE_SPEED * QUICK_FACTOR) * QUICK_SHARE)
