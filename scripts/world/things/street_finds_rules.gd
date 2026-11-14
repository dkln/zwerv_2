extends RefCounted
## Where the finds of the streets lie (logic; docs/CODE_LAGEN.md; street_finds.gd: loose
## change, lost bank cards): the arithmetic of it, without the town. Which ground a find
## lies on, how far from the start it may lie, which of the candidate cells get one, when
## the player walks over it and how long a find that could not be taken is left alone.
##   const StreetFindsRules = preload("res://scripts/world/things/street_finds_rules.gd")

## Ground tile folders finds lie on.
const FIND_GROUND := ["plein/", "stoep/"]
## How long a find that could not be taken (full pockets) is left alone.
const RETRY_SECONDS := 3.0
## What a kind of find has when it says nothing else: how far from the start the nearest
## may lie, how far the far ones lie apart (0: anywhere) and how far off the middle of its
## cell a find lies (metres).
const CLOSEST := 3.0
const APART := 0.0
const SCATTER := 1.4

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


## Whether the finds are looked at now: not while the player sleeps or is dead, and not
## before `refused_until` (a find that could not be taken is left alone for a while).
static func may_take(asleep: bool, dead: bool, clock: float, refused_until: float) -> bool:
	return not asleep and not dead and clock >= refused_until


## Until when the finds are left alone after one could not be taken at `clock`.
static func refused_until(clock: float) -> float:
	return clock + RETRY_SECONDS


## Whether a cell of the ground is built over: something of the buildings layer on its
## ground storey (`ground_item`) or the one above (`upper_item`); `empty` is the layer's
## "nothing here".
static func built_over(ground_item: int, upper_item: int, empty: int) -> bool:
	return ground_item != empty or upper_item != empty


static func _clear_of(chosen: Array[Vector3i], cell: Vector3i, apart: float, middle_of: Callable) -> bool:
	var middle: Vector3 = middle_of.call(cell)
	return chosen.all(func(other: Vector3i) -> bool:
		var other_middle: Vector3 = middle_of.call(other)
		return Vector2(middle.x, middle.z).distance_to(Vector2(other_middle.x, other_middle.z)) > apart)
