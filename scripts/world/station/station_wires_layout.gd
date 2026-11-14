extends RefCounted
## The overhead lines over the twelve tracks of Den Haag Centraal (layout;
## docs/CODE_LAGEN.md): where every wire, cantilever and mast is, as pure functions;
## station_view.gd draws them. The contact wire hangs CONTACT_WIRE_HEIGHT over the rails (as
## outside, OverheadLines.train_wire_height, so the pantographs touch it), the carrier wire
## CARRIER_RISE over it at a support, sagging CARRIER_SAG halfway. The supports are
## cantilevers from the white roof columns down the middle of every island
## (binnen/station/pilaar, at SUPPORT_Z) and from slim masts at the walls beside the two
## outer tracks; the wires run from just past the buffer stops (WIRE_FRONT_Z) through the
## openings in the back wall.
##   const WiresLayout = preload("res://scripts/world/station/station_wires_layout.gd")

const Layout = preload("res://scripts/world/station/station_layout.gd")
const CONTACT_WIRE_HEIGHT := 5.6
const CARRIER_RISE := 1.0
const CARRIER_SAG := 0.35
const SUPPORT_Z := [8.0, 20.0, 32.0, 44.0]
const WIRE_FRONT_Z := 1.5
const DROPPER_STEP := 3.0
const COLUMN_HALF_WIDTH := 0.25
## The masts at the walls: how far from the wall, their thickness and height (metres).
const WALL_MAST_INSET := 0.9
const WALL_MAST_WIDTH := 0.25
const WALL_MAST_HEIGHT := 6.0


## The height of the contact wire in the space of the station (the rails lie PLATFORM_DROP down).
static func contact_height() -> float:
	return -Layout.PLATFORM_DROP + CONTACT_WIRE_HEIGHT


## The height of the carrier wire at a support.
static func carrier_height() -> float:
	return contact_height() + CARRIER_RISE


## Every piece of wire and arm over all the tracks: two points each.
static func pieces() -> Array[PackedVector3Array]:
	var found: Array[PackedVector3Array] = []
	var contact_y := contact_height()
	var carrier_y := carrier_height()
	for track in range(1, Layout.TRACK_COUNT + 1):
		var track_x := Layout.track_x(track)
		found.append_array(track_wires(track_x, contact_y, carrier_y))
		var support := support_of(track)
		for support_z: float in SUPPORT_Z:
			found.append_array(cantilever(float(support.arm_start), track_x, float(support.towards), support_z, contact_y, carrier_y))
	return found


## The support on the platform side of `track`: a roof column in the middle of an island, or
## a mast at the wall beside an outer track: {"x", "outer", "towards" (the side of the
## track, -1 or 1), "arm_start" (the x its arm starts at)}.
static func support_of(track: int) -> Dictionary:
	var track_x := Layout.track_x(track)
	var platform: Array = Layout.platforms()[Layout.platform_of_track(track)]
	var span := Layout.platform_span(platform)
	var support_x := (span.x + span.y) * 0.5
	var outer := int(platform[0]) == int(platform[1])
	if outer:
		support_x = Layout.HALL_LEFT + WALL_MAST_INSET if support_x < 0.0 else Layout.HALL_RIGHT - WALL_MAST_INSET
	var towards := signf(track_x - support_x)
	return {"x": support_x, "outer": outer, "towards": towards,
		"arm_start": support_x + towards * (WALL_MAST_WIDTH * 0.5 if outer else COLUMN_HALF_WIDTH)}


## The height of the carrier wire `share` (0..1) of the way along the stretch `stop_index`
## (0: the anchored front end, from the contact wire up to the first support; else sagging
## between two supports).
static func carrier_at(stop_index: int, share: float, contact_y: float, carrier_y: float) -> float:
	if stop_index == 0:
		return lerpf(contact_y + 0.15, carrier_y, share)
	return carrier_y - CARRIER_SAG * 4.0 * share * (1.0 - share)


## The wires over one track: the level contact wire from the buffer stop through the back
## wall; above it the carrier wire, sagging between the supports, coming down to the
## contact wire at its front end (where it is anchored); droppers between the two.
static func track_wires(track_x: float, contact_y: float, carrier_y: float) -> Array[PackedVector3Array]:
	var found: Array[PackedVector3Array] = []
	found.append(PackedVector3Array([Vector3(track_x, contact_y, WIRE_FRONT_Z), Vector3(track_x, contact_y, Layout.BACK_WALL + 1.0)]))
	var stops: Array[float] = [WIRE_FRONT_Z]
	stops.append_array(SUPPORT_Z)
	stops.append(Layout.BACK_WALL + 1.0)
	for stop_index in stops.size() - 1:
		var from_z: float = stops[stop_index]
		var to_z: float = stops[stop_index + 1]
		var segment_count := maxi(ceili((to_z - from_z) / 1.0), 1)
		var previous := Vector3.ZERO
		for segment_index in segment_count + 1:
			var share := float(segment_index) / segment_count
			var point := Vector3(track_x, carrier_at(stop_index, share, contact_y, carrier_y), lerpf(from_z, to_z, share))
			if segment_index > 0:
				found.append(PackedVector3Array([previous, point]))
			previous = point
		# droppers from the carrier wire down to the contact wire
		var dropper_z := from_z + DROPPER_STEP
		while dropper_z < to_z - 1.0:
			var top := carrier_at(stop_index, (dropper_z - from_z) / (to_z - from_z), contact_y, carrier_y)
			if top - contact_y > 0.2:
				found.append(PackedVector3Array([Vector3(track_x, top, dropper_z), Vector3(track_x, contact_y, dropper_z)]))
			dropper_z += DROPPER_STEP
	return found


## A cantilever from a support (`arm_start`, on the side of the track `towards` points away
## from) to the wires over `track_x` at `support_z`: the top tube holding the carrier wire,
## the diagonal brace under it, the registration arm holding the contact wire, and the hanger
## between the two wires.
static func cantilever(arm_start: float, track_x: float, towards: float, support_z: float,
		contact_y: float, carrier_y: float) -> Array[PackedVector3Array]:
	var beyond := track_x + towards * 0.3
	var arms: Array[PackedVector3Array] = [
		PackedVector3Array([Vector3(arm_start, carrier_y + 0.1, support_z), Vector3(beyond, carrier_y + 0.1, support_z)]),
		PackedVector3Array([Vector3(arm_start, contact_y - 0.3, support_z), Vector3(track_x - towards * 0.5, carrier_y + 0.1, support_z)]),
		PackedVector3Array([Vector3(track_x - towards * 1.0, contact_y + 0.45, support_z), Vector3(track_x, contact_y, support_z)]),
		PackedVector3Array([Vector3(track_x, carrier_y + 0.1, support_z), Vector3(track_x, contact_y, support_z)]),
	]
	return arms


## The feet of the masts at the two walls (on the platform), in the order they are numbered.
static func wall_mast_feet() -> Array[Vector3]:
	var feet: Array[Vector3] = []
	for wall_x: float in [Layout.HALL_LEFT + WALL_MAST_INSET, Layout.HALL_RIGHT - WALL_MAST_INSET]:
		for support_z: float in SUPPORT_Z:
			feet.append(Vector3(wall_x, 0.0, support_z))
	return feet


## The size of a wall mast (and of its collider).
static func mast_size() -> Vector3:
	return Vector3(WALL_MAST_WIDTH, WALL_MAST_HEIGHT, WALL_MAST_WIDTH)


## The middle of the mast whose foot is at `foot`.
static func mast_middle(foot: Vector3) -> Vector3:
	return foot + Vector3.UP * WALL_MAST_HEIGHT * 0.5
