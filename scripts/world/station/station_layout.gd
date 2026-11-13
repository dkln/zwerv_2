class_name StationLayout
extends RefCounted
## The plan of the inside of Den Haag Centraal (scenes/binnen/centraal.tscn): one source for
## the builder (tools/build/build_interiors.gd) and the game (scripts/world/station/station.gd).
## In the space of the scene (metres): x across the hall, z along the tracks; the camera looks
## in from -z and +x (Iso.DIRECTION), so the low walls are at the front (-z) and the right.
##
##   z -32 .. 0    the hall (de stationshal): three entrances in the front wall (x -24, 0, 24,
##                 under the three canopies of the town's station), shops along the left wall
##                 and a block of shops in the middle, ticket machines along the right wall,
##                 the departure boards hanging over it
##   z ~ -1.5      the gate line: before every platform OV gates (lanes in and out), before
##                 the tracks a glass fence
##   z 0 .. 52     twelve tracks (a head station: they end at buffer stops by the hall) and
##                 seven platforms: a side platform at each wall, five islands between them
##   z 52          the back wall, with an opening for each track (the trains come and go there)
##
## The columns of the floor plan, 4 m each from x = HALL_LEFT: a platform (P), two tracks (T),
## a platform, ... : P T T P P T T P ... P T T P (COLUMNS). Platform tiles have their edge
## (the yellow line) on the side of their track. The platforms and tracks are the town's tiles
## (grond/spoor/...), their top 1.375 m above the rails: the Sporen map lies PLATFORM_DROP
## down, so the platforms are level with the floor of the hall (y = 0).

const CELL := 4.0
const TRACK_COUNT := 12
const HALL_LEFT := -48.0
const HALL_RIGHT := 48.0
const COLUMN_COUNT := 24
## Rows of platform and track (4 m each) from z = 0: 52 m, a train of three cars (40 m) fits.
const PLATFORM_ROWS := 13
const HALL_FRONT := -32.0
const BACK_WALL := 52.0
## The top of a platform tile above the rails (11 voxels of 0.125 m: grond/spoor/perron).
const PLATFORM_DROP := 1.375
## Where the nose of a train stands at its stop: just before the buffer stop.
const STOP_NOSE_Z := 2.4
## The gate line: the middle of the cabinets (1.5 m long along z).
const GATE_Z := -1.5
const GATE_LENGTH := 1.5
const GATE_CABINET_WIDTH := 0.375
## The three entrances (x of their middle) in the front wall, from left to right; the doors of
## the town's station hall from west to east lead to them.
const ENTRANCE_X := [-24.0, 0.0, 24.0]
const ENTRANCE_WIDTH := 4.0
## The block of shops in the middle of the hall (x from, x to, z from, z to).
const SHOP_BLOCK := Rect2(-8.0, -21.5, 16.0, 6.0)
## The shops along the left wall (3 m deep) and the ticket machines along the right one.
const LEFT_SHOPS_X := HALL_LEFT + 1.5
const TICKET_MACHINES_X := HALL_RIGHT - 0.5

## What runs from here: destinations and the kinds of trains (as on the boards).
const DESTINATIONS := [
	["Amsterdam Centraal", "Intercity"], ["Utrecht Centraal", "Intercity"], ["Rotterdam Centraal", "Intercity"],
	["Eindhoven Centraal", "Intercity"], ["Venlo", "Intercity"], ["Vlissingen", "Intercity"], ["Groningen", "Intercity"],
	["Leeuwarden", "Intercity"], ["Enschede", "Intercity"], ["Schiphol Airport", "Intercity"], ["Haarlem", "Sprinter"],
	["Leiden Centraal", "Sprinter"], ["Gouda", "Sprinter"], ["Dordrecht", "Sprinter"], ["Zoetermeer", "Sprinter"],
	["Rotterdam Centraal", "Sprinter"], ["Utrecht Centraal", "Sprinter"], ["Woerden", "Sprinter"],
]


