extends "res://tools/build/city/situations.gd"
## Builds scenes/stad.tscn: the centre of The Hague, compressed onto a street grid and
## made only of the tiles in the libraries. No railway: Centraal Station is the hall
## and its square.
## usage: GODOT_TIMEOUT=1200 tools/godot.sh --headless --script tools/build/build_city.gd
##
## It reuses the example-map builder (tools/build/city/): placement (G/B/D/Pr), building
## helpers (block, ring, tower, _hall, ...), the street grid (_h_street / _v_street, painted
## by _paint_streets, dressed with markings, zebra crossings and traffic lights by
## _dress_streets, kerbs by _auto_kerbs). Coordinates: x = east, z = south, ground tiles
## of 4 m; directions name the side a tile's front faces (see build_example_city.gd).
##
## MAP (x 0..175, z 0..91)
##   The Singelgracht rings the old centre (water x 2-3, x 66-67, z 2-3, z 88-89, quays
##   on both sides). Inside, on a grid of streets (x 5, 24, 48, 63 and z 5, 29, 58, 85):
##                x 7..23              x 26..47                  x 50..62
##   z  7..28     Paleis Noordeinde,   Lange Voorhout,           Denneweg,
##                Paleistuin           Kloosterkerk, Des Indes   Prinsessegracht houses
##   z 31..57     Grote Kerk,          Hofvijver, Binnenhof,     Plein with the statue,
##                Hoogstraat, Oude     Ridderzaal, Torentje,     ministries, Tweede Kamer
##                Raadhuis             Mauritshuis, Buitenhof
##   z 60..84     Grote Markt,         Grote Marktstraat with    Spuiplein, Nieuwe Kerk,
##                Chinatown            the Bijenkorf, Passage,   white city hall, Amare
##                                     shops on the Spui (x 48)
##   The street x 48 is the Korte Vijverberg, then the Lange Poten (z 31..57), then the Spui
##   (z 60..84); the shops of the Lange Poten, Spui and Grote Marktstraat are on them.
##   East of the Prinsessegracht (street x 69, Koningskade), cut by the streets x 96
##   (Juliana van Stolberglaan) and x 128 (Laan van NOI): the Haagse Bos with Paleis Huis
##   ten Bosch (z 0..17) and the offices of the Prins Clauslaan east of it; the A12
##   (Utrechtsebaan, z 19..27) coming in from the east edge, down into a trough, covered
##   from x 95 to x 130 with the Malietoren, Snackbar De Vrijheid and offices on the deck
##   (_over_a12), up again to a junction with the Koningskade by the Ministerie van
##   Financien; the Malieveld, the Bezuidenhout and the Theresiastraat (z 31..57);
##   Centraal Station with its square and towers, the Beatrixkwartier and the
##   Bezuidenhout-Oost (z 60..91).
##   Trams: Buitenhof (x 24, z 29..59), Kneuterdijk - Korte Voorhout - Malieveld (z 29)
##   and Grote Marktstraat - Spui - Centraal (z 58), over bridges across the singel;
##   the RandstadRail viaduct along the Schenkkade (z 90..91) from beside Centraal
##   Station east over the Beatrixkwartier and the Bezuidenhout-Oost (_schenkviaduct).

# streets: first lane (north or west) of the two
const X1 := 5      # Hogewal / Prinsegracht
const X2 := 24     # Noordeinde - Buitenhof (tram)
const X3 := 48     # Korte Vijverberg - Lange Poten
const X4 := 63     # Prinsessegracht (inner side)
const X5 := 69     # Koningskade (outer side)
const X6 := 96     # Juliana van Stolberglaan (over the A12 tunnel)
const XB := 112    # street through the Bezuidenhout
const XC := 128    # Laan van Nieuw Oost-Indie (over the A12 tunnel)
const XD := 152    # cross street of the Theresiastraat in the Bezuidenhout-Oost
const ZB := 43     # street through the Bezuidenhout, east of x 128 the Theresiastraat
const AZ := 19     # A12: first row of the 9 rows (berm .. berm)
const Z1 := 5      # Mauritskade
const Z2 := 29     # Kneuterdijk - Lange Vijverberg - Korte Voorhout (tram)
const Z3 := 58     # Grote Marktstraat - Spui - Centraal (tram)
const Z4 := 85     # Zuidwal
const CW := 66     # east arm of the singel, water x 66-67
const Z_END := 91  # last row of the map
const X_END := 175 # last column of the map

var _tram := {}    # Vector2i -> "h" / "v": tram cells (painted after the streets)


func _init() -> void:
	Common.watchdog(self, 1100)
	var root := _make_scene("Stad")
	root.get_node("Wandelaar").free()
	_streets()
	_singel()
	_noordeinde()
	_lange_voorhout()
	_denneweg()
	_grote_kerk()
	_binnenhof()
	_plein()
	_grote_markt()
	_grote_marktstraat()
	_spui()
	_haagse_bos()
	_a12()
	_over_a12()
	_prins_clauslaan()
	_malieveld()
	_bezuidenhout()
	_theresiastraat()
	_bezuidenhout_oost()
	_centraal()
	_beatrixkwartier()
	_tram_lines()
	_paint_streets()
	_dress_streets()
	_paint_trams()
	_bridges()
	_a12_junction()
	_square_corners()
	_auto_kerbs()
	_fill_grass_all()
	_schenkviaduct()
	_bins()
	_camera(root)
	_car(root)
	_own_tints(root)
	if missing.size() > 0:
		print("MISSING TILES: ", missing.keys())
	_report()
	root.set_meta("districts", districts)
	root.set_meta("places", places)
	_save(root, "res://scenes/stad.tscn")
	quit()


# ------------------------------------------------------------------ helpers

## Corner key of CORNER that contains both sides a and b ("" if none).
func _ck(a: String, b: String) -> String:
	for k in CORNER:
		if k.contains(a) and k.contains(b):
			return k
	return ""


func _rect(x0: int, z0: int, w: int, d: int) -> Array:
	var out := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			out.append(Vector2i(x, z))
	return out


## A quay cell (quay wall under a quay pavement) that _auto_kerbs leaves alone.
func _quay_cell(x: int, z: int, tile_name: String, rot) -> void:
	_quay(x, z, tile_name, rot)
	_pavement.erase(Vector2i(x, z))
	_taken[Vector2i(x, z)] = true


## Walled water (level -2) on every cell of `cells` (Vector2i -> true), with quays on
## every land cell next to it: a straight quay facing the water, an outer quay corner
## where the water lies on two sides, an inner corner where it only lies diagonally.
func _water(cells: Dictionary, water := "water/water_gracht") -> void:
	for c in cells:
		_trench(c.x, c.y, water, 2)
		_pavement.erase(c)
		_taken[c] = true
	var quays := {}
	for c in cells:
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var q: Vector2i = c + Vector2i(dx, dz)
				if not cells.has(q) and q.x >= 0 and q.x <= X_END and q.y >= 0 and q.y <= Z_END:
					quays[q] = true
	for q in quays:
		var orth := []
		for d in ORDER:
			if cells.has(q + DIR_OFFSET[d]):
				orth.append(d)
		var kade := "stoep/stoep_kade_klinker" if (q.x + q.y) % 5 == 0 else "stoep/stoep_kade"
		if orth.is_empty():
			var rot := "S"
			if cells.has(q + Vector2i(-1, 1)):
				rot = "W"
			elif cells.has(q + Vector2i(1, -1)):
				rot = "E"
			elif cells.has(q + Vector2i(-1, -1)):
				rot = "N"
			_quay_cell(q.x, q.y, "stoep/stoep_kade_hoek_binnen", rot)
		elif orth.size() == 2 and _ck(orth[0], orth[1]) != "":
			_quay_cell(q.x, q.y, "stoep/stoep_kade_hoek_buiten", _ck(orth[0], orth[1]))
		else:
			_quay_cell(q.x, q.y, kade, orth[0])


## Natural pond: banks on the edge cells of x0..x1, z0..z1, water (with lilies and reed)
## inside.
func _pond(x0: int, z0: int, x1: int, z1: int) -> void:
	for x in range(x0 + 1, x1):
		for z in range(z0 + 1, z1):
			_g(x, z, ["water/water", "water/water_lelies", "water/water", "water/water_riet"][(x * 3 + z) % 4])
		_g(x, z0, "water/water_oever", "S")
		_g(x, z1, "water/water_oever", "N")
	for z in range(z0 + 1, z1):
		_g(x0, z, "water/water_oever", "E")
		_g(x1, z, "water/water_oever", "W")
	_g(x0, z0, "water/water_oever_hoek_buiten", "SE")
	_g(x1, z0, "water/water_oever_hoek_buiten", "WS")
	_g(x0, z1, "water/water_oever_hoek_buiten", "EN")
	_g(x1, z1, "water/water_oever_hoek_buiten", "NW")


## Ground tile that the kerbs and street furniture leave alone.
func _g(x: int, z: int, tile_name: String, rot = "S", y := 0) -> void:
	G(x, z, tile_name, rot, y)
	_pavement.erase(Vector2i(x, z))
	_taken[Vector2i(x, z)] = true


func _fill(x0: int, z0: int, x1: int, z1: int, tile_name: String, rot = "S") -> void:
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			_g(x, z, tile_name, rot)


func _trees(cells: Array, kinds: Array) -> void:
	for i in cells.size():
		var c: Vector2i = cells[i]
		Pr(c.x * 4 + 2.0, c.y * 4 + 2.0, kinds[(c.x * 7 + c.y * 3) % kinds.size()])


## Klinker path from a block onto the street: the kerb cell becomes a driveway.
func _kerb_path(x: int, z: int, towards: String) -> void:
	_g(x, z, "stoep/stoep_oprit", towards)


const OPPOSITE := {"S": "N", "N": "S", "E": "W", "W": "E"}
const AWNINGS := ["luifels/luifel_rood", "luifels/luifel_groen", "luifels/luifel_blauw", "luifels/luifel_geel",
	"luifels/luifel_effen_rood", "luifels/luifel_effen_groen", "zonwering/knikarmscherm_streep", "zonwering/uitvalscherm_blauw",
	"zonwering/knikarmscherm_groen", "zonwering/uitvalscherm_oranje"]
const SHOPS := ["bg_bakker", "bg_cafe", "bg_kleding", "bg_boekhandel", "bg_restaurant", "bg_bloemist", "bg_juwelier", "bg_ijssalon",
	"bg_slager", "bg_fietsenwinkel", "bg_drogist", "bg_kapper", "bg_snackbar", "bg_supermarkt", "bg_telefoon", "bg_bar", "bg_dierenwinkel"]
## What the shopping streets around the Grote Marktstraat sell; HORECA is for the square.
const RETAIL := ["bg_kleding", "bg_boekhandel", "bg_juwelier", "bg_kleding", "bg_drogist", "bg_telefoon", "bg_bakker", "bg_kapper",
	"bg_kleding", "bg_bloemist", "bg_ijssalon", "bg_cafe"]
const HORECA := ["bg_cafe", "bg_bar", "bg_restaurant", "bg_cafe", "bg_snackbar", "bg_ijssalon"]
const SIGNS := {"bg_bakker": "tekst/bord_bakker", "bg_slager": "tekst/bord_slager", "bg_kapper": "tekst/bord_kapper",
	"bg_bloemist": "tekst/bord_bloemen", "bg_fietsenwinkel": "tekst/bord_fietsen", "bg_cafe": "tekst/lichtreclame_cafe",
	"bg_drogist": "tekst/tekst_apotheek", "bg_bar": "tekst/tekst_cafe", "bg_supermarkt": "tekst/bord_kaas"}


