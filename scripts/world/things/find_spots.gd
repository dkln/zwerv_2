extends RefCounted
## Where the finds of the streets lie (StreetFinds: loose change, lost bank cards): the
## arithmetic of it, without the town. Which ground a find lies on, how far from the start
## it may lie, which of the candidate cells get one and when the player walks over it.
##   const FindSpots = preload("res://scripts/world/things/find_spots.gd")

## How far above or below the player's feet a find may lie and still be walked over.
const HEIGHT_REACH := 1.6


## Whether a find lies on the ground tile `tile_name`: one of the `folders` ("plein/", ...).
static func is_find_ground(tile_name: String, folders: Array) -> bool:
	return folders.any(func(folder: String) -> bool: return tile_name.begins_with(folder))


## Which ring round the start a cell `distance` m away lies in: "near" (from `closest` up to
## `near` m), "far" (beyond it, up to `reach`) or "" (too close by or too far off).
static func ring(distance: float, closest: float, near: float, reach: float) -> String:
	if distance > reach or distance < closest:
		return ""
	return "near" if distance <= near else "far"


## The cells that get a find: the first `near_count` of `near_cells`, then of `far_cells`
## until there are `count`; a far cell only if it lies more than `apart` m (flat) from every
## cell chosen so far (0: no such rule). `middle_of` gives a cell's middle (Vector3).
static func choose(near_cells: Array, far_cells: Array, near_count: int, count: int, apart: float, middle_of: Callable) -> Array[Vector3i]:
	var chosen: Array[Vector3i] = []
	chosen.append_array(near_cells.slice(0, maxi(near_count, 0)))
	for cell: Vector3i in far_cells:
		if chosen.size() >= count:
			break
		if apart <= 0.0 or _clear_of(chosen, cell, apart, middle_of):
			chosen.append(cell)
	return chosen


## Whether the player with their feet at `feet` walks over a find at `at`: within
## `distance` m flat and about on the same height (HEIGHT_REACH).
static func walked_over(feet: Vector3, at: Vector3, distance: float) -> bool:
	return absf(at.y - feet.y) < HEIGHT_REACH and Vector2(at.x - feet.x, at.z - feet.z).length() < distance


static func _clear_of(chosen: Array[Vector3i], cell: Vector3i, apart: float, middle_of: Callable) -> bool:
	var middle: Vector3 = middle_of.call(cell)
	return chosen.all(func(other: Vector3i) -> bool:
		var other_middle: Vector3 = middle_of.call(other)
		return Vector2(middle.x, middle.z).distance_to(Vector2(other_middle.x, other_middle.z)) > apart)
