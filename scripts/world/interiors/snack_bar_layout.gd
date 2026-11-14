extends RefCounted
## The layout of a snack bar, worked out from its seed (the place on the map it belongs to),
## so the one interior (scenes/binnen/snackbar.tscn, scripts/world/interiors/interior.gd) is another
## room at every snack bar, and the same one each time you come back to it:
## - size: 2 to 4 floor tiles wide (CELL m each), 2 or 3 deep;
## - the door somewhere along the low front wall (not in a corner tile when there is room);
## - the counter before the high back wall, in any column, the fryer and the menu board
##   behind it, the keeper between them, the fridge against the left wall;
## - a table with two chairs in the columns before it (never right before the door), a
##   second row in a deep room: at least one table, how many from the seed.
## The room: x from -width/2 (the high left wall) to +width/2 (the low right one), z from
## -depth/2 (the low front with the door, where the camera looks in from) to +depth/2 (the
## high back wall), as the room the builder made (tools/build/build_interiors.gd). Every
## tile at a point of the 0.5 m grid, turned by `turn` (its front then faces (sin turn, 0,
## cos turn)); the tile names without their folder and, for the ones that have them,
## without their colour variant ("<name>_<variant>": Interior.VARIANTS; `varied` true).
##   var plan := SnackBarLayout.plan(1234)

const RandomPick = preload("res://scripts/common/random_pick.gd")
const CELL := 4.0
const WIDTHS := [2, 3, 3, 4]
const DEPTHS := [2, 2, 3]
## The counter stands this far before the back wall, the keeper behind it; the tables this
## far from the front wall (and a second row this much further in).
const COUNTER_FROM_BACK := 2.5
const KEEPER_FROM_BACK := 1.5
const TABLES_FROM_FRONT := 2.5
const SECOND_ROW := 3.0
const DOOR_INSIDE := 0.8
## Share of the table spots that get a table (at least one does).
const TABLE_SHARE := 0.7


## The plan: {"width", "depth" (m), "floor": [[tile, at]], "tiles": [[tile, at, turn, varied]],
## "door": Transform3D (where you come in, facing into the room), "keeper": Transform3D,
## "seats": [Transform3D], "name_at": Vector3, "lamps": [Vector3]}.
static func plan(seed: int) -> Dictionary:
	var random := RandomPick.seeded(hash(["snackbar", seed]))
	var columns: int = WIDTHS[random.randi() % WIDTHS.size()]
	var rows: int = DEPTHS[random.randi() % DEPTHS.size()]
	var width := columns * CELL
	var depth := rows * CELL
	var left := -width * 0.5
	var front := -depth * 0.5
	var back := depth * 0.5
	var result := {"width": width, "depth": depth, "floor": [], "tiles": [], "seats": [], "lamps": []}
	for column in columns:
		for row in rows:
			result.floor.append(["vloer", Vector3(left + CELL * 0.5 + column * CELL, 0.0, front + CELL * 0.5 + row * CELL)])
	# the door: not in a corner tile when the front is wide enough
	var door_column := random.randi_range(1, columns - 2) if columns >= 3 else random.randi_range(0, columns - 1)
	var door_x := left + CELL * 0.5 + door_column * CELL
	for column in columns:
		var x := left + CELL * 0.5 + column * CELL
		_tile(result, "muur", Vector3(x, 0.0, back), PI, true)
		if column == door_column:
			for side: float in [-1.5, 1.5]:
				_tile(result, "muur_laag_half", Vector3(x + side, 0.0, front), 0.0, true)
		else:
			_tile(result, "muur_laag", Vector3(x, 0.0, front), 0.0, true)
	for row in rows:
		var z := front + CELL * 0.5 + row * CELL
		_tile(result, "muur", Vector3(left, 0.0, z), PI * 0.5, true)
		_tile(result, "muur_laag", Vector3(-left, 0.0, z), -PI * 0.5, true)
	_tile(result, "deurmat", Vector3(door_x, 0.0, front + 0.5), 0.0, false)
	result["door"] = Transform3D(Basis.IDENTITY, Vector3(door_x, 0.0, front + DOOR_INSIDE))
	# the counter before the back wall, what belongs to it behind it
	var counter_column := random.randi_range(0, columns - 1)
	var counter_x := left + CELL * 0.5 + counter_column * CELL
	_tile(result, "toonbank", Vector3(counter_x, 0.0, back - COUNTER_FROM_BACK), PI, true)
	_tile(result, "frituur", Vector3(counter_x + 1.5, 0.0, back - 0.5), PI, false)
	_tile(result, "menubord", Vector3(counter_x - 1.5, 1.0, back - 0.5), PI, false)
	_tile(result, "koelkast", Vector3(left + 0.5, 0.0, back - 1.5 if counter_column > 0 else front + 1.5), PI * 0.5, false)
	result["keeper"] = Transform3D(Basis(Vector3.UP, PI), Vector3(counter_x - 0.5, 0.0, back - KEEPER_FROM_BACK))
	result["name_at"] = Vector3(counter_x - 1.5, 2.65, back - 0.4)
	# the tables: a spot in every column but the door's, a second row in a deep room
	var spots: Array[Vector3] = []
	for column in columns:
		if column == door_column:
			continue
		var x := left + CELL * 0.5 + column * CELL
		spots.append(Vector3(x, 0.0, front + TABLES_FROM_FRONT))
		# (not right before the counter: there you stand to order)
		if rows >= 3 and column != counter_column:
			spots.append(Vector3(x, 0.0, front + TABLES_FROM_FRONT + SECOND_ROW))
	# further in, the door's column has room for one too (unless you order there)
	if rows >= 3 and door_column != counter_column:
		spots.append(Vector3(door_x, 0.0, front + TABLES_FROM_FRONT + SECOND_ROW))
	var tables := 0
	for spot_index in spots.size():
		var last_chance := tables == 0 and spot_index == spots.size() - 1
		if random.randf() >= TABLE_SHARE and not last_chance:
			continue
		var spot := spots[spot_index]
		tables += 1
		_tile(result, "tafel", spot, 0.0, false)
		for side: float in [-1.0, 1.0]:
			var at := spot + Vector3(0.0, 0.0, side)
			var facing := PI if side > 0.0 else 0.0   # towards the table
			_tile(result, "stoel", at, facing, false)
			result.seats.append(Transform3D(Basis(Vector3.UP, facing), at))
	for lamp in 2:
		result.lamps.append(Vector3(left + width * (0.25 + 0.5 * lamp), 2.7, 0.0))
	return result


static func _tile(result: Dictionary, tile_name: String, at: Vector3, turn: float, varied: bool) -> void:
	result.tiles.append([tile_name, at, turn, varied])
