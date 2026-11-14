extends Node3D
## The beacon of the marker you set on the map (GameHud.set_waypoint, from the game menu's
## KAART; behaviour, docs/CODE_LAGEN.md): a tall beam of light standing on the place, seen
## from far over the roofs, fading out upwards, and a ring on the ground at its foot that
## pulses (waypoint_beacon_view.gd; its sizes waypoint_beacon_layout.gd, the pulse
## waypoint_beacon_rules.gd). Hidden while the player is inside a building (`visible`).
##   var beacon := WaypointBeacon.new()   # GameHud makes one, in the town
##   beacon.place(Vector3(410, 0, 439))

const WaypointBeaconRules = preload("res://scripts/world/town/waypoint_beacon_rules.gd")
const WaypointBeaconLayout = preload("res://scripts/world/town/waypoint_beacon_layout.gd")
const WaypointBeaconView = preload("res://scripts/world/town/waypoint_beacon_view.gd")

const COLOUR := WaypointBeaconView.COLOUR
const BEAM_HEIGHT := WaypointBeaconLayout.BEAM_HEIGHT
const BEAM_RADIUS := WaypointBeaconLayout.BEAM_RADIUS
const BEAM_ALPHA := WaypointBeaconView.BEAM_ALPHA
const RING_RADIUS := WaypointBeaconLayout.RING_RADIUS
const PULSE_SECONDS := WaypointBeaconRules.PULSE_SECONDS

## Its picture: the beam and the ring.
var view := WaypointBeaconView.new()

var _clock := 0.0


func _ready() -> void:
	name = "Markerbaken"
	view.build(self)


## On the ground at `at` (world).
func place(at: Vector3) -> void:
	global_position = at


func _process(delta: float) -> void:
	_clock += delta
	view.show_ring_scale(WaypointBeaconRules.ring_scale(_clock))
