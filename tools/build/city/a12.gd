extends "res://tools/build/city/south.gd"
## City builder, part 9 (see base.gd for the chain): the A12 (Utrechtsebaan) from the
## trough under the town to the bend east of it and south to the map edge, its junctions,
## bridges and footbridge, and Voorburg beyond it.


# ------------------------------------------------------------------ the A12 (Utrechtsebaan)

## Columns of the A12 (it runs west from the map edge): flat motorway from A_FLAT on,
## a 6-step ramp down west of it, an open trough, a portal, the covered part from the
## street x 96 to the street x 128 (buildings on the deck between them, _over_a12), a
## portal, a trough, a ramp up and the city end from x 71 to A_UP - 1.
const A_FLAT := 144
const A_TUNNEL := [95, 130]  # covered columns
const A_STREETS := [X6, XC]  # streets over the covered part
const A_UP := 82             # first column of the ramp up (depth 1)
## The two carriageways, each a 3-lane trough: westbound north (rows AZ+1..AZ+3),
## eastbound south (rows AZ+5..AZ+7).
const A_TUBES := [1, 5]


## True if column x belongs to a north-south street over the A12 (lanes and pavements).
func _a12_street_col(x: int) -> bool:
	for xs in A_STREETS:
		if x >= xs - 1 and x <= xs + 2:
			return true
	return false


