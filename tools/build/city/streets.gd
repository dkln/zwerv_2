extends "res://tools/build/city/map.gd"
## City builder, part 5 (see base.gd for the chain): the streets of the town on the grid
## of map.gd, the Singelgracht round the old centre with its quays and bridges, and the
## corners and kerbs of the squares and bends.


# ------------------------------------------------------------------ streets and the singel

## Cells of a 2-lane east-west street in rows z and z+1 from x0 to x1.
func _hs(x0: int, x1: int, z: int) -> void:
	for x in range(maxi(x0, 0), mini(x1, MAP_END) + 1):
		_street_h[Vector2i(x, z)] = 0
		_street_h[Vector2i(x, z + 1)] = 1


## Cells of a 2-lane north-south street in columns x and x+1 from z0 to z1.
func _vs(x: int, z0: int, z1: int) -> void:
	for z in range(z0, z1 + 1):
		for k in 2:
			_street_v[Vector2i(x + k, z)] = k


## The street grid inside the singel, the streets beyond the east arm, and the kerbed
## blocks between them (the nine blocks of the old centre and three east of it).
func _streets() -> void:
	_hs(X1, X5 + 1, Z1)
	_hs(X1, X_END, Z2)
	_hs(X2, X_END, Z3)
	_hs(X1, X5 + 1, Z4)
	_hs(0, X_END, ZS)
	_hs(X6 + 2, X_END, ZB)
	for x in [X1, X2, X3, X4]:
		_vs(x, Z1, Z4 + 1)
	_vs(X5, 0, Z_END)
	_vs(X6, 0, Z_END)
	_vs(XB, Z2 + 2, Z3 - 1)
	_vs(XC, 0, Z_END)
	_vs(XD, Z2, Z_END)
	_vs(X2, ZS, Z_END)
	_vs(X3, ZS, Z_END)
	for z in [ZR1, ZR2, ZR3]:
		_hs(0, X_END, z)
	_vs(XB, ZR1, Z_END)
	# Voorburg east of the A12: a street north-south and the two streets from the bridges
	# of the junctions (_a12_bridges)
	_vs(VOORBURG_STREET, 0, Z_END)
	lights_last_column = X_END   # the traffic lights in the city, none in Voorburg
	for junction: Array in A12_JUNCTIONS:
		_hs(A12_BRIDGE_COLUMNS[1] + 7, MAP_END, junction[0])
	for column: Array in [[A12_BRIDGE_COLUMNS[1] + 1, VOORBURG_STREET - A12_BRIDGE_COLUMNS[1] - 1], [VOORBURG_STREET + 2, MAP_END - VOORBURG_STREET - 1]]:
		_kerb_block(column[0], 0, column[1], ZS)
		_kerb_block(column[0], ZS + 2, column[1], ZR2 - ZS - 2)
		_kerb_block(column[0], ZR2 + 2, column[1], Z_END - ZR2 - 1)
	for col in [[7, 17], [26, 22], [50, 13]]:
		_kerb_block(col[0], 7, col[1], 22)
		_kerb_block(col[0], 31, col[1], 27)
		_kerb_block(col[0], 60, col[1], 25)
	# east of the singel; the rows AZ..AZ+8 between the wood and the street z 29 are the A12
	_kerb_block(71, 0, 25, 18)
	_kerb_block(X6 + 2, 0, XC - X6 - 2, 18)
	_kerb_block(XC + 2, 0, X_END - XC - 1, 18)
	_kerb_block(71, Z2 - 1, 24, 1)
	# the deck over the covered A12 between the two streets over it, and the strip east of it
	_kerb_block(X6 + 3, AZ, XC - X6 - 4, Z2 - AZ)
	_kerb_block(XC + 3, Z2 - 1, X_END - XC - 2, 1)
	_kerb_block(71, 31, 25, 27)
	_kerb_block(X6 + 2, 31, XB - X6 - 2, ZB - 31)
	_kerb_block(XB + 2, 31, XC - XB - 2, ZB - 31)
	_kerb_block(X6 + 2, ZB + 2, XB - X6 - 2, Z3 - ZB - 2)
	_kerb_block(XB + 2, ZB + 2, XC - XB - 2, Z3 - ZB - 2)
	_kerb_block(71, 60, 25, ZS - 60)
	_kerb_block(X6 + 2, 60, XC - X6 - 2, ZS - 60)
	# south of the Schenkkade
	_kerb_block(71, ZS + 2, 25, ZR1 - ZS - 2)
	_kerb_block(X6 + 2, ZS + 2, XC - X6 - 2, ZR1 - ZS - 2)
	# south of the singel, west of the Koningskade: a strip along the quay, three blocks
	# south of the Schenkkade
	_kerb_block(0, SINGEL_END + 1, X5, ZS - SINGEL_END - 1)
	_kerb_block(0, ZS + 2, X2, ZR1 - ZS - 2)
	_kerb_block(X2 + 2, ZS + 2, X3 - X2 - 2, ZR1 - ZS - 2)
	_kerb_block(X3 + 2, ZS + 2, X5 - X3 - 2, ZR1 - ZS - 2)
	# the Bezuidenhout-Oost on both sides of the street x 152
	for zd in [[31, ZB - 31], [ZB + 2, Z3 - ZB - 2], [60, ZS - 60], [ZS + 2, ZR1 - ZS - 2]]:
		_kerb_block(XC + 2, zd[0], XD - XC - 2, zd[1])
		_kerb_block(XD + 2, zd[0], X_END - XD - 1, zd[1])
	# the south of the town: eight columns of blocks between the three streets
	for column in [[0, X2], [X2 + 2, X3 - X2 - 2], [X3 + 2, X5 - X3 - 2], [X5 + 2, X6 - X5 - 2],
			[X6 + 2, XB - X6 - 2], [XB + 2, XC - XB - 2], [XC + 2, XD - XC - 2], [XD + 2, X_END - XD - 1]]:
		for street in [ZR1, ZR2, ZR3]:
			_kerb_block(column[0], street + 2, column[1], SOUTH_BLOCK_DEPTH)
	# the pedestrian part of the Grote Marktstraat west of the Buitenhof
	_fill(7, Z3, X2 - 1, Z3 + 1, "plein/plein_klinkers")
	for z in [Z3, Z3 + 1]:
		for x in [7, X2 - 1]:
			G(x, z, "stoep/stoep_vol")
			_pavement[Vector2i(x, z)] = "klinker_"
	_trees([Vector2i(10, Z3), Vector2i(16, Z3 + 1), Vector2i(20, Z3)], ["bomen/plataan"])
	for x in [12, 18]:
		Pr(x * 4 + 2.0, Z3 * 4 + 4.0, "straat/bank_modern", "S")
	Pr(14 * 4.0, Z3 * 4 + 4.0, "verlichting/lantaarn_modern")
	places["grote_marktstraat"] = Vector2(16 * 4.0, Z3 * 4 + 4.0)


