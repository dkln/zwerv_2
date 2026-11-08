extends "res://tools/build/city/a12.gd"
## City builder, part 10 (see base.gd for the chain): the tram lines and the tram tunnel,
## the RandstadRail and railway viaducts with their stations, and the ministry wing built
## over the tram.


# ------------------------------------------------------------------ trams

## Cells of a tram stop on the street: 24 m, for a RandstadRail of 22.25 m.
const TRAM_STOP_CELLS := 6


## Registers the tram cells (so the street dressing leaves them alone), puts the
## overhead line masts on the pavements and the stops (platform on the kerb, shelter,
## stop sign) along the three tram streets.
func _tram_lines() -> void:
	for z in range(Z2, Z3 + 2):
		for k in 2:
			_tram[Vector2i(X2 + k, z)] = "v"
	for zr in [Z2, Z3]:
		for x in range(X2, X_END + 1):
			for k in 2:
				if not _tram.has(Vector2i(x, zr + k)):
					_tram[Vector2i(x, zr + k)] = "h"
	for c in _tram:
		_special[c] = true
	# stops: [first cell, step, cells, side the platform faces]
	# (TRAM_STOP_CELLS long: a RandstadRail fits, the Spui between the crossing and the ramp)
	var stops := [[Vector2i(26, 38), Vector2i(0, 1), "W", "buitenhof"], [Vector2i(23, 47), Vector2i(0, 1), "E", ""],
		[Vector2i(56, Z2 - 1), Vector2i(1, 0), "S", "korte_voorhout"], [Vector2i(51, Z2 + 2), Vector2i(1, 0), "N", ""],
		[Vector2i(77, Z2 + 2), Vector2i(1, 0), "N", "tram_malieveld"], [Vector2i(84, Z2 - 1), Vector2i(1, 0), "S", ""],
		[Vector2i(77, Z3 + 2), Vector2i(1, 0), "N", "tram_centraal"], [Vector2i(86, Z3 - 1), Vector2i(1, 0), "S", ""]]
	var stop_cells := {}
	for st in stops:
		for i in TRAM_STOP_CELLS:
			var c: Vector2i = st[0] + st[1] * i
			_g(c.x, c.y, "tram/tram_halte_perron", st[2])
			stop_cells[c] = true
		var mid: Vector2i = st[0] + st[1] * (TRAM_STOP_CELLS / 2)
		Pr(mid.x * 4 + 2.0, mid.y * 4 + 2.0, "ov/abri", st[2], 0.5)
		# an OV-chipkaart reader at both ends of the platform
		for end: Vector2i in [st[0], st[0] + st[1] * (TRAM_STOP_CELLS - 1)]:
			Pr(end.x * 4 + 2.0, end.y * 4 + 2.0, "ov/ov_incheckpaal", st[2], 0.5)
		if st[3] != "":
			places[st[3]] = Vector2(mid) * 4.0 + Vector2(2.0, 2.0)
	# overhead line masts on the pavement, away from the stops, bridges and crossings
	for z in range(Z2 + 4, Z3 - 2, 4):
		var c := Vector2i(X2 - 1, z)
		if not stop_cells.has(c) and not (z >= 43 and z <= 46):
			Pr(c.x * 4 + 2.0, c.y * 4 + 2.0, "ov/tram_bovenleiding_mast", MAST_ARM_ROTATION["E"])
	for zr in [Z2, Z3]:
		for x in range(X2 + 4, X_END, 5):
			var c := Vector2i(x, zr + 2)
			if stop_cells.has(c) or (zr == Z3 and x > X2 + 1 and x <= TRAM_TUNNEL_PORTALS[1] + 6) or (x >= X3 - 1 and x <= X3 + 2) or (x >= X4 - 1 and x <= X5 + 2) or (x >= X6 - 1 and x <= X6 + 2) or (x >= XB - 1 and x <= XB + 2) \
						or (x >= XC - 1 and x <= XC + 2) or (x >= XD - 1 and x <= XD + 2):
				continue
			Pr(c.x * 4 + 2.0, c.y * 4 + 1.5, "ov/tram_bovenleiding_mast", MAST_ARM_ROTATION["N"])
	Pr((X2 - 1) * 4 + 1.0, (Z2 + 3) * 4.0, "borden/bord_trambaan", "S")
	Pr((X5 + 2) * 4 + 1.0, (Z3 + 2) * 4 + 2.0, "borden/bord_tram_kruist", "W")


