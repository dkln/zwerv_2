extends RefCounted
## Where the people on the terraces sit (layout; docs/CODE_LAGEN.md): the terrace tiles with
## a chair on either side of the table, where each chair stands from the table and which
## way it faces. Who sits there: terraces_rules.gd; the node that seats them: terraces.gd.
##   const TerracesLayout = preload("res://scripts/world/people/terraces_layout.gd")

## The terrace tiles with a chair on either side of the table (props/terras/, terrace_set).
const TERRACE_TILES := ["terras/terras_set", "terras/terras_set_parasol", "terras/terras_set_parasol_groen"]
## Metres from the middle of the table to a chair, and the height of its seat.
const CHAIR_OFFSET := 0.81
const SEAT_HEIGHT := 0.5
## The two chairs of a table: before it (+z of the tile) and behind it.
const SIDES: Array[float] = [1.0, -1.0]


## Where the chair on `side` (SIDES) of the table at `table` stands, the tile turned by
## `turn`, on the ground at `ground_height`.
static func chair_spot(table: Vector3, turn: Basis, side: float, ground_height: float) -> Vector3:
	var chair := table + turn * Vector3(0.0, 0.0, CHAIR_OFFSET * side)
	return Vector3(chair.x, ground_height, chair.z)


## The way someone on that chair faces (radians round y): back to the table.
static func facing_of(turn: Basis, side: float) -> float:
	var facing := turn * Vector3(0.0, 0.0, -side)
	return atan2(facing.x, facing.z)
