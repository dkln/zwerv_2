extends "res://tools/build/city/street_grid.gd"
## City builder, part 4 (see base.gd for the chain): the plan of this town, The Hague: the
## grid of its streets (X1.., Z1.., the map edges), the names of its neighbourhoods and
## streets for the HUD, where the shared structures lie (the A12, the viaducts, the railway
## and its stations), and the small helpers every district uses (cells, water, trees, shops,
## entrance flags, supermarkets, halls, clearing props).


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
const ZS := 96     # Schenkkade, south of the viaducts
const SINGEL_END := 91  # last row of the quay on the south side of the singel
const ZR1 := 107   # first street of the south of the town (Schilderswijk, Laak, Binckhorst)
const ZR2 := 130   # second
const ZR3 := 153   # third
const SOUTH_BLOCK_DEPTH := 21  # rows of a block between those streets
const Z_END := 175 # last row of the map
const X_END := 175 # last column of the city west of the A12
const MAP_END := 215 # last column of the map: the A12 turning south, and Voorburg east of it

var _tram := {}    # Vector2i -> "h" / "v": tram cells (painted after the streets)
var _bend_outsides := []   # the outside cell of every bend in a street, see _round_bend_kerbs


## The neighbourhoods of the map for the HUD (where the player is): name and first and last
## column and row (cells), the first that holds a spot wins (so the small ones come first).
const WIJKEN := [
	["Paleis Noordeinde", 15, 12, 20, 21], ["Lange Voorhout", 26, 7, 47, 28], ["Grote Markt", 10, 61, 22, 70],
	["Centraal Station", 72, 61, 94, 77], ["De Resident", 75, 78, 97, 91], ["Malieveld", 72, 32, 87, 56],
	["Koekamp", 88, 32, 97, 56], ["Bezuidenhout", 98, 18, 127, 57], ["Beatrixkwartier", 98, 58, 127, 91],
	["Bezuidenhout-Oost", 128, 58, 175, 91], ["Prins Clauslaan", 128, 0, 175, 17], ["Schilderswijk", 0, 109, 68, 175],
	["Laak", 69, 109, 127, 175], ["Binckhorst", 128, 109, 175, 175], ["A12", 176, 0, 189, 175],
	["Voorburg", 190, 0, 215, 175], ["Centrum", 0, 0, 71, 108], ["Den Haag", 0, 0, 215, 175]]