## The A12: flat motorway from the east edge with its lights and signs; ramps down into
## two troughs on level -6 with grass between them, a covered part under the streets
## x 96 and x 128 and the buildings between them, ramps up, and a city end with three
## lanes each way and a grass median to the junction with the Koningskade (laid by
## _a12_junction).
func _a12() -> void:
	var tw: int = A_TUNNEL[0] - 1     # west portal
	var te: int = A_TUNNEL[1] + 1     # east portal
	for x in range(71, A_BEND):
		if _a12_street_col(x):
			continue
		if x < XC:
			_g(x, AZ - 1, "natuur/bosrand", "S")
		if x >= A_FLAT:
			for i in 9:
				_g(x, AZ + i, MW_FLAT[i][0], MW_FLAT[i][1])
			continue
		if x < A_UP or (x > tw and x < te):
			continue
		for i in [0, 4, 8]:
			_g(x, AZ + i, "natuur/gras", "E")
		# depth and kind of this column; west of the tunnel the tiles face east (up the
		# ramp, into the tunnel) and their wall sides swap
		var kind := ""
		var depth := 6
		var rot := "W"
		if x > te:
			kind = "ramp" if x >= A_FLAT - 6 else "trough"
			depth = A_FLAT - x if kind == "ramp" else 6
		elif x == te:
			kind = "portal"
		else:
			rot = "E"
			if x == tw:
				kind = "portal"
			else:
				kind = "ramp" if x < A_UP + 6 else "trough"
				depth = x - A_UP + 1 if kind == "ramp" else 6
		for t in A_TUBES:
			for k in 3:
				var lane: String = TUNNEL_LANES[k if rot == "W" else 2 - k]
				var z: int = AZ + t + k
				match kind:
					"ramp":
						_trench(x, z, lane % ["tunnel/tunnel_toerit", "_d%d" % depth], depth, rot)
					"trough":
						_trench(x, z, lane % ["tunnel/tunnelbak_rijstrook", "_d6"], 6, rot)
					"portal":
						_trench(x, z, lane % ["tunnel/tunnel_rijstrook", "_portaal"], 6, rot)
				_pavement.erase(Vector2i(x, z))
		if kind == "trough" and x % 4 == 0:
			Pr(x * 4 + 2.0, (AZ + 4) * 4 + 2.0, "verlichting/lantaarn_middenberm", "E")
	# the covered part, the pavements of the streets over it, railings above the portals
	for x in range(A_TUNNEL[0], A_TUNNEL[1] + 1):
		for t in A_TUBES:
			for k in 3:
				G(x, AZ + t + k, TUNNEL_LANES[k] % ["tunnel/tunnel_rijstrook", ""], "W", -6)
	for xs in A_STREETS:
		for x in [xs - 1, xs + 2]:
			for z in range(AZ - 1, Z2):
				G(x, z, "stoep/stoep_vol")
				_pavement[Vector2i(x, z)] = ""
	for x in [A_TUNNEL[0], A_TUNNEL[1]]:
		for t in A_TUBES:
			for k in 3:
				Pr(x * 4 + (0.5 if x == A_TUNNEL[0] else 3.5), (AZ + t + k) * 4 + 2.0, "hekken/hek_ijzer", "E")
	# the berm north of the flat motorway east of the Laan van NOI, along the offices
	for x in range(XC + 3, A_BEND + 9):
		_g(x, AZ - 1, "natuur/gras", "S")
	Pr((X6 - 1) * 4 + 1.0, (AZ - 1) * 4 + 2.0, "borden/bord_tunnel", "W")
	# lights, signs and fences of the flat part
	for x in range(A_FLAT, A_BEND):
		if x % 6 == 2:
			Pr(x * 4.0, (AZ + 4) * 4 + 2.0, "verlichting/lantaarn_middenberm", "E")
		if x % 10 == 4:
			Pr(x * 4 + 2.0, AZ * 4 + 1.0, "borden/hectometerpaal", "S")
		if x % 2 == 0:
			Pr(x * 4 + 2.0, (AZ - 1) * 4 + 3.5, "hekken/hek_gaas_hoog", "S")
	for x in range(A_UP, A_FLAT):
		if x >= tw and x <= te:
			continue
		if x % 2 == 0:
			Pr(x * 4 + 2.0, AZ * 4 + 3.5, "hekken/hek_gaas_hoog", "S")
			Pr(x * 4 + 2.0, (AZ + 8) * 4 + 0.5, "hekken/hek_gaas_hoog", "N")
	# ANWB signs: a gantry over each carriageway (westbound into Den Haag, eastbound to
	# Utrecht) and a big sign beside the eastbound one
	Pr((X_END - 5) * 4.0, (AZ + 2) * 4 + 2.0, "borden/snelweg_portaal_anwb_den_haag", "E")
	Pr((A_FLAT + 10) * 4.0, (AZ + 6) * 4 + 2.0, "borden/snelweg_portaal_anwb_utrecht", "W")
	Pr((A_FLAT + 22) * 4.0, (AZ + 8) * 4 + 2.0, "borden/snelweg_bord_anwb_rotterdam_utrecht", "W")
	Pr((A_FLAT + 3) * 4 + 2.0, AZ * 4 + 2.0, "borden/bord_max_80", "E")
	Pr((A_FLAT + 14) * 4 + 2.0, AZ * 4 + 2.0, "borden/bord_file", "E")
	Pr((A_FLAT + 8) * 4 + 2.0, (AZ + 8) * 4 + 2.0, "borden/bord_max_100", "W")
	Pr(A_FLAT * 4 + 2.0, (AZ + 8) * 4 + 2.0, "borden/bord_autosnelweg", "W")
	Pr((A_FLAT - 2) * 4 + 2.0, (AZ + 4) * 4 + 2.0, "borden/bord_tunnel", "E")
	Pr((A_UP + 2) * 4 + 2.0, (AZ + 4) * 4 + 2.0, "borden/bord_tunnel", "W")
	places["a12"] = Vector2((A_FLAT - 4) * 4.0, (AZ + 4) * 4.0)