## Lays the tram tiles: tracks in the lanes, plain track over the crossings with other
## streets, curves where the Buitenhof line turns into the east-west lines, track on clinkers in the Grote
## Marktstraat (no cars) and over the bridges.
func _paint_trams() -> void:
	for c in _tram:
		var both: bool = _tram[c] == "v" and (c.y in [Z2, Z2 + 1, Z3, Z3 + 1])
		var crossing: bool = _street_h.has(c) and _street_v.has(c)
		if both:
			continue
		elif _tram[c] == "v":
			var k: int = c.x - X2
			if crossing:
				G(c.x, c.y, "tram/tram_recht", "S")
			else:
				G(c.x, c.y, "tram/tram_rijstrook_geen_kant" if k == 0 else "tram/tram_rijstrook_onderbroken_kant", "N" if k == 0 else "S")
		else:
			var north: bool = c.y == Z2 or c.y == Z3
			if crossing:
				G(c.x, c.y, "tram/tram_recht", "E")
			elif c.y >= Z3 and c.x > X2 + 1 and c.x < X3:
				G(c.x, c.y, "tram/tram_klinker_recht", "E")
			else:
				G(c.x, c.y, "tram/tram_rijstrook_onderbroken_kant" if north else "tram/tram_rijstrook_geen_kant", "E" if north else "W")
	# the Buitenhof line turns into the two east-west lines: a curve for each track (the
	# inner one in the inner corner cell, the outer one in the diagonal cell between two
	# straight cells), so the rails run on without stubs. tram_bocht "S" turns between the
	# south and east edges, "E" between the north and east edges.
	G(X2 + 1, Z2 + 1, "tram/tram_bocht", "S")
	G(X2, Z2, "tram/tram_bocht", "S")
	G(X2 + 1, Z2, "tram/tram_recht", "E")
	G(X2, Z2 + 1, "tram/tram_recht", "S")
	G(X2 + 1, Z3, "tram/tram_bocht", "E")
	G(X2, Z3 + 1, "tram/tram_bocht", "E")
	G(X2, Z3, "tram/tram_recht", "S")
	G(X2 + 1, Z3 + 1, "tram/tram_recht", "E")
	# the Grote Marktstraat is closed to cars
	for x in [X2 + 2, X3 - 1]:
		for z in [Z3, Z3 + 1]:
			Pr(x * 4 + 2.0, z * 4 + 2.0, "paaltjes/paal_afzet")
	Pr((X2 + 2) * 4 + 2.0, (Z3 - 1) * 4 + 3.0, "borden/bord_gesloten_verkeer", "W")
	Pr((X3 - 1) * 4 + 2.0, (Z3 + 2) * 4 + 1.0, "borden/bord_gesloten_verkeer", "E")


## Columns of the tram tunnel under the Grote Marktstraat: the portals (ramps of 6 columns
## lie outside them, the west one right after the curve from the Buitenhof, the east one
## coming up at the Spui by the ministry) and the underground stops: first column, last
## column, name in `places`.
const TRAM_TUNNEL_PORTALS := [32, 49]
const TRAM_TUNNEL_STOPS := [[33, 38, "tram_grote_marktstraat"], [42, 47, "tram_spui"]]


## The underground stop of TRAM_TUNNEL_STOPS at column x, or an empty array.
func _tram_tunnel_stop(x: int) -> Array:
	for stop: Array in TRAM_TUNNEL_STOPS:
		if x >= stop[0] and x <= stop[1]:
			return stop
	return []