## The named streets for the HUD: name, "x" (a street along a column: its first and last
## column, then its first and last row) or "z" (along a row: first and last row, then
## first and last column), in cells, the lanes only (the HUD also counts the pavement
## beside them). Streets without a real name are left out.
const STRATEN := [
	["Hogewal", "x", X1, X1 + 1, 0, 44], ["Prinsegracht", "x", X1, X1 + 1, 45, 90],
	["Noordeinde", "x", X2, X2 + 1, 0, 28], ["Buitenhof", "x", X2, X2 + 1, 29, 59],
	["Korte Vijverberg", "x", X3, X3 + 1, 0, 30], ["Lange Poten", "x", X3, X3 + 1, 31, 57], ["Spui", "x", X3, X3 + 1, 58, 90],
	["Prinsessegracht", "x", X4, X4 + 1, 0, 90], ["Koningskade", "x", X5, X5 + 1, 0, 175],
	["Juliana van Stolberglaan", "x", X6, X6 + 1, 0, 108], ["Laan van Nieuw Oost-Indië", "x", XC, XC + 1, 0, 175],
	["Mauritskade", "z", Z1, Z1 + 1, 0, 68], ["Kneuterdijk", "z", Z2, Z2 + 1, 0, 23], ["Lange Vijverberg", "z", Z2, Z2 + 1, 24, 47],
	["Korte Voorhout", "z", Z2, Z2 + 1, 48, 71], ["Zuid-Hollandlaan", "z", Z2, Z2 + 1, 72, 95],
	["Theresiastraat", "z", ZB, ZB + 1, 129, 175], ["Grote Marktstraat", "z", Z3, Z3 + 1, 0, 47], ["Spui", "z", Z3, Z3 + 1, 48, 95],
	["Bezuidenhoutseweg", "z", Z3, Z3 + 1, 96, 175], ["Zuidwal", "z", Z4, Z4 + 1, 0, 71], ["Schenkkade", "z", ZS, ZS + 1, 0, 175],
	["Maanweg", "z", ZR2, ZR2 + 1, 128, 215], ["A12 (Utrechtsebaan)", "z", AZ, AZ + 8, 0, 189],
	["A12", "x", A_BEND, A_BEND + 8, AZ, 175],
	# the side streets, after streets of their part of town
	["Koningin Marialaan", "z", Z2, Z2 + 1, 96, 175], ["Johannes Camphuysstraat", "z", ZB, ZB + 1, 98, 128],
	["Van Hoytemastraat", "x", XB, XB + 1, 31, 57], ["Carel Reinierszkade", "x", XD, XD + 1, 29, 95],
	["Binckhorstlaan", "x", XD, XD + 1, 96, 175], ["Calandstraat", "x", X6, X6 + 1, 109, 175],
	["Vaillantlaan", "x", X2, X2 + 1, ZS + 2, 175], ["Delftselaan", "x", X3, X3 + 1, ZS + 2, 175],
	["Rijswijkseweg", "x", XB, XB + 1, ZR1 + 2, 175], ["Hobbemastraat", "z", ZR1, ZR1 + 1, 0, 68],
	["Laakkade", "z", ZR1, ZR1 + 1, 69, 127], ["Saturnusstraat", "z", ZR1, ZR1 + 1, 128, 175],
	["Hoefkade", "z", ZR2, ZR2 + 1, 0, 68], ["Van der Vennestraat", "z", ZR2, ZR2 + 1, 69, 127],
	["Jan Steenstraat", "z", ZR3, ZR3 + 1, 0, 68], ["Neherkade", "z", ZR3, ZR3 + 1, 69, 127],
	["Regulusweg", "z", ZR3, ZR3 + 1, 128, 175], ["Herenstraat", "x", VOORBURG_STREET, VOORBURG_STREET + 1, 0, 175],
	["Prinses Mariannelaan", "z", ZS, ZS + 1, 190, 215]]

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
				if not cells.has(q) and q.x >= 0 and q.x <= MAP_END and q.y >= 0 and q.y <= Z_END:
					quays[q] = true
	for q in quays:
		var orth := []
		for d in ORDER:
			if cells.has(q + DIR_OFFSET[d]):
				orth.append(d)
		var kade := "stoep/stoep_kade"   # the same paving all along the quay
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


## Height (m) of the bottom of a shop's name sign (tekst/naam_<kind>_<n>): just over the
## shop window.
const NAME_SIGN_HEIGHT := 2.7
## Most name signs a kind of shop has (tekst/naam_<kind>_1 .. _3).
const NAME_SIGNS_PER_KIND := 3
## The name sign of the snack bars that are a Jan Blammage (scripts/story/story.gd BLAMMAGE_SIGN):
## they get the fries cone (props/terras/friet_puntzak) out front.
const JAN_BLAMMAGE_SIGN := "tekst/naam_snackbar_2"


## The name sign of a shop of this kind ("bg_bakker": tekst/naam_bakker_<n>), another one
## for another `pick`; "" if the kind has none.
func _name_sign(shop: String, pick: int) -> String:
	var kind := shop.trim_prefix("bg_")
	var names: Array[String] = []
	for number in range(1, NAME_SIGNS_PER_KIND + 1):
		var sign_name := "tekst/naam_%s_%d" % [kind, number]
		if _has(sign_name, details):
			names.append(sign_name)
	return names[pick % names.size()] if not names.is_empty() else ""


## Gable types of the canal houses (tile gevel_<type>): stepped, spout, bell and neck.
const GABLES := ["trap", "tuit", "klok", "hals"]