## A row of n shop houses, two cells deep, from `start` in steps of `step`: front cells
## facing `front` with a shop on the ground floor (from `kinds`) and homes above, rear
## cells behind them; sloped roofs (flat for styles without them), corner pieces at
## both ends, signs, awnings and flower boxes.
func _shops(start: Vector2i, step: Vector2i, n: int, front: String, seed: int, kinds: Array = SHOPS,
		awnings: Array = AWNINGS, floors := 3) -> void:
	var back: String = OPPOSITE[front]
	var off: Vector2i = DIR_OFFSET[front]
	var first_end := "N" if step.y != 0 else "W"
	var last_end := "S" if step.y != 0 else "E"
	var styles := ["klassiek_rood", "jaren30", "klassiek_geel", "herenhuis_1900", "klassiek_donker", "modern_wit"]
	var upper := ["verd_raam", "verd_balkon", "verd_luiken", "verd_erker", "verd_raam_breed", "verd_drie_ramen"]
	var roofs := ["dak_schuin", "dak_schuin_dakkapel", "dak_schuin", "dak_schuin_schoorsteen"]
	for i in n:
		var c: Vector2i = start + step * i
		var bc: Vector2i = c - off
		var style: String = styles[(i / 4 + seed) % styles.size()]
		var p := style + "/" + style + "_"
		var end := first_end if i == 0 else (last_end if i == n - 1 else "")
		var fc := _ck(front, end) if end != "" else ""
		var bk := _ck(back, end) if end != "" else ""
		var shop: String = kinds[(i + seed) % kinds.size()]
		if not _has(p + shop):
			shop = _first(p, ["bg_winkel_luifel", "bg_winkel", "bg_raam"])
		for v in floors:
			var nm := ""
			if v == 0:
				nm = shop if fc == "" else _first(p, ["bg_winkel_hoek", "bg_raam_hoek", "bg_raam_boog_hoek"])
			elif fc == "":
				var u: String = upper[(i + v + seed) % upper.size()]
				nm = u if _has(p + u) else _first(p, ["verd_raam", "verd_raam_boog", "verd_glas"])
			else:
				nm = _first(p, ["verd_raam_hoek", "verd_raam_boog_hoek", "verd_dicht_hoek"])
			B(c.x, v, c.y, p + nm, CORNER[fc] if fc != "" else front)
			var bn := ""
			if bk != "":
				bn = _first(p, ["bg_raam_hoek", "bg_raam_boog_hoek", "verd_raam_hoek"]) if v == 0 else _first(p, ["verd_raam_hoek", "verd_raam_boog_hoek"])
			else:
				bn = _first(p, ["bg_deur", "bg_raam", "bg_raam_boog"]) if v == 0 else _first(p, ["verd_raam", "verd_raam_boog"])
			B(bc.x, v, bc.y, p + bn, CORNER[bk] if bk != "" else back)
		if _has(p + "dak_schuin"):
			if fc != "":
				B(c.x, floors, c.y, p + "dak_schuin_hoek_buiten", CORNER[fc])
				B(bc.x, floors, bc.y, p + "dak_schuin_hoek_buiten", CORNER[bk])
			else:
				var rn: String = roofs[(i + seed) % roofs.size()]
				B(c.x, floors, c.y, p + (rn if _has(p + rn) else "dak_schuin"), front)
				B(bc.x, floors, bc.y, p + "dak_schuin", back)
		else:
			B(c.x, floors, c.y, p + "dak_plat_rand", front if fc == "" else fc[0])
			B(bc.x, floors, bc.y, p + "dak_plat_rand", back if bk == "" else bk[0])
		if fc != "":
			continue
		# details on the middle of the front face (a little to one side for signs)
		var wx := c.x * 4.0 + 2.0 + off.x * 2.0
		var wz := c.y * 4.0 + 2.0 + off.y * 2.0
		if SIGNS.has(shop):
			D(wx - step.x, wz - step.y, 3.5, SIGNS[shop], front)
		elif (i + seed) % 2 == 0:
			D(wx, wz, 2.5, awnings[(i + seed) % awnings.size()], front)
		if (i + seed) % 3 == 1:
			D(wx + step.x, wz + step.y, 4.0, "ramen/bloembak", front)


# ------------------------------------------------------------------ streets and the singel

## Cells of a 2-lane east-west street (like _h_street, but not cut off at the width of
## the example map).
func _hs(x0: int, x1: int, z: int) -> void:
	for x in range(maxi(x0, 0), mini(x1, X_END) + 1):
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
	_hs(X1, X4 + 1, Z1)
	_hs(X1, X_END, Z2)
	_hs(X2, X_END, Z3)
	_hs(X1, X4 + 1, Z4)
	_hs(X6 + 2, X_END, ZB)
	for x in [X1, X2, X3, X4]:
		_vs(x, Z1, Z4 + 1)
	_vs(X5, 0, Z_END)
	_vs(X6, 0, Z_END)
	_vs(XB, Z2 + 2, Z3 - 1)
	_vs(XC, 0, Z_END)
	_vs(XD, Z2, Z_END)
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
	_kerb_block(71, 60, 25, 32)
	_kerb_block(X6 + 2, 60, XC - X6 - 2, 32)
	# the Bezuidenhout-Oost on both sides of the street x 152
	for zd in [[31, ZB - 31], [ZB + 2, Z3 - ZB - 2], [60, Z_END - 59]]:
		_kerb_block(XC + 2, zd[0], XD - XC - 2, zd[1])
		_kerb_block(XD + 2, zd[0], X_END - XD - 1, zd[1])
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
	# the two cells between belong to the outside lane: towards its corner, and away from it
	for beside: Vector2i in [Vector2i(inner.x, outer.y), Vector2i(outer.x, inner.y)]:
		var towards_outer: Vector2i = outer - beside
		var along_outer_lane: Vector2i = towards_outer if towards_outer == outer_heading else -towards_outer
		G(beside.x, beside.y, tiles.outer, ROTATION_OF_HEADING[along_outer_lane])
	_undress_arm(arm_cells_x, Vector2i(arm_x, 0))
	_undress_arm(arm_cells_z, Vector2i(0, arm_z))
	return true


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
	for z in range(0, Z_END + 1):
		_g(0, z, "plein/plein_klinkers")
	for x in range(1, CW + 3):
		_g(x, 0, "plein/plein_klinkers")
		_g(x, Z_END, "plein/plein_klinkers")
	for i in range(1, 46):
		var t: String = "bomen/linde" if i % 3 else "bomen/plataan"
		Pr(0 * 4 + 2.0, i * 2 * 4 + 2.0, t)
		if i * 2 <= CW:
			Pr(i * 2 * 4 + 2.0, 0 * 4 + 2.0, t)
			Pr(i * 2 * 4 + 2.0, Z_END * 4 + 2.0, t)
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


## Bridges where the tram streets cross the east arm of the singel: deck pavements with a
## parapet over the water (the lanes are laid by the streets and the tram), piers below.
func _bridges() -> void:
	for z in [Z2, Z3]:
		for x in [CW, CW + 1]:
			G(x, z - 1, "brug/brug_dek_stoep_rand", "W")
			G(x, z + 2, "brug/brug_dek_stoep_rand", "E")
	Pr((CW - 1) * 4 + 1.0, (Z2 - 1) * 4 + 1.0, "verlichting/lantaarn_klassiek_dubbel")
	Pr((CW + 2) * 4 + 3.0, (Z3 + 2) * 4 + 3.0, "verlichting/lantaarn_klassiek_dubbel")


# ------------------------------------------------------------------ north: Noordeinde, Lange Voorhout, Denneweg

## Paleis Noordeinde (x 15..20, z 12..21) facing the street Noordeinde (x 24) behind a
## gravel forecourt with a railing and the equestrian statue; the Paleistuin west of it;
## shops along Noordeinde north and south of the palace.
func _noordeinde() -> void:
	# Paleistuin: lawns, gravel paths, trees, a fountain and a railing along the street
	for x in range(8, 14):
		for z in range(8, 28):
			var t := "natuur/gras"
			if z == 17 or x == 10:
				t = "natuur/pad_grind"
			_g(x, z, t, "S" if x == 10 else "E")
	_g(10, 17, "plein/plein_grind")
	Pr(10 * 4 + 2.0, 17 * 4 + 2.0, "straat/fontein")
	for x in range(8, 14):
		for z in range(8, 28):
			if x == 10 or z == 17 or (x + z) % 3 != 0:
				continue
			Pr(x * 4 + 2.0, z * 4 + 2.0, ["bomen/eik", "bomen/kastanje", "bomen/linde", "bomen/treurwilg", "bomen/bloesemboom"][(x * 5 + z) % 5])
	for z in range(8, 28):
		Pr(8 * 4 + 0.5, z * 4 + 2.0, "hekken/hek_ijzer" if z != 17 else "hekken/hek_ijzer_poort", "E")
	_kerb_path(7, 17, "W")
	Pr(11 * 4 + 2.0, 12 * 4 + 2.0, "straat/bank_hout", "E")
	Pr(11 * 4 + 2.0, 22 * 4 + 2.0, "straat/bank_hout", "E")
	# the palace: three storeys, a pediment over the middle, flags
	block(15, 12, 6, 10, "overheid", 3, {"front": "E", "gf": ["bg_raam", "bg_entree", "bg_raam"], "gf_side": "bg_raam",
		"gf_corner": "bg_raam_hoek", "upper": ["verd_raam_hoog", "verd_raam_hoog", "verd_balkon"], "upper_corner": "verd_raam_hoog_hoek",
		"roof": "sloped", "roof_extra": ["dak_schuin_dakkapel", "dak_schuin_schoorsteen"]})
	B(20, 3, 16, "overheid/overheid_top_fronton", "E")
	B(20, 3, 17, "overheid/overheid_top_fronton", "E")
	D(21 * 4.0, 15 * 4.0, 9.0, "gevel/vlag_nl", "E")
	D(21 * 4.0, 19 * 4.0, 9.0, "gevel/vlag_oranje", "E")
	D(21 * 4.0, 17 * 4.0, 0.0, "deuren/bordes_klassiek", "E")
	_fill(21, 12, 22, 21, "plein/plein_grind")
	Pr(22 * 4.0, 17 * 4.0, "standbeelden/ruiterstandbeeld", "E")
	for z in range(12, 22):
		Pr(23 * 4.0, z * 4 + 2.0, "hekken/hek_ijzer_poort" if z == 14 or z == 19 else "hekken/hek_ijzer", "E")
	for z in [12, 21]:
		Pr(22 * 4 + 2.0, z * 4 + 2.0, "planten/buxus_bol")
	# shops along Noordeinde and houses behind them
	_shops(Vector2i(22, 8), Vector2i(0, 1), 4, "E", 1)
	_shops(Vector2i(22, 22), Vector2i(0, 1), 6, "E", 4)
	block(15, 8, 6, 3, "klassiek_geel", 3, {"front": "N", "gf": ["bg_deur", "bg_raam"], "upper": ["verd_raam", "verd_luiken"],
		"roof": "sloped", "roof_extra": ["dak_schuin_dakkapel"]})
	block(15, 24, 6, 4, "herenhuis_1900", 3, {"front": "S", "gf": ["bg_deur", "bg_raam_boog"], "gf_side": "bg_raam_boog",
		"gf_corner": "bg_raam_boog_hoek", "upper": ["verd_raam_boog", "verd_erker"], "upper_corner": "verd_raam_boog_hoek", "roof": "sloped"})
	places["noordeinde"] = Vector2(22 * 4.0, 17 * 4.0)


