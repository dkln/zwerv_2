extends RefCounted
## The sizes of the beacon of the marker (layout; docs/CODE_LAGEN.md): the beam standing on
## the place and the ring on the ground at its foot. The node: waypoint_beacon.gd.
##   const WaypointBeaconLayout = preload("res://scripts/world/town/waypoint_beacon_layout.gd")

## The beam: how high (metres) and how wide at its foot; its top is this share as wide.
const BEAM_HEIGHT := 60.0
const BEAM_RADIUS := 0.35
const BEAM_TOP_SHARE := 0.6
## The ring on the ground: its radius, how thick it is and how high it lies above the ground.
const RING_RADIUS := 1.6
const RING_THICKNESS := 0.12
const RING_LIFT := 0.08


## Where the middle of the beam is above the beacon's place: it stands on the ground.
static func beam_centre() -> Vector3:
	return Vector3(0.0, BEAM_HEIGHT * 0.5, 0.0)


## Where the ring lies: just above the ground.
static func ring_centre() -> Vector3:
	return Vector3(0.0, RING_LIFT, 0.0)