## The kind of each column: "P" (platform) or "T" (track).
static func column_kind(column: int) -> String:
	if column == 0 or column == COLUMN_COUNT - 1:
		return "P"
	# after the first platform: two tracks, two platforms, two tracks, ...
	return "T" if ((column - 1) % 4) < 2 else "P"


## The middle (x) of a column.
static func column_x(column: int) -> float:
	return HALL_LEFT + column * CELL + CELL * 0.5


## The column of track `track` (1..TRACK_COUNT).
static func track_column(track: int) -> int:
	var pair := (track - 1) / 2
	return 1 + pair * 4 + (track - 1) % 2


static func track_x(track: int) -> float:
	return column_x(track_column(track))


## The side of track `track` its platform is on: -1 (towards -x) or 1.
static func platform_side(track: int) -> int:
	return -1 if track % 2 == 1 else 1


## The x of the yellow edge of the platform beside a track (where people wait at the doors).
static func platform_edge_x(track: int) -> float:
	return track_x(track) + platform_side(track) * CELL * 0.5


## The platforms: [first column, last column] each, from left to right.
static func platforms() -> Array:
	var found := []
	var column := 0
	while column < COLUMN_COUNT:
		if column_kind(column) == "P":
			var last := column
			while last + 1 < COLUMN_COUNT and column_kind(last + 1) == "P":
				last += 1
			found.append([column, last])
			column = last + 1
		else:
			column += 1
	return found


## The x range of a platform ([first column, last column]): Vector2(left, right).
static func platform_span(platform: Array) -> Vector2:
	return Vector2(HALL_LEFT + int(platform[0]) * CELL, HALL_LEFT + (int(platform[1]) + 1) * CELL)


## The platform (index in platforms()) a track lies at.
static func platform_of_track(track: int) -> int:
	var column := track_column(track) + platform_side(track)
	var all := platforms()
	for index in all.size():
		if column >= int(all[index][0]) and column <= int(all[index][1]):
			return index
	return -1


## The tracks beside a platform (index in platforms()).
static func tracks_of_platform(platform_index: int) -> Array[int]:
	var found: Array[int] = []
	for track in range(1, TRACK_COUNT + 1):
		if platform_of_track(track) == platform_index:
			found.append(track)
	return found


## The lanes of the gates before a platform: [x of the middle, direction] each; direction 1:
## into the station (from the hall to the platform, +z), -1 out of it. The cabinets stand
## between the lanes and at both ends (gate_cabinets).
static func gate_lanes(platform_index: int) -> Array:
	var span := platform_span(platforms()[platform_index])
	var width := span.y - span.x
	var lane_count := 4 if width > CELL * 1.5 else 2
	var pitch := (width - GATE_CABINET_WIDTH) / lane_count
	var lanes := []
	for lane in lane_count:
		var middle := span.x + GATE_CABINET_WIDTH * 0.5 + pitch * (lane + 0.5)
		lanes.append([middle, 1 if lane < lane_count / 2 else -1])
	return lanes


## The x of the cabinets before a platform (one more than there are lanes).
static func gate_cabinets(platform_index: int) -> Array[float]:
	var span := platform_span(platforms()[platform_index])
	var lane_count: int = gate_lanes(platform_index).size()
	var pitch := (span.y - span.x - GATE_CABINET_WIDTH) / lane_count
	var found: Array[float] = []
	for cabinet in lane_count + 1:
		found.append(span.x + GATE_CABINET_WIDTH * 0.5 + pitch * cabinet)
	return found


## The width of a lane between two cabinets (metres).
static func gate_lane_width(platform_index: int) -> float:
	var cabinets := gate_cabinets(platform_index)
	return cabinets[1] - cabinets[0] - GATE_CABINET_WIDTH


## The middle line people walk along on a platform beside `track` (between its edge and the
## middle of the platform, clear of the benches and columns in the middle of an island).
static func platform_walk_x(track: int) -> float:
	return platform_edge_x(track) + platform_side(track) * 1.6
