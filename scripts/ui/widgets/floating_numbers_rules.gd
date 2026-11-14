extends RefCounted
## The life of a number that floats up from a point in the world (logic;
## docs/CODE_LAGEN.md): how long it lives, how high it has risen, how big its pop still is
## and how far it has faded. Kept by floating_numbers.gd.
##   const FloatingNumbersRules = preload("res://scripts/ui/widgets/floating_numbers_rules.gd")

## Seconds a number lives, how many metres it rises in that time, and when it starts to fade.
const LIFETIME := 1.1
const RISE_METRES := 1.4
const FADE_FROM := 0.45
## The pop when it appears: this much bigger, shrinking back in POP_SECONDS.
const POP_SCALE := 1.25
const POP_SECONDS := 0.12


## Whether a number `age` seconds old has had its `lifetime`.
static func is_over(age: float, lifetime: float) -> bool:
	return age >= lifetime


## The share (0..1 and on) of its `lifetime` a number `age` seconds old has had.
static func life_share(age: float, lifetime: float) -> float:
	return age / lifetime


## How many metres a number has risen at `share` (0..1) of its life: fast at first, slowing
## down to RISE_METRES.
static func rise(share: float) -> float:
	return RISE_METRES * (1.0 - pow(1.0 - share, 2.0))


## Where a number that came from `from` is at `share` of its life.
static func place(from: Vector3, share: float) -> Vector3:
	return from + Vector3.UP * rise(share)


## How big a number is `age` seconds old: POP_SCALE as it appears, its own size after POP_SECONDS.
static func pop_scale(age: float) -> float:
	return lerpf(POP_SCALE, 1.0, clampf(age / POP_SECONDS, 0.0, 1.0))


## How opaque a number is at `share` (0..1) of its life: whole until FADE_FROM, gone at the end.
static func opacity(share: float) -> float:
	return 1.0 - clampf((share - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)