## Heading of a lane -> rotation of its tile (a lane tile drives towards its back).
const ROTATION_OF_HEADING := {Vector2i(0, -1): "S", Vector2i(-1, 0): "E", Vector2i(0, 1): "N", Vector2i(1, 0): "W"}
const FLAT_CROSSING_TILES := ["weg/kruising_vlak", "weg/weg_vlak"]
## Cells of a street next to a corner that are checked for junction markings.
const UNDRESSED_CELLS := 3


## Name of the ground tile at street level in a cell, or "".
func _street_tile(cell: Vector2i) -> String:
	var item := ground.get_cell_item(Vector3i(cell.x, 0, cell.y))
	return ground.mesh_library.get_item_name(item) if item >= 0 else ""


## True if this tile is part of a lane: it has markings for traffic along it.
func _is_lane_tile(tile_name: String) -> bool:
	for start: String in ["weg/rijstrook_", "tram/tram_rijstrook_", "weg/fietsstr", "weg/straat_", "weg/zebrapad", "weg/fietsoversteek"]:
		if tile_name.begins_with(start):
			return true
	return false


## Where a two-lane street turns a corner without a side road, its 2 x 2 flat crossing
## cells become lanes whose lines bend round (tools/voxgen/tiles/ground_corners.py).
func _square_corners() -> void:
	_bend_outsides.clear()
	var corners := 0
	for cell: Vector3i in ground.get_used_cells():
		var north_west := Vector2i(cell.x, cell.z)
		if cell.y == 0 and _lay_square_corner(north_west):
			corners += 1
	print("square street corners: ", corners)