## A row of n shop houses, two cells deep, from `start` in steps of `step`: front cells
## facing `front` with a shop on the ground floor (from `kinds`) and homes above, rear
## cells behind them; sloped roofs (flat for styles without them), corner pieces at
## both ends, signs, awnings and flower boxes. With `gables` (the old centre) most houses
## of a style that has them get a gable on the front instead: a stepped, spout, bell or
## neck gable (GABLES) with a saddle roof behind it, its ridge running from front to back.
func _shops(start: Vector2i, step: Vector2i, n: int, front: String, seed: int, kinds: Array = SHOPS,
		awnings: Array = AWNINGS, floors := 3, gables := false) -> void:
	var back: String = OPPOSITE[front]
	var off: Vector2i = DIR_OFFSET[front]
	var first_end := "N" if step.y != 0 else "W"
	var last_end := "S" if step.y != 0 else "E"
	var styles := ["klassiek_rood", "jaren30", "klassiek_geel", "herenhuis_1900", "klassiek_donker", "modern_wit"]
	if gables:
		styles[5] = "herenhuis_1600"   # the old centre has no modern white houses, but 17th-century ones
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
		if kinds == HORECA and fc == "" and not _has(p + shop):
			# a cafe row stays a cafe row: another style that has this front, not a plain window
			for other: String in styles:
				if _has(other + "/" + other + "_" + shop):
					style = other
					p = style + "/" + style + "_"
					break
		if not _has(p + shop):
			shop = _first(p, ["bg_winkel_luifel", "bg_winkel", "bg_raam"])
		# now and then a house a storey higher than its neighbours (not on the corners, nor
		# in a row lower than three storeys)
		var house_floors := floors + (1 if floors >= 3 and fc == "" and _r(c.x * 3 + seed, c.y * 7, 4) == 0 else 0)
		for v in house_floors:
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
				# windows at the back: another building often stands right behind the row
				bn = _first(p, ["bg_raam", "bg_raam_boog"]) if v == 0 else _first(p, ["verd_raam", "verd_raam_boog"])
			B(bc.x, v, bc.y, p + bn, CORNER[bk] if bk != "" else back)
		if _has(p + "dak_schuin"):
			if fc != "":
				B(c.x, house_floors, c.y, p + "dak_schuin_hoek_buiten", CORNER[fc])
				B(bc.x, house_floors, bc.y, p + "dak_schuin_hoek_buiten", CORNER[bk])
			else:
				var gable: String = "gevel_" + GABLES[(i * 3 + seed) % GABLES.size()]
				if gables and (i + seed) % 4 != 3 and _has(p + gable):
					B(c.x, house_floors, c.y, p + gable, front)
					B(bc.x, house_floors, bc.y, p + "dak_zadel", "S" if front in ["E", "W"] else "E")
				else:
					var rn: String = roofs[(i + seed) % roofs.size()]
					B(c.x, house_floors, c.y, p + (rn if _has(p + rn) else "dak_schuin"), front)
					B(bc.x, house_floors, bc.y, p + "dak_schuin", back)
		else:
			B(c.x, house_floors, c.y, p + "dak_plat_rand", front if fc == "" else fc[0])
			B(bc.x, house_floors, bc.y, p + "dak_plat_rand", back if bk == "" else bk[0])
		if fc != "":
			continue
		# details on the middle of the front face (a little to one side for signs)
		var wx := c.x * 4.0 + 2.0 + off.x * 2.0
		var wz := c.y * 4.0 + 2.0 + off.y * 2.0
		# every other shop its own name over the window (they are wider than a shop: never
		# two side by side), else the sign of its trade or an awning
		var name_sign := _name_sign(shop, i / 2 + seed) if (i + seed) % 2 == 0 else ""
		# beside a shop with its own name (on the even ones) no hanging sign at that height
		var beside_a_name := (i + seed) % 2 == 1 and (_name_sign(kinds[(i - 1 + seed) % kinds.size()], 0) != "" \
				or _name_sign(kinds[(i + 1 + seed) % kinds.size()], 0) != "")
		if name_sign != "":
			D(wx, wz, NAME_SIGN_HEIGHT, name_sign, front)
			# a Jan Blammage has its big fries cone out on the pavement, beside the door
			if name_sign == JAN_BLAMMAGE_SIGN:
				Pr(wx + off.x * 1.0 + step.x * 1.3, wz + off.y * 1.0 + step.y * 1.3, "terras/friet_puntzak", front)
		elif SIGNS.has(shop) and not beside_a_name:
			D(wx - step.x, wz - step.y, 3.5, SIGNS[shop], front)
		elif (i + seed) % 2 == 0:
			D(wx, wz, 2.5, awnings[(i + seed) % awnings.size()], front)
		if (i + seed) % 3 == 1:
			D(wx + step.x, wz + step.y, 4.0, "ramen/bloembak", front)


