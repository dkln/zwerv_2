extends RefCounted
## Where the lights in the tunnels hang (layout; docs/CODE_LAGEN.md): under the roof of the
## covered tunnel tiles of the ground layer (layer TUNNEL_LEVEL), in every SPACING-th
## column, one in the middle of each tube (each run of touching rows). The node:
## tunnel_lights.gd.
##   const TunnelLightsLayout = preload("res://scripts/world/town/tunnel_lights_layout.gd")

## Layer of the ground layer that tunnel tiles are placed on.
const TUNNEL_LEVEL := -6
## Metres above the tile's floor that a lamp hangs: just under the roof (5 m of headroom).
const LAMP_HEIGHT := 4.7
## Columns between two rows of lamps.
const SPACING := 2


## True for a column (cell x) that gets lamps: every SPACING-th.
static func is_lamp_column(column: int) -> bool:
	return posmod(column, SPACING) == 0


## The tubes in one column: the runs of touching rows among `rows` (cell z, in any order;
## sorted here), each as Vector2i(first row, last row).
static func tubes(rows: Array) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if rows.is_empty():
		return found
	rows.sort()
	var run_start: int = rows[0]
	for index in rows.size():
		var run_ends: bool = index == rows.size() - 1 or rows[index + 1] != rows[index] + 1
		if run_ends:
			found.append(Vector2i(run_start, rows[index]))
			if index < rows.size() - 1:
				run_start = rows[index + 1]
	return found


## Where the lamp of a tube hangs: over the middle between the centres of its first and last
## cell (world), LAMP_HEIGHT above the tunnel's floor.
static func lamp_position(first_cell_centre: Vector3, last_cell_centre: Vector3) -> Vector3:
	var middle := (first_cell_centre + last_cell_centre) * 0.5
	return Vector3(middle.x, TUNNEL_LEVEL + LAMP_HEIGHT, middle.z)