## Lays the corner on the 2 x 2 cells from this north-west cell, if they are one.
func _lay_square_corner(north_west: Vector2i) -> bool:
	var block: Array[Vector2i] = [north_west, north_west + Vector2i(1, 0), north_west + Vector2i(0, 1), north_west + Vector2i(1, 1)]
	for cell in block:
		if not _street_tile(cell) in FLAT_CROSSING_TILES:
			return false
	var east_lanes := [_street_tile(north_west + Vector2i(2, 0)), _street_tile(north_west + Vector2i(2, 1))]
	var west_lanes := [_street_tile(north_west + Vector2i(-1, 0)), _street_tile(north_west + Vector2i(-1, 1))]
	var south_lanes := [_street_tile(north_west + Vector2i(0, 2)), _street_tile(north_west + Vector2i(1, 2))]
	var north_lanes := [_street_tile(north_west + Vector2i(0, -1)), _street_tile(north_west + Vector2i(1, -1))]
	var arm_x := _street_arm(east_lanes, west_lanes)
	var arm_z := _street_arm(south_lanes, north_lanes)
	if arm_x == 0 or arm_z == 0:
		return false
	var arm_cells_x: Array[Vector2i] = [north_west + Vector2i(2 if arm_x > 0 else -1, 0), north_west + Vector2i(2 if arm_x > 0 else -1, 1)]
	var arm_cells_z: Array[Vector2i] = [north_west + Vector2i(0, 2 if arm_z > 0 else -1), north_west + Vector2i(1, 2 if arm_z > 0 else -1)]
	var tiles: Dictionary = _corner_tiles(arm_cells_x + arm_cells_z)
	var inner := north_west + Vector2i(1 if arm_x > 0 else 0, 1 if arm_z > 0 else 0)
	var outer := north_west + Vector2i(0 if arm_x > 0 else 1, 0 if arm_z > 0 else 1)
	var to_side := Vector2i(arm_x, 0)
	var to_street := Vector2i(0, arm_z)
	# driving on the right: the inside lane turns right, the outside lane turns left. Each
	# lane is entered from the arm whose outgoing side is on that hand.
	var inner_heading: Vector2i = -to_street if _right_of(-to_street) == to_side else -to_side
	var outer_heading: Vector2i = -to_street if _left_of(-to_street) == to_side else -to_side
	G(inner.x, inner.y, tiles.inner + "_hoek_rechts", ROTATION_OF_HEADING[inner_heading])
	G(outer.x, outer.y, tiles.outer + "_hoek_links", ROTATION_OF_HEADING[outer_heading])
	_bend_outsides.append({"cell": outer, "tile": tiles.outer + "_hoek_links", "rotation": ROTATION_OF_HEADING[outer_heading],
		"away": [-to_side, -to_street]})
	# the two cells between belong to the outside lane: towards its corner, and away from it
	for beside: Vector2i in [Vector2i(inner.x, outer.y), Vector2i(outer.x, inner.y)]:
		var towards_outer: Vector2i = outer - beside
		var along_outer_lane: Vector2i = towards_outer if towards_outer == outer_heading else -towards_outer
		G(beside.x, beside.y, tiles.outer, ROTATION_OF_HEADING[along_outer_lane])
	_undress_arm(arm_cells_x, Vector2i(arm_x, 0))
	_undress_arm(arm_cells_z, Vector2i(0, arm_z))
	return true