## The city end of the A12 (x 71..A_UP-1) and its junction with the Koningskade: three
## lanes each way with turn arrows, a stop line and a pedestrian crossing, a grass median
## with a divider head, pavements, a speed sign and traffic lights. Called after the
## streets are painted (the Koningskade cells become the crossing).
func _a12_junction() -> void:
	var north := [["snelweg/snelweg_rijstrook", "E"], ["weg/weg_vlak", "E"], ["snelweg/snelweg_rijstrook_links", "E"]]
	var south := [["snelweg/snelweg_rijstrook_links", "W"], ["weg/weg_vlak", "W"], ["snelweg/snelweg_rijstrook", "W"]]
	for x in range(71, A_UP):
		_g(x, AZ, "stoep/stoep_rand", "S")
		_g(x, AZ + 8, "stoep/stoep_rand", "N")
		_g(x, AZ + 4, "weg/middenberm_gras", "E")
		for k in 3:
			_g(x, AZ + 1 + k, north[k][0], north[k][1])
			_g(x, AZ + 5 + k, south[k][0], south[k][1])
		if x % 3 == 0:
			Pr(x * 4 + 2.0, (AZ + 4) * 4 + 2.0, "bomen/jonge_boom")
	_g(71, AZ + 4, "weg/middengeleider_kop", "W")
	_g(72, AZ + 4, "weg/middengeleider", "E")
	for k in 3:
		_g(71, AZ + 1 + k, "weg/zebrapad", "E")
		_g(71, AZ + 5 + k, "weg/zebrapad", "E")
		_g(72, AZ + 1 + k, "weg/rijstrook_stopstreep", "E")
		_g(74, AZ + 1 + k, ["weg/rijstrook_pijl_rechts", "weg/rijstrook_pijl_links", "weg/rijstrook_pijl_links"][k], "E")
	_g(71, AZ, "stoep/stoep_ribbel", "S")
	_g(71, AZ + 8, "stoep/stoep_ribbel", "N")
	_g(71, AZ - 1, "stoep/stoep_vol")
	for z in range(AZ + 1, AZ + 8):
		for x in [X5, X5 + 1]:
			_g(x, z, "weg/kruising_vlak")
	# traffic lights: the A12 approach (east-west stream), the Koningskade (north-south)
	var L := "verkeerslichten/"
	Pr(72 * 4 + 1.0, AZ * 4 + 3.0, L + "auto_rood", "E")
	Pr(72 * 4 + 1.0, (AZ + 4) * 4 + 1.0, L + "auto_rood", "E")
	Pr(72 * 4 + 1.0, AZ * 4 + 1.0, L + "voetganger_rood", "N")
	Pr(71 * 4 + 1.0, (AZ + 8) * 4 + 3.0, L + "voetganger_rood", "S")
	Pr(X5 * 4 + 1.0, (AZ - 1) * 4 + 1.0, L + "auto_groen", "N")
	Pr((X5 + 2) * 4 - 1.0, (AZ + 9) * 4 - 1.0, L + "auto_groen", "S")
	Pr(78 * 4 + 2.0, AZ * 4 + 1.0, "borden/bord_max_50", "E")
	Pr(73 * 4 + 2.0, (AZ + 8) * 4 + 3.0, "borden/wegwijzer", "W")
	places["a12_koningskade"] = Vector2(72 * 4.0, (AZ + 4) * 4.0)


# ------------------------------------------------------------------ the A12 east of the city

## Per profile row of MW_FLAT (north to south as it runs east): the tile in the bend and
## its corner. The westbound side turns left (it comes north and turns west), the
## eastbound side right; a line between two lanes bends in the inner of their two cells,
## so the lanes beside it lose it there (the "_zonder_streep" tiles).
const A12_BEND_TILES := [
	["snelweg/snelweg_berm_vangrail", "snelweg/snelweg_berm_vangrail_hoek_links"],
	["snelweg/snelweg_vluchtstrook", "snelweg/snelweg_vluchtstrook_hoek_links"],
	["snelweg/snelweg_rijstrook_zonder_streep", "snelweg/snelweg_rijstrook_zonder_streep_hoek_links"],
	["snelweg/snelweg_rijstrook_links", "snelweg/snelweg_rijstrook_links_hoek_links"],
	["snelweg/snelweg_middenberm_beton", "snelweg/snelweg_middenberm_beton_hoek_links"],
	["snelweg/snelweg_rijstrook_links_zonder_streep", "snelweg/snelweg_rijstrook_links_zonder_streep_hoek_rechts"],
	["snelweg/snelweg_rijstrook", "snelweg/snelweg_rijstrook_hoek_rechts"],
	["snelweg/snelweg_vluchtstrook", "snelweg/snelweg_vluchtstrook_hoek_rechts"],
	["snelweg/snelweg_berm_vangrail", "snelweg/snelweg_berm_vangrail_hoek_rechts"]]
