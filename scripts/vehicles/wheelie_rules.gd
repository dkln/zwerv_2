extends RefCounted
## The sums of a wheelie (logic; docs/CODE_LAGEN.md): how often one starts, how far the front
## is up while it wobbles, how fast it rises and drops, the bounce of the front wheel landing
## and the turn of the body about the rear wheel's contact point. Pure: the state, the clock
## and the draws are wheelie.gd's.
##   const WheelieRules = preload("res://scripts/vehicles/wheelie_rules.gd")

## Mean seconds between two wheelies of one rider while it may do one.
const MEAN_PAUSE := 45.0
## Seconds the front stays up (shortest, longest).
const UP_SECONDS := Vector2(4.0, 7.0)
## The share of its most angle a wheelie goes up to (least, most).
const HEIGHT_SHARE := Vector2(0.9, 1.0)
## How fast the front goes up and comes down (1/s), and the wobble while up.
const RISE_RATE := 5.0
const DROP_RATE := 7.0
const WOBBLE_SHARE := 0.12
const WOBBLE_SPEED := 6.0
## The bounce of the front wheel landing: share of the height, how fast it dies out, how
## fast it springs (radians per second) and how long it lasts (seconds).
const BOUNCE_SHARE := 0.18
const BOUNCE_DAMPING := 9.0
const BOUNCE_SPEED := 14.0
const BOUNCE_SECONDS := 0.8
## Under this angle (radians) the front counts as down (a new wheelie may start), over
## UP_ANGLE as up, and under BOUNCE_UNDER the landing bounce shows.
const DOWN_ANGLE := 0.01
const UP_ANGLE := 0.01
const BOUNCE_UNDER := 0.02


## Whether the front is up: still being held up (`up_left` seconds to go) or not down yet.
static func is_up(up_left: float, angle: float) -> bool:
	return up_left > 0.0 or angle > UP_ANGLE


## The chance that a wheelie starts within `delta` seconds.
static func start_chance(delta: float) -> float:
	return delta / MEAN_PAUSE


## Whether a wheelie may start: allowed, and the front down (at `angle`).
static func may_start(allowed: bool, angle: float) -> bool:
	return allowed and angle < DOWN_ANGLE


## The angle the front wants to be at while up: `height`, wobbling with the `clock` (seconds).
static func wanted_angle(height: float, clock: float) -> float:
	return height * (1.0 + WOBBLE_SHARE * sin(clock * WOBBLE_SPEED))


## `angle` a step of `delta` seconds on its way up to `wanted`.
static func risen(angle: float, wanted: float, delta: float) -> float:
	return lerpf(angle, wanted, 1.0 - exp(-RISE_RATE * delta))


## `angle` a step of `delta` seconds on its way down.
static func dropped(angle: float, delta: float) -> float:
	return lerpf(angle, 0.0, 1.0 - exp(-DROP_RATE * delta))


## How far the front wheel springs up `bounce` seconds after it landed from `height`.
static func spring(bounce: float, height: float) -> float:
	return absf(sin(bounce * BOUNCE_SPEED)) * exp(-bounce * BOUNCE_DAMPING) * BOUNCE_SHARE * height


## `angle` with the landing bounce in it: only when the front is nearly down.
static func bounced(angle: float, spring_angle: float) -> float:
	return maxf(angle, spring_angle) if angle < BOUNCE_UNDER else angle


## Whether the landing bounce is over, `bounce` seconds after the front wheel landed.
static func bounce_done(bounce: float) -> bool:
	return bounce > BOUNCE_SECONDS


## The turn of the body (in its own space: front +z, up +y) that lifts the front by `angle`
## about `pivot`, the point where its rear wheel touches the road.
static func tilt_about(angle: float, pivot: Vector3) -> Transform3D:
	var turn := Basis(Vector3.RIGHT, -angle)
	return Transform3D(turn, pivot - turn * pivot)