## Runs the kerb round the outside of each bend along the curve of its lane: the corner tile
## with the kind of pavement beside it, and a full pavement tile diagonally outside it.
## Called after _auto_kerbs, which decides the pavement tiles around it.
func _round_bend_kerbs() -> void:
	for bend: Dictionary in _bend_outsides:
		var cell: Vector2i = bend.cell
		var away: Array = bend.away
		var pavement_kind := ""
		for side: Vector2i in away:
			var beside := _street_tile(cell + side)
			if beside.begins_with("stoep/"):
				pavement_kind = "goot" if beside.contains("goot") else ("klinker" if beside.contains("klinker") else "stoep")
				break
		if pavement_kind == "":
			continue   # no pavement on the outside: the road stays square there
		G(cell.x, cell.y, bend.tile + "_" + pavement_kind, bend.rotation)
		var diagonal: Vector2i = cell + away[0] + away[1]
		if _street_tile(diagonal).begins_with("stoep/"):
			G(diagonal.x, diagonal.y, "stoep/stoep_klinker_vol" if pavement_kind == "klinker" else "stoep/stoep_vol")


## The straight tile of the inside and the outside lane of a corner, from the streets that
## meet there; a mark that only one of them has (a bike lane, a solid line) goes round.
func _corner_tiles(arm_cells: Array[Vector2i]) -> Dictionary:
	var names := ""
	for cell in arm_cells:
		names += _street_tile(cell) + " "
	if names.contains("tram/"):
		return {"inner": "tram/tram_rijstrook_onderbroken_kant", "outer": "tram/tram_rijstrook_geen_kant"}
	if names.contains("weg/fietsstraat"):
		return {"inner": "weg/fietsstraat", "outer": "weg/fietsstraat"}
	if names.contains("fietsstrook"):
		return {"inner": "weg/fietsstrook", "outer": "weg/fietsstrook"}
	if names.contains("dubbel"):
		return {"inner": "weg/rijstrook_dubbel_kant", "outer": "weg/rijstrook_geen_kant"}
	if names.contains("streep"):
		return {"inner": "weg/rijstrook_streep_kant", "outer": "weg/rijstrook_geen_kant"}
	return {"inner": "weg/rijstrook_onderbroken_kant", "outer": "weg/rijstrook_geen_kant"}


## Takes what belongs before a junction (arrows, give-way lines) off the first cells of a
## street that now just turns a corner: they get the tile that comes next along their lane.
func _undress_arm(first_cells: Array[Vector2i], outward: Vector2i) -> void:
	for first_cell in first_cells:
		for cells_out in UNDRESSED_CELLS:
			var cell := first_cell + outward * cells_out
			if not _is_junction_marking(_street_tile(cell)):
				continue
			var plain := cell + outward
			while _is_junction_marking(_street_tile(plain)):
				plain += outward
			var at := Vector3i(plain.x, 0, plain.y)
			if ground.get_cell_item(at) >= 0:
				ground.set_cell_item(Vector3i(cell.x, 0, cell.y), ground.get_cell_item(at), ground.get_cell_item_orientation(at))


func _is_junction_marking(tile_name: String) -> bool:
	for start: String in ["weg/rijstrook_pijl_", "weg/rijstrook_haaientanden", "weg/rijstrook_stop", "weg/rijstrook_blok_"]:
		if tile_name.begins_with(start):
			return true
	return false


## 1 or -1 if a two-lane street leaves on that side only (positive, negative), else 0.
func _street_arm(positive: Array, negative: Array) -> int:
	if _both_lanes(positive) and not _any_road(negative):
		return 1
	if _both_lanes(negative) and not _any_road(positive):
		return -1
	return 0


func _both_lanes(tiles: Array) -> bool:
	return _is_lane_tile(tiles[0]) and _is_lane_tile(tiles[1])


## A flat crossing cell counts: then this is part of a wider junction, not a corner.
func _any_road(tiles: Array) -> bool:
	for tile_name: String in tiles:
		if _is_lane_tile(tile_name) or tile_name in FLAT_CROSSING_TILES:
			return true
	return false


## The heading to the right of this one on the map (x = east, y = south).
static func _right_of(heading: Vector2i) -> Vector2i:
	return Vector2i(-heading.y, heading.x)


static func _left_of(heading: Vector2i) -> Vector2i:
	return Vector2i(heading.y, -heading.x)