## A rotation turned a quarter clockwise (seen from above): east-west tiles to north-south.
const QUARTER_CLOCKWISE := {"E": "S", "S": "W", "W": "N", "N": "E"}


## Column of profile row `row` (0..8 of MW_FLAT) on the southward part: the westbound
## side of the east-west part lies on the outside of the bend, in the east.
func _a12_column(row: int) -> int:
	return A_BEND + 8 - row


func _a12_east() -> void:
	# the bend: cell (across, back) counted from its inside corner in the south-west
	for across in 9:
		for back in 9:
			var lane: int = maxi(across, back)
			var row: int = 8 - lane
			var westbound: bool = row <= 4
			var tiles: Array = A12_BEND_TILES[row]
			var x: int = A_BEND + across
			var z: int = AZ + 8 - back
			if across == back:
				_g(x, z, tiles[1], "S" if westbound else "W")
			elif across < back:
				_g(x, z, tiles[0], "E" if westbound else "W")
			else:
				_g(x, z, tiles[0], "S" if westbound else "N")
	# south to the trough, then down into it
	for z in range(A_SOUTH, Z_END + 1):
		if z >= A_TROUGH:
			_a12_trough_row(z)
			continue
		for row in 9:
			_g(_a12_column(row), z, MW_FLAT[row][0], QUARTER_CLOCKWISE[MW_FLAT[row][1]])
	for junction: Array in A12_JUNCTIONS:
		_a12_ramp_designs(junction[0])
	# lights on the median, hectometre posts and fences along the flat part, away from the
	# bridges over it and from the ramps
	for z in range(A_SOUTH, A_TROUGH):
		if _a12_near_junction(z, -2, 17) or (z >= VIADUCT_ROWS[0] - 2 and z <= RAILWAY_ROWS[1] + 1):
			continue
		if z % 6 == 2:
			Pr(_a12_column(4) * 4 + 2.0, z * 4.0, "verlichting/lantaarn_middenberm", "S")
		if z % 10 == 4:
			Pr(_a12_column(0) * 4 + 3.0, z * 4 + 2.0, "borden/hectometerpaal", "W")
		if z % 2 == 0:
			Pr(_a12_column(8) * 4 + 0.5, z * 4 + 2.0, "hekken/hek_gaas_hoog", "W")
			Pr(_a12_column(0) * 4 + 3.5, z * 4 + 2.0, "hekken/hek_gaas_hoog", "E")
	Pr(_a12_column(0) * 4 + 3.5, 62 * 4 + 2.0, "borden/bord_plaatsnaam_den_haag", "S")
	Pr(_a12_column(2) * 4.0, 70 * 4 + 2.0, "borden/snelweg_portaal_anwb_den_haag", "S")
	Pr(_a12_column(6) * 4.0, 50 * 4 + 2.0, "borden/snelweg_portaal_anwb_utrecht", "N")
	Pr(_a12_column(0) * 4 + 2.0, 74 * 4 + 2.0, "borden/snelweg_bord_anwb_den_haag_centrum", "S")
	places["a12_bocht"] = Vector2((A_BEND + 4) * 4.0, (AZ + 4) * 4.0)
	places["a12_tunnelbak_voorburg"] = Vector2(_a12_column(4) * 4.0, (A_TROUGH + 10) * 4.0)


## True if row z lies from `before` rows before to `after` rows after the street of a junction.
func _a12_near_junction(z: int, before: int, after: int) -> bool:
	for junction: Array in A12_JUNCTIONS:
		if z >= junction[0] + before and z <= junction[0] + after:
			return true
	return false