## The tram tunnel under the Grote Marktstraat: two ramps, two portals and a covered part
## with two underground stops (platforms under the pavements, entrances on the street); the
## pedestrian street and the crossing with the Korte Vijverberg run on above it, so the
## whole Grote Marktstraat is closed on top. Called after _paint_trams. Rows Z3 and Z3 + 1
## hold the tracks; the side of a tile's wall follows from its rotation (front side W: wall north).
func _tram_tunnel() -> void:
	var tunnel_prefix := "tunnel/tramtunnel"
	for x in range(TRAM_TUNNEL_PORTALS[0] - 6, TRAM_TUNNEL_PORTALS[1] + 7):
		_clear_props(x, Z3)
		_clear_props(x, Z3 + 1)
	for depth in range(1, 7):
		var west: int = TRAM_TUNNEL_PORTALS[0] - 7 + depth
		_trench(west, Z3 + 1, "%s_toerit_wand_d%d" % [tunnel_prefix, depth], depth, "E")
		_trench(west, Z3, "%s_toerit_wand_rechts_d%d" % [tunnel_prefix, depth], depth, "E")
		var east: int = TRAM_TUNNEL_PORTALS[1] + 7 - depth
		_trench(east, Z3, "%s_toerit_wand_d%d" % [tunnel_prefix, depth], depth, "W")
		_trench(east, Z3 + 1, "%s_toerit_wand_rechts_d%d" % [tunnel_prefix, depth], depth, "W")
		for z in [Z3, Z3 + 1]:
			_pavement.erase(Vector2i(west, z))
			_pavement.erase(Vector2i(east, z))
	# from the east ramp to the Prinsessegracht only trams (cars would end at the ramp)
	for x in range(TRAM_TUNNEL_PORTALS[1] + 7, X4):
		for z in [Z3, Z3 + 1]:
			G(x, z, "tram/tram_klinker_recht", "E")
	for x in range(TRAM_TUNNEL_PORTALS[0], TRAM_TUNNEL_PORTALS[1] + 1):
		var stop := _tram_tunnel_stop(x)
		if x >= X3:
			for z in [Z3, Z3 + 1]:
				G(x, z, "weg/kruising_vlak")
		else:
			_fill(x, Z3, x, Z3 + 1, "plein/plein_klinkers")
		if x == TRAM_TUNNEL_PORTALS[0]:
			G(x, Z3, tunnel_prefix + "_wand_portaal", "W", -6)
			G(x, Z3 + 1, tunnel_prefix + "_wand_rechts_portaal", "W", -6)
		elif x == TRAM_TUNNEL_PORTALS[1]:
			G(x, Z3 + 1, tunnel_prefix + "_wand_portaal", "E", -6)
			G(x, Z3, tunnel_prefix + "_wand_rechts_portaal", "E", -6)
		elif not stop.is_empty():
			G(x, Z3, tunnel_prefix + "_kaal", "E", -6)
			G(x, Z3 + 1, tunnel_prefix + "_kaal", "E", -6)
			# closed at both ends; a tile's front lies west on the north side, east on the south
			var north_platform := "_perron_begin" if x == stop[0] else ("_perron_eind" if x == stop[1] else "_perron")
			var south_platform := "_perron_eind" if x == stop[0] else ("_perron_begin" if x == stop[1] else "_perron")
			G(x, Z3 - 1, tunnel_prefix + north_platform, "W", -6)
			G(x, Z3 + 2, tunnel_prefix + south_platform, "E", -6)
		else:
			G(x, Z3 + 1, tunnel_prefix + "_wand", "E", -6)
			G(x, Z3, tunnel_prefix + "_wand_rechts", "E", -6)
	# railings above the portals, the street entrances of the stop
	for z in [Z3, Z3 + 1]:
		Pr(TRAM_TUNNEL_PORTALS[0] * 4 + 0.5, z * 4 + 2.0, "hekken/hek_ijzer", "E")
		Pr((TRAM_TUNNEL_PORTALS[1] + 1) * 4 + 0.5, z * 4 + 2.0, "hekken/hek_ijzer", "E")
	for stop: Array in TRAM_TUNNEL_STOPS:
		var middle: int = (stop[0] + stop[1]) / 2
		Pr(middle * 4 + 2.0, (Z3 - 1) * 4 + 2.0, "ov/tramtunnel_ingang", "S")
		Pr(middle * 4 + 2.0, (Z3 + 2) * 4 + 2.0, "ov/tramtunnel_ingang", "N")
		# OV-chipkaart readers on the platforms below (their surface 0.625 m up the floor)
		for reader_x: int in [stop[0] + 1, stop[1] - 1]:
			Pr(reader_x * 4 + 2.0, (Z3 - 1) * 4 + 2.0, "ov/ov_incheckpaal", "S", -6.0 + 0.625)
			Pr(reader_x * 4 + 2.0, (Z3 + 2) * 4 + 2.0, "ov/ov_incheckpaal", "N", -6.0 + 0.625)
		places[stop[2]] = Vector2(middle * 4.0 + 2.0, (Z3 + 1) * 4.0)