## The Singelgracht round the old centre, the outer quays with a row of trees along the
## map edge, and boats in the water.
func _singel() -> void:
	var cells := {}
	for x in range(2, CW + 2):
		for z in [2, 3, 88, 89]:
			cells[Vector2i(x, z)] = true
	for z in range(2, 90):
		for x in [2, 3, CW, CW + 1]:
			cells[Vector2i(x, z)] = true
	_water(cells)
	# the strip outside the outer quays (map edge)
	for z in range(0, SINGEL_END + 1):
		_g(0, z, "plein/plein_klinkers")
	for x in range(1, CW + 3):
		_g(x, 0, "plein/plein_klinkers")
		_g(x, SINGEL_END, "plein/plein_klinkers")
	for i in range(1, 46):
		var t: String = "bomen/linde" if i % 3 else "bomen/plataan"
		Pr(0 * 4 + 2.0, i * 2 * 4 + 2.0, t)
		if i * 2 <= CW:
			Pr(i * 2 * 4 + 2.0, 0 * 4 + 2.0, t)
			Pr(i * 2 * 4 + 2.0, SINGEL_END * 4 + 2.0, t)
	# lanterns and bollards on the inner quays
	for x in range(8, 63, 6):
		Pr(x * 4 + 2.0, 4 * 4 + 1.0, "verlichting/lantaarn_klassiek", "S")
		Pr(x * 4 + 2.0, 87 * 4 + 3.0, "verlichting/lantaarn_klassiek", "N")
		Pr(x * 4 + 4.0, 87 * 4 + 3.5, "paaltjes/bolder")
	for z in range(8, 86, 6):
		Pr(4 * 4 + 1.0, z * 4 + 2.0, "verlichting/lantaarn_klassiek", "E")
		Pr(65 * 4 + 3.0, z * 4 + 2.0, "verlichting/lantaarn_klassiek", "W")
	# boats
	for b in [[12, 88, "water/woonboot", "E"], [30, 88, "water/woonboot", "E"], [44, 89, "water/sloep", "W"],
			[56, 88, "water/woonboot", "E"], [CW, 14, "water/woonboot", "S"], [CW + 1, 47, "water/roeiboot", "N"],
			[CW, 75, "water/sloep", "S"], [20, 2, "water/roeiboot", "E"], [2, 40, "water/woonboot", "S"], [3, 64, "water/sloep", "N"]]:
		Pr(b[0] * 4 + 4.0 if b[0] in [2, CW] else b[0] * 4 + 2.0, b[1] * 4 + 4.0 if b[1] in [2, 88] else b[1] * 4 + 2.0, b[2], b[3], -2.0)
	Pr(CW * 4 + 4.0, 20 * 4 + 2.0, "water/steiger", "E", -2.0)
	Pr(24 * 4 + 2.0, 87 * 4 + 3.0, "water/reddingsboei", "N")
	places["singel"] = Vector2(CW * 4 + 4.0, 20 * 4.0)


## Bridges where the streets cross the east arm of the singel: deck pavements with a
## parapet over the water (the lanes are laid by the streets and the tram), piers below.
func _bridges() -> void:
	for z in [Z1, Z2, Z3, Z4]:
		for x in [CW, CW + 1]:
			G(x, z - 1, "brug/brug_dek_stoep_rand", "W")
			G(x, z + 2, "brug/brug_dek_stoep_rand", "E")
	Pr((CW - 1) * 4 + 1.0, (Z2 - 1) * 4 + 1.0, "verlichting/lantaarn_klassiek_dubbel")
	Pr((CW + 2) * 4 + 3.0, (Z3 + 2) * 4 + 3.0, "verlichting/lantaarn_klassiek_dubbel")
	Pr((CW - 1) * 4 + 1.0, (Z1 - 1) * 4 + 1.0, "verlichting/lantaarn_klassiek_dubbel")
	Pr((CW + 2) * 4 + 3.0, (Z4 + 2) * 4 + 3.0, "verlichting/lantaarn_klassiek_dubbel")