## One row of the trough past Voorburg: two 3-lane troughs on level -6 (a ramp down over
## the first 6 rows), grass at street level on the verges and between them, with fences
## along the edges and lights on the middle.
func _a12_trough_row(z: int) -> void:
	var depth: int = mini(z - A_TROUGH + 1, 6)
	var ramp: bool = z < A_TROUGH + 6
	if z >= Z_END - 1:
		# at the map edge one wide trough, where traffic turns round into the other side
		for x in range(_a12_column(7), _a12_column(1) + 1):
			var k: int = 0 if x == _a12_column(7) else (2 if x == _a12_column(1) else 1)
			_trench(x, z, TUNNEL_LANES[k] % ["tunnel/tunnelbak_rijstrook", "_d6"], 6, "S")
		# the middle has no lanes of its own along the road: across it, both ways
		_choose_lanes(_a12_column(4), z, [Vector2i(1, 0), Vector2i(-1, 0)], [], -6)
		for row in [0, 8]:
			_g(_a12_column(row), z, "natuur/gras", "S")
		return
	for row in [0, 4, 8]:
		_g(_a12_column(row), z, "natuur/gras", "S")
	for tube_first: int in [_a12_column(7), _a12_column(3)]:
		for k in 3:
			var tile_name: String = TUNNEL_LANES[k] % (["tunnel/tunnel_toerit", "_d%d" % depth] if ramp else ["tunnel/tunnelbak_rijstrook", "_d6"])
			_trench(tube_first + k, z, tile_name, depth, "S")
			_pavement.erase(Vector2i(tube_first + k, z))
	if not ramp and z % 4 == 0:
		Pr(_a12_column(4) * 4 + 2.0, z * 4 + 2.0, "verlichting/lantaarn_middenberm", "S")
	if z % 2 == 0:
		Pr(_a12_column(8) * 4 + 3.5, z * 4 + 2.0, "hekken/hek_gaas_hoog", "E")
		Pr(_a12_column(0) * 4 + 0.5, z * 4 + 2.0, "hekken/hek_gaas_hoog", "W")


## The ramps of the half junction at the street of row zc, at grade (the bridge over the
## motorway and the slopes up to it: _a12_bridges). The exit for the northbound side (to
## Den Haag) leaves its hard shoulder on the east side over the 8 x 4 tiles of the afrit
## design and runs on north up to the bridge; the on-ramp for the southbound side comes down
## from the bridge on the west side and joins its hard shoulder over the toerit design
## (tile (i, j) of a design along the road and away from it, see ground_junction.py).
func _a12_ramp_designs(zc: int) -> void:
	for i in 8:
		for j in 4:
			_g(_a12_column(1) + j, zc + 9 + i, "snelweg/afrit_%d_%d" % [i, j], "W")
			_g(_a12_column(7) - j, zc + 16 - i, "snelweg/toerit_%d_%d" % [i, j], "E")
	Pr((_a12_column(0)) * 4 + 2.0, (zc + 12) * 4 + 2.0, "borden/bord_afrit", "S")
	Pr((_a12_column(8) - 2) * 4 + 2.0, (zc + 10) * 4 + 2.0, "borden/bord_autosnelweg", "N")