## The Grote Marktstraat above the tram tunnel is for pedestrians, cyclists and mopeds
## (no cars): a lane each way over the square, past the west ramp over the pavement
## north of it, westbound on into the Buitenhof, both joined to the crossing with the Korte
## Vijverberg (the eastbound lane starts where the westbound one turns round). Chosen
## per placed tile (RoadNetwork.LANE_CHOICES), after the kerbs are final.
func _grote_marktstraat_lanes() -> void:
	var slow_traffic := ["voetganger", "fiets", "brommer"]
	var west := Vector2i(-1, 0)
	var east := Vector2i(1, 0)
	var north := Vector2i(0, -1)
	var first_square_column: int = TRAM_TUNNEL_PORTALS[0]
	for x in range(first_square_column + 1, X3):
		_choose_lanes(x, Z3, [west], slow_traffic)
		_choose_lanes(x, Z3 + 1, [east], slow_traffic)
	# at the west end of the square: on over the north pavement past the ramp, or round
	_choose_lanes(first_square_column, Z3, [north, Vector2i(0, 1)], slow_traffic)
	_choose_lanes(first_square_column, Z3 + 1, [east], slow_traffic)
	_choose_lanes(first_square_column, Z3 - 1, [west], slow_traffic)
	for x in range(X2 + 2, first_square_column):
		_choose_lanes(x, Z3 - 1, [west], slow_traffic)


# ------------------------------------------------------------------ finishing

## The RandstadRail viaduct north of the Schenkkade: a two-track tram deck on concrete
## piers, from a ramp beside Centraal Station east over the streets x 96, 128 and 152 to
## the map edge, with stops and overhead line masts. The piers stand on the pavement or
## grass below, never on a lane or in the water, and props in their way are taken away.
## Built after the grass fill, so the ground under it is final.
func _schenkviaduct() -> void:
	var foot_kinds := {"natuur": "brug/brug_pijler_gras", "stoep": "brug/brug_pijler_stoep", "plein": "brug/brug_pijler_stoep"}
	for x in range(VIADUCT_START, MAP_END + 1):
		var stop := _viaduct_stop(x)
		# the deck: parapets on the outside, the north track turned to face north; open
		# track along a platform, so nothing stands between the tram and the platform
		for row_index in VIADUCT_ROWS.size():
			var row: int = VIADUCT_ROWS[row_index]
			if not stop.is_empty() and _platform_row(row_index) in stop[2]:
				G(x, row, "tram/trambaan_vrij", "E", VIADUCT_LEVEL)
			else:
				G(x, row, "brug/brug_dek_tram_rand", "W" if row_index == 0 else "E", VIADUCT_LEVEL)
	_viaduct_piers(VIADUCT_ROWS, VIADUCT_START, foot_kinds)
	_railway_viaduct(foot_kinds)
	_clear_trees_along_viaduct()
	_viaduct_link(foot_kinds)
	for stop: Array in VIADUCT_STOPS:
		_viaduct_platforms(stop, foot_kinds)
	for x in range(VIADUCT_START + 2, MAP_END, 5):
		if _viaduct_stop(x).is_empty():
			Pr(x * 4 + 2.0, (VIADUCT_ROWS[1] + 1) * 4 - 0.5, "ov/tram_bovenleiding_mast", MAST_ARM_ROTATION["N"], VIADUCT_LEVEL + 0.5)
	places["schenkviaduct"] = Vector2(112 * 4.0, VIADUCT_ROWS[0] * 4.0)


## Piers under the deck on `rows` from column `start` on, about every VIADUCT_SPAN columns,
## at the first column where all rows have a pavement or grass cell below.
func _viaduct_piers(rows: Array, start: int, foot_kinds: Dictionary) -> void:
	var since_pier := VIADUCT_SPAN
	for x in range(start, MAP_END):
		since_pier += 1
		if since_pier < VIADUCT_SPAN:
			continue
		var feet := []
		for z in rows:
			feet.append(_pier_foot(x, z, foot_kinds))
		if "" in feet:
			continue   # a lane, a crossing or water below: try the next column
		for k in rows.size():
			_clear_props(x, rows[k])
			_pier(x, rows[k], feet[k], 0, VIADUCT_LEVEL - 1)
		since_pier = 0


