extends RefCounted
## The sums of someone knocked over (logic; docs/CODE_LAGEN.md): which way the body is
## thrown, how fast and how high, how it tumbles, how a dive out of a door goes, and how
## hard a blow of the lying body is. The body itself: knock_down.gd (throw) and
## knock_down_body.gd (the shards at every hard blow).
##   const KnockDownRules = preload("res://scripts/world/people/knock_down_rules.gd")

## Friction and bounce of a body on the street.
const FRICTION := 0.9
const BOUNCE := 0.2
## How high it is thrown (m/s up: this, plus this per m/s of the blow, at most MOST_UP), and
## how fast it tumbles (rad/s per m/s of the blow, at most MOST_SPIN).
const UP_BASE := 1.5
const UP_PER_IMPACT := 0.22
const MOST_UP := 7.0
const SPIN_PER_IMPACT := 0.6
const MOST_SPIN := 14.0
## The most it turns round its upright axis (rad/s, either way), and round the way it flies
## in a dive.
const MOST_TWIST := 3.0
const MOST_DIVE_ROLL := 1.0
## Thrown this far off the ground (m) so it does not start inside it.
const START_LIFT := 0.05
## A dive (`dive`: thrown out of a door head first, as a pike dive): the body already flat
## (pitched this far forward), lifted this high so it flies over the street, a little up
## (m/s) and hardly turning in the air; hitting the street it tumbles over by itself.
const DIVE_PITCH := deg_to_rad(80.0)
const DIVE_LIFT := 1.2
const DIVE_UP := 3.6
const DIVE_SPIN := 0.8
## The lying body: a blow counts from HARD_SPEED (m/s), not twice within QUIET_SECONDS; the
## speed of a blow that throws the most shards, and the least share of them.
const HARD_SPEED := 3.0
const QUIET_SECONDS := 0.12
const FULLEST_SPEED := 16.0
const LEAST_STRENGTH := 0.15


## `push` along the ground.
static func flat(push: Vector3) -> Vector3:
	return Vector3(push.x, 0.0, push.z)


## The way the body is thrown: along the push, or without one the way it faced (`facing`).
static func towards(push: Vector3, facing: Vector3) -> Vector3:
	var flat_push := flat(push)
	return flat_push.normalized() if flat_push.length_squared() > 0.01 else facing


## How fast the body flies off: the push along the ground (`push_factor` times) and up by
## the blow of `impact` (m/s).
static func thrown_velocity(push: Vector3, push_factor: float, impact: float) -> Vector3:
	return flat(push) * push_factor + Vector3.UP * minf(UP_BASE + impact * UP_PER_IMPACT, MOST_UP)


## How it tumbles: forward over (by the blow, `extra_spin` rad/s more) and `twist` rad/s round.
static func thrown_spin(way: Vector3, impact: float, extra_spin: float, twist: float) -> Vector3:
	return Vector3.UP.cross(way) * minf(impact * SPIN_PER_IMPACT + extra_spin, MOST_SPIN) + Vector3.UP * twist


## Where a dive starts: flat in the air, head first the way it is thrown, DIVE_LIFT up.
static func dive_start(way: Vector3, origin: Vector3) -> Transform3D:
	var facing := Basis.looking_at(-way, Vector3.UP)
	var tipped := Basis(way.cross(Vector3.UP).normalized(), -DIVE_PITCH) * facing
	return Transform3D(tipped, origin + Vector3.UP * DIVE_LIFT)


static func dive_velocity(push: Vector3, push_factor: float) -> Vector3:
	return flat(push) * push_factor + Vector3.UP * DIVE_UP


## Hardly turning in the air: a little over, and `roll` rad/s round the way it flies.
static func dive_spin(way: Vector3, roll: float) -> Vector3:
	return Vector3.UP.cross(way) * DIVE_SPIN + way * roll


## True if the lying body hitting something at `speed` (m/s) is a hard blow, `quiet` seconds
## of the pause after the last one still to go.
static func is_hard_blow(speed: float, quiet: float) -> bool:
	return speed >= HARD_SPEED and quiet <= 0.0


## The share of the shards of a crash (LEAST_STRENGTH..1) a blow at `speed` throws.
static func blow_strength(speed: float) -> float:
	return clampf(speed / FULLEST_SPEED, LEAST_STRENGTH, 1.0)