## The bridges of the junctions over the A12, at the level of the viaducts: the street
## rises to them over 6 columns on each side on a solid concrete approach, crosses on a
## deck with pavements and parapets on piers (on the verges and on the median barrier),
## and the ramps come up to it beside the motorway, each in its own column, also on a
## solid approach. Called after the grass fill.
func _a12_bridges() -> void:
	var level: int = VIADUCT_LEVEL
	var west: int = A12_BRIDGE_COLUMNS[0]
	var east: int = A12_BRIDGE_COLUMNS[1]
	var ramp_columns := [_a12_column(8) - 1, _a12_column(0) + 1]
	for junction: Array in A12_JUNCTIONS:
		var zc: int = junction[0]
		# the slopes of the street: rising east to the bridge on the west side, west on the east side
		for step in level:
			_a12_bridge_slope(west - level + step, zc, step, "W")
			_a12_bridge_slope(east + level - step, zc, step, "E")
		# the deck; where a ramp meets it its lanes become a crossing
		for x in range(west, east + 1):
			for z in range(zc - 1, zc + 3):
				_clear_props(x, z)
			G(x, zc - 1, "brug/brug_dek_stoep_rand", "W", level)
			if x in ramp_columns:
				G(x, zc, "weg/kruising_vlak", "S", level)
				G(x, zc + 1, "weg/kruising_vlak", "S", level)
				G(x, zc + 2, "snelweg/snelweg_aansluiting", "S", level)
			else:
				G(x, zc, "weg/rijstrook_onderbroken_kant", "E", level)
				G(x, zc + 1, "weg/rijstrook_geen_kant", "W", level)
				G(x, zc + 2, "brug/brug_dek_stoep_rand", "E", level)
		for z in range(zc - 1, zc + 3):
			_pier(west, z, "brug/brug_pijler_gras", 0, level - 1)
			_pier(_a12_column(4), z, "snelweg/snelweg_middenberm_beton", 0, level - 1)
			_pier(east, z, "brug/brug_pijler_gras", 0, level - 1)
		# the ramps between the bridge and the designs, rising north to the deck
		for step in level:
			var z: int = zc + 3 + step
			var ramp_level: int = level - 1 - step
			for x: int in ramp_columns:
				_clear_props(x, z)
				_abutment(x, z, ramp_level)
				G(x, z, "brug/helling/helling_snelweg_aansluiting_rand", "S", ramp_level)
		_a12_ramp_lanes(zc)
		var top := float(level)
		Pr(ramp_columns[1] * 4 + 3.5, (zc + 3) * 4 + 0.5, "borden/bord_voorrang_verlenen", "S", top)
		Pr(ramp_columns[0] * 4 + 0.5, (zc - 1) * 4 + 3.5, "borden/wegwijzer", "E", top)
		places[junction[1]] = Vector2(_a12_column(4) * 4.0, (zc + 1) * 4.0)


## The lanes of the ramps of the junction at the street of row zc, which their tiles do
## not have themselves, and the cells where traffic moves over (RoadNetwork MOVE_OVERS).
## Exit: from the right lane of the northbound side over into the exit lane where the hard
## shoulder becomes one, then in two steps out along the design to the ramp, up it and
## onto the crossing on the bridge. On-ramp: from the crossing down the ramp, in two steps
## in along the design to the acceleration lane in the hard shoulder, and at its end over
## into the right lane.
func _a12_ramp_lanes(zc: int) -> void:
	var north := [Vector2i(0, -1)]
	var south := [Vector2i(0, 1)]
	var level: int = VIADUCT_LEVEL
	var shoulder: int = _a12_column(1)
	var verge: int = _a12_column(0)
	var ramp: int = _a12_column(0) + 1
	for z in [zc + 15, zc + 14, zc + 13]:
		_choose_lanes(shoulder, z, north)
	_choose_lanes(verge, zc + 11, north)
	_choose_lanes(ramp, zc + 9, north)
	_move_over_link(Vector3i(_a12_column(2), 0, zc + 17), Vector3i(shoulder, 0, zc + 15))
	_move_over_link(Vector3i(shoulder, 0, zc + 13), Vector3i(verge, 0, zc + 11))
	_move_over_link(Vector3i(verge, 0, zc + 11), Vector3i(ramp, 0, zc + 9))
	var west_shoulder: int = _a12_column(7)
	var west_verge: int = _a12_column(8)
	var west_ramp: int = _a12_column(8) - 1
	_choose_lanes(west_ramp, zc + 9, south)
	_choose_lanes(west_ramp, zc + 10, south)
	_choose_lanes(west_verge, zc + 12, south)
	for z in [zc + 14, zc + 15, zc + 16]:
		_choose_lanes(west_shoulder, z, south)
	_move_over_link(Vector3i(west_ramp, 0, zc + 10), Vector3i(west_verge, 0, zc + 12))
	_move_over_link(Vector3i(west_verge, 0, zc + 12), Vector3i(west_shoulder, 0, zc + 14))
	_move_over_link(Vector3i(west_shoulder, 0, zc + 16), Vector3i(_a12_column(6), 0, zc + 17))
	# the ramps and where they meet the bridge
	for step in level:
		_choose_lanes(ramp, zc + 3 + step, north, [], level - 1 - step)
		_choose_lanes(west_ramp, zc + 3 + step, south, [], level - 1 - step)
	_choose_lanes(ramp, zc + 2, north, [], level)
	_choose_lanes(west_ramp, zc + 2, south, [], level)
	# the crossings on the bridge: from the exit right into the eastbound lane or left into
	# the westbound one; onto the on-ramp right from the eastbound lane or left from the
	# westbound one (the westbound cell over the exit is a plain lane, not a crossing, so
	# the traffic coming up sees the road go on)
	var west := Vector2i(-1, 0)
	var east := Vector2i(1, 0)
	_choose_lanes(ramp, zc, [west], [], level)
	_choose_lanes(ramp, zc + 1, [north[0], east], [], level)
	_choose_lanes(west_ramp, zc, [west, south[0]], [], level)
	_choose_lanes(west_ramp, zc + 1, [east, south[0]], [], level)