## Two railway tracks from inside the station hall south over the square, under the tram
## viaduct, round a corner and up a ramp to the foot of the railway viaduct, with platforms
## in and just outside the hall and signals. Called after the grass fill.
func _railway() -> void:
	for x in RAILWAY_COLUMNS:
		buildings.set_cell_item(Vector3i(x, 0, RAILWAY_LEAVE_HALL), GridMap.INVALID_CELL_ITEM)   # where the trains leave the hall
		G(x, RAILWAY_HALL_END, "spoor/trein_stootblok", "S")
		for z in range(RAILWAY_HALL_END + 1, RAILWAY_ROWS[0]):
			_clear_props(x, z)
			G(x, z, "spoor/trein_recht", "S")
	# platforms on both sides, out of the hall and on between the office towers
	for z in range(RAILWAY_HALL_END, RAILWAY_HALL_END + RAILWAY_PLATFORM_CELLS):
		_clear_props(RAILWAY_COLUMNS[0] - 1, z)
		_clear_props(RAILWAY_COLUMNS[1] + 1, z)
		G(RAILWAY_COLUMNS[0] - 1, z, "spoor/perron", "E")
		G(RAILWAY_COLUMNS[1] + 1, z, "spoor/perron", "W")
	# OV-chipkaart readers where the platforms start in the hall and at their far end
	for z: int in [RAILWAY_HALL_END + 1, RAILWAY_HALL_END + RAILWAY_PLATFORM_CELLS - 2]:
		Pr((RAILWAY_COLUMNS[0] - 1) * 4 + 2.0, z * 4 + 2.0, "ov/ov_incheckpaal", "E", 1.0)
		Pr((RAILWAY_COLUMNS[1] + 1) * 4 + 2.0, z * 4 + 2.0, "ov/ov_incheckpaal", "W", 1.0)
	# the corner to the east: one track inside the other
	var outer_column: int = RAILWAY_COLUMNS[0]
	var inner_column: int = RAILWAY_COLUMNS[1]
	for x in range(outer_column, RAILWAY_DECK_START):
		for z in RAILWAY_ROWS:
			_clear_props(x, z)
	G(inner_column, RAILWAY_ROWS[0], "spoor/trein_bocht", "E")
	G(outer_column, RAILWAY_ROWS[1], "spoor/trein_bocht", "E")
	G(outer_column, RAILWAY_ROWS[0], "spoor/trein_recht", "S")
	G(inner_column, RAILWAY_ROWS[1], "spoor/trein_recht", "E")
	Pr((RAILWAY_COLUMNS[1] + 1) * 4 + 1.0, 85 * 4 + 2.0, "spoor/seinpaal", "S")
	# overhead line masts on the west platform and beside the tracks over the square
	var mast_cells := []
	for z in range(RAILWAY_HALL_END + 3, RAILWAY_ROWS[0] - 3, 5):
		mast_cells.append(Vector2i(RAILWAY_COLUMNS[0] - 1, z))
	_line_masts(mast_cells, "spoor/bovenleidingmast", "E")
	places["spoor_centraal"] = Vector2(inner_column * 4.0, 84 * 4.0)


