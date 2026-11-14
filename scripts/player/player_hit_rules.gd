extends RefCounted
## The rules of the player being hit, knocked down, thrown out and dying (logic;
## docs/CODE_LAGEN.md): how hard a blow is and what it costs, which cry it gives, when the
## figure blinks, when the knocked down body stands up or drowns, and the slow motion of a
## death or of being thrown out. The behaviour is player_controller.gd (hit_by_moving,
## thrown_out, _die, _set_game_speed).
##   const PlayerHitRules = preload("res://scripts/player/player_hit_rules.gd")

## The impact (m/s) that counts as the hardest blow (strength 1), and the weakest strength.
const HARDEST_IMPACT := 20.0
const WEAKEST_STRENGTH := 0.15
## How far (metres) a slow nudge makes it step aside.
const NUDGE_STEP := 0.08
## The short cries of pain (pijn_<voice>_1..SHORT_CRY_COUNT).
const SHORT_CRY_COUNT := 3
## The blinking after a blow: seconds per blink, and the part of it the figure is hidden.
const BLINK_PERIOD := 0.14
const BLINK_HIDDEN := 0.07
## Run over and killed, or starved: the game runs at DEATH_SLOW_MOTION of its speed (the
## sound slowed down with it, at least SLOWEST_SOUND) for DEATH_SLOW_SECONDS real seconds;
## then the speed comes back over DEATH_SPEED_UP seconds and the death screen comes up.
const DEATH_SLOW_MOTION := 0.15
const SLOWEST_SOUND := 0.45
const DEATH_SLOW_SECONDS := 2.2
const DEATH_SPEED_UP := 0.5
## The deaths that get the slow motion and the close-up.
const SLOW_MOTION_DEATHS := ["aangereden", "honger"]
## What the player dies of or is hurt by (the death screen's reasons).
const RUN_OVER := "aangereden"
const STARVED := "honger"
const DROWNED := "verdronken"
const WOUNDED := "gewond"
const THROWN_OUT := "eruit_gegooid"
## Thrown out of a building: the health it costs, the slow motion (game speed, real seconds
## it holds and takes to come back), and when the groan comes at the latest (three times
## THROW_GROAN_AFTER seconds of game time after the kick).
const THROW_DAMAGE := 12.0
const THROW_SLOW_MOTION := 0.3
const THROW_SLOW_SECONDS := 1.4
const THROW_SPEED_UP := 0.6
const THROW_GROAN_AFTER := 0.5
## Getting up after being knocked over: seconds from lying to standing.
const STAND_UP_SECONDS := 0.9
## The knocked down body lies still below this speed (m/s); it gives up waiting to lie still
## after GIVES_UP times the knock down time.
const STILL_SPEED := 0.3
const GIVES_UP := 3.0
## Thrown into the water: from this long after the throw, not going up faster than this,
## and this close over the water it drowns. Sinking takes off this share of the health at once.
const WATER_AFTER := 0.3
const WATER_RISING := 0.5
const WATER_NEAR := 0.8
const SINK_HEALTH_SHARE := 0.5
## A vehicle further up or down than this (metres) does not touch the figure.
const VEHICLE_HEIGHT := 2.5
## Vehicles are looked at within this far (metres) for being hit, and for standing in the way.
const HIT_LOOK := 60.0
const VEHICLE_GAP := 0.05
const VEHICLE_LOOK := 18.0
const VEHICLE_LOOK_MARGIN := 100.0


## The speed (m/s) something moving at `mover_velocity` closes in on a figure moving at `own_velocity`.
static func impact(mover_velocity: Vector3, own_velocity: Vector3) -> float:
	return (mover_velocity - own_velocity).length()


## Whether a blow is only a nudge (slower than `threshold`): it steps aside, no harm.
static func is_nudge(impact_speed: float, threshold: float) -> bool:
	return impact_speed < threshold


## The step aside for a nudge from `from`: away from it over the ground; ZERO right on top of it.
static func nudge_step(position: Vector3, from: Vector3) -> Vector3:
	var away := position - from
	away.y = 0.0
	if not away.length_squared() > 0.0001:
		return Vector3.ZERO
	return away.normalized() * NUDGE_STEP