## Marks road cell `from_cell` as one traffic can move over from into `to_cell` (an exit).
func _move_over_link(from_cell: Vector3i, to_cell: Vector3i) -> void:
	var links: Dictionary = ground.get_meta(RoadNetwork.MOVE_OVERS, {})
	links[from_cell] = to_cell
	ground.set_meta(RoadNetwork.MOVE_OVERS, links)


## One column of the slope of a junction street at `step` levels up: pavements with a
## parapet on the outside, two lanes, on a solid concrete approach. `rot` "W" rises east,
## "E" rises west; the centre line lies on the lane on the left of the way it rises.
func _a12_bridge_slope(x: int, zc: int, step: int, rot: String) -> void:
	var rises_east: bool = rot == "W"
	var rows := {zc - 1: "brug/helling/helling_stoep_vol_rand" if rises_east else "brug/helling/helling_stoep_vol_rand_rechts",
		zc: "brug/helling/helling_weg_vlak" if rises_east else "brug/helling/helling_rijstrook_onderbroken_kant",
		zc + 1: "brug/helling/helling_rijstrook_onderbroken_kant" if rises_east else "brug/helling/helling_weg_vlak",
		zc + 2: "brug/helling/helling_stoep_vol_rand_rechts" if rises_east else "brug/helling/helling_stoep_vol_rand"}
	for z: int in rows:
		_clear_props(x, z)
		_abutment(x, z, step)
		G(x, z, rows[z], rot, step)


## Solid concrete under a slope or ramp tile at `level`: one abutment storey per level
## below it (none at level 0, where the tile lies on the ground).
func _abutment(x: int, z: int, level: int) -> void:
	for storey in level:
		G(x, z, "brug/brug_landhoofd", "S", storey)


## Voorburg east of the A12 (x 192..215): closed blocks of houses of three storeys on both
## sides of its street, the Oude Kerk with its tower west of it, grass under the viaducts
## and Station Voorburg over the street (VIADUCT_STOPS).
func _voorburg() -> void:
	var styles := ["jaren30", "klassiek_rood", "klassiek_donker", "jaren30", "klassiek_geel", "jaren60"]
	var west: int = A12_BRIDGE_COLUMNS[1] + 2
	var west_width: int = VOORBURG_STREET - west - 1
	var east: int = VOORBURG_STREET + 3
	var east_width: int = MAP_END - east
	var style_index := 0
	# [first row, last row] of the blocks between the streets, leaving the rows under the viaducts free
	for rows: Array in [[1, 76], [ZS + 3, ZR2 - 2], [ZR2 + 3, Z_END - 1]]:
		var z: int = rows[0]
		while z + 6 <= rows[1]:
			var depth: int = mini(9, rows[1] - z + 1)
			for column: Array in [[west, west_width], [east, east_width]]:
				if column[0] == west and rows[0] == 1 and z >= 67:
					continue   # the church
				var style: String = styles[style_index % styles.size()]
				style_index += 1
				ring(column[0], z, column[1], depth, style, 3, _housing_options(style))
			z += depth + 2
	# the Oude Kerk: a brick church with its tower on the north side, on a green with trees
	_fill(west, 67, west + west_width - 1, 86, "natuur/gras")
	block(west + 2, 72, 5, 9, "kerk_baksteen", 2, {"front": "N", "gf": ["bg_spitsraam"], "gf_side": "bg_spitsraam", "gf_corner": "bg_spitsraam_hoek",
		"upper": ["verd_spitsraam"], "upper_corner": "verd_spitsraam_hoek", "roof": "sloped"})
	tower(west + 4, 71, "kerk_baksteen", ["toren_portaal", "toren_raam", "toren_galmgat", "toren_spits_onder", "toren_spits_boven"], "N")
	_trees([Vector2i(west + 1, 68), Vector2i(west + 8, 69), Vector2i(west + 9, 78), Vector2i(west + 1, 84), Vector2i(west + 7, 85)],
		["bomen/linde", "bomen/eik", "bomen/kastanje"])
	_fill(east, 78, east + east_width - 1, 86, "natuur/gras")
	_trees([Vector2i(east + 1, 79), Vector2i(east + 5, 81), Vector2i(east + 3, 85)], ["bomen/plataan", "bomen/linde"])
	places["voorburg"] = Vector2(VOORBURG_STREET * 4.0, 50 * 4.0)
	places["oude_kerk_voorburg"] = Vector2((west + 4) * 4.0, 76 * 4.0)