## The ramp and the deck of the railway from the corner east to the map edge, with piers,
## overhead line masts on both parapets and open track along Station Laan van NOI.
func _railway_viaduct(foot_kinds: Dictionary) -> void:
	for level in range(VIADUCT_LEVEL):
		var x := RAILWAY_DECK_START - VIADUCT_LEVEL + level
		G(x, RAILWAY_ROWS[0], "brug/helling/helling_trein_recht_rand", "W", level)
		G(x, RAILWAY_ROWS[1], "brug/helling/helling_trein_recht_rand_rechts", "W", level)
		if level >= 2 and (level - 2) % 3 == 0:
			for z in RAILWAY_ROWS:
				var foot := _pier_foot(x, z, foot_kinds)
				if foot != "":
					_pier(x, z, foot, 0, level - 1)
	for x in range(RAILWAY_DECK_START, MAP_END + 1):
		var at_station: bool = _viaduct_stop(x).size() > 0 and _viaduct_stop(x)[4]
		G(x, RAILWAY_ROWS[0], "brug/brug_dek_trein_kaal" if at_station else "brug/brug_dek_trein_rand", "W", VIADUCT_LEVEL)
		G(x, RAILWAY_ROWS[1], "brug/brug_dek_trein_kaal" if at_station else "brug/brug_dek_trein_rand", "E", VIADUCT_LEVEL)
		if not at_station and (x - RAILWAY_DECK_START) % 6 == 3:
			Pr(x * 4 + 2.0, RAILWAY_ROWS[0] * 4 + 0.5, "spoor/bovenleidingmast", MAST_ARM_ROTATION["S"], VIADUCT_LEVEL + 0.5)
			Pr(x * 4 + 2.0, (RAILWAY_ROWS[1] + 1) * 4 - 0.5, "spoor/bovenleidingmast", MAST_ARM_ROTATION["N"], VIADUCT_LEVEL + 0.5)
	_viaduct_piers(RAILWAY_ROWS, RAILWAY_DECK_START, foot_kinds)


## Joins the viaduct to the tram network: a ramp up from the square, a curve and two
## tracks north over the square to branches in the south track of street Z3.
func _viaduct_link(foot_kinds: Dictionary) -> void:
	var outer_column: int = VIADUCT_LINK_COLUMNS[0]
	var inner_column: int = VIADUCT_LINK_COLUMNS[1]
	for x in VIADUCT_LINK_COLUMNS:
		for z in range(Z3 + 2, VIADUCT_ROWS[1] + 1):
			_clear_props(x, z)
	for level in range(VIADUCT_LEVEL):
		var x := VIADUCT_RAMP_START + level
		for z in VIADUCT_ROWS:
			_clear_props(x, z)
		G(x, VIADUCT_ROWS[0], "brug/helling/helling_tram_recht_rand", "W", level)
		G(x, VIADUCT_ROWS[1], "brug/helling/helling_tram_recht_rand_rechts", "W", level)
		# piers under the higher part, one column below the deck's first pier spacing
		if level >= 2 and (level - 2) % 3 == 0:
			for z in VIADUCT_ROWS:
				var foot := _pier_foot(x, z, foot_kinds)
				if foot != "":
					_pier(x, z, foot, 0, level - 1)
	# the curve: the same corner of tiles as the Buitenhof line, one track inside the other
	G(inner_column, VIADUCT_ROWS[0], "tram/tram_klinker_bocht", "E")
	G(outer_column, VIADUCT_ROWS[1], "tram/tram_klinker_bocht", "E")
	G(outer_column, VIADUCT_ROWS[0], "tram/tram_klinker_recht", "S")
	G(inner_column, VIADUCT_ROWS[1], "tram/tram_klinker_recht", "E")
	for x in VIADUCT_LINK_COLUMNS:
		for z in range(Z3 + 2, VIADUCT_ROWS[0]):
			G(x, z, "tram/tram_klinker_recht", "S")
	# the stop beside Centraal Station: a platform each side of the two tracks, by the square
	for z in range(STATION_TRAM_STOP_ROWS[0], STATION_TRAM_STOP_ROWS[1] + 1):
		for platform: Array in [[outer_column - 1, "E"], [inner_column + 1, "W"]]:
			_clear_props(platform[0], z)
			_g(platform[0], z, "tram/tram_halte_perron", platform[1])
	var middle_row: int = (STATION_TRAM_STOP_ROWS[0] + STATION_TRAM_STOP_ROWS[1]) / 2
	for platform: Array in [[outer_column - 1, "E"], [inner_column + 1, "W"]]:
		Pr(platform[0] * 4 + 2.0, middle_row * 4 + 2.0, "ov/abri", platform[1], 0.5)
		for row: int in STATION_TRAM_STOP_ROWS:
			Pr(platform[0] * 4 + 2.0, row * 4 + 2.0, "ov/ov_incheckpaal", platform[1], 0.5)
	places["tram_centraal_station"] = Vector2(inner_column * 4.0, middle_row * 4.0)
	var mast_cells := []
	for z in range(Z3 + 4, VIADUCT_ROWS[0] - 2, 5):
		mast_cells.append(Vector2i(outer_column - 1, z))
	_line_masts(mast_cells, "ov/tram_bovenleiding_mast", "E")
	# towards the viaduct from the south track of street Z3; from the viaduct over that track
	# to the north one, each in the lane that goes that way
	G(outer_column, Z3 + 1, "tram/tram_t", "W")
	G(inner_column, Z3 + 1, "tram/tram_kruising")
	G(inner_column, Z3, "tram/tram_t", "W")
	places["tram_centraal_viaduct"] = Vector2(inner_column * 4.0, (Z3 + 12) * 4.0)


