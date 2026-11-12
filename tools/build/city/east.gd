extends "res://tools/build/city/old_centre.gd"
## City builder, part 7 (see base.gd for the chain): the town east of the singel: the
## Haagse Bos, the Malieveld and Koekamp, the Bezuidenhout, Centraal Station, the
## Beatrixkwartier, the buildings over the A12, the Prins Clauslaan, the Theresiastraat and
## the Bezuidenhout-Oost.


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
	_deer_camp_snack_bar()
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
	# the neighbourhood's two supermarkets, on the street north of the blocks
	_next_supermarket(99, 32, 12, "jaren30")
	_next_supermarket(115, 32, 12, "jaren30")
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
	# the glass canopies over the doors (the tile is the flat pane: up above the doorway)
	D(83 * 4 + 2.0, 69 * 4.0, GLASS_CANOPY_HEIGHT, "luifels/luifel_glas", "N")
	D(77 * 4 + 2.0, 69 * 4.0, GLASS_CANOPY_HEIGHT, "luifels/luifel_glas", "N")
	D(89 * 4 + 2.0, 69 * 4.0, GLASS_CANOPY_HEIGHT, "luifels/luifel_glas", "N")
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
	# street food on the west side of the square, facing it
	Pr(77 * 4 + 2.0, 63 * 4 + 2.0, "markt/frietkar", "E")
	Pr(77 * 4 + 2.0, 65 * 4 + 2.0, "markt/loempiakar", "E")
	places["centraal"] = Vector2(83 * 4.0, 64 * 4.0)


## A Jan Blammage in the Koekamp, by the deer camp, close to Centraal Station: a white pavilion
## of two cells and one storey on the grass just south of the gravel path (x 92..93, z 44),
## its front to the path (N): the snack bar (you walk into it: scripts/world/interiors.gd)
## and a window, flat roofs, its name sign and the big fries cone on the path before it.
func _deer_camp_snack_bar() -> void:
	var z := 44
	B(92, 0, z, "modern_wit/modern_wit_bg_snackbar", "N")
	B(93, 0, z, "modern_wit/modern_wit_bg_raam", "N")
	for x in [92, 93]:
		B(x, 1, z, "modern_wit/modern_wit_dak_plat_los", "N")
	D(92 * 4 + 2.0, z * 4.0, NAME_SIGN_HEIGHT, JAN_BLAMMAGE_SIGN, "N")
	Pr(92 * 4 + 0.5, z * 4 - 1.5, "terras/friet_puntzak", "N")
	places["snackbar_hertenkamp"] = Vector2(92 * 4.0 + 2.0, z * 4.0 + 2.0)


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


# ------------------------------------------------------------------ the A12 east of the city

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