# ------------------------------------------------------------------ finishing

## Column, level and first and last row of the footbridge over the flat A12.
const FOOTBRIDGE_COLUMN := 160
const FOOTBRIDGE_LEVEL := 6
const FOOTBRIDGE_ROWS := [AZ - 2, AZ + 9]


## A footbridge over the flat A12, from the offices of the Prins Clauslaan to the street
## z 29 and the Bezuidenhout-Oost: an open deck on three piers (the berm on both sides and
## on the median barrier, which stays) and stairs of two flights along the pavement at
## both ends. Built after the grass fill, so the ground under it is final.
func _a12_footbridge() -> void:
	for row in range(FOOTBRIDGE_ROWS[0] + 1, FOOTBRIDGE_ROWS[1]):
		G(FOOTBRIDGE_COLUMN, row, "brug/loopbrug_open", "S", FOOTBRIDGE_LEVEL)
	# the ends have an opening on the west side for the stairs
	G(FOOTBRIDGE_COLUMN, FOOTBRIDGE_ROWS[0], "brug/loopbrug_open_zijtoegang_rechts", "N", FOOTBRIDGE_LEVEL)
	G(FOOTBRIDGE_COLUMN, FOOTBRIDGE_ROWS[1], "brug/loopbrug_open_zijtoegang", "S", FOOTBRIDGE_LEVEL)
	_clear_props(FOOTBRIDGE_COLUMN, AZ - 1)
	_pier(FOOTBRIDGE_COLUMN, AZ - 1, "brug/brug_pijler_gras", 0, FOOTBRIDGE_LEVEL - 1)
	_clear_props(FOOTBRIDGE_COLUMN, FOOTBRIDGE_ROWS[1])
	_pier(FOOTBRIDGE_COLUMN, FOOTBRIDGE_ROWS[1], "brug/brug_pijler_stoep", 0, FOOTBRIDGE_LEVEL - 1)
	for level in range(1, FOOTBRIDGE_LEVEL - 1):
		G(FOOTBRIDGE_COLUMN, AZ + 4, "brug/brug_pijler", "S", level)
	G(FOOTBRIDGE_COLUMN, AZ + 4, "brug/brug_pijler_kop", "S", FOOTBRIDGE_LEVEL - 1)
	# the stairs rise east to the deck; props on their pavement and tree crowns over them go
	for row: int in FOOTBRIDGE_ROWS:
		for x in range(FOOTBRIDGE_COLUMN - 4, FOOTBRIDGE_COLUMN):
			_clear_props(x, row)
			if row < AZ:
				_clear_props(x, row - 1)
		Pr(FOOTBRIDGE_COLUMN * 4 - 2.5, row * 4 + 2.0, "trappen/trap_3m", "W", 3.0)
		Pr(FOOTBRIDGE_COLUMN * 4 - 8.5, row * 4 + 2.0, "trappen/trap_3m", "W", 0.0)
	places["voetbrug_a12"] = Vector2(FOOTBRIDGE_COLUMN * 4.0 + 2.0, (AZ + 4) * 4.0 + 2.0)