## Overhead line masts in the middle of the given ground cells, their arm turned to
## `arm_side`, each only on a pavement, square, grass or platform cell without a building
## or a deck above it (the Bovenleiding node draws the span from it to the tracks).
func _line_masts(cells: Array, tile_name: String, arm_side: String) -> void:
	for cell: Vector2i in cells:
		var below := ground.get_cell_item(Vector3i(cell.x, 0, cell.y))
		if below < 0:
			continue
		var below_name := ground.mesh_library.get_item_name(below)
		var free_ground := false
		for start: String in ["stoep/", "plein/", "natuur/", "spoor/perron"]:
			free_ground = free_ground or below_name.begins_with(start)
		if not free_ground or buildings.get_cell_item(Vector3i(cell.x, 0, cell.y)) >= 0:
			continue
		var covered := false
		for level in range(1, 12):
			covered = covered or ground.get_cell_item(Vector3i(cell.x, level, cell.y)) >= 0
		if covered:
			continue
		_clear_props(cell.x, cell.y)
		Pr(cell.x * 4 + 2.0, cell.y * 4 + 2.0, tile_name, MAST_ARM_ROTATION[arm_side])


## The stop of VIADUCT_STOPS at column x, or an empty array.
func _viaduct_stop(x: int) -> Array:
	for stop: Array in VIADUCT_STOPS:
		if x >= stop[0] and x <= stop[1]:
			return stop
	return []


## The platform row next to the track in VIADUCT_ROWS[row_index].
func _platform_row(row_index: int) -> int:
	return VIADUCT_ROWS[0] - 1 if row_index == 0 else VIADUCT_ROWS[1] + 1


## The foot tile of a pier on ground cell (x, z); "" on a lane, a crossing or water.
func _pier_foot(x: int, z: int, foot_kinds: Dictionary) -> String:
	var below := ground.get_cell_item(Vector3i(x, 0, z))
	var kind: String = "" if below < 0 else ground.mesh_library.get_item_name(below).get_slice("/", 0)
	return foot_kinds.get(kind, "")


