extends RefCounted
## The logic of what drifts through space behind the story of the intro (the rules layer
## of scripts/ui/intro/drifter.gd, which is the behaviour; drifter_layout.gd has the sizes,
## drifter_view.gd builds and shows it): what drifts next, when, and the flight it makes:
## in a straight line from one side of the screen to the other (a little up or down),
## smaller or bigger as it is further or nearer, tumbling round an axis of its own. Plain
## functions, without nodes; the toss is a RandomNumberGenerator handed in.
##   const DrifterRules = preload("res://scripts/ui/intro/drifter_rules.gd")

const PlayerCharacter = preload("res://scripts/player/player_character.gd")

## The first one comes FIRST seconds after the stars, then every EVERY (from .. to)
## seconds, each crossing the screen in SECONDS (from .. to); none starts in the last
## STOP_BEFORE_END seconds of the intro.
const FIRST := 14.0
const EVERY := Vector2(10.0, 20.0)
const SECONDS := Vector2(14.0, 20.0)
const STOP_BEFORE_END := 6.0
## What drifts: one of the characters (PlayerCharacter.ORDER) with CHARACTER_CHANCE, else
## a tractor (TRACTOR_MODELS); never the same one twice in a row.
const TRACTOR_MODELS := ["trekker", "trekker_rood"]
const CHARACTER_CHANCE := 0.7
## How big it shows (share of the biggest, from .. to), where it comes in (share of the
## height of the screen, from .. to), how far up or down it goes on the way (pixels each
## way) and how fast it tumbles (degrees a second, from .. to).
const SHOWN_SHARE := Vector2(0.45, 1.0)
const START_HEIGHT := Vector2(0.1, 0.75)
const DRIFT_UP_DOWN := 160.0
const SPIN := Vector2(18.0, 45.0)


## The next one to drift (`random` decides): a character with CHARACTER_CHANCE, else a
## tractor; never `last`, the one before.
static func pick_drifter(random: RandomNumberGenerator, last: String) -> String:
	var choices: Array = PlayerCharacter.ORDER if random.randf() < CHARACTER_CHANCE else TRACTOR_MODELS
	var others := choices.filter(func(choice: String) -> bool: return choice != last)
	return others[random.randi() % others.size()]


## Whether `drifter_name` is one of the characters (else: a tractor model).
static func is_character(drifter_name: String) -> bool:
	return PlayerCharacter.ARCHETYPES.has(drifter_name)


## Whether a new one may set off at `clock`: its time has come (`next_at`) and the intro
## is not nearly over (`last_at`).
static func may_start(clock: float, next_at: float, last_at: float) -> bool:
	return clock >= next_at and clock <= last_at


## A flight starting at `clock` over a screen of `screen_size`, shown `largest` pixels big
## at most (`random` decides): {"shown" (pixels big), "from", "to" (its top left corner),
## "start", "seconds", "axis" and "spin" (rad/s) of its tumbling, "attitude" (how it lies
## at the start, euler angles)}.
static func plan_flight(random: RandomNumberGenerator, clock: float, screen_size: Vector2, largest: float) -> Dictionary:
	var shown := largest * random.randf_range(SHOWN_SHARE.x, SHOWN_SHARE.y)
	var from_left := random.randf() < 0.5
	var start_height := random.randf_range(START_HEIGHT.x, START_HEIGHT.y) * screen_size.y
	var end_height := clampf(start_height + random.randf_range(-DRIFT_UP_DOWN, DRIFT_UP_DOWN), 0.0, screen_size.y - shown)
	var left := Vector2(-shown, start_height)
	var right := Vector2(screen_size.x, end_height)
	var seconds := random.randf_range(SECONDS.x, SECONDS.y)
	var axis := Vector3(random.randf_range(-1.0, 1.0), random.randf_range(-1.0, 1.0), random.randf_range(-0.5, 0.5)).normalized()
	var spin := deg_to_rad(random.randf_range(SPIN.x, SPIN.y)) * (1.0 if random.randf() < 0.5 else -1.0)
	var attitude := Vector3(random.randf_range(0.0, TAU), random.randf_range(0.0, TAU), 0.0)
	return {"shown": shown, "from": left if from_left else right, "to": right if from_left else left,
		"start": clock, "seconds": seconds, "axis": axis, "spin": spin, "attitude": attitude}


## How far `flight` is at `clock` (0: setting off, 1 or more: across).
static func flown(flight: Dictionary, clock: float) -> float:
	return (clock - float(flight.start)) / float(flight.seconds)


## Where `flight` is (its top left corner on the screen) at `share` of its way.
static func position_at(flight: Dictionary, share: float) -> Vector2:
	return (flight.from as Vector2).lerp(flight.to as Vector2, share)


## How far `flight` tumbles on in `delta` seconds (a turn round its axis).
static func tumble(flight: Dictionary, delta: float) -> Basis:
	return Basis(flight.axis as Vector3, float(flight.spin) * delta)


## How far off one shown `shown` pixels big is (0: the nearest, `largest` big; towards 1:
## smaller, further).
static func far_share(shown: float, largest: float) -> float:
	return 1.0 - shown / largest


## The moment the next one sets off after one that got across at `clock` (`random` decides).
static func next_start(random: RandomNumberGenerator, clock: float) -> float:
	return clock + random.randf_range(EVERY.x, EVERY.y)