## Where the Zebraklok stands on the square before Centraal Station (world metres x, z)
## and its turn (degrees round the vertical: one face looks along the square).
const ZEBRA_CLOCK_AT := Vector2(84 * 4.0, 62 * 4 + 2.0)
const ZEBRA_CLOCK_TURN := 0.0


## A glass hall (style `hall` of the hallen group) of w x d cells and `storeys` storeys:
## walls of glass on the outside, the roof on the top storey, doors in cell `door` and in
## `more_doors` (on the ground: a door wall with its own little roof, a canopy over the
## door in a taller hall).
func _tall_hall(x0: int, z0: int, w: int, d: int, hall: String, storeys: int, door: Vector2i, more_doors := []) -> void:
	var prefix := "hallen/" + hall + "_"
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			var sides := _sides(x, z, x0, z0, w, d)
			for storey in storeys:
				var top := storey == storeys - 1
				if sides.size() == 0:
					if top:
						B(x, storey, z, prefix + "dak", "S")
				elif sides.size() == 1:
					var is_door := storey == 0 and (Vector2i(x, z) == door or more_doors.has(Vector2i(x, z)))
					if is_door:
						B(x, storey, z, prefix + "wand_deur_dak", sides[0])
					else:
						B(x, storey, z, prefix + "wand" + ("_dak" if top else ""), sides[0])
				else:
					B(x, storey, z, prefix + ("hoek_dak" if top else "hoek"), CORNER[_corner_pair(sides, "")])


## Motorway profile across 9 rows (north verge to south verge): [tile, rotation]. The
## right lanes are plain asphalt of the motorway itself (its lines lie on the tiles beside
## them), so they keep its speed limit instead of taking that of the tunnel ahead.
const MW_FLAT := [["snelweg/snelweg_berm_vangrail", "E"], ["snelweg/snelweg_vluchtstrook", "E"], ["snelweg/snelweg_rijstrook_zonder_streep", "E"],
	["snelweg/snelweg_rijstrook_links", "E"], ["snelweg/snelweg_middenberm_beton", "E"], ["snelweg/snelweg_rijstrook_links", "W"],
	["snelweg/snelweg_rijstrook_zonder_streep", "W"], ["snelweg/snelweg_vluchtstrook", "W"], ["snelweg/snelweg_berm_vangrail", "W"]]


