@tool
extends RefCounted
## Where the road surface lies (the layout layer of scripts/traffic/road_network.gd): the
## size of a road cell, the middle of a cell on the map, the height of the surface (flat at
## its layer, or rising across a ramp) and the slope of a ramp. A road cell is
## Vector3i(x, level, z): the ground cell (4 x 4 m) and its layer (1 m steps). A ramp is
## given as `rise`: [the heading it rises in, metres]; an empty one is a flat cell.
## (@tool: the editor shows the lanes, lane_arrows.gd.)
##   const RoadNetworkLayout = preload("res://scripts/traffic/road_network_layout.gd")

const CELL := 4.0
## Top of the road surface above the bottom of its layer (metres; 2 voxels of 0.125 m).
const ROAD_SURFACE := 0.25
## A flat cell (no ramp).
const FLAT := []


## The middle of a cell on the map (metres, x and z).
static func middle(cell: Vector3i) -> Vector2:
	return Vector2(cell.x + 0.5, cell.z + 0.5) * CELL


## Centre of a cell on the map (metres), at the height of its road surface.
static func centre(cell: Vector3i, rise: Array = FLAT) -> Vector3:
	var spot := middle(cell)
	return Vector3(spot.x, height(cell, spot, rise), spot.y)


## Height of the road surface of `cell` at map position `spot` (metres, x and z): flat
## at its layer, or rising across a ramp.
static func height(cell: Vector3i, spot: Vector2, rise: Array = FLAT) -> float:
	var surface := cell.y + ROAD_SURFACE
	if not rise.is_empty():
		var along := clampf((spot - middle(cell)).dot(Vector2(rise[0])) / CELL + 0.5, 0.0, 1.0)
		surface += along * float(rise[1])
	return surface


## Slope of the road in `heading` on a cell (metres up per metre).
static func slope(rise: Array, heading: Vector2i) -> float:
	if rise.is_empty():
		return 0.0
	return float(rise[1]) / CELL * float(Vector2(rise[0]).dot(Vector2(heading)))
