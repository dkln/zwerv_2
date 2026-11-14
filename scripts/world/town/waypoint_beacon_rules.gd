extends RefCounted
## The pulse of the beacon of the marker (logic; docs/CODE_LAGEN.md): how big the ring on
## the ground is at a moment. The node: waypoint_beacon.gd.
##   const WaypointBeaconRules = preload("res://scripts/world/town/waypoint_beacon_rules.gd")

## The ring pulses once in this many seconds: from SMALLEST times its own size, SWELL more
## at its largest.
const PULSE_SECONDS := 1.4
const SMALLEST := 0.85
const SWELL := 0.3


## The size of the ring (a factor on its own) `clock` seconds after the beacon appeared.
static func ring_scale(clock: float) -> float:
	var pulse := 0.5 + 0.5 * sin(clock / PULSE_SECONDS * TAU)
	return SMALLEST + SWELL * pulse
