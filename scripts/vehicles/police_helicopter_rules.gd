extends RefCounted
## How the police helicopter flies and flashes (logic; docs/CODE_LAGEN.md): how far its
## rotors have turned and how much their blades blur, when the strobe and the beacon are lit,
## from which darkness the search light is on, and the circle it flies (where it is, which
## way it faces, banked into the turn with its nose a little down). Pure: the clock and the
## angles are police_helicopter.gd's.
##   const PoliceHelicopterRules = preload("res://scripts/vehicles/police_helicopter_rules.gd")

## Turns per second of the main rotor and the tail rotor, and from how many radians per
## second their blades blur into a disc (fully at twice that).
const MAIN_ROTOR_TURNS := 5.0
const TAIL_ROTOR_TURNS := 22.0
const BLUR_FROM := 6.0
## Seconds of one flash of the strobe and the beacon, the share of it they are lit, and how
## far (share of the cycle) the beacon is behind the strobe.
const FLASH_CYCLE := 1.1
const FLASH_LIT := 0.12
const BEACON_BEHIND := 0.5
## Degrees it banks into the turn while circling, and how far its nose dips.
const BANK_DEGREES := 14.0
const NOSE_DOWN_DEGREES := 6.0
## From this darkness (the Dagcyclus' "night", 0 .. 1) the search light is on.
const SEARCHLIGHT_FROM := 0.35
## The smallest radius (m) the speed round the circle is worked out with.
const LEAST_RADIUS := 1.0


## Radians per second of a rotor making `turns_per_second`.
static func rotor_speed(turns_per_second: float) -> float:
	return TAU * turns_per_second


## The angle of a rotor at `angle`, `delta` seconds on (0 .. TAU).
static func rotor_angle(angle: float, turns_per_second: float, delta: float) -> float:
	return fmod(angle + TAU * turns_per_second * delta, TAU)


## How much the blades of a rotor blur into a disc (0 .. 1) at `radians_per_second`.
static func spin_blur(radians_per_second: float) -> float:
	return clampf((radians_per_second - BLUR_FROM) / BLUR_FROM, 0.0, 1.0)


## How far into the flash cycle (0 .. 1) the lamps are at `seconds`.
static func flash_phase(seconds: float) -> float:
	return fmod(seconds, FLASH_CYCLE) / FLASH_CYCLE


## Whether the strobe on the fin is lit at `phase` of the flash cycle.
static func strobe_lit(phase: float) -> bool:
	return phase < FLASH_LIT


## Whether the beacon under the belly is lit at `phase`: half a cycle after the strobe.
static func beacon_lit(phase: float) -> bool:
	return fmod(phase + BEACON_BEHIND, 1.0) < FLASH_LIT


## Whether the search light is on at this darkness (`night`, 0 .. 1).
static func searchlight_on(night: float) -> bool:
	return night >= SEARCHLIGHT_FROM


## The way the angle round the circle goes: a growing angle on (cos, 0, sin) goes from x to
## z, clockwise seen from above (1.0); anticlockwise it shrinks (-1.0).
static func turning(anticlockwise: bool) -> float:
	return -1.0 if anticlockwise else 1.0


## The angle round the circle `delta` seconds on, at `speed` m/s round `radius` m.
static func circle_angle(angle: float, anticlockwise: bool, speed: float, radius: float, delta: float) -> float:
	return fmod(angle + turning(anticlockwise) * speed / maxf(radius, LEAST_RADIUS) * delta, TAU)


## The direction from the middle of the circle out to the helicopter at `angle`.
static func circle_out(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle))


## Where it is at `angle` round the circle about `centre`.
static func circle_position(centre: Vector3, radius: float, height: float, angle: float) -> Vector3:
	return centre + circle_out(angle) * radius + Vector3.UP * height


## The way it flies at `angle`: along the circle the way it goes.
static func circle_ahead(angle: float, anticlockwise: bool) -> Vector3:
	var out := circle_out(angle)
	return Vector3(-out.z, 0.0, out.x) * turning(anticlockwise)


## How it is turned at `angle` round the circle: the nose (+Z) along it, banked into the
## turn (its top towards the middle of the circle), the nose a little down.
static func circle_basis(angle: float, anticlockwise: bool) -> Basis:
	var ahead := circle_ahead(angle, anticlockwise)
	var facing := Basis.looking_at(-ahead, Vector3.UP)   # its front is +Z
	var bank := Basis(ahead, deg_to_rad(BANK_DEGREES) * turning(anticlockwise))
	var nose_down := Basis(Vector3.RIGHT, deg_to_rad(NOSE_DOWN_DEGREES))
	return bank * facing * nose_down