## Lange Voorhout (x 26..47, z 7..28): a gravel avenue with four rows of limes between
## two clinker lanes, mansions on both sides, the Kloosterkerk at the west end, Hotel Des
## Indes at the east end and the Escher museum in a palace on the north side.
func _lange_voorhout() -> void:
	block(27, 8, 4, 2, "kerk_steen", 3, {"front": "S", "gf": ["bg_portaal", "bg_spitsraam"], "gf_side": "bg_spitsraam",
		"gf_corner": "bg_spitsraam_hoek", "upper": ["verd_spitsraam", "verd_steunbeer"], "upper_corner": "verd_spitsraam_hoek", "roof": "gable"})
	block(31, 8, 16, 2, "herenhuis_1600", 3, {"front": "S", "gf": ["bg_deur", "bg_raam"], "gf_side": "bg_raam",
		"gf_corner": "bg_raam_hoek", "upper": ["verd_raam", "verd_balkon"], "upper_corner": "verd_raam_hoek", "roof": "sloped",
		"roof_extra": ["dak_schuin_dakkapel", "dak_schuin_schoorsteen"]})
	block(27, 24, 17, 2, "herenhuis_1900", 3, {"front": "N", "gf": ["bg_deur", "bg_raam_boog"], "gf_side": "bg_raam_boog",
		"gf_corner": "bg_raam_boog_hoek", "upper": ["verd_raam_boog", "verd_erker", "verd_balkon"], "upper_corner": "verd_raam_boog_hoek",
		"roof": "sloped", "roof_extra": ["dak_schuin_dakkapel", "dak_schuin_schoorsteen"]})
	# Hotel Des Indes on the corner
	block(44, 23, 3, 5, "klassiek_geel", 5, {"front": "N", "gf": ["bg_deur", "bg_raam"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_balkon", "verd_drie_ramen"], "roof": "cornice"})
	D(45 * 4 + 2.0, 23 * 4.0, 12.0, "tekst/tekst_hotel", "N")
	D(45 * 4 + 2.0, 23 * 4.0, 0.0, "luifels/luifel_glas", "N")
	D(47 * 4.0, 25 * 4 + 2.0, 9.0, "tekst/lichtreclame_hotel", "E")
	for x in range(27, 47):
		_g(x, 10, "weg/straat_klinkers", "E")
		if x < 44:
			_g(x, 23, "weg/straat_klinkers", "E")
		for z in range(11, 23):
			_g(x, z, "plein/plein_grind" if z in [12, 14, 19, 21] or x % 6 else "natuur/grindpad", "E")
		for z in [12, 14, 19, 21]:
			if x % 2 == 0 and x > 27:
				Pr(x * 4 + 2.0, z * 4 + 2.0, "bomen/linde")
		if x < 44:
			_g(x, 26, "natuur/gras")
			_g(x, 27, "natuur/gras" if x % 4 else "plein/plein_vlonder")
			Pr(x * 4 + 2.0, 27 * 4 + 3.5, "muurtjes/tuinmuur_middel" if x % 5 else "muurtjes/tuinmuur_poort", "S")
	for z in [10, 23]:
		_kerb_path(26, z, "W")
	_kerb_path(47, 10, "E")
	for x in range(29, 46, 4):
		Pr(x * 4.0, 16 * 4 + 2.0, "straat/bank_hout", "S")
		Pr(x * 4.0 + 2.0, 18 * 4 + 2.0, "verlichting/lantaarn_klassiek")
		Pr(x * 4.0, 15 * 4 + 2.0, "verlichting/lantaarn_klassiek")
	for x in [32, 40]:
		Pr(x * 4.0, 17 * 4.0, "standbeelden/kunstwerk_modern", "S")
	Pr(36 * 4.0, 17 * 4.0, "standbeelden/obelisk", "S")
	# details on the mansions: doors with steps, balconies, flags, the museum
	for x in range(32, 46, 3):
		D(x * 4 + 2.0, 10 * 4.0, 0.0, "deuren/bordes_klassiek", "S")
		D(x * 4 + 2.0, 10 * 4.0, 3.5, "balkons/balkon_klassiek", "S")
	for x in range(28, 43, 3):
		D(x * 4 + 2.0, 24 * 4.0, 0.0, "deuren/opstap_3_treden", "N")
	D(38 * 4.0, 10 * 4.0, 3.0, "tekst/tekst_museum", "S")
	D(33 * 4 + 2.0, 10 * 4.0, 6.0, "gevel/vlag_nl", "S")
	D(42 * 4 + 2.0, 10 * 4.0, 6.0, "gevel/vlag_eu", "S")
	D(29 * 4.0, 10 * 4.0, 2.5, "tekst/tekst_kerk", "S")
	Pr(27 * 4 + 2.0, 10 * 4 + 2.0, "borden/bord_eenrichtingsweg", "E")
	places["lange_voorhout"] = Vector2(36 * 4.0, 17 * 4.0)


## Denneweg (x 55, z 7..28): a narrow clinker street with small shops on both sides;
## mansions along the Korte Vijverberg side and canal houses facing the Prinsessegracht.
func _denneweg() -> void:
	for z in range(8, 28):
		_g(55, z, "weg/straat_klinkers", "S")
		if z % 4 == 1:
			Pr(55 * 4 + 2.0, z * 4 + 2.0, "verlichting/lantaarn_wand_klassiek", "S")
	_kerb_path(55, 7, "N")
	_kerb_path(55, 28, "S")
	Pr(55 * 4 + 1.0, 8 * 4 + 1.0, "borden/bord_woonerf", "S")
	_shops(Vector2i(54, 8), Vector2i(0, 1), 20, "E", 2)
	_shops(Vector2i(56, 8), Vector2i(0, 1), 20, "W", 6)
	block(51, 8, 2, 20, "herenhuis_1900", 3, {"front": "W", "gf": ["bg_deur", "bg_raam_boog"], "gf_side": "bg_raam_boog",
		"gf_corner": "bg_raam_boog_hoek", "upper": ["verd_raam_boog", "verd_erker", "verd_balkon"], "upper_corner": "verd_raam_boog_hoek",
		"roof": "sloped", "roof_extra": ["dak_schuin_dakkapel"]})
	for z in range(9, 27, 3):
		D(51 * 4.0, z * 4 + 2.0, 0.0, "deuren/stoeptrap", "W")
	# canal houses facing the singel, small back gardens towards the shops
	var styles := ["klassiek_rood", "klassiek_donker", "klassiek_geel"]
	var tops := ["trap", "klok", "hals", "tuit"]
	var upper := ["verd_raam", "verd_drie_ramen", "verd_luiken", "verd_balkon", "verd_raam", "verd_erker"]
	for z in range(8, 28):
		var style: String = styles[(z * 7 + 1) % 3]
		var n := 3 + (z % 2)
		_house(61, z, "E", style, n, upper, tops[(z * 3) % 4], z * 5 + 2)
		var p := style + "/" + style + "_"
		for v in n:
			B(60, v, z, p + ("verd_raam" if v > 0 else "bg_raam"), "W")
		B(60, n, z, p + "dak_zadel", "S")
		_g(59, z, "natuur/gras" if z % 3 else "natuur/moestuin")
		Pr(58 * 4 + 3.5, z * 4 + 2.0, "hekken/schutting_hout", "E")
		if z % 4 == 0:
			Pr(59 * 4 + 2.0, z * 4 + 2.0, "bomen/fruitboom")
		if z % 2 == 0:
			D(62 * 4.0, z * 4 + 2.0, 3.5, "ramen/bloembak", "E")
		if z % 5 == 3:
			D(62 * 4.0, z * 4 + 1.0, 0.0, "deuren/stoeptrap", "E")
	places["denneweg"] = Vector2(55 * 4.0, 18 * 4.0)


# ------------------------------------------------------------------ middle: Grote Kerk, Binnenhof, Plein

## Grote Kerk (nave x 12..19, tower at the west end) on the Kerkplein; the Hoogstraat
## (z 44-45), a pedestrian street with shops on both sides leading to the Buitenhof;
## the Oude Raadhuis with its tower and a closed block behind.
func _grote_kerk() -> void:
	_fill(8, 32, 22, 43, "plein/plein_keien")
	block(12, 35, 8, 4, "kerk_baksteen", 3, {"front": "S", "gf": ["bg_spitsraam"], "gf_side": "bg_spitsraam",
		"gf_corner": "bg_spitsraam_hoek", "upper": ["verd_spitsraam", "verd_steunbeer"], "upper_corner": "verd_spitsraam_hoek", "roof": "sloped"})
	tower(11, 36, "kerk_baksteen", ["toren_portaal", "toren_raam", "toren_galmgat", "toren_klok", "toren_pinakels", "toren_spits_onder", "toren_spits_boven"], "W")
	tower(11, 37, "kerk_baksteen", ["toren_portaal", "toren_raam", "toren_galmgat", "dak_kantelen_toren"], "W")
	D(11 * 4.0, 37 * 4.0, 3.0, "tekst/tekst_kerk", "W")
	_trees([Vector2i(8, 33), Vector2i(22, 33), Vector2i(8, 40), Vector2i(22, 40), Vector2i(15, 33), Vector2i(15, 41)], ["bomen/linde", "bomen/kastanje"])
	Pr(21 * 4 + 2.0, 36 * 4 + 2.0, "standbeelden/buste", "W")
	Pr(9 * 4 + 2.0, 36 * 4 + 2.0, "straat/bank_hout", "E")
	Pr(20 * 4 + 2.0, 41 * 4 + 2.0, "terras/terras_set_parasol", "N")
	Pr(18 * 4 + 2.0, 41 * 4 + 2.0, "terras/terras_set", "N")
	Pr(22 * 4 + 2.0, 37 * 4 + 2.0, "verlichting/lantaarn_klassiek_dubbel")
	# Hoogstraat
	_fill(8, 44, 22, 45, "plein/plein_klinkers")
	for x in range(9, 23, 4):
		Pr(x * 4 + 2.0, 44 * 4 + 4.0, "verlichting/lantaarn_gietijzer")
	for x in [12, 20]:
		Pr(x * 4.0, 45 * 4 + 1.0, "fietsen/fietsenrek_vol", "N")
	_shops(Vector2i(8, 43), Vector2i(1, 0), 15, "S", 1)
	_shops(Vector2i(8, 46), Vector2i(1, 0), 9, "N", 5)
	# Oude Raadhuis on the corner of the Hoogstraat, with its tower
	block(18, 46, 5, 5, "klassiek_geel", 3, {"front": "N", "gf": ["bg_deur", "bg_raam"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_luiken"], "roof": "sloped", "roof_extra": ["dak_schuin_dakkapel"]})
	tower(22, 46, "overheid", ["toren_klok", "toren_spits_onder", "toren_spits_boven"], "N", 3)
	D(20 * 4 + 2.0, 46 * 4.0, 3.0, "tekst/tekst_raadhuis", "N")
	D(19 * 4 + 2.0, 46 * 4.0, 6.0, "gevel/vlag_denhaag", "N")
	# shops on the north side of the Grote Marktstraat (the street runs along z 58-59)
	_shops(Vector2i(8, 56), Vector2i(1, 0), 9, "S", 15, RETAIL)
	_shops(Vector2i(18, 56), Vector2i(1, 0), 5, "S", 16, RETAIL)
	ring(8, 48, 9, 7, "klassiek_donker", 4, {"gf": ["bg_raam", "bg_deur", "bg_winkel_luifel"], "upper": ["verd_raam", "verd_drie_ramen"],
		"back": ["verd_raam"], "roof_extra": ["dak_schuin_schoorsteen", "dak_schuin_dakkapel"]})
	block(18, 52, 5, 3, "herenhuis_1900", 3, {"front": "E", "gf": ["bg_deur", "bg_raam_boog"], "gf_side": "bg_raam_boog",
		"gf_corner": "bg_raam_boog_hoek", "upper": ["verd_raam_boog", "verd_erker"], "upper_corner": "verd_raam_boog_hoek", "roof": "sloped"})
	places["grote_kerk"] = Vector2(15 * 4.0, 37 * 4.0)


## The Hofvijver (with its island) right by the Lange Vijverberg; the Binnenhof south of
## it: wings round a cobbled courtyard with the Ridderzaal and its two towers, the
## Torentje on the corner by the pond; the Mauritshuis beside it; the Buitenhof square
## with the Gevangenpoort on the west side; the Tweede Kamer building.
func _binnenhof() -> void:
	var pond := {}
	for c in _rect(31, 33, 16, 5):
		if not (c.x in [38, 39] and c.y in [34, 35]):
			pond[c] = true
	_water(pond)
	Pr(34 * 4 + 2.0, 35 * 4.0, "standbeelden/fontein_beeld", "S", -2.0)
	Pr(43 * 4 + 2.0, 35 * 4.0, "standbeelden/fontein_beeld", "S", -2.0)
	for c in [Vector2i(38, 34), Vector2i(39, 35)]:
		Pr(c.x * 4 + 2.0, c.y * 4 + 2.0, "bomen/treurwilg")
	for x in range(31, 47, 3):
		Pr(x * 4 + 2.0, 32 * 4 + 1.0, "bomen/linde")
	# Buitenhof and the path along the pond
	_fill(27, 32, 29, 56, "plein/plein_natuursteen")
	_fill(30, 39, 30, 56, "plein/plein_natuursteen")
	_fill(31, 39, 46, 39, "plein/plein_natuursteen")
	block(27, 32, 3, 3, "klassiek_rood", 3, {"front": "W", "gf": ["bg_poort"], "gf_side": "bg_raam", "upper": ["verd_raam", "verd_dicht"],
		"roof": "battlements"})
	D(27 * 4.0, 33 * 4 + 2.0, 3.0, "tekst/tekst_museum", "W")
	for z in [44, 48, 52]:
		Pr(28 * 4 + 2.0, z * 4 + 2.0, ["terras/terras_set_parasol", "terras/terras_set_parasol_groen", "terras/tafel_rond_stoelen"][(z / 4) % 3], "W")
		Pr(29 * 4 + 2.0, z * 4 + 2.0, "terras/terras_set", "W")
	_trees([Vector2i(30, 40), Vector2i(30, 46), Vector2i(30, 52)], ["bomen/plataan"])
	Pr(28 * 4 + 2.0, 40 * 4 + 2.0, "ov/reclamezuil")
	Pr(28 * 4.0, 56 * 4.0, "verlichting/lantaarn_gietijzer")
	# Binnenhof: wings round a courtyard
	_fill(31, 40, 42, 56, "plein/plein_keien")
	var gov := {"gf": ["bg_raam", "bg_entree", "bg_raam"], "gf_side": "bg_raam", "gf_corner": "bg_raam_hoek",
		"upper": ["verd_raam_hoog", "verd_balkon", "verd_raam_hoog"], "upper_corner": "verd_raam_hoog_hoek", "roof": "sloped",
		"roof_extra": ["dak_schuin_dakkapel", "dak_schuin_schoorsteen"]}
	for wing in [[31, 40, 12, 2, "N"], [31, 54, 12, 2, "S"], [31, 42, 2, 12, "W"], [41, 42, 2, 12, "E"]]:
		var o := gov.duplicate()
		o["front"] = wing[4]
		block(wing[0], wing[1], wing[2], wing[3], "overheid", 3, o)
	# the Torentje (prime minister's office) on the corner by the pond
	tower(42, 40, "overheid", ["toren_klok", "toren_spits_onder", "toren_spits_boven"], "N", 3)
	# Ridderzaal: a gothic hall with a gable roof and a tower each side of its front
	block(35, 45, 5, 4, "kerk_steen", 3, {"front": "W", "gf": ["bg_portaal", "bg_spitsraam"], "gf_side": "bg_spitsraam",
		"upper": ["verd_spitsraam", "verd_roosvenster"], "gf_corner": "bg_spitsraam_hoek", "upper_corner": "verd_spitsraam_hoek", "roof": "gable"})
	for tz in [45, 48]:
		tower(34, tz, "kerk_steen", ["toren_portaal", "toren_raam", "toren_raam", "toren_pinakels", "toren_spits_onder", "toren_spits_boven"], "W")
	Pr(38 * 4.0, 51 * 4 + 2.0, "straat/fontein")
	for c in [Vector2i(33, 43), Vector2i(40, 43), Vector2i(33, 52), Vector2i(40, 52)]:
		Pr(c.x * 4 + 2.0, c.y * 4 + 2.0, "verlichting/lantaarn_gietijzer")
	D(36 * 4.0, 40 * 4.0, 6.5, "gevel/vlag_nl", "N")
	D(32 * 4.0, 40 * 4.0, 6.5, "gevel/vlag_denhaag", "N")
	Pr(30 * 4 + 2.0, 47 * 4 + 4.0, "hekken/poort_groot", "W")
	# Mauritshuis on the corner of the pond, and the Tweede Kamer behind it
	_fill(43, 40, 46, 56, "plein/plein_natuursteen")
	block(44, 40, 3, 5, "herenhuis_1600", 3, {"front": "N", "gf": ["bg_deur", "bg_raam"], "gf_side": "bg_raam", "gf_corner": "bg_raam_hoek",
		"upper": ["verd_raam"], "upper_corner": "verd_raam_hoek", "roof": "sloped", "top": "top_lijstgevel_fronton"})
	D(45 * 4 + 2.0, 40 * 4.0, 3.0, "tekst/tekst_museum", "N")
	# the Lange Poten: shops along its west side, round the corner into the Grote Marktstraat
	_shops(Vector2i(46, 46), Vector2i(0, 1), 9, "E", 2, RETAIL)
	_shops(Vector2i(43, 56), Vector2i(1, 0), 4, "S", 4, RETAIL)
	places["lange_poten"] = Vector2(48 * 4.0, 50 * 4.0)
	# the north side of the Grote Marktstraat, on the corner of the Buitenhof
	_shops(Vector2i(27, 56), Vector2i(1, 0), 3, "S", 6, RETAIL)
	places["hofvijver"] = Vector2(38 * 4.0, 35 * 4.0)
	places["binnenhof"] = Vector2(37 * 4.0, 47 * 4.0)
	places["buitenhof"] = Vector2(28 * 4.0, 45 * 4.0)


## The Plein: a square of natural stone with the statue in the middle, trees, terraces
## in front of the cafes on its east side, flags; ministries round it.
func _plein() -> void:
	_fill(51, 32, 58, 51, "plein/plein_natuursteen")
	for c in [Vector2i(54, 41), Vector2i(55, 41), Vector2i(54, 42), Vector2i(55, 42)]:
		_g(c.x, c.y, "plein/plein_patroon")
	Pr(55 * 4.0, 42 * 4.0, "standbeelden/standbeeld_persoon", "W")
	var trees := []
	for z in range(33, 51, 3):
		for x in [51, 58]:
			trees.append(Vector2i(x, z))
			_g(x, z, "stoep/stoep_boomrooster")
	_trees(trees, ["bomen/linde"])
	for c in [Vector2i(53, 38), Vector2i(56, 38), Vector2i(53, 46), Vector2i(56, 46)]:
		_g(c.x, c.y, "natuur/bloemperk_tulpen")
	for z in range(34, 50, 3):
		Pr(57 * 4 + 2.0, z * 4 + 2.0, ["terras/terras_set_parasol_groen", "terras/terras_set_parasol", "terras/tafel_vierkant_stoelen"][z % 3], "W")
		Pr(58 * 4 + 2.0, z * 4 + 1.0, "terras/bloembak_terras", "W")
	for x in [52, 54, 56]:
		Pr(x * 4 + 2.0, 51 * 4 + 2.0, ["straat/vlaggenmast_nl", "straat/vlaggenmast_denhaag", "straat/vlaggenmast_eu"][(x - 52) / 2])
	Pr(52 * 4.0, 32 * 4 + 2.0, "verlichting/lantaarn_klassiek_dubbel")
	Pr(52 * 4.0, 50 * 4 + 2.0, "verlichting/lantaarn_klassiek_dubbel")
	# cafes and a ministry on the east side, the Tweede Kamer on the south side
	block(59, 32, 3, 19, "klassiek_geel", 4, {"front": "W", "gf": ["bg_cafe", "bg_restaurant", "bg_bar", "bg_deur"], "gf_side": "bg_raam",
		"gf_corner": "bg_raam_hoek", "upper": ["verd_raam", "verd_balkon", "verd_drie_ramen"], "upper_corner": "verd_raam_hoek", "roof": "cornice"})
	for z in range(33, 50, 4):
		D(59 * 4.0, z * 4 + 2.0, 2.5, ["luifels/luifel_groen", "zonwering/knikarmscherm_streep", "luifels/luifel_rood", "luifels/luifel_blauw"][(z / 4) % 4], "W")
	D(59 * 4.0, 45 * 4 + 2.0, 7.0, "gevel/vlag_nl", "W")
	# on the Plein side offices; on the Lange Poten and the Spui shops in front of them
	block(53, 52, 9, 3, "kantoor_modern", 6, {"front": "N", "gf": ["bg_entree", "bg_glas", "bg_kolonnade"], "gf_side": "bg_glas",
		"gf_corner": "bg_glas_hoek", "upper": ["verd_lamellen", "verd_raam_groot"], "upper_corner": "verd_lamellen_hoek", "roof": "flat"})
	_shops(Vector2i(51, 52), Vector2i(0, 1), 5, "W", 8, RETAIL)
	_shops(Vector2i(53, 56), Vector2i(1, 0), 9, "S", 10, RETAIL)
	D(56 * 4.0, 52 * 4.0, 0.0, "luifels/luifel_kantoor", "N")
	D(56 * 4.0, 52 * 4.0, 0.0, "deuren/draaideur", "N")
	places["plein"] = Vector2(55 * 4.0, 42 * 4.0)


# ------------------------------------------------------------------ south: Grote Markt, Grote Marktstraat, Spui

## The Grote Markt (x 10..22, z 61..70): a clinker square with cafes and terraces on its
## west and south sides; Chinatown south of it along the Wagenstraat (x 15-16).
func _grote_markt() -> void:
	_fill(10, 61, 22, 70, "plein/plein_klinkers")
	for c in [Vector2i(15, 65), Vector2i(16, 65), Vector2i(15, 66), Vector2i(16, 66)]:
		_g(c.x, c.y, "plein/plein_dambord")
	Pr(16 * 4.0, 66 * 4.0, "standbeelden/standbeeld_persoon", "S")
	_shops(Vector2i(9, 61), Vector2i(0, 1), 10, "E", 3, HORECA)
	_shops(Vector2i(22, 63), Vector2i(0, 1), 6, "W", 5, HORECA)
	var cafes := {"front": "N", "gf": ["bg_cafe", "bg_restaurant", "bg_bar", "bg_snackbar"], "gf_side": "bg_raam",
		"gf_corner": "bg_cafe_hoek", "upper": ["verd_raam", "verd_balkon", "verd_erker"], "roof": "sloped", "roof_extra": ["dak_schuin_dakkapel"]}
	block(10, 71, 5, 2, "jaren30", 3, cafes)
	block(17, 71, 6, 2, "jaren30", 3, cafes)
	for x in range(10, 23):
		if x == 15 or x == 16:
			continue
		D(x * 4 + 2.0, 71 * 4.0, 2.5, ["zonwering/markies", "luifels/luifel_rood", "zonwering/knikarmscherm_streep", "luifels/luifel_groen"][x % 4], "N")
		if x % 2 == 0:
			Pr(x * 4 + 2.0, 70 * 4 + 1.0, ["terras/terras_set_parasol", "terras/terras_set_parasol_groen", "terras/tafel_rond_stoelen"][(x / 2) % 3], "N")
			Pr(x * 4 + 2.0, 69 * 4 + 1.0, "terras/terras_scherm", "N")
	for z in range(62, 70, 2):
		Pr(10 * 4 + 2.0, z * 4 + 2.0, ["terras/statafel", "terras/parasol_groot", "terras/bistrostoel"][(z / 2) % 3], "E")
	# terraces in front of the cafes on the west and the east side
	for z in range(61, 69, 2):
		Pr(11 * 4 + 2.0, z * 4 + 2.0, ["terras/terras_set_parasol", "terras/terras_set_parasol_groen", "terras/tafel_vierkant_stoelen"][(z / 2) % 3], "E")
		Pr(12 * 4 + 2.0, z * 4 + 2.0, "terras/terras_set", "E")
	for z in [63, 65, 68]:
		Pr(20 * 4 + 2.0, z * 4 + 2.0, ["terras/terras_set_parasol_groen", "terras/tafel_rond_stoelen", "terras/terras_set_parasol"][z % 3], "W")
		Pr(19 * 4 + 2.0, z * 4 + 2.0, "terras/terras_set", "W")
	Pr(19 * 4.0, 61 * 4 + 2.0, "straat/kiosk")
	Pr(13 * 4.0, 63 * 4.0, "verlichting/lantaarn_gietijzer")
	Pr(20 * 4.0, 67 * 4.0, "verlichting/lantaarn_gietijzer")
	Pr(22 * 4 + 2.0, 61 * 4 + 2.0, "straat/vlaggenmast_denhaag")
	D(12 * 4.0, 71 * 4.0, 5.0, "tekst/tekst_cafe", "N")
	# Chinatown: the Wagenstraat with restaurants and red awnings
	_kerb_path(15, 84, "S")
	_kerb_path(16, 84, "S")
	for z in range(71, 84):
		_g(15, z, "plein/plein_klinkers")
		_g(16, z, "plein/plein_klinkers")
		if z % 3 == 0:
			Pr(15 * 4 + 4.0, z * 4 + 2.0, "verlichting/lantaarn_klassiek_dubbel")
	var asian := ["bg_restaurant", "bg_snackbar", "bg_restaurant", "bg_supermarkt", "bg_restaurant", "bg_bar", "bg_telefoon"]
	var red := ["luifels/luifel_rood", "luifels/luifel_effen_rood", "luifels/luifel_rood_smal", "luifels/luifel_effen_rood_smal"]
	_shops(Vector2i(14, 73), Vector2i(0, 1), 11, "E", 7, asian, red)
	_shops(Vector2i(17, 73), Vector2i(0, 1), 11, "W", 9, asian, red)
	for z in range(74, 84, 3):
		D(15 * 4.0, z * 4 + 2.0, 4.5, "gevel/uithangbord", "E")
		D(17 * 4.0, z * 4 + 1.0, 4.5, "gevel/uithangbord", "W")
	ring(8, 73, 5, 11, "klassiek_donker", 3, {"gf": ["bg_raam", "bg_deur"], "upper": ["verd_raam", "verd_luiken"], "back": ["verd_raam"],
		"roof_extra": ["dak_schuin_dakkapel"]})
	block(19, 73, 4, 11, "jaren30", 4, {"front": "E", "gf": ["bg_portiek", "bg_raam", "bg_winkel"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_balkon", "verd_erker"], "roof": "flat"})
	places["grote_markt"] = Vector2(16 * 4.0, 66 * 4.0)
	places["chinatown"] = Vector2(16 * 4.0, 78 * 4.0)


## Along the Grote Marktstraat (tram on clinkers): the Bijenkorf and modern stores; the
## Passage, a glass-roofed arcade with shops on both sides; homes and offices behind.
func _grote_marktstraat() -> void:
	block(27, 61, 8, 6, "jaren30", 5, {"front": "N", "gf": ["bg_kleding", "bg_winkel", "bg_kleding", "bg_portiek"], "gf_side": "bg_winkel",
		"gf_corner": "bg_winkel_hoek", "upper": ["verd_raam", "verd_trappenhuis", "verd_raam", "verd_erker"], "upper_corner": "verd_raam_hoek",
		"roof": "flat"})
	D(30 * 4.0, 61 * 4.0, 12.0, "gevel/vlag", "N")
	for x in range(28, 35, 2):
		D(x * 4.0, 61 * 4.0, 2.5, "luifels/luifel_effen_groen", "N")
	block(37, 61, 10, 5, "modern_donker", 4, {"front": "N", "gf": ["bg_kleding", "bg_winkel", "bg_juwelier", "bg_telefoon"],
		"gf_side": "bg_winkel", "gf_corner": "bg_raam_hoek", "upper": ["verd_raam_breed", "verd_dicht", "verd_frans"],
		"upper_corner": "verd_raam_breed_hoek", "roof": "flat"})
	D(42 * 4.0, 61 * 4.0, 9.0, "tekst/lichtreclame_zwervr", "N")
	# the Passage: a glass hall over the arcade between two rows of shops
	_fill(35, 61, 36, 83, "plein/plein_tegels")
	_hall(35, 68, 2, 15, "hal_glas", Vector2i(35, 68))
	_shops(Vector2i(34, 68), Vector2i(0, 1), 15, "E", 11, SHOPS, AWNINGS, 2)
	_shops(Vector2i(37, 68), Vector2i(0, 1), 15, "W", 13, SHOPS, AWNINGS, 2)
	_kerb_path(35, 84, "S")
	_kerb_path(36, 84, "S")
	for z in [62, 65]:
		Pr(35 * 4 + 4.0, z * 4 + 2.0, "fietsen/fietsenrek_vol", "S")
	ring(27, 68, 6, 16, "klassiek_rood", 4, {"gf": ["bg_raam", "bg_deur", "bg_winkel_luifel"], "upper": ["verd_raam", "verd_drie_ramen", "verd_balkon"],
		"back": ["verd_raam"], "roof_extra": ["dak_schuin_dakraam", "dak_schuin_dakkapel"]})
	# the Spui (x 48): shops along its west side, in front of offices and flats
	_shops(Vector2i(46, 67), Vector2i(0, 1), 7, "E", 12, RETAIL)
	_shops(Vector2i(46, 76), Vector2i(0, 1), 8, "E", 14, RETAIL)
	places["spui_straat"] = Vector2(48 * 4.0, 72 * 4.0)
	block(40, 67, 5, 7, "kantoor_80", 5, {"front": "E", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_spiegelband", "verd_raam_groot"], "upper_corner": "verd_spiegelband_hoek", "roof": "flat"})
	block(40, 76, 5, 8, "jaren60", 4, {"front": "E", "gf": ["bg_deur", "bg_raam", "bg_erker"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_balkon"], "roof": "flat"})
	places["passage"] = Vector2(36 * 4.0, 66 * 4.0)


## Spuiplein with the Nieuwe Kerk, the white city hall (two slabs with the glass atrium
## between them) and the Amare theatre.
func _spui() -> void:
	_fill(51, 61, 61, 68, "plein/plein_tegels")
	_fill(55, 69, 55, 83, "plein/plein_tegels")
	_fill(51, 74, 54, 75, "natuur/gras")
	block(51, 69, 4, 5, "kerk_baksteen", 2, {"front": "N", "gf": ["bg_spitsraam"], "gf_side": "bg_spitsraam", "gf_corner": "bg_spitsraam_hoek",
		"upper": ["verd_spitsraam"], "upper_corner": "verd_spitsraam_hoek", "roof": "sloped"})
	tower(52, 68, "kerk_baksteen", ["toren_portaal", "toren_raam", "toren_galmgat", "toren_spits_onder", "toren_spits_boven"], "N")
	_trees([Vector2i(51, 75), Vector2i(54, 74)], ["bomen/linde"])
	# city hall: two white slabs of ten storeys, a glass hall between
	for s in [[56, "W"], [60, "E"]]:
		block(s[0], 69, 2, 15, "modern_wit", 10, {"front": s[1], "gf": ["bg_deur", "bg_raam"], "gf_side": "bg_raam", "gf_corner": "bg_raam_hoek",
			"upper": ["verd_raam_breed", "verd_raam", "verd_raam_breed"], "upper_corner": "verd_raam_breed_hoek", "roof": "flat"})
	_hall(58, 69, 2, 15, "hal_glas", Vector2i(58, 69))
	D(59 * 4.0, 69 * 4.0, 4.5, "tekst/tekst_raadhuis", "N")
	D(57 * 4.0, 69 * 4.0, 27.0, "gevel/vlag_denhaag", "N")
	# Amare
	block(51, 76, 4, 8, "museum_modern", 4, {"front": "W", "gf": ["bg_entree", "bg_dicht"], "gf_side": "bg_dicht",
		"gf_corner": "bg_entree_hoek", "upper": ["verd_lichtstrook", "verd_dicht"], "upper_corner": "verd_lichtstrook_hoek", "roof": "flat"})
	D(51 * 4.0, 79 * 4.0, 3.5, "tekst/tekst_theater", "W")
	D(51 * 4.0, 81 * 4.0, 8.0, "tekst/lichtreclame_theater", "W")
	# the square
	Pr(57 * 4.0, 64 * 4.0, "standbeelden/kunstwerk_modern", "S")
	Pr(60 * 4 + 2.0, 66 * 4 + 2.0, "straat/afvalcontainer_ondergronds")
	_trees([Vector2i(54, 62), Vector2i(61, 62), Vector2i(61, 66)], ["bomen/plataan"])
	for c in [Vector2i(53, 64), Vector2i(59, 63)]:
		Pr(c.x * 4 + 2.0, c.y * 4 + 2.0, "verlichting/lantaarn_modern")
	for x in [55, 58]:
		Pr(x * 4 + 2.0, 67 * 4 + 2.0, "straat/bank_beton", "S")
	Pr(61 * 4 + 2.0, 61 * 4 + 2.0, "fietsen/fietsenrek_vol", "E")
	places["spui"] = Vector2(57 * 4.0, 65 * 4.0)


# ------------------------------------------------------------------ east of the singel

## Haagse Bos on both sides of the street x 96 (z 1..16): wood, wood edge and heath. West
## part: a pond (bridges, a landing, a rowing boat), a cycle path, gravel and sand paths,
## a playground and picnic tables. East part: Paleis Huis ten Bosch with its dome, a
## forecourt and a flower parterre, reached by a gravel lane from the street.
func _haagse_bos() -> void:
	for x in range(72, XC - 1):
		if x >= X6 - 1 and x <= X6 + 2:
			continue
		for z in range(1, 17):
			var t := "natuur/bos"
			if z == 1 or z == 16 or x == 72 or x == X6 - 2 or x == X6 + 3 or x == XC - 2:
				t = "natuur/bosrand"
			elif (x + z * 3) % 11 == 0:
				t = "natuur/heide"
			_g(x, z, t, ["S", "E", "N", "W"][(x + z) % 4])
	var px := 77
	var pz := 4
	_pond(px, pz, px + 9, pz + 5)
	_g(px + 3, pz + 2, "brug/voetbrug_hout_boog", "E")
	_g(px + 6, pz + 3, "brug/voetbrug_hout_vlak", "S")
	_g(px + 2, pz + 5, "waterkant/aanlegplaats", "N")
	Pr((px + 5) * 4.0, (pz + 3) * 4.0, "water/roeiboot", "E")
	Pr((px + 7) * 4.0, (pz + 1) * 4 + 2.0, "water/steiger", "S")
	for z in range(1, 17):
		_g(88, z, "fietspad/fietspad_recht", "S")
	for x in range(72, X6 - 1):
		_g(x, 12, "natuur/pad_grind", "E")
		_g(x, 2, "natuur/zandpad", "E")
	_g(88, 12, "fietspad/fietspad_kruising", "S")
	_g(88, 2, "fietspad/fietspad_kruising", "S")
	_g(72, 12, "plein/plein_grind")
	_kerb_path(71, 12, "W")
	_kerb_path(X6 - 1, 12, "E")
	for z in range(13, 16):
		_g(80, z, "natuur/keienpad", "S")
	_fill(90, 13, 93, 15, "natuur/speeltuin_zand")
	var play := ["speeltuin/schommel", "speeltuin/glijbaan", "speeltuin/klimrek", "speeltuin/wipwap", "speeltuin/draaimolen", "speeltuin/speelhuisje"]
	for i in play.size():
		Pr((90 + (i % 3) * 1.3) * 4.0 + 2.0, (13 + (i / 3) * 2) * 4.0 + 2.0, play[i], "S")
	Pr(74 * 4 + 2.0, 14 * 4 + 2.0, "straat/picknicktafel")
	Pr(76 * 4 + 2.0, 14 * 4 + 2.0, "straat/picknicktafel")
	for z in range(2, 17, 4):
		Pr(88 * 4 - 0.5, z * 4 + 2.0, "verlichting/lantaarn_park", "E")
	# Huis ten Bosch: a palace with a dome over its middle, a gravel lane from the street
	var hx := 113
	_fill(hx - 2, 3, hx + 8, 11, "plein/plein_grind")
	block(hx, 4, 7, 4, "overheid", 2, {"front": "S", "gf": ["bg_raam", "bg_entree", "bg_raam"], "gf_side": "bg_raam",
		"gf_corner": "bg_raam_hoek", "upper": ["verd_raam_hoog"], "upper_corner": "verd_raam_hoog_hoek", "roof": "sloped",
		"roof_extra": ["dak_schuin_schoorsteen"]})
	B(hx + 3, 2, 5, "museum_klassiek/museum_klassiek_dak_koepel", "S")
	B(hx + 3, 2, 7, "overheid/overheid_top_fronton", "S")
	for x in [hx - 1, hx + 7]:
		for z in [9, 10]:
			_g(x, z, "natuur/bloemperk_tulpen")
	for x in range(hx + 1, hx + 6):
		_g(x, 10, "natuur/gras")
	Pr((hx + 3) * 4 + 2.0, 10 * 4 + 2.0, "straat/fontein")
	for x in range(hx - 2, hx + 9):
		Pr(x * 4 + 2.0, 11 * 4 + 3.5, "hekken/hek_ijzer_poort" if x == hx + 3 else "hekken/hek_ijzer", "S")
	for z in range(12, 17):
		_g(hx + 3, z, "natuur/pad_grind", "S")
	for x in range(X6 + 4, hx + 3):
		_g(x, 14, "natuur/pad_grind", "E")
	_g(hx + 3, 14, "plein/plein_grind")
	_kerb_path(X6 + 2, 14, "W")
	_g(X6 + 3, 14, "natuur/pad_grind", "E")
	D((hx + 3) * 4 + 2.0, 8 * 4.0, 6.5, "gevel/vlag_nl", "S")
	Pr((hx - 2) * 4 + 2.0, 12 * 4 + 2.0, "borden/bord_gesloten_verkeer", "S")
	# the trees of the wood
	for x in range(72, XC - 1):
		for z in range(1, 17):
			if _taken_by_path(x, z):
				continue
			if (x * 5 + z * 3) % 4 == 0:
				Pr(x * 4 + 1.0 + (z % 3), z * 4 + 1.0 + (x % 3), ["bomen/eik", "bomen/kastanje", "bomen/berk", "bomen/linde", "bomen/den", "bomen/populier"][(x + z * 2) % 6])
			elif (x + z) % 7 == 0:
				Pr(x * 4 + 2.0, z * 4 + 2.0, ["planten/varen", "planten/braamstruik", "planten/struikgewas", "planten/graspol"][(x + z) % 4])
	places["haagse_bos"] = Vector2(82 * 4.0, 7 * 4.0)
	places["huis_ten_bosch"] = Vector2((hx + 3) * 4.0, 9 * 4.0)


## True if (x, z) lies on a path, the pond or the playground of the Haagse Bos.
func _taken_by_path(x: int, z: int) -> bool:
	var id := ground.get_cell_item(Vector3i(x, 0, z))
	if id < 0:
		return true
	var nm := ground.mesh_library.get_item_name(id)
	return not (nm == "natuur/bos" or nm == "natuur/bosrand" or nm == "natuur/heide")


## The Ministerie van Financien on the corner of the Malieveld by the end of the A12, the
## Malieveld (x 81..94): a big open lawn with a gravel path round it, lanterns and flags;
## the Koekamp pond with trees in the south-west corner.
func _malieveld() -> void:
	_fill(72, 32, 80, 47, "natuur/gras")
	_fill(72, 32, 80, 33, "plein/plein_tegels")
	block(72, 34, 9, 7, "kantoor_beton", 8, {"front": "N", "gf": ["bg_entree", "bg_kolonnade", "bg_glas"], "gf_side": "bg_glas",
		"gf_corner": "bg_kolonnade_hoek", "upper": ["verd_band", "verd_band", "verd_raam_groot"], "upper_corner": "verd_band_hoek", "roof": "flat"})
	B(75, 8, 36, "kantoor_beton/kantoor_beton_dak_installatie", "S")
	D(76 * 4 + 2.0, 34 * 4.0, 0.0, "luifels/luifel_kantoor", "N")
	D(76 * 4 + 2.0, 34 * 4.0, 0.0, "deuren/draaideur", "N")
	for x in [74, 76, 78]:
		Pr(x * 4 + 2.0, 33 * 4 + 1.0, "straat/vlaggenmast_nl")
	for x in range(73, 80, 2):
		Pr(x * 4 + 2.0, 32 * 4 + 2.0, "planten/plantenbak_beton")
	_trees([Vector2i(73, 43), Vector2i(77, 42), Vector2i(80, 45), Vector2i(74, 46)], ["bomen/eik", "bomen/kastanje", "bomen/linde"])
	for x in range(81, 95):
		for z in range(32, 57):
			var edge := x == 81 or x == 94 or z == 32 or z == 56
			_g(x, z, "natuur/pad_grind" if edge else "natuur/gras", "E")
	_pond(73, 48, 79, 55)
	_trees([Vector2i(80, 49), Vector2i(80, 53), Vector2i(76, 47)], ["bomen/treurwilg", "bomen/eik"])
	for x in range(82, 94, 3):
		Pr(x * 4 + 2.0, 32 * 4 + 1.0, "verlichting/lantaarn_park", "S")
		Pr(x * 4 + 2.0, 56 * 4 + 3.0, "verlichting/lantaarn_park", "N")
	for x in [85, 90]:
		for z in [36, 50]:
			_g(x, z, "natuur/bloemperk_tulpen")
	for x in [86, 87, 88]:
		Pr(x * 4 + 2.0, 43 * 4.0, ["straat/vlaggenmast_denhaag", "straat/vlaggenmast_nl", "straat/vlaggenmast_eu"][x - 86])
	Pr(91 * 4.0, 52 * 4.0, "straat/bouwkeet", "W")
	_kerb_path(X6 - 1, 44, "E")
	places["malieveld"] = Vector2(87 * 4.0, 44 * 4.0)
	places["ministerie_van_financien"] = Vector2(76 * 4.0, 34 * 4.0)


## The Bezuidenhout (x 98..127, z 31..57) in four blocks round a crossing: closed 1930s
## blocks of flats with courtyard gardens, a school with a playground, a modern church
## and a block of 1960s flats.
func _bezuidenhout() -> void:
	var flats := {"gf": ["bg_portiek", "bg_raam", "bg_erker"], "upper": ["verd_raam", "verd_balkon", "verd_erker"], "back": ["verd_raam", "verd_balkon"],
		"roof_extra": ["dak_schuin_dakkapel", "dak_schuin_schoorsteen"]}
	ring(99, 32, 12, 10, "jaren30", 3, flats)
	ring(115, 32, 12, 10, "jaren30", 4, flats)
	for o in [Vector2i(101, 34), Vector2i(117, 34)]:
		_fill(o.x, o.y, o.x + 7, o.y + 5, "natuur/gras")
		for i in 4:
			Pr((o.x + 1 + i * 2) * 4 + 2.0, (o.y + 2) * 4 + 2.0, ["bomen/fruitboom", "bomen/bloesemboom", "bomen/berk", "speeltuin/schommel"][i])
		Pr((o.x + 3) * 4.0, (o.y + 4) * 4.0, "hekken/schutting_hout", "S")
	for x in range(100, 110, 3):
		D(x * 4 + 2.0, 32 * 4.0, 3.5, "ramen/bloembak", "N")
	# school and playground, a modern church
	block(99, 46, 7, 4, "school", 2, {"front": "N", "gf": ["bg_entree", "bg_raam"], "gf_side": "bg_raam", "gf_corner": "bg_raam_hoek",
		"upper": ["verd_raam"], "upper_corner": "verd_raam_hoek", "roof": "flat"})
	D(102 * 4 + 2.0, 46 * 4.0, 4.0, "tekst/tekst_school", "N")
	_fill(99, 51, 105, 56, "natuur/speeltuin_rubber")
	var play := ["speeltuin/schommel", "speeltuin/glijbaan", "speeltuin/wipwap", "speeltuin/klimrek", "speeltuin/basketbalpaal", "speeltuin/voetbaldoel"]
	for i in play.size():
		Pr((99 + (i % 3) * 2) * 4.0 + 2.0, (51 + (i / 3) * 3) * 4.0 + 2.0, play[i], "S")
	for x in range(99, 106):
		Pr(x * 4 + 2.0, 50 * 4 + 3.5, "hekken/schoolhek", "S")
	block(107, 47, 4, 6, "kerk_modern", 2, {"front": "W", "gf": ["bg_entree", "bg_dicht"], "gf_side": "bg_dicht", "gf_corner": "bg_entree_hoek",
		"upper": ["verd_spleet", "verd_kruis"], "upper_corner": "verd_spleet_hoek", "roof": "flat"})
	tower(107, 54, "kerk_modern", ["toren_beton", "toren_beton", "toren_beton", "toren_beton_klok"], "W")
	_fill(107, 55, 110, 56, "plein/plein_tegels")
	# 1960s flats with parking in front
	block(115, 47, 12, 3, "jaren60", 5, {"front": "S", "gf": ["bg_deur", "bg_berging", "bg_raam"], "gf_side": "bg_raam",
		"gf_corner": "bg_raam_hoek", "upper": ["verd_galerij_deur", "verd_galerij_raam"], "upper_corner": "verd_galerij_raam_hoek", "roof": "flat"})
	for x in range(115, 127):
		_g(x, 52, "parkeren/parkeerplaats_rijbaan", "E")
		_g(x, 53, "parkeren/parkeervak_haaks" if x % 5 else "parkeren/parkeervak_laadpaal", "N")
	_kerb_path(XB + 2, 52, "W")
	_trees([Vector2i(116, 55), Vector2i(120, 55), Vector2i(124, 55), Vector2i(126, 51)], ["bomen/plataan", "bomen/linde"])
	Pr(118 * 4.0, 51 * 4 + 2.0, "straat/glasbak")
	Pr(119 * 4.0, 51 * 4 + 2.0, "straat/afvalcontainer_ondergronds")
	places["bezuidenhout"] = Vector2(112 * 4.0, 44 * 4.0)


## Centraal Station without its tracks: the glass station hall (x 74..92, z 69..77)
## behind a square with bicycle parking, taxis and the tram stop; behind it the towers
## (Hoftoren, the twin ministry towers with a footbridge, De Kroon) and a car park.
func _centraal() -> void:
	_fill(72, 61, 94, 68, "plein/plein_tegels")
	_hall(74, 69, 19, 9, "hal_glas", Vector2i(83, 69), 83)
	block(80, 70, 7, 3, "kantoor_glas", 3, {"front": "N", "y0": 1, "gf": ["verd_vliesgevel"], "gf_side": "verd_vliesgevel",
		"gf_corner": "verd_vliesgevel_hoek", "upper": ["verd_vliesgevel"], "upper_corner": "verd_vliesgevel_hoek", "roof": "flat"})
	D(83 * 4 + 2.0, 69 * 4.0, 8.0, "tekst/tekst_station", "N")
	D(83 * 4 + 2.0, 69 * 4.0, 0.0, "luifels/luifel_glas", "N")
	D(77 * 4 + 2.0, 69 * 4.0, 0.0, "luifels/luifel_glas", "N")
	D(89 * 4 + 2.0, 69 * 4.0, 0.0, "luifels/luifel_glas", "N")
	_fill(72, 69, 73, 90, "plein/plein_tegels")
	_fill(93, 69, 94, 90, "plein/plein_tegels")
	# the square
	for x in range(73, 80):
		Pr(x * 4 + 2.0, 66 * 4 + 2.0, "fietsen/fietsenrek_vol", "S")
		Pr(x * 4 + 2.0, 67 * 4 + 2.0, "fietsen/fietsnietje", "S")
	for x in range(87, 94):
		Pr(x * 4 + 2.0, 67 * 4 + 2.0, "fietsen/fietsenrek_vol", "S")
	for x in range(80, 87):
		_g(x, 64, "parkeren/parkeerstrook_langs", "E")
	Pr(80 * 4 + 1.0, 64 * 4 + 1.0, "borden/bord_parkeren", "E")
	Pr(84 * 4.0, 62 * 4 + 2.0, "standbeelden/kunstwerk_modern", "S")
	Pr(90 * 4.0, 63 * 4.0, "straat/kiosk")
	Pr(76 * 4.0, 63 * 4.0, "ov/reclamezuil")
	for x in [75, 81, 87, 93]:
		Pr(x * 4 + 2.0, 65 * 4 + 2.0, "verlichting/lantaarn_modern")
	# towers behind the station
	_fill(74, 78, 92, 90, "plein/plein_tegels")
	block(74, 80, 3, 3, "kantoor_glas", 22, {"front": "N", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_vliesgevel"], "upper_corner": "verd_vliesgevel_hoek", "roof": "flat"})
	B(75, 22, 81, "kantoor_glas/kantoor_glas_dak_installatie", "S")
	for tx in [79, 85]:
		block(tx, 80, 4, 4, "kantoor_beton", 15, {"front": "N", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
			"upper": ["verd_band", "verd_raam_groot"], "upper_corner": "verd_band_hoek", "roof": "flat"})
	for x in [83, 84]:
		G(x, 81, "brug/loopbrug_overdekt", "E", 15)
	block(90, 80, 3, 4, "luxe_appartement", 11, {"front": "N", "gf": ["bg_glas", "bg_lobby", "bg_glas"], "gf_side": "bg_glas",
		"gf_corner": "bg_glas_hoek", "upper": ["verd_terras", "verd_glas"], "upper_corner": "verd_terras_hoek", "roof": "none"})
	for x in range(90, 93):
		for z in range(80, 84):
			var e := _edge(_sides(x, z, 90, 80, 3, 4))
			B(x, 11, z, "luxe_appartement/luxe_appartement_penthouse_" + e[0], e[1])
	B(91, 12, 81, "luxe_appartement/luxe_appartement_dak_terras", "N")
	_parking_decks(75, 86, 8, 4, 3)
	_trees([Vector2i(78, 79), Vector2i(84, 85), Vector2i(89, 79), Vector2i(93, 86)], ["bomen/plataan", "bomen/linde"])
	for x in [76, 88]:
		Pr(x * 4 + 2.0, 79 * 4 + 2.0, "straat/bank_beton", "S")
	for x in [74, 79]:
		D(x * 4 + 6.0, 80 * 4.0, 0.0, "luifels/luifel_kantoor", "N")
		D(x * 4 + 6.0, 80 * 4.0, 0.0, "deuren/draaideur", "N")
	places["centraal"] = Vector2(83 * 4.0, 64 * 4.0)


## The Beatrixkwartier (x 98..127, z 60..91): office towers, an apartment tower and the
## Haagse Hogeschool on a paved square with trees, and a car park.
func _beatrixkwartier() -> void:
	_fill(99, 61, 126, 90, "plein/plein_tegels")
	var glass := {"front": "N", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek", "roof": "flat"}
	var t1 := glass.duplicate()
	t1.merge({"upper": ["verd_vliesgevel", "verd_zonwering"], "upper_corner": "verd_vliesgevel_hoek"})
	block(100, 62, 5, 5, "kantoor_2000", 14, t1)
	B(102, 14, 64, "kantoor_2000/kantoor_2000_dak_installatie", "S")
	var t2 := glass.duplicate()
	t2.merge({"upper": ["verd_lamellen", "verd_raam_groot"], "upper_corner": "verd_lamellen_hoek"})
	block(108, 62, 6, 4, "kantoor_modern", 8, t2)
	var t3 := glass.duplicate()
	t3.merge({"upper": ["verd_balkon", "verd_loggia", "verd_glas"], "upper_corner": "verd_balkon_hoek"})
	block(118, 62, 4, 4, "appartement_modern", 17, t3)
	B(119, 17, 63, "appartement_modern/appartement_modern_dak_daktuin", "S")
	var t4 := glass.duplicate()
	t4.merge({"front": "S", "upper": ["verd_spiegelband", "verd_raam_groot"], "upper_corner": "verd_spiegelband_hoek"})
	block(100, 72, 8, 5, "kantoor_80", 6, t4)
	var t5 := glass.duplicate()
	t5.merge({"upper": ["verd_vliesgevel"], "upper_corner": "verd_vliesgevel_hoek"})
	block(111, 72, 4, 4, "kantoor_glas", 19, t5)
	block(119, 72, 6, 9, "hogeschool", 4, {"front": "W", "gf": ["bg_entree", "bg_glas", "bg_kolonnade"], "gf_side": "bg_glas",
		"gf_corner": "bg_kolonnade_hoek", "upper": ["verd_band", "verd_lamellen", "verd_raam_groot"], "upper_corner": "verd_lamellen_hoek", "roof": "flat"})
	D(119 * 4.0, 76 * 4.0, 7.0, "tekst/tekst_hogeschool", "W")
	_parking_decks(100, 82, 8, 6, 4)
	Pr(99 * 4 + 2.0, 84 * 4 + 2.0, "borden/bord_parkeren", "E")
	_kerb_path(X6 + 2, 84, "W")
	_trees([Vector2i(106, 68), Vector2i(110, 69), Vector2i(115, 68), Vector2i(116, 78), Vector2i(110, 82), Vector2i(114, 86), Vector2i(120, 86), Vector2i(125, 68)],
		["bomen/plataan", "bomen/linde", "bomen/jonge_boom"])
	Pr(113 * 4.0, 80 * 4.0, "standbeelden/kunstwerk_modern", "S")
	for x in [104, 112, 122]:
		Pr(x * 4 + 2.0, 69 * 4 + 2.0, "straat/bank_beton", "S")
		Pr(x * 4.0, 70 * 4 + 2.0, "verlichting/lantaarn_modern")
	for x in range(108, 114):
		Pr(x * 4 + 2.0, 67 * 4 + 2.0, "fietsen/fietsenrek_vol", "S")
	places["beatrixkwartier"] = Vector2(112 * 4.0, 74 * 4.0)


# ------------------------------------------------------------------ the A12 (Utrechtsebaan)

## Motorway profile across 9 rows (north verge to south verge): [tile, rotation].
const MW_FLAT := [["snelweg/snelweg_berm_vangrail", "E"], ["snelweg/snelweg_vluchtstrook", "E"], ["weg/weg_vlak", "E"],
	["snelweg/snelweg_rijstrook_links", "E"], ["snelweg/snelweg_middenberm_beton", "E"], ["snelweg/snelweg_rijstrook_links", "W"],
	["weg/weg_vlak", "W"], ["snelweg/snelweg_vluchtstrook", "W"], ["snelweg/snelweg_berm_vangrail", "W"]]
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
	for x in range(71, X_END + 1):
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
	for x in range(XC + 3, X_END + 1):
		_g(x, AZ - 1, "natuur/gras", "S")
	Pr((X6 - 1) * 4 + 1.0, (AZ - 1) * 4 + 2.0, "borden/bord_tunnel", "W")
	# lights, signs and fences of the flat part
	for x in range(A_FLAT, X_END + 1):
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
	Pr((X_END - 5) * 4.0, (AZ + 2) * 4 + 2.0, "borden/snelweg_portaal", "E")
	Pr((A_FLAT + 10) * 4.0, (AZ + 6) * 4 + 2.0, "borden/snelweg_portaal", "W")
	Pr((A_FLAT + 22) * 4.0, (AZ + 6) * 4 + 2.0, "borden/snelweg_portaal", "W")
	Pr((X_END - 1) * 4 + 2.0, (AZ - 1) * 4 + 2.0, "borden/bord_plaatsnaam_den_haag", "E")
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


## The deck over the covered A12 between the Juliana van Stolberglaan (x 96) and the Laan
## van Nieuw Oost-Indie (x 128), facing the Bezuidenhoutseweg (street z 29): the
## Malietoren on its plaza, a row of shops with Snackbar De Vrijheid and an office slab
## behind them, a ministry on a square with trees, and a row of trees along the wood.
func _over_a12() -> void:
	_fill(X6 + 4, AZ + 1, XC - 3, Z2 - 2, "plein/plein_tegels")
	# Malietoren: a dark glass tower with its entrance on the street side
	_fill(X6 + 4, AZ + 1, X6 + 8, Z2 - 2, "plein/plein_natuursteen")
	block(X6 + 4, AZ + 2, 4, 5, "kantoor_2000", 24, {"front": "S", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas",
		"gf_corner": "bg_glas_hoek", "upper": ["verd_vliesgevel", "verd_zonwering"], "upper_corner": "verd_vliesgevel_hoek", "roof": "flat"})
	B(X6 + 5, 24, AZ + 4, "kantoor_2000/kantoor_2000_dak_installatie", "S")
	D((X6 + 6) * 4.0, (AZ + 7) * 4.0, 0.0, "luifels/luifel_kantoor", "S")
	D((X6 + 6) * 4.0, (AZ + 7) * 4.0, 0.0, "deuren/draaideur", "S")
	for x in [X6 + 4, X6 + 6, X6 + 8]:
		Pr(x * 4 + 2.0, (Z2 - 2) * 4 + 2.0, "straat/vlaggenmast_nl" if x != X6 + 6 else "straat/vlaggenmast_eu")
	Pr((X6 + 8) * 4 + 2.0, (AZ + 3) * 4 + 2.0, "standbeelden/kunstwerk_modern", "W")
	# shops on the street, Snackbar De Vrijheid third from the west; an office slab behind
	var sx := X6 + 10
	_shops(Vector2i(sx, Z2 - 2), Vector2i(1, 0), 7, "S", 0,
		["bg_cafe", "bg_kapper", "bg_snackbar", "bg_supermarkt", "bg_bakker", "bg_telefoon", "bg_drogist"])
	var snack := Vector2i(sx + 2, Z2 - 2)
	D(snack.x * 4 + 1.0, snack.y * 4 + 4.0, 3.0, "gevel/uithangbord", "S")
	D(snack.x * 4 + 3.0, snack.y * 4 + 4.0, 5.5, "gevel/reclamebord", "S")
	Pr(snack.x * 4 + 1.0, (Z2 - 1) * 4 + 1.5, "terras/statafel", "S")
	Pr(snack.x * 4 + 3.0, (Z2 - 1) * 4 + 1.5, "terras/bistrostoel", "S")
	Pr((snack.x + 1) * 4 + 2.0, (Z2 - 1) * 4 + 1.5, "straat/prullenbak_rond")
	Pr((sx - 1) * 4 + 2.0, (Z2 - 1) * 4 + 1.5, "fietsen/fietsenrek_vol", "S")
	places["snackbar_de_vrijheid"] = Vector2(snack) * 4.0 + Vector2(2.0, 4.0)
	block(sx, AZ + 1, 7, 5, "kantoor_80", 6, {"front": "N", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_spiegelband", "verd_raam_groot"], "upper_corner": "verd_spiegelband_hoek", "roof": "flat"})
	# a ministry on a square with trees, benches and bicycle racks
	var mx := sx + 9
	block(mx, AZ + 1, XC - 3 - mx, 4, "kantoor_modern", 8, {"front": "S", "gf": ["bg_entree", "bg_glas", "bg_kolonnade"], "gf_side": "bg_glas",
		"gf_corner": "bg_glas_hoek", "upper": ["verd_lamellen", "verd_raam_groot"], "upper_corner": "verd_lamellen_hoek", "roof": "flat"})
	D((mx + 4) * 4 + 2.0, (AZ + 5) * 4.0, 0.0, "luifels/luifel_kantoor", "S")
	D((mx + 4) * 4 + 2.0, (AZ + 5) * 4.0, 0.0, "deuren/draaideur", "S")
	D((mx + 2) * 4 + 2.0, (AZ + 5) * 4.0, 9.0, "gevel/vlag_nl", "S")
	_trees([Vector2i(mx, Z2 - 3), Vector2i(mx + 3, Z2 - 2), Vector2i(mx + 6, Z2 - 3), Vector2i(mx + 9, Z2 - 2)], ["bomen/plataan", "bomen/linde"])
	for x in [mx + 1, mx + 5, mx + 8]:
		Pr(x * 4 + 2.0, (Z2 - 3) * 4 + 2.0, "straat/bank_beton", "S")
	Pr((mx + 4) * 4.0, (Z2 - 2) * 4 + 2.0, "verlichting/lantaarn_modern")
	Pr((sx + 7) * 4 + 2.0, (AZ + 3) * 4 + 2.0, "fietsen/fietsenrek_vol", "E")
	places["malietoren"] = Vector2((X6 + 6) * 4.0, (Z2 - 2) * 4.0)
	places["over_de_a12"] = Vector2((mx + 4) * 4.0, (Z2 - 3) * 4.0)


## Offices along the Prins Clauslaan north of the A12 (x 130..175, z 0..17): glass and
## concrete towers on a paved square, a car park, a pond with willows.
func _prins_clauslaan() -> void:
	var x0 := XC + 3
	_fill(x0, 1, X_END - 1, 16, "plein/plein_tegels")
	var glass := {"front": "S", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek", "roof": "flat"}
	var t1 := glass.duplicate()
	t1.merge({"upper": ["verd_vliesgevel"], "upper_corner": "verd_vliesgevel_hoek"})
	block(x0 + 1, 3, 5, 5, "kantoor_glas", 16, t1)
	B(x0 + 2, 16, 5, "kantoor_glas/kantoor_glas_dak_installatie", "S")
	var t2 := glass.duplicate()
	t2.merge({"upper": ["verd_band", "verd_raam_groot"], "upper_corner": "verd_band_hoek"})
	block(x0 + 9, 2, 10, 4, "kantoor_beton", 7, t2)
	_parking_decks(x0 + 9, 9, 10, 5, 3)
	Pr((x0 + 8) * 4 + 2.0, 10 * 4 + 2.0, "borden/bord_parkeren", "E")
	var t3 := glass.duplicate()
	t3.merge({"upper": ["verd_vliesgevel", "verd_zonwering"], "upper_corner": "verd_vliesgevel_hoek"})
	block(x0 + 22, 3, 5, 6, "kantoor_2000", 12, t3)
	_pond(x0 + 29, 2, x0 + 38, 8)
	_trees([Vector2i(x0 + 28, 10), Vector2i(x0 + 32, 10), Vector2i(x0 + 36, 10), Vector2i(x0 + 40, 9)], ["bomen/treurwilg", "bomen/berk"])
	var t4 := glass.duplicate()
	t4.merge({"front": "N", "upper": ["verd_spiegelband", "verd_raam_groot"], "upper_corner": "verd_spiegelband_hoek"})
	block(x0 + 22, 11, 14, 4, "kantoor_80", 5, t4)
	for x in range(x0, X_END - 1, 4):
		Pr(x * 4 + 2.0, 16 * 4 + 2.0, "bomen/jonge_boom")
	for x in [x0 + 3, x0 + 24]:
		Pr(x * 4 + 2.0, 9 * 4 + 2.0, "straat/bank_beton", "S")
		Pr(x * 4.0, 10 * 4 + 2.0, "verlichting/lantaarn_modern")
	Pr((x0 + 3) * 4 + 2.0, 12 * 4 + 2.0, "standbeelden/kunstwerk_modern", "S")
	_kerb_path(XC + 2, 9, "W")
	places["prins_clauslaan"] = Vector2((x0 + 12) * 4.0, 8 * 4.0)


## The Theresiastraat (street z 43 east of x 128): a shopping street with shops on both
## sides, 1930s blocks of flats round courtyard gardens behind them, and on its south
## side east of the street x 152 a church on a little square.
func _theresiastraat() -> void:
	var flats := {"gf": ["bg_portiek", "bg_raam", "bg_erker"], "upper": ["verd_raam", "verd_balkon", "verd_erker"], "back": ["verd_raam", "verd_balkon"],
		"roof_extra": ["dak_schuin_dakkapel", "dak_schuin_schoorsteen"]}
	var west := XC + 3
	var east := XD + 3
	for i in 2:
		var x0: int = [west, east][i]
		_shops(Vector2i(x0, ZB - 2), Vector2i(1, 0), 20, "S", 3 + i * 5)
		_shops(Vector2i(x0, ZB + 3), Vector2i(1, 0), 20, "N", 8 + i * 5)
		ring(x0, 32, 20, 8, "jaren30", 3 + i, flats)
		_fill(x0 + 2, 34, x0 + 17, 37, "natuur/gras")
		for k in 5:
			Pr((x0 + 3 + k * 3) * 4 + 2.0, 35 * 4 + 2.0, ["bomen/fruitboom", "bomen/bloesemboom", "speeltuin/schommel", "bomen/berk", "speeltuin/wipwap"][k])
		# bicycle racks and bins on the pavements of the shopping street
		for x in range(x0 + 2, x0 + 20, 6):
			Pr(x * 4 + 2.0, (ZB - 1) * 4 + 1.0, "fietsen/fietsenrek_vol", "S")
			Pr(x * 4 + 2.0, (ZB + 2) * 4 + 3.0, "fietsen/fietsnietje", "N")
		Pr((x0 + 9) * 4 + 2.0, (ZB + 2) * 4 + 3.0, "straat/prullenbak_paal")
	# south of the shops: flats on the west side, a church on a square on the east side
	ring(west, 49, 20, 8, "jaren30", 4, flats)
	_fill(west + 2, 51, west + 17, 54, "natuur/gras")
	_fill(east, 49, east + 11, 56, "plein/plein_keien")
	block(east + 2, 50, 8, 4, "kerk_baksteen", 3, {"front": "W", "gf": ["bg_portaal", "bg_spitsraam"], "gf_side": "bg_spitsraam",
		"gf_corner": "bg_spitsraam_hoek", "upper": ["verd_spitsraam", "verd_steunbeer"], "upper_corner": "verd_spitsraam_hoek", "roof": "gable"})
	tower(east + 1, 51, "kerk_baksteen", ["toren_portaal", "toren_raam", "toren_galmgat", "toren_klok", "toren_spits_onder", "toren_spits_boven"], "W")
	D((east + 1) * 4.0, 52 * 4.0, 3.0, "tekst/tekst_kerk", "W")
	_trees([Vector2i(east, 49), Vector2i(east, 55), Vector2i(east + 6, 55), Vector2i(east + 11, 49)], ["bomen/linde"])
	Pr((east + 4) * 4 + 2.0, 55 * 4 + 2.0, "straat/bank_hout", "N")
	ring(east + 13, 49, 7, 8, "klassiek_rood", 3, {"gf": ["bg_raam", "bg_deur"], "upper": ["verd_raam", "verd_luiken"], "back": ["verd_raam"],
		"roof_extra": ["dak_schuin_dakkapel"]})
	places["theresiastraat"] = Vector2((XD + 2) * 4.0, (ZB + 1) * 4.0)


## Bezuidenhout-Oost south of the tram (x 130..175, z 60..91): two 1960s gallery slabs
## with parking and a closed block behind them west of the street x 152; a park with a
## pond and a playground, a block of flats and an apartment tower east of it.
func _bezuidenhout_oost() -> void:
	var west := XC + 3
	var east := XD + 3
	var slab := {"front": "S", "gf": ["bg_deur", "bg_berging", "bg_raam"], "gf_side": "bg_raam",
		"gf_corner": "bg_raam_hoek", "upper": ["verd_galerij_deur", "verd_galerij_raam"], "upper_corner": "verd_galerij_raam_hoek", "roof": "flat"}
	for z in [61, 70]:
		block(west + 1, z, 18, 3, "jaren60", 5, slab)
		for x in range(west, west + 20):
			_g(x, z + 4, "parkeren/parkeerplaats_rijbaan", "E")
			_g(x, z + 5, "parkeren/parkeervak_haaks" if x % 5 else "parkeren/parkeervak_laadpaal", "N")
		_kerb_path(XC + 2, z + 4, "W")
	_fill(west, 76, west + 19, 78, "natuur/gras")
	_trees([Vector2i(west + 2, 77), Vector2i(west + 7, 76), Vector2i(west + 12, 77), Vector2i(west + 17, 76)], ["bomen/plataan", "bomen/linde"])
	Pr((west + 9) * 4.0, 77 * 4.0, "straat/glasbak")
	ring(west, 79, 20, 11, "klassiek_donker", 4, {"gf": ["bg_raam", "bg_deur", "bg_winkel_luifel"], "upper": ["verd_raam", "verd_drie_ramen"],
		"back": ["verd_raam"], "roof_extra": ["dak_schuin_schoorsteen", "dak_schuin_dakkapel"]})
	# the park
	_fill(east, 61, X_END - 1, 76, "natuur/gras")
	_pond(east + 2, 63, east + 11, 70)
	for x in range(east, X_END):
		_g(x, 72, "natuur/pad_grind", "E")
	for z in range(61, 72):
		_g(east + 14, z, "natuur/pad_grind", "S")
	_g(east + 14, 72, "plein/plein_grind")
	_kerb_path(XD + 2, 72, "W")
	_fill(east + 16, 63, east + 19, 66, "natuur/speeltuin_zand")
	var play := ["speeltuin/glijbaan", "speeltuin/schommel", "speeltuin/zandbak", "speeltuin/klimrek"]
	for i in play.size():
		Pr((east + 16 + (i % 2) * 2) * 4.0 + 2.0, (63 + (i / 2) * 2) * 4.0 + 2.0, play[i], "S")
	_trees([Vector2i(east, 62), Vector2i(east + 13, 62), Vector2i(east + 12, 74), Vector2i(east + 4, 75), Vector2i(east + 18, 75), Vector2i(east + 19, 69)],
		["bomen/treurwilg", "bomen/eik", "bomen/kastanje", "bomen/linde"])
	for x in [east + 5, east + 10]:
		Pr(x * 4 + 2.0, 71 * 4 + 2.0, "straat/bank_hout", "S")
	Pr((east + 14) * 4 + 2.0, 73 * 4 + 2.0, "verlichting/lantaarn_park")
	# flats and an apartment tower
	ring(east, 79, 10, 11, "jaren30", 4, {"gf": ["bg_portiek", "bg_raam"], "upper": ["verd_raam", "verd_balkon"], "back": ["verd_raam"],
		"roof_extra": ["dak_schuin_dakkapel"]})
	block(east + 13, 79, 4, 4, "appartement_modern", 13, {"front": "W", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_balkon", "verd_loggia", "verd_glas"], "upper_corner": "verd_balkon_hoek", "roof": "flat"})
	B(east + 14, 13, 80, "appartement_modern/appartement_modern_dak_daktuin", "S")
	_fill(east + 12, 84, X_END - 1, 89, "plein/plein_tegels")
	_trees([Vector2i(east + 13, 86), Vector2i(east + 17, 87), Vector2i(east + 19, 85)], ["bomen/jonge_boom", "bomen/plataan"])
	places["bezuidenhout_oost"] = Vector2((east + 6) * 4.0, 72 * 4.0)


# ------------------------------------------------------------------ trams

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
	var stops := [[Vector2i(26, 41), Vector2i(0, 1), 3, "W", "buitenhof"], [Vector2i(23, 47), Vector2i(0, 1), 3, "E", ""],
		[Vector2i(51, Z2 - 1), Vector2i(1, 0), 3, "S", "korte_voorhout"], [Vector2i(56, Z2 + 2), Vector2i(1, 0), 3, "N", ""],
		[Vector2i(80, Z2 + 2), Vector2i(1, 0), 3, "N", "tram_malieveld"], [Vector2i(84, Z2 - 1), Vector2i(1, 0), 3, "S", ""],
		[Vector2i(38, Z3 - 1), Vector2i(1, 0), 3, "S", "tram_grote_marktstraat"], [Vector2i(42, Z3 + 2), Vector2i(1, 0), 3, "N", ""],
		[Vector2i(52, Z3 - 1), Vector2i(1, 0), 3, "S", "tram_spui"], [Vector2i(51, Z3 + 2), Vector2i(1, 0), 3, "N", ""],
		[Vector2i(77, Z3 + 2), Vector2i(1, 0), 6, "N", "tram_centraal"], [Vector2i(86, Z3 - 1), Vector2i(1, 0), 3, "S", ""]]
	var stop_cells := {}
	for st in stops:
		for i in st[2]:
			var c: Vector2i = st[0] + st[1] * i
			_g(c.x, c.y, "tram/tram_halte_perron", st[3])
			stop_cells[c] = true
		var mid: Vector2i = st[0] + st[1]
		Pr(mid.x * 4 + 2.0, mid.y * 4 + 2.0, "ov/abri", st[3], 0.5)
		var last: Vector2i = st[0] + st[1] * (st[2] - 1)
		Pr(last.x * 4 + 2.0, last.y * 4 + 2.0, "ov/tramhalte_paal", st[3], 0.5)
		if st[4] != "":
			places[st[4]] = Vector2(mid) * 4.0 + Vector2(2.0, 2.0)
	# overhead line masts on the pavement, away from the stops, bridges and crossings
	for z in range(Z2 + 4, Z3 - 2, 4):
		var c := Vector2i(X2 - 1, z)
		if not stop_cells.has(c) and not (z >= 43 and z <= 46):
			Pr(c.x * 4 + 2.0, c.y * 4 + 2.0, "ov/tram_bovenleiding_mast", "E")
	for zr in [Z2, Z3]:
		for x in range(X2 + 4, X_END, 5):
			var c := Vector2i(x, zr + 2)
			if stop_cells.has(c) or (x >= X3 - 1 and x <= X3 + 2) or (x >= X4 - 1 and x <= X5 + 2) or (x >= X6 - 1 and x <= X6 + 2) or (x >= XB - 1 and x <= XB + 2) \
						or (x >= XC - 1 and x <= XC + 2) or (x >= XD - 1 and x <= XD + 2):
				continue
			Pr(c.x * 4 + 2.0, c.y * 4 + 1.5, "ov/tram_bovenleiding_mast", "N")
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


# ------------------------------------------------------------------ finishing

## Grass on every empty ground cell of the map (not water or a sunk cell).
func _fill_grass_all() -> void:
	for x in range(0, X_END + 1):
		for z in range(0, Z_END + 1):
			if ground.get_cell_item(Vector3i(x, 0, z)) != GridMap.INVALID_CELL_ITEM:
				continue
			if occupied.has(Vector2i(x, z)) or ground.get_cell_item(Vector3i(x, -2, z)) != GridMap.INVALID_CELL_ITEM:
				continue
			G(x, z, "natuur/gras")


## Rows of the viaduct along the Schenkkade (north track, south track), the column of
## its abutment beside Centraal Station, the level of its deck (1 m per level) and the
## columns between its piers.
const VIADUCT_ROWS := [90, 91]
const VIADUCT_START := 73
const VIADUCT_LEVEL := 6
const VIADUCT_SPAN := 6


## The RandstadRail viaduct along the Schenkkade: a two-track tram deck on concrete
## piers, from an abutment beside Centraal Station east over the streets x 96, 128 and
## 152 to the map edge (towards Laan van NOI). The piers stand on the pavement or grass
## below, never on a lane or in the water, and props in their way are taken away. Built
## after the grass fill, so the ground under it is final.
func _schenkviaduct() -> void:
	var foot_kinds := {"natuur": "brug/brug_pijler_gras", "stoep": "brug/brug_pijler_stoep", "plein": "brug/brug_pijler_stoep"}
	var since_pier := VIADUCT_SPAN
	for x in range(VIADUCT_START, X_END + 1):
		# the deck: parapets on the outside, the north track turned to face north
		G(x, VIADUCT_ROWS[0], "brug/brug_dek_tram_rand", "W", VIADUCT_LEVEL)
		G(x, VIADUCT_ROWS[1], "brug/brug_dek_tram_rand", "E", VIADUCT_LEVEL)
		if x == VIADUCT_START:
			for z in VIADUCT_ROWS:
				for y in range(VIADUCT_LEVEL):
					G(x, z, "brug/brug_landhoofd", "E", y)
			continue
		since_pier += 1
		if since_pier < VIADUCT_SPAN or x == X_END:
			continue
		var feet := []
		for z in VIADUCT_ROWS:
			var below := ground.get_cell_item(Vector3i(x, 0, z))
			var kind: String = "" if below < 0 else ground.mesh_library.get_item_name(below).get_slice("/", 0)
			feet.append(foot_kinds.get(kind, ""))
		if "" in feet:
			continue   # a lane, a crossing or water below: try the next column
		for k in VIADUCT_ROWS.size():
			_clear_props(x, VIADUCT_ROWS[k])
			_pier(x, VIADUCT_ROWS[k], feet[k], 0, VIADUCT_LEVEL - 1)
		since_pier = 0
	places["schenkviaduct"] = Vector2(112 * 4.0, VIADUCT_ROWS[0] * 4.0)


## Removes the props standing on ground cell (x, z).
func _clear_props(x: int, z: int) -> void:
	for cell in props.get_used_cells():
		if floori(cell.x / 8.0) == x and floori(cell.z / 8.0) == z:
			props.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)


## The camera over the old centre, the slow flight over the map that starts the game
## (node Rondvlucht, scripts/camera/fly_over.gd) and the vignette (node Vignet,
## scripts/effects/vignette.gd).
func _camera(root: Node3D) -> void:
	# two shadow cascades instead of four: the game looks at the town from close by
	# (following a car), where two are as sharp, and it saves the GPU most of a millisecond
	(root.get_node("Zon") as DirectionalLight3D).directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	var cam: Camera3D = root.get_node("Camera")
	var Iso = load("res://scripts/camera/iso_camera.gd")
	cam.position = Iso.position(Vector3(40 * 4.0, 0, 42 * 4.0), 160.0)
	var fly := Node.new()
	fly.name = "Rondvlucht"
	fly.set_script(load("res://scripts/camera/fly_over.gd"))
	root.add_child(fly)
	fly.owner = root
	var lens := CanvasLayer.new()
	lens.name = "Vignet"
	lens.set_script(load("res://scripts/effects/vignette.gd"))
	root.add_child(lens)
	lens.owner = root


## The car (node Auto, scripts/characters/car.gd), an SUV that drives round too (node
## SUV, scripts/characters/suv.gd, starting in the Bezuidenhout), the camera that follows
## the car (node Volgcamera, F in the game; B sends the SUV into it, the demo crash), the
## rest of the traffic (node Verkeer, scripts/world/traffic.gd, spreads it at the start) and
## the see-through buildings while it follows (node Doorkijk,
## scripts/world/building_fade.gd). The car finds its lanes in the ground tiles themselves
## (their "traffic" metadata, scripts/world/road_network.gd).
func _car(root: Node3D) -> void:
	var car := Node3D.new()
	car.name = "Auto"
	car.set_script(load("res://scripts/characters/car.gd"))
	root.add_child(car)
	car.owner = root
	var suv := Node3D.new()
	suv.name = "SUV"
	suv.set_script(load("res://scripts/characters/suv.gd"))
	suv.set("start_cell", Vector2i(XB, ZB + 6))
	suv.set("start_heading", Vector2i(0, 1))
	suv.set("route_seed", 23)
	root.add_child(suv)
	suv.owner = root
	var traffic := Node.new()
	traffic.name = "Verkeer"
	traffic.set_script(load("res://scripts/world/traffic.gd"))
	root.add_child(traffic)
	traffic.owner = root
	var follow := Node.new()
	follow.name = "Volgcamera"
	follow.set_script(load("res://scripts/camera/follow_camera.gd"))
	root.add_child(follow)
	follow.owner = root
	var see_through := Node.new()
	see_through.name = "Doorkijk"
	see_through.set_script(load("res://scripts/world/building_fade.gd"))
	root.add_child(see_through)
	see_through.owner = root


## Props a waste bin belongs next to: benches, picnic tables, kiosks, tram shelters.
const BIN_NEAR := ["straat/bank_hout", "straat/bank_beton", "straat/bank_modern", "straat/picknicktafel", "straat/kiosk", "ov/abri"]
## Shopping streets with a bin every few cells on the pavement in front of the shops:
## [first cell, step, count, interval].
const BIN_STREETS := [
	[Vector2i(54, 7), Vector2i(0, 1), 1, 1],         # Denneweg, at its north end
	[Vector2i(9, 44), Vector2i(1, 0), 14, 5],        # Hoogstraat
	[Vector2i(15, 72), Vector2i(0, 1), 12, 5],       # Wagenstraat (Chinatown)
	[Vector2i(35, 63), Vector2i(0, 1), 20, 6],       # Passage
	[Vector2i(XC + 3, ZB - 1), Vector2i(1, 0), 46, 7],   # Theresiastraat, north pavement
	[Vector2i(XC + 6, ZB + 2), Vector2i(1, 0), 46, 7],   # Theresiastraat, south pavement
]


## Waste bins at logical spots: beside benches, picnic tables, kiosks and tram shelters
## (on a free walkable spot 1.5 m away, at most one per 6 m), and at intervals along the
## shopping streets. Lampposts and bins alternate: a lamppost bin on pavements and
## squares, a round bin in parks.
func _bins() -> void:
	var placed: Array[Vector2] = []
	var spots := []
	for c in props.get_used_cells():
		if c.y != 0 and c.y != 1:
			continue
		var nm := props.mesh_library.get_item_name(props.get_cell_item(c))
		if nm in BIN_NEAR:
			spots.append(Vector2(c.x, c.z) * 0.5)
	spots.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	for p in spots:
		for off in [Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(0, 1.5), Vector2(0, -1.5)]:
			if _try_bin(p + off, placed):
				break
	for st in BIN_STREETS:
		for i in range(0, st[2], st[3]):
			var c: Vector2i = st[0] + st[1] * i
			_try_bin(Vector2(c) * 4.0 + Vector2(2.0, 2.0) + Vector2(st[1]) * 1.0, placed)
	print("waste bins: ", placed.size())


## Places a bin at p (metres) if the spot is walkable, free of props within 1 m and no
## bin lies within 6 m; true when placed.
func _try_bin(p: Vector2, placed: Array[Vector2]) -> bool:
	for q in placed:
		if q.distance_to(p) < 6.0:
			return false
	var cell := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	var id := ground.get_cell_item(Vector3i(cell.x, 0, cell.y))
	if id < 0:
		return false
	var g := ground.mesh_library.get_item_name(id)
	var park := g.begins_with("natuur/pad") or g.begins_with("natuur/grind") or g == "natuur/gras"
	if not (g.begins_with("stoep/") or g.begins_with("plein/") or g.begins_with("tram/tram_halte") or park):
		return false
	if g.contains("kade") or g.contains("rand"):
		return false   # not on the quay edge or the kerb
	var pc := Vector2i(roundi(p.x * 2), roundi(p.y * 2))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for y in [0, 1]:
				if props.get_cell_item(Vector3i(pc.x + dx, y, pc.y + dz)) != GridMap.INVALID_CELL_ITEM:
					return false
	Pr(p.x, p.y, "straat/prullenbak_rond" if park else "straat/prullenbak_paal")
	placed.append(p)
	return true


## Prints how many library items the town uses per layer.
func _report() -> void:
	for gm in [ground, buildings, details, props]:
		var used := {}
		for c in gm.get_used_cells():
			used[gm.get_cell_item(c)] = true
		var total: int = gm.mesh_library.get_item_list().size()
		print("%s: %d of %d used" % [gm.name, used.size(), total])