## The A12 east of the city: on east in its rows to the bend, a square bend of 9 x 9 cells
## from column A_BEND (lane k from the inside turns in cell (k, k), see ground_corners.py),
## then south in the columns A_BEND..A_BEND+8 past the Binckhorst and Voorburg, at grade
## with the half junctions of the Schenkkade and of Voorburg (A12_JUNCTIONS), and from row
## A_TROUGH down into a trough to the map edge.
const A_BEND := X_END + 6
## First row of the southward part, and of the ramp down into the trough past Voorburg.
const A_SOUTH := AZ + 9
const A_TROUGH := 148
## The half junctions (as on the real A12: an exit for the traffic towards Den Haag, an
## on-ramp for the traffic away from it): the first lane row of the street that crosses
## the motorway on a bridge, and its name in `places`. 3: Bezuidenhout (the Schenkkade),
## 4: Voorburg (the street ZR2 into the Binckhorst, as the Maanweg).
const A12_JUNCTIONS := [[ZS, "a12_afslag_bezuidenhout"], [ZR2, "a12_afslag_voorburg"]]
## First and last column of the bridges of the junctions (level VIADUCT_LEVEL); the
## street rises to them over the 6 columns before and after.
const A12_BRIDGE_COLUMNS := [A_BEND - 3, A_BEND + 10]
## The street north-south through Voorburg.
const VOORBURG_STREET := 204


## The name of a (made-up) company, tekst/naam_kantoor_<number>, high on the front of an
## office from column x0, `width` wide, whose front face lies on the edge z (metres z * 4)
## and faces `front` ("N" or "S"), under the top of its `storeys`.
func _company_name(x0: int, width: int, z: int, front: String, storeys: int, number: int) -> void:
	D(x0 * 4 + width * 2.0, z * 4.0, storeys * 3.0 - 4.2, "tekst/naam_kantoor_%d" % number, front)


## Two Dutch flags on poles flanking the entrance of a government building: the door in the
## middle of the front face at (wx, wz) metres, which faces `front` ("N", "S", "E", "W").
const ENTRANCE_FLAG_SPREAD := 3.5
const ENTRANCE_FLAG_OUT := 2.5


func _entrance_flags(wx: float, wz: float, front: String) -> void:
	var out := Vector2(DIR_OFFSET[front])
	var along := Vector2(-out.y, out.x)
	for side in [-1.0, 1.0]:
		var spot: Vector2 = Vector2(wx, wz) + out * ENTRANCE_FLAG_OUT + along * side * ENTRANCE_FLAG_SPREAD
		Pr(spot.x, spot.y, "straat/vlaggenmast_nl", front)


## The supermarket brands, taking turns (_housing_block), the colour of their carts, and
## the most cells of front a supermarket in a housing block takes.
const SUPERMARKET_BRANDS := ["derrek", "alfred_steyhn"]
const SUPERMARKET_CARTS := {"derrek": "rood", "alfred_steyhn": "blauw"}
const SUPERMARKET_MOST_CELLS := 7
var _supermarket_count := 0


## A supermarket of `brand` ("derrek", "alfred_steyhn") in the ground floor of the north
## front (row z) of a block of `style` from column x0, `width` wide: shop windows in the
## brand's colours between the corners, the sliding doors in the middle, the brand's sign
## over them, and before it a cart shelter, a row of carts and a couple left standing
## (handles in `cart_colour`: "rood", "blauw").
func _supermarket(x0: int, z: int, width: int, style: String, brand: String, cart_colour: String) -> void:
	var prefix := style + "/" + style + "_bg_" + brand + "_"
	var door := x0 + width / 2
	for x in range(x0 + 1, x0 + width - 1):
		B(x, 0, z, prefix + ("ingang" if x == door else "raam"), "N")
	D(door * 4 + 2.0, z * 4.0, 3.1, "tekst/tekst_" + brand, "N")
	# the logo on the corner of the front, high up, and a pylon at the forecourt
	D((x0 + width - 1) * 4 + 2.0, z * 4.0, 6.5, "tekst/logo_" + brand, "N")
	Pr((x0 + width - 1) * 4 + 3.0, (z - 1) * 4 + 0.5, "winkel/reclamezuil_" + brand, "N")
	Pr((x0 + 1) * 4 + 2.0, (z - 1) * 4 + 1.0, "winkel/winkelwagenstalling_" + cart_colour, "S")
	Pr((x0 + width - 2) * 4 + 2.0, (z - 1) * 4 + 2.5, "winkel/winkelwagens_rij_" + cart_colour, "E")
	Pr((door - 1) * 4 + 2.5, (z - 1) * 4 + 2.0, "winkel/winkelwagen_" + cart_colour, "W")
	Pr((door + 1) * 4 + 1.0, (z - 1) * 4 + 1.0, "winkel/winkelwagen", "N")
	var key := brand
	var number := 2
	while places.has(key):
		key = "%s_%d" % [brand, number]
		number += 1
	places[key] = Vector2(door * 4 + 2.0, z * 4.0)