## Health a blow of `impact_speed` m/s costs.
static func damage(impact_speed: float, per_speed: float, per_speed_squared: float) -> float:
	return per_speed * impact_speed + per_speed_squared * impact_speed * impact_speed


## How hard a blow is, WEAKEST_STRENGTH..1 (shards, the shake of the view, which cry).
static func strength(impact_speed: float) -> float:
	return clampf(impact_speed / HARDEST_IMPACT, WEAKEST_STRENGTH, 1.0)


## Whether a blow of this strength gets the long cry.
static func is_heavy(blow_strength: float, hard_cry_strength: float) -> bool:
	return blow_strength >= hard_cry_strength


## Whether nothing can hit it now: knocked down, dead, or just hit.
static func cannot_be_hit(knocked_down: bool, dead: bool, invulnerable_left: float) -> bool:
	return knocked_down or dead or invulnerable_left > 0.0


## The short cry to give when `drawn` (1..SHORT_CRY_COUNT) came up and `last` was the one
## before: never the same twice in a row.
static func short_cry(drawn: int, last: int) -> int:
	return drawn % SHORT_CRY_COUNT + 1 if drawn == last else drawn


## The sound of a cry of pain in `voice`: the long one, or short cry `number`.
static func cry_name(voice: String, heavy: bool, number: int) -> String:
	return "pijn_%s_hard" % voice if heavy else "pijn_%s_%d" % [voice, number]


## The sound of the cry it dies with, and of the groan after being thrown out.
static func death_cry(voice: String) -> String:
	return "pijn_%s_dood" % voice


static func groan(voice: String) -> String:
	return "pijn_%s_kreun" % voice


## Whether the figure shows with `blink_left` seconds of blinking to go.
static func blink_shows(blink_left: float) -> bool:
	return blink_left <= 0.0 or fmod(blink_left, BLINK_PERIOD) > BLINK_HIDDEN


## Whether a blow that leaves `health` blinks: not the one it dies of.
static func blow_blinks(health: Vector2) -> bool:
	return health.x > 0.0


## Whether the figure has no health left.
static func is_fatal(health: Vector2) -> bool:
	return health.x <= 0.0


## Whether a death gets the slow motion and the close-up.
static func is_slow_motion_death(cause: String) -> bool:
	return cause in SLOW_MOTION_DEATHS


## The physics steps a second at game speed `speed` when `normal_ticks` is the ordinary
## number: as often in real time.
static func physics_ticks(normal_ticks: int, speed: float) -> int:
	return roundi(normal_ticks / speed)


## The speed of the sound at game speed `speed`: slowed down with it, at least SLOWEST_SOUND.
static func sound_speed(speed: float) -> float:
	return maxf(speed, SLOWEST_SOUND) if speed < 1.0 else 1.0


## Whether the knocked down body lies still.
static func lies_still(asleep: bool, body_speed: float) -> bool:
	return asleep or body_speed < STILL_SPEED


## Whether the knocked down figure stands up, `seconds` after the blow: lying still after
## `knock_down_time`, or anyhow after GIVES_UP times as long.
static func stands_up(seconds: float, knock_down_time: float, still: bool) -> bool:
	return (seconds >= knock_down_time and still) or seconds >= knock_down_time * GIVES_UP


## Whether the thrown body is looked at for landing in water: a moment after the throw, coming down.
static func may_hit_water(seconds: float, vertical_speed: float) -> bool:
	return seconds > WATER_AFTER and vertical_speed <= WATER_RISING


## Whether the thrown body at `body_height` is in the water whose surface is at `water_height`.
static func is_in_water(body_height: float, water_height: float) -> bool:
	return body_height - water_height < WATER_NEAR


## Whether the landing of someone thrown out still has to come, `seconds` after the kick.
static func landing_overdue(seconds: float) -> bool:
	return seconds >= THROW_GROAN_AFTER * GIVES_UP


## Health going under costs at once.
static func sink_damage(health: Vector2) -> float:
	return health.x * SINK_HEALTH_SHARE


## Whether a vehicle at `offset` from the figure is near enough (within `look` metres over the
## ground, squared margin `margin`) and on its level to matter.
static func vehicle_matters(offset: Vector3, look: float, margin: float) -> bool:
	return not (absf(offset.y) > VEHICLE_HEIGHT or Vector2(offset.x, offset.z).length_squared() > look * look + margin)