## The platforms of a stop of VIADUCT_STOPS at deck level on piers of their own, each with
## a shelter, a stop sign and stairs down to the street at the west end. On a station the
## first cell holds the top of the stairs, and the street below stays free of props.
func _viaduct_platforms(stop: Array, foot_kinds: Dictionary) -> void:
	var first: int = stop[0]
	var last: int = stop[1]
	var high: bool = stop[4]
	for row: int in stop[2]:
		var towards_track: String = "S" if row < VIADUCT_ROWS[0] else "N"
		var between_tracks: bool = row > VIADUCT_ROWS[1] and row < RAILWAY_ROWS[0]
		var platform_tile := "spoor/perron_midden" if between_tracks else "spoor/perron"
		for x in range(first - 3, last + 1):
			_clear_lamps_and_trees(x, row)
		for x in range(first, last + 1):
			if high:
				G(x, row, "spoor/perron_trap" if x == first else platform_tile, "E" if x == first else towards_track, VIADUCT_LEVEL)
			else:
				G(x, row, "tram/tram_halte_perron", towards_track, VIADUCT_LEVEL)
		# a pier near each end, moved inwards off a lane
		for wanted: int in [first + 1, last - 1]:
			var step := 1 if wanted < (first + last) / 2 else -1
			var x := wanted
			while x > first and x < last and _pier_foot(x, row, foot_kinds) == "":
				x += step
			var foot := _pier_foot(x, row, foot_kinds)
			if foot != "":
				_clear_props(x, row)
				_pier(x, row, foot, 0, VIADUCT_LEVEL - 1)
		var middle := (first + last) / 2
		var platform_height: float = 1.0 if high else 0.5
		Pr(middle * 4 + 2.0, row * 4 + 2.0, "ov/abri", towards_track, VIADUCT_LEVEL + platform_height)
		for reader_x: int in [first + 1, last - 1]:
			Pr(reader_x * 4 + 2.0, row * 4 + 2.0, "ov/ov_incheckpaal", towards_track, VIADUCT_LEVEL + platform_height)
		# a station's name board on its platforms, either side of the shelter
		var board := "borden/stationsbord_" + (stop[3] as String).trim_prefix("station_")
		if high and _has(board, props):
			for board_x: int in [middle - 3, middle + 3]:
				Pr(board_x * 4 + 2.0, row * 4 + 2.0, board, towards_track, VIADUCT_LEVEL + platform_height)
		# two flights of 3 m (6 m long each) up to the west end of the platform: to deck
		# level on a station (the stairs in the first cell go on), else to the low platform
		var stairs_start: float = 0.0 if high else 0.5
		Pr(first * 4 - 3.0, row * 4 + 2.0, "trappen/trap_3m", VIADUCT_STAIR_ROTATION, stairs_start + 3.0)
		Pr(first * 4 - 9.0, row * 4 + 2.0, "trappen/trap_3m", VIADUCT_STAIR_ROTATION, stairs_start)
	places[stop[3]] = Vector2((first + last) * 2.0 + 2.0, stop[2][0] * 4.0 + 2.0)


## Columns and rows of the wing of the Ministerie van VWS over the tram tracks beside
## Centraal Station, and the storey it starts on.
const MINISTRY_COLUMNS := [VIADUCT_LINK_COLUMNS[0] - 1, VIADUCT_LINK_COLUMNS[1] + 1]
const MINISTRY_ROWS := [86, 89]
const MINISTRY_FIRST_STOREY := 2
const MINISTRY_WING_STOREYS := 10


## The low wing of the Ministerie van VWS (De Resident) west of the Castalia towers, built
## over the two tram tracks from Centraal Station to the viaduct, on columns on the
## pavement on both sides: the trams run under it with 6 m of headroom, as they run under
## the ministry on their way between Centraal and the city hall.
func _ministry_over_tram() -> void:
	for x in range(MINISTRY_COLUMNS[0], MINISTRY_COLUMNS[1] + 1):
		for z in range(MINISTRY_ROWS[0], MINISTRY_ROWS[1] + 1):
			_clear_lamps_and_trees(x, z)
	block(MINISTRY_COLUMNS[0], MINISTRY_ROWS[0], MINISTRY_COLUMNS[1] - MINISTRY_COLUMNS[0] + 1, MINISTRY_ROWS[1] - MINISTRY_ROWS[0] + 1, "klassiek_geel", MINISTRY_WING_STOREYS,
		{"front": "N", "y0": MINISTRY_FIRST_STOREY, "gf": ["verd_raam"], "gf_side": "verd_raam", "gf_corner": "verd_raam_hoek",
		"upper": ["verd_raam", "verd_drie_ramen"], "upper_corner": "verd_raam_hoek", "roof": "sloped"})
	for x: int in MINISTRY_COLUMNS:
		for z in range(MINISTRY_ROWS[0], MINISTRY_ROWS[1] + 1, 3):
			for storey in range(MINISTRY_FIRST_STOREY):
				B(x, storey, z, "pilaren/pilaar_beton", "S")
	places["ministerie_vws_tram"] = Vector2(VIADUCT_LINK_COLUMNS[1] * 4.0, (MINISTRY_ROWS[0] + MINISTRY_ROWS[1] + 1) * 2.0)


## Removes the trees on and beside the viaducts, whose crowns would grow through them.
func _clear_trees_along_viaduct() -> void:
	for cell in props.get_used_cells():
		var row := floori(cell.z / 8.0)
		if row >= VIADUCT_ROWS[0] - 1 and row <= RAILWAY_ROWS[1] + 1 and floori(cell.x / 8.0) >= VIADUCT_RAMP_START:
			if props.mesh_library.get_item_name(props.get_cell_item(cell)).begins_with("bomen/"):
				props.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)
