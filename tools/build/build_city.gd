extends "res://tools/build/city/street_grid.gd"
## Builds scenes/stad.tscn: the centre of The Hague, compressed onto a street grid and
## made only of the tiles in the libraries.
## usage: GODOT_TIMEOUT=1200 tools/godot.sh --headless --script tools/build/build_city.gd
##
## It uses the builder in tools/build/city/: placement (G/B/D/Pr), building
## helpers (block, ring, tower, _hall, ...), the street grid (_h_street / _v_street, painted
## by _paint_streets, dressed with markings, zebra crossings and traffic lights by
## _dress_streets, kerbs by _auto_kerbs). Coordinates: x = east, z = south, ground tiles
## of 4 m; directions name the side a tile's front faces (see city/base.gd).
##
## MAP (x 0..215, z 0..175: the city x 0..175, the A12 and Voorburg east of it)
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
##   (Utrechtsebaan, z 19..27) coming in from the bend east of the city, down into a trough, covered
##   from x 95 to x 130 with the Malietoren, Snackbar De Vrijheid and offices on the deck
##   (_over_a12), up again to a junction with the Koningskade by the Ministerie van
##   Financien; the Malieveld, the Bezuidenhout and the Theresiastraat (z 31..57);
##   Centraal Station with its square and towers, the Beatrixkwartier and the
##   Bezuidenhout-Oost (z 60..91).
##   Trams: Buitenhof (x 24, z 29..59), Kneuterdijk - Korte Voorhout - Malieveld (z 29)
##   and Grote Marktstraat - Spui - Centraal (z 58), over bridges across the singel;
##   the RandstadRail viaduct (z 90..91) from Centraal Station east over the
##   Beatrixkwartier, with stops at Centraal, there and at the Laan van NOI, on over the
##   Bezuidenhout-Oost; a ramp and tracks along x 72..73 join it to the line of street
##   z 58 (_schenkviaduct). Railway: two tracks from Centraal Station south and up to a
##   viaduct beside the tram (z 93..94), through elevated Station Laan van NOI over the
##   street x 128 and Station Voorburg to the map edge (_railway). The trams of the Grote Marktstraat run through a tunnel with an
##   underground stops at the Grote Markt and the Spui between two ramps (x 26..55, _tram_tunnel). The tracks along
##   x 72..73 run under a wing of the Ministerie van VWS (De Resident) built over them (_ministry_over_tram). South of the viaducts the Schenkkade (z 96) and the
##   neighbourhood along it (_schenkkade). Road bridges over the east arm of the singel
##   at the Mauritskade (z 5), the two tram streets and the Zuidwal (z 85).
##   East of the city (x 176..215): the A12 turns south in a square bend (x 181..189) and
##   runs past the Binckhorst and Voorburg, with the half junctions 3 (Bezuidenhout, the
##   Schenkkade) and 4 (Voorburg, the street z 130) whose streets cross it on bridges, and
##   from z 148 in a trough to the map edge (_a12_east, _a12_bridges); the viaducts of
##   RandstadRail and railway cross it to Station Voorburg (x 200..210); Voorburg on the
##   street x 204 with the Oude Kerk (_voorburg).

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