## Rows of the viaduct north of the Schenkkade (north track, south track), the columns
## where its ramp from street level starts and where the deck starts, the level of the
## deck (1 m per level, the ramp rises 1 m per column) and the columns between its piers.
const VIADUCT_ROWS := [90, 91]
const VIADUCT_RAMP_START := 74
const VIADUCT_START := 80
const VIADUCT_LEVEL := 6
const VIADUCT_SPAN := 6
const VIADUCT_STAIR_ROTATION := "W"
## Columns of the tracks from the foot of the ramp north to the line of street Z3.
const VIADUCT_LINK_COLUMNS := [72, 73]
## Rows of the tram stop on those tracks beside Centraal Station (6 cells, a RandstadRail fits).
const STATION_TRAM_STOP_ROWS := [63, 68]
## Stops on the viaduct: first column, last column, platform rows, name in `places` and
## whether it has the high platforms of a station (the first cell holds the stairs).
## The stop at Centraal has its platform on the south side only, a car park stands to the
## north. Station Laan van NOI lies over the street x 128 with the trains on its south side:
## the platform between the tram and the train is shared.
const STATION_FIRST := 119
const STATION_LAST := 129
const VIADUCT_STOPS := [
	[88, 93, [92], "halte_centraal_viaduct", false],
	[104, 109, [89, 92], "halte_beatrixkwartier", false],
	[STATION_FIRST, STATION_LAST, [89, 92, 95], "station_laan_van_noi", true],
	[VOORBURG_STATION_FIRST, VOORBURG_STATION_FIRST + 10, [89, 92, 95], "station_voorburg", true],
]
## First column of Station Voorburg, over the street of Voorburg: the stairs at its west
## end come down on the pavement of the street from the bridge of the junction.
const VOORBURG_STATION_FIRST := 200
## Rows of the railway viaduct (north track, south track) and the column where its deck
## starts; the ramp up from street level lies in the 6 columns before it.
const RAILWAY_ROWS := [93, 94]
const RAILWAY_DECK_START := 91
## Columns of the tracks from the station hall south to the foot of the ramp, and the
## row where they leave the hall (the buffer stops stand inside it, at RAILWAY_HALL_END).
const RAILWAY_COLUMNS := [83, 84]
const RAILWAY_LEAVE_HALL := 77
const RAILWAY_HALL_END := 73
## Cells of a railway platform: 44 m, for an NS train of 40 m.
const RAILWAY_PLATFORM_CELLS := 11


## Rotation of an overhead line mast tile whose arm points to this side (the arm runs
## along the tile's x, so it turns a quarter ahead of the side its front faces).
const MAST_ARM_ROTATION := {"E": "S", "N": "E", "W": "N", "S": "W"}


## Removes the lamps, overhead line masts and trees on ground cell (x, z), which would reach
## up into what is built above them; traffic lights stay.
func _clear_lamps_and_trees(x: int, z: int) -> void:
	for cell in props.get_used_cells():
		if floori(cell.x / 8.0) == x and floori(cell.z / 8.0) == z:
			var item_name := props.mesh_library.get_item_name(props.get_cell_item(cell))
			if item_name.begins_with("verlichting/") or item_name.begins_with("bomen/") or item_name.begins_with("ov/tram_bovenleiding"):
				props.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)


## Removes the props standing on ground cell (x, z).
func _clear_props(x: int, z: int) -> void:
	for cell in props.get_used_cells():
		if floori(cell.x / 8.0) == x and floori(cell.z / 8.0) == z:
			props.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)