func _init() -> void:
	Common.watchdog(self, 1100)
	var root := _make_scene("Stad")
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
	_a12_east()
	_over_a12()
	_prins_clauslaan()
	_malieveld()
	_bezuidenhout()
	_theresiastraat()
	_bezuidenhout_oost()
	_centraal()
	_beatrixkwartier()
	_schenkkade()
	_schilderswijk()
	_laakkwartier()
	_binckhorst()
	_voorburg()
	_tram_lines()
	_paint_streets()
	_dress_streets()
	_paint_trams()
	_tram_tunnel()
	_bridges()
	_a12_junction()
	_square_corners()
	_auto_kerbs()
	_round_bend_kerbs()
	_fill_grass_all()
	_railway()
	_a12_bridges()
	_schenkviaduct()
	_ministry_over_tram()
	_a12_footbridge()
	_paths_to_lonely_buildings()
	_join_gravel_paths()
	_roof_equipment()
	_straighten_hidden_corners()
	_flatten_facades_by_viaducts()
	_remove_trees_in_buildings()
	_fit_signs_on_facades()
	_one_sign_per_spot()
	_clear_behind_signs()
	_bins()
	_grote_marktstraat_lanes()
	_camera(root)
	_zebra_clock(root)
	_car(root)
	_own_tints(root)
	if missing.size() > 0:
		print("MISSING TILES: ", missing.keys())
	_report()
	root.set_meta("districts", districts)
	root.set_meta("places", places)
	root.set_meta("wijken", WIJKEN)
	root.set_meta("straten", STRATEN)
	_save(root, "res://scenes/stad.tscn")
	quit()


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
		elif SIGNS.has(shop) and not beside_a_name:
			D(wx - step.x, wz - step.y, 3.5, SIGNS[shop], front)
		elif (i + seed) % 2 == 0:
			D(wx, wz, 2.5, awnings[(i + seed) % awnings.size()], front)
		if (i + seed) % 3 == 1:
			D(wx + step.x, wz + step.y, 4.0, "ramen/bloembak", front)


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
	_shops(Vector2i(22, 8), Vector2i(0, 1), 4, "E", 1, SHOPS, AWNINGS, 3, true)
	_shops(Vector2i(22, 22), Vector2i(0, 1), 6, "E", 4, SHOPS, AWNINGS, 3, true)
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
## mansions along the Korte Vijverberg side and canal houses facing the Prinsessegracht;
## at its south end on the east side the Ministerie van Financien (from FINANCIEN_ROWS[0]).
func _denneweg() -> void:
	for z in range(8, 28):
		_g(55, z, "weg/straat_klinkers", "S")
		if z % 4 == 1:
			Pr(55 * 4 + 2.0, z * 4 + 2.0, "verlichting/lantaarn_wand_klassiek", "S")
	_kerb_path(55, 7, "N")
	_kerb_path(55, 28, "S")
	Pr(55 * 4 + 1.0, 8 * 4 + 1.0, "borden/bord_woonerf", "S")
	_shops(Vector2i(54, 8), Vector2i(0, 1), 20, "E", 2, SHOPS, AWNINGS, 3, true)
	_shops(Vector2i(56, 8), Vector2i(0, 1), FINANCIEN_ROWS[0] - 8, "W", 6, SHOPS, AWNINGS, 3, true)
	block(51, 8, 2, 20, "herenhuis_1900", 3, {"front": "W", "gf": ["bg_deur", "bg_raam_boog"], "gf_side": "bg_raam_boog",
		"gf_corner": "bg_raam_boog_hoek", "upper": ["verd_raam_boog", "verd_erker", "verd_balkon"], "upper_corner": "verd_raam_boog_hoek",
		"roof": "sloped", "roof_extra": ["dak_schuin_dakkapel"]})
	for z in range(9, 27, 3):
		D(51 * 4.0, z * 4 + 2.0, 0.0, "deuren/stoeptrap", "W")
	# canal houses facing the singel, small back gardens towards the shops
	var styles := ["klassiek_rood", "klassiek_donker", "klassiek_geel"]
	var tops := ["trap", "klok", "hals", "tuit"]
	var upper := ["verd_raam", "verd_drie_ramen", "verd_luiken", "verd_balkon", "verd_raam", "verd_erker"]
	for z in range(8, FINANCIEN_ROWS[0]):
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
	_ministerie_van_financien()


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
	_shops(Vector2i(8, 43), Vector2i(1, 0), 15, "S", 1, SHOPS, AWNINGS, 3, true)
	_shops(Vector2i(8, 46), Vector2i(1, 0), 9, "N", 5, SHOPS, AWNINGS, 3, true)
	# Oude Raadhuis on the corner of the Hoogstraat, with its tower
	block(18, 46, 5, 5, "klassiek_geel", 3, {"front": "N", "gf": ["bg_deur", "bg_raam"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_luiken"], "roof": "sloped", "roof_extra": ["dak_schuin_dakkapel"]})
	tower(22, 46, "overheid", ["toren_klok", "toren_spits_onder", "toren_spits_boven"], "N", 3)
	D(20 * 4 + 2.0, 46 * 4.0, 3.0, "tekst/tekst_raadhuis", "N")
	D(19 * 4 + 2.0, 46 * 4.0, 6.0, "gevel/vlag_denhaag", "N")
	# shops on the north side of the Grote Marktstraat (the street runs along z 58-59)
	_shops(Vector2i(8, 56), Vector2i(1, 0), 9, "S", 15, RETAIL, AWNINGS, 3, true)
	_shops(Vector2i(18, 56), Vector2i(1, 0), 5, "S", 16, RETAIL, AWNINGS, 3, true)
	ring(8, 48, 9, 7, "klassiek_donker", 4, {"gf": ["bg_raam", "bg_deur", "bg_winkel_luifel"], "upper": ["verd_raam", "verd_drie_ramen"],
		"back": ["verd_raam"], "roof_extra": ["dak_schuin_schoorsteen", "dak_schuin_dakkapel"]})
	# De Snoeptrommel (the "snoeppaleis", with The Sting) on the Dagelijkse Groenmarkt,
	# across from the Oude Raadhuis: a colonnade of shop fronts under colourful striped storeys
	block(18, 52, 5, 3, "hogeschool", 4, {"front": "E", "gf": ["bg_kolonnade", "bg_entree", "bg_kolonnade"], "gf_side": "bg_kolonnade",
		"gf_corner": "bg_kolonnade_hoek", "upper": ["verd_lamellen"], "upper_corner": "verd_lamellen_hoek", "roof": "flat"})
	places["snoeptrommel"] = Vector2(23 * 4.0, 53 * 4.0 + 2.0)
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
	# Binnenhof: wings round a courtyard
	_fill(31, 40, 42, 56, "plein/plein_keien")
	var gov := {"gf": ["bg_raam", "bg_entree", "bg_raam"], "gf_side": "bg_raam", "gf_corner": "bg_raam_hoek",
		"upper": ["verd_raam_hoog", "verd_balkon", "verd_raam_hoog"], "upper_corner": "verd_raam_hoog_hoek", "roof": "sloped",
		"roof_extra": ["dak_schuin_dakkapel", "dak_schuin_schoorsteen"]}
	for wing in [[31, 40, 12, 2, "N"], [31, 54, 12, 2, "S"], [31, 42, 2, 12, "W"], [41, 42, 2, 12, "E"]]:
		var o := gov.duplicate()
		o["front"] = wing[4]
		block(wing[0], wing[1], wing[2], wing[3], "overheid", 3, o)
	# gateways through the wings at street level: the Stadhouderspoort to the Buitenhof,
	# the way to the Plein, the Grenadierspoort to the Hofvijver and one to the Grote
	# Marktstraat side (the upper floors run on over them)
	for gate: Vector2i in [Vector2i(31, 47), Vector2i(32, 47), Vector2i(41, 47), Vector2i(42, 47), Vector2i(36, 40), Vector2i(36, 41),
			Vector2i(37, 54), Vector2i(37, 55)]:
		buildings.set_cell_item(Vector3i(gate.x, 0, gate.y), GridMap.INVALID_CELL_ITEM)
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
		_g(c.x, c.y, "natuur/gras")
	for z in range(34, 50, 3):
		Pr(57 * 4 + 2.0, z * 4 + 2.0, ["terras/terras_set_parasol_groen", "terras/terras_set_parasol", "terras/tafel_vierkant_stoelen"][z % 3], "W")
		Pr(58 * 4 + 2.0, z * 4 + 1.0, "terras/bloembak_terras", "W")
	# the terraces reach well out onto the square, round the statue too
	for z in range(33, 51, 2):
		if z >= 40 and z <= 43:
			continue
		Pr(56 * 4 + 1.0, z * 4 + 2.0, ["terras/terras_set_parasol", "terras/terras_set_parasol_groen"][(z / 2) % 2], "W")
		if z % 4 == 1:
			Pr(54 * 4 + 2.0, z * 4 + 2.0, ["terras/terras_set_parasol_groen", "terras/terras_set_parasol"][(z / 4) % 2], "W")
	for z in [35, 44, 48]:
		Pr(57 * 4 + 3.0, z * 4.0, "terras/stoepbord", "W")
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
	# the Tweede Kamer at Plein 2: flags over the entrance
	for x in [54, 56, 58]:
		D(x * 4.0, 52 * 4.0, 10.0, "gevel/vlag_nl", "N")
	places["tweede_kamer"] = Vector2(56 * 4.0, 53 * 4.0)
	places["plein"] = Vector2(55 * 4.0, 42 * 4.0)


# ------------------------------------------------------------------ south: Grote Markt, Grote Marktstraat, Spui

## The Grote Markt (x 10..22, z 61..70): a clinker square with cafes and terraces on its
## west and south sides; Chinatown south of it along the Wagenstraat (x 15-16).
func _grote_markt() -> void:
	_fill(10, 61, 22, 70, "plein/plein_klinkers")
	for c in [Vector2i(15, 65), Vector2i(16, 65), Vector2i(15, 66), Vector2i(16, 66)]:
		_g(c.x, c.y, "plein/plein_dambord")
	Pr(16 * 4.0, 66 * 4.0, "standbeelden/standbeeld_persoon", "S")
	_shops(Vector2i(9, 61), Vector2i(0, 1), 10, "E", 3, HORECA, AWNINGS, 3, true)
	_shops(Vector2i(22, 63), Vector2i(0, 1), 6, "W", 5, HORECA, AWNINGS, 3, true)
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
	places["bijenkorf"] = Vector2(31 * 4.0, 61 * 4.0)
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


## Spuiplein with the Nieuwe Kerk and the white city hall (two slabs with the glass atrium
## between them); south of the church cafes on the Spui and a little square beside the
## city hall (Amare stands at the Dirigentplein by De Resident, _de_resident).
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
	places["stadhuis"] = Vector2(59 * 4.0, 69 * 4.0)
	# cafes along the Spui, a square with trees between them and the city hall
	_shops(Vector2i(51, 76), Vector2i(0, 1), 8, "W", 2, HORECA, AWNINGS, 3, true)
	_fill(53, 76, 54, 83, "plein/plein_tegels")
	_trees([Vector2i(53, 77), Vector2i(54, 80), Vector2i(53, 83)], ["bomen/plataan", "bomen/linde"])
	for z in [78, 82]:
		Pr(54 * 4 + 2.0, z * 4 + 2.0, "straat/bank_beton", "E")
	for z in [76, 79, 81]:
		Pr(50 * 4 + 1.5, z * 4 + 2.0, ["terras/terras_set_parasol", "terras/terras_set_parasol_groen"][z % 2], "W")
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
			_g(x, z, "natuur/gras")
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


## Storeys of the Ministerie van Financien and of its winter garden; its first and last
## row (east of the Denneweg, north of the Korte Voorhout) and first and last column
## (from the Denneweg to the Prinsessegracht).
const FINANCIEN_STOREYS := 8
const WINTER_GARDEN_STOREYS := 3
const FINANCIEN_ROWS := [21, 27]
const FINANCIEN_COLUMNS := [56, 61]


## The Ministerie van Financien on the corner of the Korte Voorhout and the
## Prinsessegracht: the 1970s building with its glass second skin over the old concrete
## balconies, wings round a courtyard under a glass roof (the atrium), the entrance on the
## Korte Voorhout and a glass winter garden on the corner with the Prinsessegracht.
func _ministerie_van_financien() -> void:
	var x0: int = FINANCIEN_COLUMNS[0]
	var x1: int = FINANCIEN_COLUMNS[1]
	var z0: int = FINANCIEN_ROWS[0]
	var z1: int = FINANCIEN_ROWS[1]
	var skin := {"front": "S", "gf": ["bg_entree", "bg_kolonnade", "bg_glas"], "gf_side": "bg_glas",
		"gf_corner": "bg_kolonnade_hoek", "upper": ["verd_vliesgevel"], "upper_corner": "verd_vliesgevel_hoek", "roof": "flat"}
	block(x0, z0, x1 - x0 + 1, 2, "kantoor_beton", FINANCIEN_STOREYS, skin)          # north wing
	block(x0, z1 - 1, x1 - x0 - 1, 2, "kantoor_beton", FINANCIEN_STOREYS, skin)      # south wing, on the Korte Voorhout
	block(x0, z0 + 2, 2, z1 - z0 - 3, "kantoor_beton", FINANCIEN_STOREYS, skin)      # west wing, on the Denneweg
	block(x1 - 1, z0 + 2, 2, z1 - z0 - 3, "kantoor_beton", FINANCIEN_STOREYS, skin)  # east wing, on the Prinsessegracht
	for x in range(x0 + 2, x1 - 1):
		for z in range(z0 + 2, z1 - 1):
			B(x, FINANCIEN_STOREYS - 1, z, "hallen/hal_glas_dak", "S")   # the atrium's glass roof
	_tall_hall(x1 - 1, z1 - 1, 2, 2, "hal_glas", WINTER_GARDEN_STOREYS, Vector2i(x1, z1))
	B(x0 + 2, FINANCIEN_STOREYS, z0, "kantoor_beton/kantoor_beton_dak_installatie", "S")
	var entrance := (x0 + 1) * 4 + 2.0
	D(entrance, (z1 + 1) * 4.0, 0.0, "luifels/luifel_kantoor", "S")
	D(entrance, (z1 + 1) * 4.0, 0.0, "deuren/draaideur", "S")
	D(entrance + 4.0, (z1 + 1) * 4.0, 7.5, "tekst/tekst_ministerie_financien", "S")
	D(entrance + 4.0, (z1 + 1) * 4.0, FINANCIEN_STOREYS * 3.0 - 4.0, "gevel/vlag_nl", "S")
	_entrance_flags(entrance, (z1 + 1) * 4.0, "S")
	places["ministerie_van_financien"] = Vector2((x0 + x1 + 1) * 2.0, (z0 + z1 + 1) * 2.0)


## Storeys of the main building of the Provinciehuis, of its wing and of the Statenzaal.
const PROVINCIEHUIS_STOREYS := 10
const PROVINCIEHUIS_WING_STOREYS := 4
const STATENZAAL_STOREYS := 2


## First and last row of the Provinciehuis on the north-west corner of the Malieveld; the
## first column of the Koekamp.
const PROVINCIEHUIS_ROWS := [32, 39]
const KOEKAMP_COLUMN := 88


## The Provinciehuis van Zuid-Holland on the north-west corner of the Malieveld (x 72..80,
## z 32..39), where the A12 comes out on the Zuid-Hollandlaan (the street z 29 east of the
## Koningskade): the 1960s main building, a long slab with concrete bands, on the
## Zuid-Hollandlaan, so it is what you see coming off the motorway; a lower wing along the
## Koningskade; the Statenzaal behind a glass front looking out over the Malieveld; the
## Zuid-Hollandplein between them, open to the field.
func _provinciehuis() -> void:
	var z0: int = PROVINCIEHUIS_ROWS[0]
	var z1: int = PROVINCIEHUIS_ROWS[1]
	_fill(72, z0, 80, z1, "plein/plein_tegels")
	var bands := {"gf": ["bg_entree", "bg_glas", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_band", "verd_raam_groot"], "upper_corner": "verd_band_hoek", "roof": "flat"}
	var main := bands.duplicate()
	main["front"] = "N"
	block(72, z0, 9, 2, "kantoor_beton", PROVINCIEHUIS_STOREYS, main)
	B(76, PROVINCIEHUIS_STOREYS, z0, "kantoor_beton/kantoor_beton_dak_installatie", "S")
	var wing := bands.duplicate()
	wing["front"] = "W"
	block(72, z0 + 2, 2, 5, "kantoor_beton", PROVINCIEHUIS_WING_STOREYS, wing)
	_tall_hall(77, z1 - 1, 3, 2, "hal_glas", STATENZAAL_STOREYS, Vector2i(78, z1))
	D(76 * 4.0 + 2.0, z0 * 4.0, 4.5, "gevel/vlag_nl", "N")
	D(76 * 4.0 + 2.0, (z0 + 2) * 4.0, 4.5, "gevel/vlag_nl", "S")
	for x in [74, 75, 76]:
		Pr(x * 4 + 2.0, (z0 + 4) * 4 + 2.0, "straat/vlaggenmast_nl")
	_trees([Vector2i(80, z0 + 3), Vector2i(75, z1)], ["bomen/linde"])
	Pr(77 * 4 + 2.0, (z0 + 4) * 4 + 2.0, "straat/bank_beton", "S")
	places["provinciehuis"] = Vector2(76 * 4.0, z0 * 4.0)


## The Koekamp between the Malieveld, the Juliana van Stolberglaan and the station (x 88..94,
## z 32..56): a wood with gravel paths, the deer camp behind a high wire fence in its north
## part, a pond with weeping willows by the Bezuidenhoutseweg and benches.
func _koekamp() -> void:
	var x0 := KOEKAMP_COLUMN
	for x in range(x0, 95):
		for z in range(32, 57):
			var path := x == x0 or x == 94 or z == 32 or z == 56 or z == 43
			_g(x, z, "natuur/pad_grind" if path else "natuur/gras", "E")
	# the deer camp: a fenced meadow with a few trees
	var pen := Rect2i(x0 + 1, 34, 5, 7)
	for x in range(pen.position.x, pen.end.x):
		Pr(x * 4 + 2.0, pen.position.y * 4 + 0.5, "hekken/hek_gaas_hoog", "N")
		Pr(x * 4 + 2.0, pen.end.y * 4 - 0.5, "hekken/hek_gaas_hoog", "S")
	for z in range(pen.position.y, pen.end.y):
		Pr(pen.position.x * 4 + 0.5, z * 4 + 2.0, "hekken/hek_gaas_hoog", "W")
		Pr(pen.end.x * 4 - 0.5, z * 4 + 2.0, "hekken/hek_gaas_hoog", "E")
	_trees([Vector2i(x0 + 2, 36), Vector2i(x0 + 4, 39)], ["bomen/eik"])
	# the wood round it and the pond towards the station
	_trees([Vector2i(x0 + 1, 33), Vector2i(x0 + 4, 33), Vector2i(x0 + 1, 42), Vector2i(x0 + 5, 42), Vector2i(x0 + 2, 45),
		Vector2i(x0 + 5, 46), Vector2i(x0 + 1, 52), Vector2i(x0 + 5, 54), Vector2i(x0 + 3, 55)], ["bomen/populier", "bomen/eik", "bomen/kastanje", "bomen/linde"])
	_pond(x0 + 1, 47, x0 + 5, 51)
	_trees([Vector2i(x0 + 1, 47), Vector2i(x0 + 5, 51)], ["bomen/treurwilg"])
	for z in [44, 53]:
		Pr((x0 + 3) * 4 + 2.0, z * 4 + 2.0, "straat/bank_hout", "N")
	places["koekamp"] = Vector2((x0 + 3) * 4.0, 38 * 4.0)
	places["bezuidenhoutseweg"] = Vector2((x0 + 3) * 4.0, 58 * 4.0 + 4.0)


## The Malieveld (x 72..87, z 32..56) from the Koningskade: one big open lawn with a gravel
## path round it, lanterns and flags; the Provinciehuis on its north-west corner by the end
## of the A12 and the Koekamp east of it.
func _malieveld() -> void:
	for x in range(72, KOEKAMP_COLUMN):
		for z in range(32, 57):
			if x <= 80 and z <= PROVINCIEHUIS_ROWS[1]:
				continue
			var edge := x == 72 or x == KOEKAMP_COLUMN - 1 or z == 32 or z == 56 or (z == PROVINCIEHUIS_ROWS[1] + 1 and x <= 81) or (x == 81 and z <= PROVINCIEHUIS_ROWS[1])
			_g(x, z, "natuur/pad_grind" if edge else "natuur/gras", "E")
	_provinciehuis()
	_koekamp()
	for x in range(83, KOEKAMP_COLUMN, 3):
		Pr(x * 4 + 2.0, 32 * 4 + 1.0, "verlichting/lantaarn_park", "S")
	for x in range(74, KOEKAMP_COLUMN, 3):
		Pr(x * 4 + 2.0, 56 * 4 + 3.0, "verlichting/lantaarn_park", "N")
	for x in [79, 80, 81]:
		Pr(x * 4 + 2.0, 44 * 4.0, ["straat/vlaggenmast_denhaag", "straat/vlaggenmast_nl", "straat/vlaggenmast_eu"][x - 79])
	_kerb_path(X6 - 1, 44, "E")
	places["malieveld"] = Vector2(80 * 4.0, 46 * 4.0)
	places["zuid_hollandlaan"] = Vector2(78 * 4.0, (Z2 + 1) * 4.0)


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
	# the station hall: a tall glass hall over the concourse and the platforms, with doors
	# under the three canopies on the square
	_tall_hall(74, 69, 19, 9, "hal_glas", CENTRAAL_HALL_STOREYS, Vector2i(83, 69), [Vector2i(77, 69), Vector2i(89, 69)])
	block(80, 70, 7, 3, "kantoor_glas", 3, {"front": "N", "gf": ["verd_vliesgevel"], "gf_side": "verd_vliesgevel",
		"gf_corner": "verd_vliesgevel_hoek", "upper": ["verd_vliesgevel"], "upper_corner": "verd_vliesgevel_hoek", "roof": "flat"})
	# half a metre in front of the hall: on the glass wall itself the glass drew over it
	D(83 * 4 + 2.0, 69 * 4.0 - 0.5, CENTRAAL_HALL_STOREYS * 3.0 - 3.9, "tekst/tekst_den_haag_centraal", "N")
	D(83 * 4 + 2.0, 69 * 4.0, 0.0, "luifels/luifel_glas", "N")
	D(77 * 4 + 2.0, 69 * 4.0, 0.0, "luifels/luifel_glas", "N")
	D(89 * 4 + 2.0, 69 * 4.0, 0.0, "luifels/luifel_glas", "N")
	_fill(72, 69, 73, 90, "plein/plein_tegels")
	_fill(93, 69, 94, 90, "plein/plein_tegels")
	# the square
	# bicycle racks in short rows with room to walk between them, not one long block
	for x in range(73, 80):
		if x % 3 != 1:
			Pr(x * 4 + 2.0, 66 * 4 + 2.0, "fietsen/fietsenrek_vol" if x % 4 else "fietsen/fietsenrek", "S")
		elif x % 2 == 0:
			Pr(x * 4 + 2.0, 67 * 4 + 2.0, "fietsen/fietsnietje", "S")
	for x in range(87, 94):
		if x % 3 != 1:
			Pr(x * 4 + 2.0, 67 * 4 + 2.0, "fietsen/fietsenrek_vol" if x % 5 else "fietsen/fietsenrek", "S")
	for x in range(80, 87):
		_g(x, 64, "parkeren/parkeerstrook_langs", "E")
	Pr(80 * 4 + 1.0, 64 * 4 + 1.0, "borden/bord_parkeren", "E")
	# the Zebraklok (a node of its own: scripts/world/zebra_clock.gd, placed by _zebra_clock)
	_taken[Vector2i(floori(ZEBRA_CLOCK_AT.x / 4.0), floori(ZEBRA_CLOCK_AT.y / 4.0))] = true
	Pr(90 * 4.0, 63 * 4.0, "straat/kiosk")
	Pr(76 * 4.0, 63 * 4.0, "ov/reclamezuil")
	for x in [75, 81, 87, 93]:
		Pr(x * 4 + 2.0, 65 * 4 + 2.0, "verlichting/lantaarn_modern")
	# towers behind the station
	_fill(74, 78, 92, 90, "plein/plein_tegels")
	# the Hoftoren: a slender glass tower of 40 storeys with a spire
	block(74, 80, 3, 3, "kantoor_glas", HOFTOREN_STOREYS, {"front": "N", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_vliesgevel"], "upper_corner": "verd_vliesgevel_hoek", "roof": "flat"})
	B(75, HOFTOREN_STOREYS, 81, "kantoor_glas/kantoor_glas_dak_installatie", "S")
	B(75, HOFTOREN_STOREYS + 1, 81, "overig/radiotoren_segment", "S")
	B(75, HOFTOREN_STOREYS + 2, 81, "overig/radiotoren_top", "S")
	places["hoftoren"] = Vector2(75 * 4.0 + 2.0, 81 * 4.0 + 2.0)
	# the twin towers of the Ministeries van Justitie en Veiligheid and Binnenlandse Zaken,
	# joined by a footbridge (three wide: the platforms of the railway run on between them)
	for tx in [79, 86]:
		block(tx, 80, 3, 4, "kantoor_beton", MINISTRY_TOWER_STOREYS, {"front": "N", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
			"upper": ["verd_band", "verd_raam_groot"], "upper_corner": "verd_band_hoek", "roof": "flat"})
		B(tx + 1, MINISTRY_TOWER_STOREYS, 81, "kantoor_beton/kantoor_beton_dak_installatie", "S")
		B(tx + 1, MINISTRY_TOWER_STOREYS, 82, "kantoor_beton/kantoor_beton_dak_installatie", "S")
		D(tx * 4 + 6.0, 80 * 4.0, 4.5, "tekst/tekst_ministerie_justitie_en_veiligheid" if tx == 79 else "tekst/tekst_ministerie_binnenlandse_zaken", "N")
		D(tx * 4 + 6.0, 80 * 4.0, MINISTRY_TOWER_STOREYS * 3.0 - 4.0, "gevel/vlag_nl", "N")
		_entrance_flags(tx * 4 + 6.0, 80 * 4.0, "N")
	for x in range(82, 86):
		G(x, 81, "brug/loopbrug_overdekt", "E", 15)
	places["ministerie_van_justitie"] = Vector2(80 * 4.0 + 2.0, 80 * 4.0)
	block(90, 80, 3, 4, "luxe_appartement", 11, {"front": "N", "gf": ["bg_glas", "bg_lobby", "bg_glas"], "gf_side": "bg_glas",
		"gf_corner": "bg_glas_hoek", "upper": ["verd_terras", "verd_balkons", "verd_glas"], "upper_corner": "verd_balkons_hoek", "roof": "none"})
	for x in range(90, 93):
		for z in range(80, 84):
			var e := _edge(_sides(x, z, 90, 80, 3, 4))
			B(x, 11, z, "luxe_appartement/luxe_appartement_penthouse_" + e[0], e[1])
	B(91, 12, 81, "luxe_appartement/luxe_appartement_dak_terras", "N")
	_de_resident()
	_trees([Vector2i(78, 79), Vector2i(89, 79)], ["bomen/plataan", "bomen/linde"])
	for x in [76, 88]:
		Pr(x * 4 + 2.0, 79 * 4 + 2.0, "straat/bank_beton", "S")
	for x in [74, 79]:
		D(x * 4 + 6.0, 80 * 4.0, 0.0, "luifels/luifel_kantoor", "N")
		D(x * 4 + 6.0, 80 * 4.0, 0.0, "deuren/draaideur", "N")
	places["centraal"] = Vector2(83 * 4.0, 64 * 4.0)


## Where the Zebraklok stands on the square before Centraal Station (world metres x, z)
## and its turn (degrees round the vertical: one face looks along the square).
const ZEBRA_CLOCK_AT := Vector2(84 * 4.0, 62 * 4 + 2.0)
const ZEBRA_CLOCK_TURN := 0.0


## The Zebraklok on the square before Centraal Station (Jaap Karman, 1977): a node with
## scripts/world/zebra_clock.gd, which builds the clock and sets its hands to the time.
func _zebra_clock(root: Node3D) -> void:
	var clock := Node3D.new()
	clock.name = "Zebraklok"
	clock.set_script(load("res://scripts/world/zebra_clock.gd"))
	clock.position = Vector3(ZEBRA_CLOCK_AT.x, 0.0, ZEBRA_CLOCK_AT.y)
	clock.rotation_degrees.y = ZEBRA_CLOCK_TURN
	root.add_child(clock)
	clock.owner = root


## Storeys of the glass hall of Centraal Station (3 m each).
const CENTRAAL_HALL_STOREYS := 5
## Storeys of the Hoftoren and of the twin ministry towers behind Centraal Station.
const HOFTOREN_STOREYS := 40
const MINISTRY_TOWER_STOREYS := 34


## Storeys of the Castalia towers (Ministerie van VWS) and of the Muzentoren.
const CASTALIA_STOREYS := 28
const MUZENTOREN_STOREYS := 25
## Storeys of the glass atrium on the Parnassusplein between the Castalia towers.
const PARNASSUS_ATRIUM_STOREYS := 6


## De Resident behind the towers (x 75..82, z 86..89): Castalia, the Ministerie van VWS,
## two slender light towers each crowned with two canal-house spout gables (front and back,
## a saddle roof between), as Michael Graves drew them after the Hague canal houses; the
## covered Parnassusplein between them, a glass atrium; and the Muzentoren, a dark brick
## tower with a hipped roof.
func _de_resident() -> void:
	for tower_x in [75, 79]:
		block(tower_x, 86, 2, 3, "klassiek_geel", CASTALIA_STOREYS, {"front": "N", "gf": ["bg_deur", "bg_raam"], "gf_side": "bg_raam",
			"gf_corner": "bg_raam_hoek", "upper": ["verd_raam", "verd_drie_ramen"], "upper_corner": "verd_raam_hoek", "roof": "none"})
		for x in [tower_x, tower_x + 1]:
			B(x, CASTALIA_STOREYS, 86, "klassiek_geel/klassiek_geel_gevel_tuit", "N")
			B(x, CASTALIA_STOREYS, 87, "klassiek_geel/klassiek_geel_dak_zadel", "E")
			B(x, CASTALIA_STOREYS, 88, "klassiek_geel/klassiek_geel_gevel_tuit", "S")
	_tall_hall(77, 86, 2, 3, "hal_glas", PARNASSUS_ATRIUM_STOREYS, Vector2i(77, 86))
	D(77 * 4.0 + 4.0, 86 * 4.0, 4.5, "tekst/tekst_ministerie_vws", "N")
	D(77 * 4.0 + 4.0, 86 * 4.0, PARNASSUS_ATRIUM_STOREYS * 3.0 + 1.0, "gevel/vlag_nl", "N")
	_entrance_flags(77 * 4.0 + 4.0, 86 * 4.0, "N")
	places["de_resident"] = Vector2(78 * 4.0, 87 * 4.0)
	places["castalia"] = Vector2(76 * 4.0, 86 * 4.0)
	block(81, 87, 2, 2, "klassiek_donker", MUZENTOREN_STOREYS, {"front": "N", "gf": ["bg_deur"], "gf_side": "bg_raam", "gf_corner": "bg_raam_hoek",
		"upper": ["verd_raam"], "upper_corner": "verd_raam_hoek", "roof": "sloped"})
	places["muzentoren"] = Vector2(82 * 4.0, 88 * 4.0)
	_amare()


## Amare, the theatre, concert hall and conservatory, at the Dirigentplein beside De
## Resident (across the railway from the Muzentoren): a big modern block with bands of
## light, its entrance and name on the square, which has trees, benches and a sculpture.
func _amare() -> void:
	block(89, 84, 6, 6, "museum_modern", 5, {"front": "W", "gf": ["bg_entree", "bg_dicht", "bg_entree"], "gf_side": "bg_dicht",
		"gf_corner": "bg_entree_hoek", "upper": ["verd_lichtstrook", "verd_dicht"], "upper_corner": "verd_lichtstrook_hoek", "roof": "flat"})
	D(89 * 4.0, 86 * 4 + 2.0, 3.5, "tekst/tekst_theater", "W")
	D(89 * 4.0, 87 * 4.0, 9.0, "tekst/lichtreclame_theater", "W")
	_fill(85, 84, 88, 89, "plein/plein_natuursteen")
	_trees([Vector2i(85, 84), Vector2i(85, 89), Vector2i(88, 89)], ["bomen/plataan", "bomen/jonge_boom"])
	Pr(86 * 4 + 2.0, 86 * 4 + 2.0, "standbeelden/kunstwerk_modern", "W")
	for z in [85, 88]:
		Pr(87 * 4 + 2.0, z * 4 + 2.0, "straat/bank_beton", "E")
	Pr(88 * 4 + 2.0, 84 * 4 + 2.0, "verlichting/lantaarn_modern")
	places["amare"] = Vector2(89 * 4.0, 87 * 4.0)
	places["dirigentplein"] = Vector2(86 * 4.0 + 2.0, 87 * 4.0)


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


## The neighbourhood south of the Schenkkade (z 99..105): closed blocks of flats beside
## the Koningskade, offices and a gallery flat in line with the Beatrixkwartier, closed
## blocks at the Laan van NOI and a green end with an apartment block; also the paving
## under the viaduct where the squares north of it run up to it.
func _schenkkade() -> void:
	_fill(72, 91, 94, 91, "plein/plein_tegels")
	_fill(X6 + 3, 91, XC - 3, 91, "plein/plein_tegels")
	var south := ZS + 3
	var depth := 7
	var flats := {"gf": ["bg_portiek", "bg_raam"], "upper": ["verd_raam", "verd_balkon"], "back": ["verd_raam"], "roof_extra": ["dak_schuin_dakkapel"]}
	var dark := {"gf": ["bg_raam", "bg_deur", "bg_winkel_luifel"], "upper": ["verd_raam", "verd_drie_ramen"], "back": ["verd_raam"],
		"roof_extra": ["dak_schuin_schoorsteen", "dak_schuin_dakkapel"]}
	ring(72, south, 11, depth, "jaren30", 4, flats)
	ring(84, south, 11, depth, "klassiek_donker", 4, dark)
	_fill(X6 + 3, south, XC - 3, south + depth - 1, "plein/plein_tegels")
	block(X6 + 4, south, 7, 5, "kantoor_modern", 7, {"front": "N", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_lamellen", "verd_raam_groot"], "upper_corner": "verd_lamellen_hoek", "roof": "flat"})
	_company_name(X6 + 4, 7, south, "N", 7, 1)
	block(X6 + 13, south, 5, 5, "kantoor_beton", 11, {"front": "N", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_band", "verd_raam_groot"], "upper_corner": "verd_band_hoek", "roof": "flat"})
	block(X6 + 20, south + 1, 9, 3, "jaren60", 5, {"front": "N", "gf": ["bg_deur", "bg_berging", "bg_raam"], "gf_side": "bg_raam",
		"gf_corner": "bg_raam_hoek", "upper": ["verd_galerij_deur", "verd_galerij_raam"], "upper_corner": "verd_galerij_raam_hoek", "roof": "flat"})
	_trees([Vector2i(X6 + 12, south + 1), Vector2i(X6 + 19, south + 5), Vector2i(X6 + 24, south + 5), Vector2i(X6 + 8, south + 6)], ["bomen/plataan", "bomen/linde"])
	for x in [X6 + 5, X6 + 15]:
		Pr(x * 4 + 2.0, (south + 6) * 4 + 2.0, "straat/bank_beton", "S")
	ring(XC + 3, south, 10, depth, "klassiek_donker", 4, dark)
	ring(XC + 14, south, 9, depth, "jaren30", 4, flats)
	_fill(XD + 3, south, X_END - 1, south + depth - 1, "natuur/gras")
	block(XD + 5, south + 1, 7, 3, "appartement_modern", 9, {"front": "N", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_balkon", "verd_loggia", "verd_glas"], "upper_corner": "verd_balkon_hoek", "roof": "flat"})
	# a DERREK under the flats, its carts on the pavement before it
	_fill(XD + 5, south, XD + 11, south, "plein/plein_tegels")
	_supermarket(XD + 5, south + 1, 7, "appartement_modern", "derrek", "rood")
	_trees([Vector2i(XD + 4, south + 5), Vector2i(XD + 13, south + 2), Vector2i(XD + 16, south + 5), Vector2i(XD + 19, south + 1)], ["bomen/eik", "bomen/linde", "bomen/kastanje"])
	places["schenkkade"] = Vector2(112 * 4.0, ZS * 4.0)
	_schenkkade_west(south, depth, flats, dark)


## The Schenkkade west of the Koningskade, on the south side of the singel: gallery flats
## and trees on the strip along the quay; south of the street closed blocks of flats and,
## in the middle, a square with a church and a playing green.
func _schenkkade_west(south: int, depth: int, flats: Dictionary, dark: Dictionary) -> void:
	var gallery := {"front": "S", "gf": ["bg_deur", "bg_berging", "bg_raam"], "gf_side": "bg_raam",
		"gf_corner": "bg_raam_hoek", "upper": ["verd_galerij_deur", "verd_galerij_raam"], "upper_corner": "verd_galerij_raam_hoek", "roof": "flat"}
	for x in [6, 28, 50]:
		block(x, SINGEL_END + 2, 11, 2, "jaren60", 3, gallery)
	_trees([Vector2i(3, 93), Vector2i(20, 93), Vector2i(24, 94), Vector2i(42, 93), Vector2i(46, 94), Vector2i(64, 93)], ["bomen/plataan", "bomen/linde"])
	ring(2, south, 10, depth, "klassiek_donker", 4, dark)
	ring(13, south, 10, depth, "jaren30", 4, flats)
	_fill(X2 + 3, south, X3 - 2, south + depth - 1, "plein/plein_tegels")
	block(X2 + 5, south + 1, 4, 5, "kerk_modern", 2, {"front": "E", "gf": ["bg_entree", "bg_dicht"], "gf_side": "bg_dicht", "gf_corner": "bg_entree_hoek",
		"upper": ["verd_spleet", "verd_kruis"], "upper_corner": "verd_spleet_hoek", "roof": "flat"})
	_fill(X2 + 12, south + 1, X3 - 3, south + depth - 2, "natuur/gras")
	_trees([Vector2i(X2 + 13, south + 2), Vector2i(X2 + 19, south + 2), Vector2i(X2 + 16, south + 4)], ["bomen/eik", "bomen/kastanje"])
	for x in [X2 + 11, X2 + 17]:
		Pr(x * 4 + 2.0, (south + depth - 1) * 4 + 2.0, "straat/bank_beton", "N")
	ring(X3 + 3, south, 7, depth, "jaren30", 4, flats)
	ring(X3 + 11, south, 7, depth, "klassiek_donker", 4, dark)
	places["schenkkade_west"] = Vector2(36 * 4.0, ZS * 4.0)


## Closed blocks of flats filling a block of the south of the town (columns of `w` tiles at
## x0, the block `SOUTH_BLOCK_DEPTH` deep from z0): two on two if it is wide enough, with a
## strip of grass and a few trees between them. The styles take turns.
func _housing_block(x0: int, z0: int, w: int, styles: Array) -> void:
	var columns := 2 if w >= 19 else 1
	var ring_width := (w - 2 - (columns - 1)) / columns
	var ring_depth := (SOUTH_BLOCK_DEPTH - 3) / 2
	var style_index := 0
	for row in 2:
		for column in columns:
			var style: String = styles[style_index % styles.size()]
			style_index += 1
			var ring_x := x0 + 1 + column * (ring_width + 1)
			var ring_z := z0 + 1 + row * (ring_depth + 1)
			ring(ring_x, ring_z, ring_width, ring_depth, style, 4, _housing_options(style))
			# a supermarket on the street side of the block's first ring, where its style has
			# the storefronts (the brands take turns through the town)
			if row == 0 and column == 0 and _has(style + "/" + style + "_bg_derrek_raam"):
				var brand: String = SUPERMARKET_BRANDS[_supermarket_count % SUPERMARKET_BRANDS.size()]
				_supermarket(ring_x, ring_z, mini(ring_width, SUPERMARKET_MOST_CELLS), style, brand, SUPERMARKET_CARTS[brand])
				_supermarket_count += 1
	_trees([Vector2i(x0 + 2, z0 + ring_depth + 1), Vector2i(x0 + w - 3, z0 + ring_depth + 1)], ["bomen/linde", "bomen/plataan"])


func _housing_options(style: String) -> Dictionary:
	if style == "jaren30":
		return {"gf": ["bg_portiek", "bg_raam"], "upper": ["verd_raam", "verd_balkon"], "back": ["verd_raam"], "roof_extra": ["dak_schuin_dakkapel"]}
	if style == "klassiek_donker":
		return {"gf": ["bg_raam", "bg_deur", "bg_winkel_luifel"], "upper": ["verd_raam", "verd_drie_ramen"], "back": ["verd_raam"],
			"roof_extra": ["dak_schuin_schoorsteen", "dak_schuin_dakkapel"]}
	return {"gf": ["bg_raam", "bg_deur"], "upper": ["verd_raam"], "back": ["verd_raam"]}


## The Schilderswijk (x 0..68, z 109..175), west of the Koningskade: closed blocks of flats
## round a market square, a school and a church, and a park with a pond at the south end.
func _schilderswijk() -> void:
	var first := ZR1 + 2
	var second := ZR2 + 2
	var third := ZR3 + 2
	var west_width := X2
	var middle := X2 + 2
	var middle_width := X3 - X2 - 2
	var east := X3 + 2
	var east_width := X5 - X3 - 2
	_housing_block(0, first, west_width, ["klassiek_donker", "jaren30", "klassiek_rood", "jaren30"])
	_housing_block(middle, first, middle_width, ["jaren30", "klassiek_rood", "klassiek_donker", "jaren30"])
	_housing_block(east, first, east_width, ["klassiek_geel", "jaren30", "jaren30", "klassiek_donker"])
	_housing_block(0, second, west_width, ["jaren30", "klassiek_geel", "klassiek_donker", "jaren30"])
	# the market square with shops along its north side
	_fill(middle + 1, second + 1, middle + middle_width - 2, second + SOUTH_BLOCK_DEPTH - 2, "plein/plein_klinkers")
	block(middle + 1, second + 1, middle_width - 2, 3, "jaren30", 3, {"front": "S", "gf": ["bg_winkel_luifel", "bg_raam"], "gf_side": "bg_raam",
		"gf_corner": "bg_raam_hoek", "upper": ["verd_raam"], "upper_corner": "verd_raam_hoek", "roof": "flat"})
	_trees([Vector2i(middle + 3, second + 7), Vector2i(middle + 9, second + 7), Vector2i(middle + 15, second + 7),
		Vector2i(middle + 3, second + 16), Vector2i(middle + 9, second + 16), Vector2i(middle + 15, second + 16)], ["bomen/plataan", "bomen/linde"])
	for x in [middle + 5, middle + 11]:
		Pr(x * 4 + 2.0, (second + 12) * 4 + 2.0, "straat/bank_beton", "S")
	Pr((middle + 10) * 4.0, (second + 11) * 4.0, "standbeelden/buste", "S")
	places["schilderswijk"] = Vector2((middle + 10) * 4.0, (second + 11) * 4.0)
	# the school and its playground
	block(east + 2, second + 2, east_width - 4, 4, "school", 2, {"front": "S", "gf": ["bg_entree", "bg_raam"], "gf_side": "bg_raam", "gf_corner": "bg_raam_hoek",
		"upper": ["verd_raam"], "upper_corner": "verd_raam_hoek", "roof": "flat"})
	_fill(east + 3, second + 8, east + east_width - 4, second + 15, "natuur/speeltuin_zand")
	var play := ["speeltuin/glijbaan", "speeltuin/schommel", "speeltuin/zandbak", "speeltuin/klimrek"]
	for play_index in play.size():
		Pr((east + 5 + (play_index % 2) * 6) * 4.0 + 2.0, (second + 10 + (play_index / 2) * 3) * 4.0 + 2.0, play[play_index], "S")
	# the park: a pond, a path through it to both streets
	_fill(1, third + 1, west_width - 2, third + SOUTH_BLOCK_DEPTH - 2, "natuur/gras")
	_pond(4, third + 3, 19, third + 11)
	for z in range(third + 1, third + 19):
		_g(21, z, "natuur/pad_grind", "S")
	_kerb_path(21, third, "N")
	_trees([Vector2i(2, third + 2), Vector2i(20, third + 3), Vector2i(3, third + 14), Vector2i(9, third + 16), Vector2i(15, third + 14), Vector2i(19, third + 17)],
		["bomen/treurwilg", "bomen/eik", "bomen/kastanje", "bomen/linde"])
	for x in [7, 14]:
		Pr(x * 4 + 2.0, (third + 13) * 4 + 2.0, "straat/bank_hout", "S")
	# the church on its own square, flats beside it
	_fill(middle + 1, third + 1, middle + middle_width - 2, third + 9, "plein/plein_tegels")
	block(middle + 7, third + 3, 4, 5, "kerk_baksteen", 2, {"front": "N", "gf": ["bg_spitsraam"], "gf_side": "bg_spitsraam", "gf_corner": "bg_spitsraam_hoek",
		"upper": ["verd_spitsraam"], "upper_corner": "verd_spitsraam_hoek", "roof": "sloped"})
	tower(middle + 8, third + 2, "kerk_baksteen", ["toren_portaal", "toren_raam", "toren_galmgat", "toren_spits_onder", "toren_spits_boven"], "N")
	ring(middle + 1, third + 11, middle_width - 2, 9, "klassiek_rood", 4, _housing_options("klassiek_rood"))
	_housing_block(east, third, east_width, ["jaren30", "klassiek_donker", "klassiek_geel", "jaren30"])


## Storeys of Het Strijkijzer, and of its narrower top.
const STRIJKIJZER_STOREYS := 42
const STRIJKIJZER_TOP_STOREYS := 4


## Het Strijkijzer: a slender residential tower (2 x 5 cells) on the office square in Laak,
## with a narrower glass top that reads as the point of the iron.
func _strijkijzer(x0: int, z0: int) -> void:
	block(x0, z0, 2, 5, "appartement_modern", STRIJKIJZER_STOREYS, {"front": "S", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas",
		"gf_corner": "bg_glas_hoek", "upper": ["verd_glas", "verd_balkon", "verd_glas"], "upper_corner": "verd_balkon_hoek", "roof": "flat"})
	block(x0, z0 + 1, 2, 3, "appartement_modern", STRIJKIJZER_TOP_STOREYS, {"front": "S", "y0": STRIJKIJZER_STOREYS, "gf": ["verd_glas"],
		"gf_side": "verd_glas", "gf_corner": "verd_glas_hoek", "upper": ["verd_glas"], "upper_corner": "verd_glas_hoek", "roof": "flat"})
	places["strijkijzer"] = Vector2(x0 * 4.0 + 4.0, z0 * 4.0 + 10.0)


## Laak (x 71..127, z 109..175), between the Koningskade and the Laan van NOI: gallery flats
## with parking, the university of applied sciences with its square, offices with Het Strijkijzer, and flats.
func _laakkwartier() -> void:
	var first := ZR1 + 2
	var second := ZR2 + 2
	var third := ZR3 + 2
	var west := X5 + 2
	var west_width := X6 - X5 - 2
	var middle := X6 + 2
	var middle_width := XB - X6 - 2
	var east := XB + 2
	var east_width := XC - XB - 2
	var slab := {"front": "S", "gf": ["bg_deur", "bg_berging", "bg_raam"], "gf_side": "bg_raam",
		"gf_corner": "bg_raam_hoek", "upper": ["verd_galerij_deur", "verd_galerij_raam"], "upper_corner": "verd_galerij_raam_hoek", "roof": "flat"}
	for offset: int in [1, 11]:
		var z := first + offset
		block(west + 2, z, west_width - 4, 3, "jaren60", 5, slab)
		for x in range(west + 1, west + west_width - 1):
			_g(x, z + 4, "parkeren/parkeerplaats_rijbaan", "E")
			_g(x, z + 5, "parkeren/parkeervak_haaks" if x % 5 else "parkeren/parkeervak_laadpaal", "N")
		_kerb_path(west, z + 4, "W")
	_housing_block(middle, first, middle_width, ["jaren30", "klassiek_donker"])
	_housing_block(east, first, east_width, ["klassiek_rood", "jaren30"])
	# the university and its square
	_fill(west + 1, second + 1, west + west_width - 2, second + SOUTH_BLOCK_DEPTH - 2, "plein/plein_tegels")
	block(west + 3, second + 2, west_width - 6, 9, "hogeschool", 4, {"front": "S", "gf": ["bg_entree", "bg_glas", "bg_kolonnade"], "gf_side": "bg_glas",
		"gf_corner": "bg_kolonnade_hoek", "upper": ["verd_band", "verd_lamellen", "verd_raam_groot"], "upper_corner": "verd_lamellen_hoek", "roof": "flat"})
	_trees([Vector2i(west + 4, second + 14), Vector2i(west + 10, second + 16), Vector2i(west + 16, second + 14), Vector2i(west + 21, second + 16)], ["bomen/plataan", "bomen/linde"])
	for x in [west + 7, west + 13, west + 19]:
		Pr(x * 4 + 2.0, (second + 13) * 4 + 2.0, "straat/bank_beton", "S")
	places["laakkwartier"] = Vector2((west + west_width / 2) * 4.0, (second + 10) * 4.0)
	# offices on a square
	_fill(middle + 1, second + 1, middle + middle_width - 2, second + SOUTH_BLOCK_DEPTH - 2, "plein/plein_tegels")
	block(middle + 2, second + 2, middle_width - 4, 7, "kantoor_modern", 8, {"front": "S", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_lamellen", "verd_raam_groot"], "upper_corner": "verd_lamellen_hoek", "roof": "flat"})
	_company_name(middle + 2, middle_width - 4, second + 9, "S", 8, 2)
	# Het Strijkijzer stands free on the south half of the square
	var iron := Vector2i(middle + middle_width / 2 - 1, second + 12)
	_strijkijzer(iron.x, iron.y)
	_trees([Vector2i(middle + 2, second + 12), Vector2i(middle + 2, second + 17), Vector2i(middle + middle_width - 3, second + 12),
		Vector2i(middle + middle_width - 3, second + 17)], ["bomen/plataan"])
	for x in [iron.x - 2, iron.x + 3]:
		Pr(x * 4 + 2.0, (iron.y + 2) * 4 + 2.0, "straat/bank_beton", "W" if x < iron.x else "E")
	_housing_block(east, second, east_width, ["klassiek_donker", "jaren30"])
	_housing_block(west, third, west_width, ["jaren30", "klassiek_geel", "klassiek_donker", "jaren30"])
	# an apartment tower in the green
	_fill(middle + 1, third + 1, middle + middle_width - 2, third + SOUTH_BLOCK_DEPTH - 2, "natuur/gras")
	block(middle + 3, third + 6, middle_width - 6, 4, "appartement_modern", 11, {"front": "N", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_balkon", "verd_loggia", "verd_glas"], "upper_corner": "verd_balkon_hoek", "roof": "flat"})
	# an ALFRED STEYHN in its ground floor, a paved forecourt to the street
	_fill(middle + 3, third + 1, middle + middle_width - 4, third + 5, "plein/plein_tegels")
	_supermarket(middle + 3, third + 6, middle_width - 6, "appartement_modern", "alfred_steyhn", "blauw")
	_trees([Vector2i(middle + 2, third + 2), Vector2i(middle + 2, third + 5), Vector2i(middle + 3, third + 15), Vector2i(middle + 10, third + 17)], ["bomen/eik", "bomen/linde", "bomen/kastanje"])
	_housing_block(east, third, east_width, ["jaren30", "klassiek_rood"])


## A paved yard of an industrial lot of the Binckhorst (w x SOUTH_BLOCK_DEPTH cells) with
## its gate on the street to the north.
func _industrial_yard(x0: int, z0: int, w: int) -> void:
	_fill(x0 + 1, z0 + 1, x0 + w - 2, z0 + SOUTH_BLOCK_DEPTH - 2, "plein/plein_tegels")
	_kerb_path(x0 + w / 2, z0, "N")


## Industrial props along a yard: one every four cells from x, in row z (and z + 1).
func _yard_props(x: int, x_end: int, z: int, kinds: Array) -> void:
	for index in kinds.size():
		var spot: int = x + index * 4
		if spot < x_end:
			Pr(spot * 4 + 2.0, (z + index % 2) * 4 + 2.0, kinds[index], "E" if index % 2 else "S")


## A car park in rows z (spaces facing south), z + 1 (the aisle) and z + 2 (spaces facing
## north), from column x0 to x1.
func _car_park(x0: int, x1: int, z: int) -> void:
	for x in range(x0, x1 + 1):
		_g(x, z, "parkeren/parkeervak_haaks", "S")
		_g(x, z + 1, "parkeren/parkeerplaats_rijbaan", "E")
		_g(x, z + 2, "parkeren/parkeervak_haaks" if x % 6 else "parkeren/parkeervak_laadpaal", "N")


## A hall of w x d cells and `storeys` storeys of an industrial style, with `roof` (a roof
## tile of the style, e.g. "dak_ton", "dak_shed", "dak_lichtstraten") on every cell.
func _industrial_hall(x0: int, z0: int, w: int, d: int, style: String, storeys: int, front: String, roof: String, roof_turn := "S",
		gf := ["bg_roldeur", "bg_dock", "bg_loopdeur"], upper := ["verd_wand", "verd_lichtstraat", "verd_logo"]) -> void:
	block(x0, z0, w, d, style, storeys, {"front": front, "gf": gf, "gf_side": "bg_dicht", "gf_corner": "bg_dicht_hoek",
		"upper": upper, "upper_corner": "verd_lichtstraat_hoek", "roof": "none"})
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			B(x, storeys, z, style + "/" + style + "_" + roof, roof_turn)


## A round brick factory chimney of `pieces` storeys at cell (x, z), from storey y0.
func _factory_chimney(x: int, z: int, pieces: int, y0 := 0) -> void:
	B(x, y0, z, "overig/fabrieksschoorsteen_voet", "S")
	for level in range(1, pieces - 1):
		B(x, y0 + level, z, "overig/fabrieksschoorsteen_segment", "S")
	B(x, y0 + pieces - 1, z, "overig/fabrieksschoorsteen_top", "S")


## Storeys of the halls, offices and factories of the Binckhorst (3 m each): a warehouse or
## a hangar 9 m, business units 6 m, the CaballeroFabriek 12 m.
const SHED_STOREYS := 3
const UNIT_STOREYS := 2
const CABALLERO_STOREYS := 4


## The Binckhorst (x 130..175, z 109..175), east of the Laan van NOI, the industrial estate
## after what stands there: the CaballeroFabriek (the 1953 tobacco factory, now studios),
## the Haags Busmuseum in a hall with a sawtooth roof beside business units, the Fokker
## Terminal (the aviation school of 1961 with its hangar of 9 m, before a big car park), the
## Fokkerhaven with the old Paulussen paint factory and its chimney, a distribution
## warehouse with a concrete plant, and Kasteel Binckhorst on an island in its park.
func _binckhorst() -> void:
	var west := XC + 2
	var west_width := XD - XC - 2
	var east := XD + 2
	var east_width := X_END - XD - 1
	var first := ZR1 + 2
	var second := ZR2 + 2
	var third := ZR3 + 2
	# CaballeroFabriek: a long factory with tall windows, a wing behind it, parking
	_industrial_yard(west, first, west_width)
	block(west + 2, first + 3, 16, 5, "fabriek", CABALLERO_STOREYS, {"front": "N", "gf": ["bg_poort", "bg_kantoor", "bg_loopdeur", "bg_kantoor"],
		"gf_side": "bg_dicht", "gf_corner": "bg_dicht_hoek", "upper": ["verd_raam_hoog"], "upper_corner": "verd_raam_hoog_hoek", "roof": "flat"})
	block(west + 2, first + 8, 5, 8, "fabriek", SHED_STOREYS, {"front": "E", "gf": ["bg_roldeur", "bg_dock", "bg_loopdeur"],
		"gf_side": "bg_dicht", "gf_corner": "bg_dicht_hoek", "upper": ["verd_raam_hoog", "verd_wand"], "upper_corner": "verd_raam_hoog_hoek", "roof": "flat"})
	_car_park(west + 9, west + west_width - 5, first + 11)
	# the Binckhorsthaven along its east and south side, with quays (the real factory lies
	# on the water)
	var harbour := {}
	for z in range(first + 1, first + SOUTH_BLOCK_DEPTH - 2):
		for x in [west + west_width - 3, west + west_width - 2]:
			harbour[Vector2i(x, z)] = true
	for x in range(west + 2, west + west_width - 1):
		for z in [first + SOUTH_BLOCK_DEPTH - 4, first + SOUTH_BLOCK_DEPTH - 3]:
			harbour[Vector2i(x, z)] = true
	_water(harbour)
	places["caballerofabriek"] = Vector2((west + 10) * 4.0, (first + 3) * 4.0)
	# Haags Busmuseum and business units
	_industrial_yard(east, first, east_width)
	_industrial_hall(east + 2, first + 3, 10, 7, "loods_steen", SHED_STOREYS, "N", "dak_shed", "S",
		["bg_roldeur", "bg_loopdeur", "bg_roldeur", "bg_kantoor"], ["verd_lichtstraat", "verd_wand"])
	for row in [first + 3, first + 9]:
		block(east + 14, row, 6, 3, "bedrijfspand", UNIT_STOREYS, {"front": "N", "gf": ["bg_roldeur", "bg_kantoor"], "gf_side": "bg_dicht",
			"gf_corner": "bg_kantoor_hoek", "upper": ["verd_logo", "verd_lichtstraat"], "upper_corner": "verd_lichtstraat_hoek", "roof": "flat"})
	_yard_props(east + 2, east + east_width - 2, first + 13, ["industrie/zeecontainer", "industrie/heftruck", "industrie/pallet_stapel", "industrie/zeecontainer_stapel"])
	places["busmuseum"] = Vector2((east + 7) * 4.0, (first + 3) * 4.0)
	# Fokker Terminal: the school on the street, the hangar behind it, a big car park
	_industrial_yard(west, second, west_width)
	block(west + 2, second + 2, 17, 2, "kantoor_80", SHED_STOREYS, {"front": "N", "gf": ["bg_entree", "bg_glas", "bg_glas"], "gf_side": "bg_glas",
		"gf_corner": "bg_glas_hoek", "upper": ["verd_band", "verd_raam_groot"], "upper_corner": "verd_band_hoek", "roof": "flat"})
	_industrial_hall(west + 2, second + 4, 17, 9, "loods_staal", SHED_STOREYS, "N", "dak_ton", "E", ["bg_dicht", "bg_roldeur"], ["verd_wand", "verd_lichtstraat"])
	_car_park(west + 2, west + west_width - 3, second + 14)
	_car_park(west + 2, west + west_width - 3, second + 17)
	places["fokker_terminal"] = Vector2((west + 10) * 4.0, (second + 2) * 4.0)
	# the Fokkerhaven: a basin with quays, the Paulussen factory with its chimney beside it
	_industrial_yard(east, second, east_width)
	var basin := {}
	for x in range(east + 2, east + east_width - 2):
		for z in range(second + 11, second + 16):
			basin[Vector2i(x, z)] = true
	_water(basin)
	block(east + 2, second + 3, 8, 5, "fabriek", SHED_STOREYS, {"front": "N", "gf": ["bg_poort", "bg_kantoor", "bg_loopdeur"], "gf_side": "bg_dicht",
		"gf_corner": "bg_dicht_hoek", "upper": ["verd_raam_hoog"], "upper_corner": "verd_raam_hoog_hoek", "roof": "flat"})
	_factory_chimney(east + 11, second + 5, 8)
	block(east + 13, second + 3, 6, 4, "loods_steen", UNIT_STOREYS, {"front": "N", "gf": ["bg_kantoor", "bg_loopdeur"], "gf_side": "bg_dicht",
		"gf_corner": "bg_kantoor_hoek", "upper": ["verd_lichtstraat"], "upper_corner": "verd_lichtstraat_hoek", "roof": "flat"})
	for x in [east + 4, east + 9, east + 15]:
		Pr(x * 4 + 2.0, (second + 9) * 4 + 2.0, "terras/terras_set_parasol", "S")
	places["fokkerhaven"] = Vector2((east + 10) * 4.0, (second + 13) * 4.0)
	# a distribution warehouse and a concrete plant with silos
	_industrial_yard(west, third, west_width)
	_industrial_hall(west + 2, third + 3, 12, 9, "magazijn", SHED_STOREYS, "N", "dak_lichtstraten", "S",
		["bg_dock", "bg_dock", "bg_roldeur", "bg_kantoor"], ["verd_wand", "verd_logo"])
	block(west + 15, third + 11, 5, 4, "fabriek", UNIT_STOREYS, {"front": "N", "gf": ["bg_roldeur", "bg_kantoor"], "gf_side": "bg_dicht",
		"gf_corner": "bg_dicht_hoek", "upper": ["verd_wand"], "upper_corner": "verd_wand_hoek", "roof": "flat"})
	for x in range(west + 15, west + 20, 2):
		for z in [third + 4, third + 7]:
			Pr(x * 4 + 2.0, z * 4 + 2.0, "industrie/silo" if (x + z) % 3 else "industrie/opslagtank", "S")
	_yard_props(west + 2, west + 14, third + 14, ["industrie/zeecontainer_stapel", "industrie/heftruck", "industrie/zeecontainer"])
	# Kasteel Binckhorst on an island in its moat, in the Binckhorstpark; business units south
	_fill(east + 1, third + 1, east + east_width - 2, third + 13, "natuur/gras")
	_pond(east + 5, third + 2, east + 14, third + 11)
	for x in range(east + 7, east + 13):
		for z in range(third + 4, third + 10):
			_g(x, z, "natuur/gras")
	for z in [third + 2, third + 3]:
		_g(east + 9, z, "natuur/pad_grind", "S")   # the way over the moat
	block(east + 8, third + 5, 4, 4, "klassiek_rood", 3, {"front": "N", "gf": ["bg_poort", "bg_raam"], "gf_side": "bg_raam", "upper": ["verd_raam", "verd_dicht"],
		"roof": "battlements"})
	tower(east + 11, third + 5, "kerk_baksteen", ["toren_raam", "toren_spits_onder", "toren_spits_boven"], "N", 3)
	_trees([Vector2i(east + 2, third + 3), Vector2i(east + 3, third + 9), Vector2i(east + 17, third + 4), Vector2i(east + 16, third + 10),
		Vector2i(east + 7, third + 12), Vector2i(east + 13, third + 12)], ["bomen/eik", "bomen/linde", "bomen/treurwilg"])
	places["kasteel_binckhorst"] = Vector2((east + 10) * 4.0, (third + 7) * 4.0)
	_fill(east + 1, third + 14, east + east_width - 2, third + SOUTH_BLOCK_DEPTH - 2, "plein/plein_tegels")
	for x in [east + 2, east + 11]:
		block(x, third + 15, 8, 4, "bedrijfspand", UNIT_STOREYS, {"front": "N", "gf": ["bg_roldeur", "bg_kantoor"], "gf_side": "bg_dicht",
			"gf_corner": "bg_kantoor_hoek", "upper": ["verd_logo", "verd_lichtstraat"], "upper_corner": "verd_lichtstraat_hoek", "roof": "flat"})
	_kerb_path(east + east_width / 2, third, "N")
	places["binckhorst"] = Vector2(XD * 4.0, ZR2 * 4.0)


## The Beatrixkwartier (x 98..127, z 60..91): office towers, an apartment tower and the
## Haagse Hogeschool on a paved square with trees, and a car park.
func _beatrixkwartier() -> void:
	_fill(99, 61, 126, 90, "plein/plein_tegels")
	var glass := {"front": "N", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek", "roof": "flat"}
	var t1 := glass.duplicate()
	t1.merge({"upper": ["verd_vliesgevel", "verd_zonwering"], "upper_corner": "verd_vliesgevel_hoek"})
	block(100, 62, 5, 5, "kantoor_2000", 14, t1)
	_company_name(100, 5, 62, "N", 14, 4)
	B(102, 14, 64, "kantoor_2000/kantoor_2000_dak_installatie", "S")
	var t2 := glass.duplicate()
	t2.merge({"upper": ["verd_lamellen", "verd_raam_groot"], "upper_corner": "verd_lamellen_hoek"})
	block(108, 62, 6, 4, "kantoor_modern", 8, t2)
	_company_name(108, 6, 62, "N", 8, 3)
	var t3 := glass.duplicate()
	# balconies that step from side to side, glass and steel (the towers round Centraal)
	t3.merge({"upper": ["verd_balkon_glas_links", "verd_balkon_glas_rechts", "verd_balkon_metaal", "verd_glas"],
		"upper_corner": "verd_balkon_glas_links_hoek"})
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
	for x in range(108, 114, 2):
		Pr(x * 4 + 2.0, 67 * 4 + 2.0, "fietsen/fietsenrek_vol", "S")
	places["beatrixkwartier"] = Vector2(112 * 4.0, 74 * 4.0)


# ------------------------------------------------------------------ the A12 (Utrechtsebaan)

## Motorway profile across 9 rows (north verge to south verge): [tile, rotation]. The
## right lanes are plain asphalt of the motorway itself (its lines lie on the tiles beside
## them), so they keep its speed limit instead of taking that of the tunnel ahead.
const MW_FLAT := [["snelweg/snelweg_berm_vangrail", "E"], ["snelweg/snelweg_vluchtstrook", "E"], ["snelweg/snelweg_rijstrook_zonder_streep", "E"],
	["snelweg/snelweg_rijstrook_links", "E"], ["snelweg/snelweg_middenberm_beton", "E"], ["snelweg/snelweg_rijstrook_links", "W"],
	["snelweg/snelweg_rijstrook_zonder_streep", "W"], ["snelweg/snelweg_vluchtstrook", "W"], ["snelweg/snelweg_berm_vangrail", "W"]]
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
	_entrance_flags((mx + 4) * 4 + 2.0, (AZ + 5) * 4.0, "S")
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
	_company_name(x0 + 1, 5, 8, "S", 16, 5)
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
		"upper": ["verd_balkon_metaal", "verd_balkon_glas_rechts", "verd_loggia", "verd_balkon_glas_links"], "upper_corner": "verd_balkon_metaal_hoek", "roof": "flat"})
	B(east + 14, 13, 80, "appartement_modern/appartement_modern_dak_daktuin", "S")
	_fill(east + 12, 84, X_END - 1, 89, "plein/plein_tegels")
	_trees([Vector2i(east + 13, 86), Vector2i(east + 17, 87), Vector2i(east + 19, 85)], ["bomen/jonge_boom", "bomen/plataan"])
	places["bezuidenhout_oost"] = Vector2((east + 6) * 4.0, 72 * 4.0)


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


## Styles whose roofs stay bare: churches, museums, the Binnenhof and other monuments,
## halls and structures.
const BARE_ROOF_STYLES := ["kerk_baksteen", "kerk_steen", "kerk_modern", "museum_klassiek", "museum_modern", "herenhuis_1600",
	"overheid", "universiteit", "hallen", "pilaren", "overkapping", "parkeergarage", "overig", "daken"]
## Building groups by what they put on their roofs.
const OFFICE_STYLES := ["kantoor_2000", "kantoor_80", "kantoor_beton", "kantoor_glas", "kantoor_modern", "hogeschool", "school"]
const FLAT_STYLES := ["galerijflat", "jaren60", "appartement_modern", "luxe_appartement", "modern_donker", "modern_hout", "modern_wit"]
const INDUSTRY_STYLES := ["loods_staal", "loods_steen", "magazijn", "fabriek", "bedrijfspand"]
## Antennas on the roofs of tall buildings (from this storey), metres between two of them.
const ANTENNAS := ["dak/zendmast", "dak/telecom_antennes", "dak/zendmast_klein", "dak/telecom_antennes"]
const ANTENNA_FROM_STOREY := 8
const ANTENNA_SPACING := 60.0


## What stands on the roofs, where it makes sense: on offices installation roofs, air
## handlers and cooling units; on flats solar panels and vents; on halls and factories
## big fields of solar panels; on houses solar panels on the slopes facing south or west
## and now and then an air conditioner. Churches, museums and monuments stay bare
## (BARE_ROOF_STYLES). Chosen per cell from its position, so a rebuild gives the same.
func _roof_equipment() -> void:
	var antennas: Array[Vector2] = []
	for cell: Vector3i in buildings.get_used_cells():
		if buildings.get_cell_item(cell + Vector3i.UP) >= 0:
			continue
		var tile_name := buildings.mesh_library.get_item_name(buildings.get_cell_item(cell))
		var style := tile_name.get_slice("/", 0)
		if style in BARE_ROOF_STYLES:
			continue
		var piece := tile_name.get_slice("/", 1).trim_prefix(style + "_")
		var flat_middle := piece in ["dak_plat_midden", "dak_bitumen_midden", "dak_grind_midden"]
		var flat_edge := piece in ["dak_plat_rand", "dak_bitumen_rand", "dak_grind_rand"]
		var pick := _r(cell.x * 7 + cell.y, cell.z * 3 + 1, 12)
		var prefix := style + "/" + style + "_"
		var side := _front_of(cell)
		var roof_height := cell.y * 3.0
		var spot := Vector2(cell.x * 4 + 2.0, cell.z * 4 + 2.0)
		var turn: String = ["S", "E", "N", "W"][pick % 4]
		# here and there a radio mast or telecom antennas on a tall flat roof
		if flat_middle and cell.y >= ANTENNA_FROM_STOREY and pick == 11 \
				and antennas.all(func(other: Vector2) -> bool: return other.distance_to(spot) > ANTENNA_SPACING):
			D(spot.x, spot.y, roof_height, ANTENNAS[_r(cell.x, cell.z, ANTENNAS.size())], turn)
			antennas.append(spot)
			continue
		if style in OFFICE_STYLES:
			if flat_middle and pick < 3 and _has(prefix + "dak_installatie"):
				B(cell.x, cell.y, cell.z, prefix + "dak_installatie", "S")
			elif flat_middle and pick < 5:
				D(spot.x, spot.y, roof_height, "dak/luchtbehandeling" if pick == 3 else "dak/koelinstallatie", turn)
			elif flat_middle and pick < 7 and _has(prefix + "dak_zonnepanelen"):
				B(cell.x, cell.y, cell.z, prefix + "dak_zonnepanelen", "S")
			elif flat_edge and pick == 0 and _has(prefix + "dak_installatie_rand"):
				B(cell.x, cell.y, cell.z, prefix + "dak_installatie_rand", side)
		elif style in FLAT_STYLES:
			if flat_middle and pick < 4:
				if _has(prefix + "dak_zonnepanelen"):
					B(cell.x, cell.y, cell.z, prefix + "dak_zonnepanelen", "S")
				else:
					D(spot.x, spot.y, roof_height, "dak/zonnepanelen", "S")
			elif (flat_middle or flat_edge) and pick == 5:
				D(spot.x, spot.y, roof_height, "dak/ventilatiekap", "S")
			elif flat_middle and pick == 6:
				D(spot.x, spot.y, roof_height, "dak/airco_buitenunit", turn)
		elif style in INDUSTRY_STYLES:
			if flat_middle and pick < 6:
				D(spot.x, spot.y, roof_height, "dak/zonnepanelen_groot", "S")
			elif (flat_middle or flat_edge) and pick == 6:
				D(spot.x, spot.y, roof_height, "dak/ventilatiekap", "S")
		elif piece == "dak_schuin" and side in ["S", "W"] and pick < 3 and _has(prefix + "dak_schuin_zonnepanelen"):
			B(cell.x, cell.y, cell.z, prefix + "dak_schuin_zonnepanelen", side)
		elif (flat_middle or flat_edge) and pick == 0:
			D(spot.x, spot.y, roof_height, "dak/airco_buitenunit", turn)


## Ground a building can be reached over (a street, pavement, square, path or car park).
const ACCESS_GROUND := ["stoep/", "plein/", "weg/", "tram/", "spoor/perron", "natuur/pad", "natuur/grindpad", "natuur/keienpad", "brug/", "parkeren/"]
## Ground-floor pieces that are a way in.
const ENTRANCE_PIECES := ["bg_entree", "bg_deur", "bg_portiek", "bg_portaal", "bg_lobby"]


## Gravel paths that join up (the parks): every straight gravel path cell is turned along
## the paths beside it, and where a path turns a corner it gets the curve. A junction of
## three or four keeps the straight piece of its through way; a lone piece turns towards
## the pavement it leads onto.
const GRAVEL_PATH := "natuur/pad_grind"
const GRAVEL_PATH_CURVE := "natuur/pad_grind_bocht"


func _join_gravel_paths() -> void:
	var paths := {}
	for cell in ground.get_used_cells():
		if cell.y == 0 and _street_tile(Vector2i(cell.x, cell.z)) in [GRAVEL_PATH, GRAVEL_PATH_CURVE]:
			paths[Vector2i(cell.x, cell.z)] = true
	for cell: Vector2i in paths:
		var ways: Array[String] = []
		for direction: String in ORDER:
			if paths.has(cell + DIR_OFFSET[direction]):
				ways.append(direction)
		if ways.is_empty():
			for direction: String in ORDER:
				var beside := _street_tile(cell + DIR_OFFSET[direction])
				if beside.begins_with("stoep/") or beside.begins_with("plein/") or beside.begins_with("natuur/pad"):
					ways.append(direction)
		if ways.is_empty():
			continue
		if ways.size() == 2 and _ck(ways[0], ways[1]) != "":
			_g(cell.x, cell.y, GRAVEL_PATH_CURVE, _ck(ways[0], ways[1]))
			continue
		var along_x := (ways.has("E") and ways.has("W")) or not (ways.has("N") or ways.has("S"))
		if ways.has("N") and ways.has("S") and not (ways.has("E") and ways.has("W")):
			along_x = false
		_g(cell.x, cell.y, GRAVEL_PATH, "E" if along_x else "S")


## The name of a (made-up) company, tekst/naam_kantoor_<number>, high on the front of an
## office from column x0, `width` wide, whose front face lies on the edge z (metres z * 4)
## and faces `front` ("N" or "S"), under the top of its `storeys`.
func _company_name(x0: int, width: int, z: int, front: String, storeys: int, number: int) -> void:
	D(x0 * 4 + width * 2.0, z * 4.0, storeys * 3.0 - 4.2, "tekst/naam_kantoor_%d" % number, front)


## A corner piece of a building (its "_hoek" tiles: a facade on its front and its right
## side, often with a corner pillar) whose side stands against another building (a glass
## hall built on, the next block): its pillar and facade would stand in the other one's wall
## and flicker through it. It becomes the straight piece facing its open side.
func _straighten_hidden_corners() -> void:
	var straightened := 0
	for cell in buildings.get_used_cells():
		var tile_name := buildings.mesh_library.get_item_name(buildings.get_cell_item(cell))
		if not tile_name.ends_with("_hoek"):
			continue
		var straight := tile_name.trim_suffix("_hoek")
		if not _has(straight):
			continue
		var turn := orient.find(buildings.get_cell_item_orientation(cell))
		if turn < 0:
			continue
		var front: String = ORDER[turn]
		var right: String = ORDER[(turn + 1) % 4]
		var style := tile_name.get_slice("/", 0)
		var front_blocked := _other_building(cell, front, style)
		var right_blocked := _other_building(cell, right, style)
		if right_blocked and not front_blocked:
			B(cell.x, cell.y, cell.z, straight, front)
		elif front_blocked and not right_blocked:
			B(cell.x, cell.y, cell.z, straight, right)
		else:
			continue
		straightened += 1
	print("corners against another building made straight: %d" % straightened)


## True if the cell beside `cell` towards `side` holds a building piece of another style
## in the same storey.
func _other_building(cell: Vector3i, side: String, style: String) -> bool:
	var offset: Vector2i = DIR_OFFSET[side]
	var item := buildings.get_cell_item(cell + Vector3i(offset.x, 0, offset.y))
	return item >= 0 and buildings.mesh_library.get_item_name(item).get_slice("/", 0) != style


## Facade pieces that stick out (balconies, bay windows) right beside a viaduct deck or a
## bridge (Grond above street level) at their height would reach into it: they become the
## plain facade of their style.
func _flatten_facades_by_viaducts() -> void:
	var flattened := 0
	for cell in ground.get_used_cells():
		if cell.y < 2:
			continue
		var tile_name := ground.mesh_library.get_item_name(ground.get_cell_item(cell))
		if not (tile_name.begins_with("brug/") or tile_name.begins_with("spoor/") or tile_name.begins_with("tram/")):
			continue
		var storey := floori(cell.y / 3.0)
		for side: String in ORDER:
			var offset: Vector2i = DIR_OFFSET[side]
			for nearby_storey in [storey - 1, storey, storey + 1]:
				if nearby_storey >= 1 and _flatten_facade(Vector3i(cell.x + offset.x, nearby_storey, cell.z + offset.y)):
					flattened += 1
	print("facades beside viaducts made plain: %d" % flattened)


## Trees whose crown would grow into a building (planted too close to a facade) go.
const TREE_CLEARANCE := 0.4


func _remove_trees_in_buildings() -> void:
	var removed := 0
	var boxes := {}
	for cell in props.get_used_cells():
		var item := props.get_cell_item(cell)
		var tile_name := props.mesh_library.get_item_name(item)
		if not tile_name.begins_with("bomen/"):
			continue
		if not boxes.has(item):
			boxes[item] = props.mesh_library.get_item_mesh_transform(item) * props.mesh_library.get_item_mesh(item).get_aabb()
		var turn := props.get_basis_with_orthogonal_index(props.get_cell_item_orientation(cell))
		var box: AABB = (props.transform * Transform3D(turn, props.map_to_local(cell))) * boxes[item]
		box = box.grow(-TREE_CLEARANCE)
		var hits := false
		for x in range(floori(box.position.x / 4.0), floori(box.end.x / 4.0) + 1):
			for z in range(floori(box.position.z / 4.0), floori(box.end.z / 4.0) + 1):
				for storey in range(maxi(1, floori(box.position.y / 3.0)), floori(box.end.y / 3.0) + 1):
					hits = hits or buildings.get_cell_item(Vector3i(x, storey, z)) >= 0
		if hits:
			props.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)
			removed += 1
	print("trees growing into buildings taken away: %d" % removed)


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


## Keeps every sign and logo on a facade (Details "tekst/...") on its building: where it
## would hang past the end of the facade (a wide name on a narrow front or near a corner)
## it moves along the wall until it lies on it whole, or, wider than the front, to its
## middle.
func _fit_signs_on_facades() -> void:
	var moved := 0
	var signs: Array[Vector3i] = []
	for cell in details.get_used_cells():
		if details.mesh_library.get_item_name(details.get_cell_item(cell)).begins_with("tekst/"):
			signs.append(cell)
	for sign_cell in signs:
		var item := details.get_cell_item(sign_cell)
		var orientation := details.get_cell_item_orientation(sign_cell)
		var half_width := details.mesh_library.get_item_mesh(item).get_aabb().size.x * 0.5
		var turn := details.get_basis_with_orthogonal_index(orientation)
		var out := turn * Vector3(0, 0, 1)
		var across := turn * Vector3(1, 0, 0)
		var wall := Vector3(sign_cell) * 0.5
		var storey := floori(wall.y / 3.0)
		# the facade behind it: from its middle along the wall each way while there is building
		var behind := wall - out * 0.5
		if not _building_at(behind, storey):
			continue
		var left := 0.0
		while left > -40.0 and _building_at(behind + across * (left - 0.5), storey):
			left -= 0.5
		var right := 0.0
		while right < 40.0 and _building_at(behind + across * (right + 0.5), storey):
			right += 0.5
		# the facade runs from left - (the rest of that half metre) to right; the cell centres
		# lie on whole cells, so measure to the cell edges
		var start := _facade_edge(behind, across, left, storey, -1.0)
		var finish := _facade_edge(behind, across, right, storey, 1.0)
		var shift := 0.0
		if finish - start < half_width * 2.0:
			shift = (start + finish) * 0.5
		elif -half_width < start:
			shift = start + half_width
		elif half_width > finish:
			shift = finish - half_width
		var steps := roundi(shift * 2.0)
		if steps == 0:
			continue
		var target := Vector3i((wall + across * steps * 0.5) * 2.0)
		details.set_cell_item(sign_cell, GridMap.INVALID_CELL_ITEM)
		details.set_cell_item(target, item, orientation)
		moved += 1
	print("signs fitted on their facades: %d moved" % moved)


## True if a building piece stands at this point (metres) in this storey.
func _building_at(point: Vector3, storey: int) -> bool:
	return buildings.get_cell_item(Vector3i(floori(point.x / 4.0), storey, floori(point.z / 4.0))) >= 0


## The end of the facade along `across` (metres from the sign's middle), from the last
## offset with building found that way (`direction` -1 or 1): the edge of that cell.
func _facade_edge(behind: Vector3, across: Vector3, last_offset: float, storey: int, direction: float) -> float:
	var point := behind + across * last_offset
	var cell_start := Vector3(floorf(point.x / 4.0) * 4.0, 0.0, floorf(point.z / 4.0) * 4.0)
	# along `across` the cell spans 4 m from its start (across is +-x or +-z)
	var along_start := (cell_start - behind).dot(across)
	var along_end := along_start + 4.0 * (across.x + across.z)
	var low := minf(along_start, along_end)
	var high := maxf(along_start, along_end)
	return high if direction > 0.0 else low


## Two signs or logos (Details "tekst/...") on the same facade that overlap (a wide shop name
## over the hanging sign of the shop next door, a logo over a sign): the smaller one moves
## aside along the wall until it is clear; only without room on the facade does it go.
func _one_sign_per_spot() -> void:
	var signs: Array[Dictionary] = []
	for cell in details.get_used_cells():
		var item := details.get_cell_item(cell)
		if not details.mesh_library.get_item_name(item).begins_with("tekst/"):
			continue
		var box := details.mesh_library.get_item_mesh(item).get_aabb()
		var turn := details.get_basis_with_orthogonal_index(details.get_cell_item_orientation(cell))
		signs.append({"cell": cell, "wall": Vector3(cell) * 0.5, "out": turn * Vector3(0, 0, 1),
			"across": turn * Vector3(1, 0, 0), "width": box.size.x, "height": box.size.y, "gone": false})
	var removed := 0
	var shifted := 0
	for first_index in signs.size():
		var first: Dictionary = signs[first_index]
		for second_index in range(first_index + 1, signs.size()):
			var second: Dictionary = signs[second_index]
			if first.gone or second.gone:
				continue
			var relative: Vector3 = second.wall - first.wall
			# the same wall: facing the same way, (almost) in one plane
			if (first.out as Vector3).dot(second.out) < 0.9 or absf(relative.dot(first.out)) > 0.6:
				continue
			var apart_sideways := absf(relative.dot(first.across))
			var first_top: float = first.wall.y + first.height
			var second_top: float = second.wall.y + second.height
			var overlap_up := minf(first_top, second_top) - maxf(first.wall.y, second.wall.y)
			if apart_sideways >= (first.width + second.width) * 0.5 or overlap_up <= 0.0:
				continue
			var smaller: Dictionary = first if first.width * first.height < second.width * second.height else second
			var bigger: Dictionary = second if smaller == first else first
			if _shift_sign_clear(smaller, bigger, signs):
				shifted += 1
			else:
				details.set_cell_item(smaller.cell, GridMap.INVALID_CELL_ITEM)
				smaller.gone = true
				removed += 1
	print("signs over each other: %d moved aside, %d without room taken away" % [shifted, removed])


## Moves `sign` along its wall away from `other` until it clears every other sign there,
## staying on the facade; false if there is no such spot within SIGN_SHIFT_MOST metres.
const SIGN_SHIFT_MOST := 4.0


func _shift_sign_clear(sign: Dictionary, other: Dictionary, signs: Array[Dictionary]) -> bool:
	var across: Vector3 = sign.across
	var away := signf((sign.wall as Vector3 - other.wall).dot(across))
	if away == 0.0:
		away = 1.0
	var item := details.get_cell_item(sign.cell)
	var orientation := details.get_cell_item_orientation(sign.cell)
	var behind: Vector3 = sign.wall - (sign.out as Vector3) * 0.5
	var storey := floori((sign.wall as Vector3).y / 3.0)
	var step := 0.5
	while step <= SIGN_SHIFT_MOST:
		var spot: Vector3 = sign.wall + across * away * step
		# whole on the facade?
		var on_facade := true
		for edge in [-sign.width * 0.5, sign.width * 0.5]:
			on_facade = on_facade and _building_at(behind + across * (away * step + edge * 0.98), storey)
		if on_facade and not _overlaps_a_sign(spot, sign, signs):
			details.set_cell_item(sign.cell, GridMap.INVALID_CELL_ITEM)
			var target := Vector3i((spot * 2.0).round())
			details.set_cell_item(target, item, orientation)
			sign.cell = target
			sign.wall = Vector3(target) * 0.5
			return true
		step += 0.5
	return false


## True if `sign` put at `spot` would overlap another sign on its wall.
func _overlaps_a_sign(spot: Vector3, sign: Dictionary, signs: Array[Dictionary]) -> bool:
	for other: Dictionary in signs:
		if other == sign or other.gone:
			continue
		var relative: Vector3 = other.wall - spot
		if (sign.out as Vector3).dot(other.out) < 0.9 or absf(relative.dot(sign.out)) > 0.6:
			continue
		var overlap_up := minf(spot.y + sign.height, other.wall.y + other.height) - maxf(spot.y, other.wall.y)
		if absf(relative.dot(sign.across)) < (sign.width + other.width) * 0.5 and overlap_up > 0.0:
			return true
	return false


## Facade parts that stick out (balconies, bay windows, loggias, terraces, awnings) and
## would cover a sign or logo; the plain facade pieces that take their place, the first a
## style has.
const STICKING_OUT := ["balkon", "erker", "loggia", "terras", "luifel"]
const PLAIN_FACADES := ["verd_raam", "verd_glas", "verd_raam_groot", "verd_wand", "verd_dicht"]
## Details that may hang in front of a sign (the signs themselves are "tekst/").
const SIGN_FREE_MARGIN := 0.5


## Keeps every sign and logo on a facade (Details items "tekst/...") free: the building
## pieces behind it that stick out become the plain facade of their style, and other
## details hanging in front of it (flower boxes, flags, awnings) go.
func _clear_behind_signs() -> void:
	var flattened := 0
	var removed := 0
	var signs: Array[Vector3i] = []
	for cell in details.get_used_cells():
		if details.mesh_library.get_item_name(details.get_cell_item(cell)).begins_with("tekst/"):
			signs.append(cell)
	for sign_cell in signs:
		var item := details.get_cell_item(sign_cell)
		var box := details.mesh_library.get_item_mesh(item).get_aabb()
		var turn := details.get_basis_with_orthogonal_index(details.get_cell_item_orientation(sign_cell))
		var out := turn * Vector3(0, 0, 1)        # the way the sign faces
		var across := turn * Vector3(1, 0, 0)
		var wall := Vector3(sign_cell) * 0.5      # metres: on the wall, mid-width, its bottom
		var half_width := box.size.x * 0.5
		var bottom := wall.y
		var top := wall.y + box.size.y
		# the building pieces behind it
		var offset := -half_width
		while offset <= half_width + 0.01:
			var behind := wall - out * 0.5 + across * offset
			for storey in range(floori(bottom / 3.0), floori((top - 0.01) / 3.0) + 1):
				if _flatten_facade(Vector3i(floori(behind.x / 4.0), storey, floori(behind.z / 4.0))):
					flattened += 1
			offset += 1.0
		# other details in front of it
		for other in details.get_used_cells():
			if other == sign_cell:
				continue
			var other_name := details.mesh_library.get_item_name(details.get_cell_item(other))
			if other_name.begins_with("tekst/") or other_name.begins_with("deuren/"):
				continue
			var relative := Vector3(other) * 0.5 - wall
			var sideways := absf(relative.dot(across))
			var outwards := relative.dot(out)
			var up := Vector3(other).y * 0.5
			if sideways < half_width + SIGN_FREE_MARGIN and outwards > -0.6 and outwards < 1.6 \
					and up > bottom - 1.5 and up < top + SIGN_FREE_MARGIN:
				details.set_cell_item(other, GridMap.INVALID_CELL_ITEM)
				removed += 1
	print("signs kept free: %d facade pieces made plain, %d details taken away" % [flattened, removed])


## Turns a building piece that sticks out (STICKING_OUT) into the plain facade of its
## style, kept facing the same way; true if it did.
func _flatten_facade(cell: Vector3i) -> bool:
	var item := buildings.get_cell_item(cell)
	if item < 0:
		return false
	var tile_name := buildings.mesh_library.get_item_name(item)
	if not STICKING_OUT.any(func(part: String) -> bool: return tile_name.contains(part)):
		return false
	var style := tile_name.get_slice("/", 0)
	var corner := "_hoek" if tile_name.ends_with("_hoek") else ""
	for plain: String in PLAIN_FACADES:
		var replacement := style + "/" + style + "_" + plain + corner
		if _has(replacement):
			buildings.set_cell_item(cell, buildings.mesh_library.find_item_by_name(replacement), buildings.get_cell_item_orientation(cell))
			return true
	return false


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


## A paved path over the grass from the entrance of every building standing free in the
## grass (a gallery flat, a tower, a school) to the nearest pavement or street.
func _paths_to_lonely_buildings() -> void:
	var footprint := {}
	for cell: Vector3i in buildings.get_used_cells():
		if cell.y == 0:
			footprint[Vector2i(cell.x, cell.z)] = true
	var seen := {}
	for first: Vector2i in footprint:
		if seen.has(first):
			continue
		var group: Array[Vector2i] = [first]
		seen[first] = true
		var index := 0
		var reachable := false
		var doors: Array[Vector2i] = []   # grass cells in front of an entrance
		var beside: Array[Vector2i] = []  # grass cells beside the building
		while index < group.size():
			var here: Vector2i = group[index]
			index += 1
			var piece := buildings.mesh_library.get_item_name(buildings.get_cell_item(Vector3i(here.x, 0, here.y)))
			var front := _front_of(Vector3i(here.x, 0, here.y))
			for side: String in DIR_OFFSET:
				var next: Vector2i = here + DIR_OFFSET[side]
				if footprint.has(next):
					if not seen.has(next):
						seen[next] = true
						group.append(next)
					continue
				var below := _ground_name(next)
				for start: String in ACCESS_GROUND:
					reachable = reachable or below.begins_with(start)
				if below == "natuur/gras":
					beside.append(next)
					for entrance: String in ENTRANCE_PIECES:
						if piece.contains("_" + entrance) and side == front:
							doors.append(next)
		if reachable or beside.is_empty():
			continue
		_lay_path(doors[doors.size() / 2] if not doors.is_empty() else beside[0], footprint)


## The side the ground-floor piece in building cell `cell` faces ("" if not turned square).
func _front_of(cell: Vector3i) -> String:
	var orientation := buildings.get_cell_item_orientation(cell)
	for side: String in DIR:
		if orient[DIR[side]] == orientation:
			return side
	return ""


## The name of the ground tile at street level in map cell `cell` ("" if empty).
func _ground_name(cell: Vector2i) -> String:
	var item := ground.get_cell_item(Vector3i(cell.x, 0, cell.y))
	return ground.mesh_library.get_item_name(item) if item >= 0 else ""


## Paves the shortest way over grass cells from `start` to a cell beside ground that can be
## reached (ACCESS_GROUND), without crossing a building.
func _lay_path(start: Vector2i, footprint: Dictionary) -> void:
	var came_from := {start: start}
	var queue: Array[Vector2i] = [start]
	var index := 0
	var goal := Vector2i(-1, -1)
	while index < queue.size() and goal.x < 0:
		var here: Vector2i = queue[index]
		index += 1
		for side: String in DIR_OFFSET:
			var next: Vector2i = here + DIR_OFFSET[side]
			if came_from.has(next) or footprint.has(next):
				continue
			var below := _ground_name(next)
			var reachable := false
			for access: String in ACCESS_GROUND:
				reachable = reachable or below.begins_with(access)
			if reachable:
				goal = here
				break
			if below == "natuur/gras":
				came_from[next] = here
				queue.append(next)
	if goal.x < 0:
		return
	var step := goal
	while true:
		_clear_props(step.x, step.y)
		_g(step.x, step.y, "stoep/stoep_vol")
		if step == start:
			break
		step = came_from[step]


# ------------------------------------------------------------------ finishing

## Grass on every empty ground cell of the map (not water or a sunk cell); paving under a
## building whose floor can be seen (a glass hall, a canopy, pillars), never grass.
func _fill_grass_all() -> void:
	for x in range(0, MAP_END + 1):
		for z in range(0, Z_END + 1):
			if ground.get_cell_item(Vector3i(x, 0, z)) != GridMap.INVALID_CELL_ITEM:
				continue
			if ground.get_cell_item(Vector3i(x, -2, z)) != GridMap.INVALID_CELL_ITEM:
				continue
			var standing := buildings.get_cell_item(Vector3i(x, 0, z))
			var piece := buildings.mesh_library.get_item_name(standing) if standing >= 0 else ""
			if piece.begins_with("hallen/") or piece.begins_with("overkapping/") or piece.begins_with("pilaren/"):
				G(x, z, "plein/plein_tegels")
			elif not occupied.has(Vector2i(x, z)):
				G(x, z, "natuur/gras")


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


## Rotation of an overhead line mast tile whose arm points to this side (the arm runs
## along the tile's x, so it turns a quarter ahead of the side its front faces).
const MAST_ARM_ROTATION := {"E": "S", "N": "E", "W": "N", "S": "W"}


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


## Removes the lamps, overhead line masts and trees on ground cell (x, z), which would reach
## up into what is built above them; traffic lights stay.
func _clear_lamps_and_trees(x: int, z: int) -> void:
	for cell in props.get_used_cells():
		if floori(cell.x / 8.0) == x and floori(cell.z / 8.0) == z:
			var item_name := props.mesh_library.get_item_name(props.get_cell_item(cell))
			if item_name.begins_with("verlichting/") or item_name.begins_with("bomen/") or item_name.begins_with("ov/tram_bovenleiding"):
				props.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)


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
	# the rail traffic: each on its own kind of rails, a tile knows who rides on it
	for rail_start: Array in [["RandstadRail1", "res://scripts/vehicles/randstadrail.gd", Vector2i(VIADUCT_LINK_COLUMNS[1], 70), Vector2i(0, -1)],
			["RandstadRail2", "res://scripts/vehicles/randstadrail.gd", Vector2i(VIADUCT_LINK_COLUMNS[0], 74), Vector2i(0, 1)],
			# two trains, each on its own track (own_track in ns_train.gd)
			["Trein1", "res://scripts/vehicles/ns_train.gd", Vector2i(RAILWAY_COLUMNS[1], 90), Vector2i(0, -1)],
			["Trein2", "res://scripts/vehicles/ns_train.gd", Vector2i(RAILWAY_COLUMNS[0], 75), Vector2i(0, 1)]]:
		var rail_vehicle := Node3D.new()
		rail_vehicle.name = rail_start[0]
		rail_vehicle.set_script(load(rail_start[1]))
		rail_vehicle.set("start_cell", rail_start[2])
		rail_vehicle.set("start_heading", rail_start[3])
		root.add_child(rail_vehicle)
		rail_vehicle.owner = root
	var tunnel_lights := Node.new()
	tunnel_lights.name = "Tunnelverlichting"
	tunnel_lights.set_script(load("res://scripts/world/tunnel_lights.gd"))
	root.add_child(tunnel_lights)
	tunnel_lights.owner = root
	var lens := CanvasLayer.new()
	lens.name = "Vignet"
	lens.set_script(load("res://scripts/effects/vignette.gd"))
	root.add_child(lens)
	lens.owner = root


## The car (node Auto, scripts/vehicles/car.gd), an SUV that drives round too (node
## SUV, scripts/vehicles/suv.gd, starting in the Bezuidenhout), the camera that follows
## the car (node Volgcamera, F in the game; B sends the SUV into it, the demo crash), the
## rest of the traffic (node Verkeer, scripts/world/traffic.gd, spreads it at the start) and
## the see-through buildings while it follows (node Doorkijk,
## scripts/world/building_fade.gd). The car finds its lanes in the ground tiles themselves
## (their "traffic" metadata, scripts/world/road_network.gd).
func _car(root: Node3D) -> void:
	var car := Node3D.new()
	car.name = "Auto"
	car.set_script(load("res://scripts/vehicles/car.gd"))
	root.add_child(car)
	car.owner = root
	var suv := Node3D.new()
	suv.name = "SUV"
	suv.set_script(load("res://scripts/vehicles/suv.gd"))
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
