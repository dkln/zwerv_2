extends "res://tools/build/city/kit.gd"
## Example-map builder, part 3 of 7 (see base.gd for the chain): the old town
## (x 0..35, z 0..29): canal and canal houses, Main Street, North and Cross Street,
## city block with sloped roofs, square, modern blocks, railway viaduct and park, plus
## grass on every empty cell (_fill_grass).


## Canal x 8-9 from z 0 to 48: water and quay walls below street level, quays,
## quay streets and pavements, a flat bridge in North Street, a brick arch bridge in
## Main Street, trees, lanterns, bollards and boats.
func _canal() -> void:
	# canal: water at level -2, quay walls at -2 and -1 below the quays
	for z in range(0, 49):
		occupied[Vector2i(8, z)] = true
		occupied[Vector2i(9, z)] = true
		for x in [8, 9]:
			if z >= 12 and z <= 17:
				continue
			if z == 0:
				continue
			G(x, z, "water/water_gracht", "S", -2)
		for x in [7, 10]:
			G(x, z, "water/kademuur_alg", "S", -2)
			G(x, z, "water/kademuur", "S", -1)
	# bridge in North Street: concrete bridge deck with parapets on both sides
	G(8, 0, "water/water_gracht", "S", -2)
	G(9, 0, "water/water_gracht", "S", -2)
	G(8, 0, "brug/brug_dek_weg_beide", "E")
	G(9, 0, "brug/brug_dek_weg_beide", "E")
	# brick arch bridge in Main Street (placed at water level)
	for x in [8, 9]:
		G(x, 12, "brug/brug_boog_gracht_rand", 3, -2)
		for z in range(13, 17):
			G(x, z, "brug/brug_boog_gracht_midden", 1, -2)
		G(x, 17, "brug/brug_boog_gracht_rand", 1, -2)
		for z in range(12, 18):
			occupied[Vector2i(x, z)] = true
	# quays
	for z in range(1, 49):
		if z >= 12 and z <= 17:
			continue
		G(7, z, "stoep/stoep_kade_klinker" if z % 5 == 0 else "stoep/stoep_kade", "E")
		G(10, z, "stoep/stoep_kade_klinker" if z % 5 == 0 else "stoep/stoep_kade", "W")
	# quay streets (clinkers) and pavements along the buildings
	for z in range(1, 49):
		if z >= 12 and z <= 17:
			continue
		G(6, z, "weg/straat_klinkers")
		G(11, z, "weg/straat_klinkers")
		G(5, z, "stoep/stoep_rand", "E")
		G(12, z, "stoep/stoep_rand", "W")
	# trees, lanterns, bollards and bicycles along the canal
	for z in range(1, 49):
		if (z >= 11 and z <= 18) or (z >= 39 and z <= 47):
			continue
		var wz := z * 4.0 + 2.0
		if z % 2 == 0:
			Pr(7 * 4 + 1.5, wz, "bomen/linde")
			Pr(10 * 4 + 2.5, wz, "bomen/linde" if z % 4 else "bomen/plataan")
		else:
			Pr(7 * 4 + 1.0, wz, "verlichting/lantaarn_klassiek")
			Pr(10 * 4 + 3.0, wz, "verlichting/lantaarn_klassiek")
		Pr(7 * 4 + 3.5, wz - 1.0, "paaltjes/bolder")
		Pr(10 * 4 + 0.5, wz + 1.0, "paaltjes/bolder")
		if z % 3 == 0:
			Pr(5 * 4 + 0.5, wz, "paaltjes/amsterdammertje")
			Pr(5 * 4 + 0.5, wz + 1, "paaltjes/amsterdammertje")
			Pr(12 * 4 + 3.5, wz, "paaltjes/amsterdammertje")
		if z % 4 == 1:
			Pr(7 * 4 + 2.5, wz + 0.5, "fietsen/fiets_zwart", "E")
			Pr(7 * 4 + 2.5, wz + 1.0, "fietsen/fiets_rood", "E")
	# boats
	Pr(36.0, 14.0, "water/woonboot", "S", -2.0)
	Pr(36.0, 30.0, "water/sloep", "N", -2.0)
	Pr(35.0, 40.0, "water/roeiboot", "S", -2.0)
	Pr(36.0, 96.0, "water/woonboot", "N", -2.0)
	Pr(36.5, 108.0, "water/roeiboot", "E", -2.0)
	Pr(34.0, 84.0, "water/steiger", "S", -2.0)


## Main Street along x at z 12..17 (pavement, cycle path, two lanes, cycle path,
## pavement) with a tram section, the intersection with Cross Street, a tram/bus stop,
## lanterns, signs and traffic lights.
func _main_street() -> void:
	# profile (z): 12 pavement, 13 cycle path, 14-15 lanes, 16 cycle path, 17 pavement
	for x in range(0, W):
		if x == 8 or x == 9:
			continue
		if x == 28 or x == 29 or x == 60 or x == 61:
			continue # intersections with Cross Street and Cross Street 2
		if x == 6 or x == 11:
			G(x, 12, "weg/weg_vlak")
			G(x, 17, "weg/weg_vlak")
		elif x == 5 or x == 12:
			G(x, 12, "stoep/stoep_hoek_buiten", "SE" if x == 5 else "WS")
			G(x, 17, "stoep/stoep_hoek_buiten", "EN" if x == 5 else "NW")
		elif x == 27 or x == 59:
			G(x, 12, "stoep/stoep_hoek_buiten", "SE")
			G(x, 17, "stoep/stoep_hoek_buiten", "EN")
		elif x == 30 or x == 62:
			G(x, 12, "stoep/stoep_hoek_buiten", "WS")
			G(x, 17, "stoep/stoep_hoek_buiten", "NW")
		else:
			# a gully every 7 tiles
			var pavement := "stoep/stoep_goot_rand" if x % 7 != 3 else "stoep/stoep_goot_kolk"
			G(x, 12, pavement, "S")
			G(x, 17, pavement, "N")
		G(x, 13, "fietspad/fietspad_recht", "E")
		G(x, 16, "fietspad/fietspad_recht", "E")
		var tram := x >= 12 and x <= 35
		if tram and x >= 62:
			G(x, 14, "tram/tram_rijstrook_onderbroken_kant", "E")
			G(x, 15, "tram/tram_rijstrook_geen_kant", "W")
		elif tram:
			G(x, 14, "tram/tram_recht", "E")
			G(x, 15, "tram/tram_recht", "E")
		else:
			G(x, 14, "weg/rijstrook_onderbroken_kant", "E")
			G(x, 15, "weg/rijstrook_geen_kant", "W")
	# intersection with Cross Street
	for x in [28, 29]:
		G(x, 12, "weg/zebrapad", "S")
		G(x, 13, "weg/fietsoversteek", "S")
		G(x, 14, "weg/weg_vlak")
		G(x, 15, "weg/weg_vlak")
		G(x, 16, "weg/fietsoversteek", "S")
		G(x, 17, "weg/zebrapad", "S")
	# tram stop and street furniture
	Pr(20 * 4 + 2, 12 * 4 + 1.5, "ov/abri", "S")
	Pr(23 * 4, 12 * 4 + 1.0, "ov/tramhalte_paal", "S")
	Pr(18 * 4, 17 * 4 + 3.0, "ov/bushokje", "N")
	Pr(16 * 4, 17 * 4 + 3.5, "ov/bushalte_paal", "N")
	for x in range(0, W, 3):
		if x >= 7 and x <= 10:
			continue
		Pr(x * 4 + 2, 12 * 4 + 0.5, "verlichting/lantaarn_dubbel", "E")
		Pr(x * 4 + 2, 17 * 4 + 3.5, "verlichting/lantaarn_modern", "N")
	for x in [14, 24, 33]:
		Pr(x * 4 + 1, 12 * 4 + 3.0, "straat/prullenbak_paal")
		Pr(x * 4 + 3, 17 * 4 + 1.0, "fietsen/fietsenrek_vol", "N")
	Pr(13 * 4 + 1, 17 * 4 + 2, "borden/bord_max_50", "N")
	Pr(1 * 4, 12 * 4 + 2, "borden/bord_bebouwde_kom", "E")
	# traffic lights
	Pr(27 * 4 + 3, 12 * 4 + 3.5, "verkeer/verkeerslicht", "N")
	Pr(30 * 4 + 1, 17 * 4 + 0.5, "verkeer/verkeerslicht", "S")
	Pr(27 * 4 + 3.5, 17 * 4 + 0.5, "verkeer/verkeerslicht_fiets", "E")
	Pr(30 * 4 + 0.5, 12 * 4 + 3.5, "verkeer/verkeerslicht_voetganger", "W")
	Pr(30 * 4 + 2, 12 * 4 + 1, "verkeer/verkeerslicht_mast", "W")
	# signpost
	Pr(26 * 4 + 2, 17 * 4 + 2, "borden/wegwijzer", "N")


## North Street along the top edge (z 0, pavement z 1) and Cross Street (x 28-29,
## pavements x 27 and 30) from z 1 to 39, with zebra crossings, tree grates and signs.
func _north_street_and_cross_street() -> void:
	# North Street (z=0), pavement z=1
	for x in range(0, 33):
		if x == 8 or x == 9:
			continue
		if x == 28 or x == 29:
			G(x, 0, "weg/weg_vlak")
			continue
		G(x, 0, "weg/straat_klinkers" if x < 12 else "weg/weg_vlak", "E")
	G(30, 0, "weg/weg_vlak")
	G(31, 0, "weg/weg_vlak")
	G(32, 0, "weg/zebrapad", "E")
	for x in range(13, 28):
		if x == 27:
			G(x, 1, "stoep/stoep_hoek_buiten", "EN")
		elif x == 13:
			G(x, 1, "stoep/stoep_hoek_buiten", "NW")
		else:
			G(x, 1, "stoep/stoep_rand", "N")
	for x in range(0, 5):
		G(x, 1, "stoep/stoep_rand", "N")
	G(5, 1, "stoep/stoep_hoek_buiten", "EN")
	G(12, 1, "stoep/stoep_hoek_buiten", "NW")
	G(7, 0, "weg/straat_klinkers", "E")
	G(10, 0, "weg/straat_klinkers", "E")
	Pr(15 * 4, 1 * 4 + 1, "borden/bord_max_30", "N")
	Pr(25 * 4, 1 * 4 + 1, "borden/bord_woonerf", "N")
	Pr(4 * 4, 1 * 4 + 1, "borden/bord_eenrichtingsweg", "N")
	# Cross Street (x=28,29), pavements x=27 and x=30
	for z in range(1, 40):
		if z >= 12 and z <= 17:
			continue
		if z == 10 or z == 19:
			G(28, z, "weg/zebrapad")
			G(29, z, "weg/zebrapad")
		elif z == 11:
			G(28, z, "weg/rijstrook_haaientanden", "N")
			G(29, z, "weg/rijstrook_pijl_rechtdoor", "S")
		else:
			G(28, z, "weg/rijstrook_geen_kant", "N")
			G(29, z, "weg/rijstrook_onderbroken_kant", "S")
		if z == 1:
			G(30, z, "stoep/stoep_hoek_buiten", "NW")
		elif z == 10 or z == 19:
			G(27, z, "stoep/stoep_ribbel", "E")
			G(30, z, "stoep/stoep_ribbel", "W")
		elif z % 4 == 2:
			G(27, z, "stoep/stoep_boomrooster", "E")
			G(30, z, "stoep/stoep_boomrooster", "W")
			Pr(27 * 4 + 2, z * 4 + 2, "bomen/linde" if z < 12 else "bomen/kastanje")
			Pr(30 * 4 + 2, z * 4 + 2, "bomen/linde")
		else:
			if z != 1:
				G(27, z, "stoep/stoep_rand", "E")
			G(30, z, "stoep/stoep_rand", "W")
	Pr(30 * 4 + 1, 10 * 4 + 1, "borden/bord_zebrapad", "W")
	Pr(27 * 4 + 3, 19 * 4 + 3, "borden/bord_zebrapad", "E")
	Pr(27 * 4 + 3, 11 * 4, "borden/bord_voorrang_verlenen", "N")
	Pr(30 * 4 + 1, 22 * 4, "borden/bord_parkeren", "W")
	Pr(30 * 4 + 1, 26 * 4, "paaltjes/laadpaal", "W")
	Pr(27 * 4 + 3, 7 * 4, "straat/brievenbus", "E")


# ------------------------------------------------------------------ canal houses

## One narrow canal house at tile (x, z) facing front: a ground floor picked by rnd,
## floors - 1 upper storeys from facades and a gable top ("gevel_" + gable_top) on storey floors.
func _house(x: int, z: int, front: String, style: String, floors: int, facades: Array, gable_top: String, rnd: int) -> void:
	var p := style + "/" + style + "_"
	var gf: String = ["bg_deur", "bg_deur", "bg_winkel_luifel", "bg_raam", "bg_winkel"][rnd % 5]
	B(x, 0, z, p + gf, front)
	for v in range(1, floors):
		B(x, v, z, p + facades[(rnd + v) % facades.size()], front)
	B(x, floors, z, p + "gevel_" + gable_top, front)


## Rows of canal houses on both quays (front houses with rear houses behind them),
## back gardens on the west side and facade details.
func _canal_houses() -> void:
	var styles := ["klassiek_rood", "klassiek_donker", "klassiek_geel"]
	var tops := ["trap", "klok", "hals", "tuit"]
	var upper := ["verd_raam", "verd_drie_ramen", "verd_luiken", "verd_balkon", "verd_raam", "verd_erker"]
	# west: front facade facing east (x=4), rear house x=3
	for z in range(2, 12):
		var r := z * 7 + 3
		var style: String = styles[r % 3]
		var n := 3 + (r % 2)
		_house(4, z, "E", style, n, upper, tops[(z * 3) % 4], r)
		var p := style + "/" + style + "_"
		for v in range(0, n):
			B(3, v, z, p + ("verd_raam" if v > 0 else "bg_raam"), "W")
		B(3, n, z, p + ("dak_zadel_schoorsteen" if z % 3 == 0 else "dak_zadel"), "S")
		# small back gardens
		G(2, z, "natuur/gras")
		G(1, z, "natuur/moestuin" if z % 3 == 0 else "natuur/gras")
		G(0, z, "plein/plein_vlonder" if z % 4 == 0 else "natuur/gras")
		Pr(2 * 4 + 0.5, z * 4 + 2, "hekken/schutting_hout", "E")
		if z % 3 == 1:
			Pr(1 * 4 + 2, z * 4 + 2, "bomen/fruitboom")
	# east: front facade facing west (x=13), rear house x=14
	for zz in range(2, 12) + range(18, 29):
		var r: int = zz * 5 + 1
		var style: String = styles[(r + 1) % 3]
		var n := 3 + (1 if r % 3 == 0 else 0)
		_house(13, zz, "W", style, n, upper, tops[(zz * 5) % 4], r)
		var p := style + "/" + style + "_"
		for v in range(0, n):
			B(14, v, zz, p + ("verd_luiken" if v > 0 else "bg_raam"), "E")
		B(14, n, zz, p + "dak_zadel", "S")
		G(15, zz, "stoep/stoep_vol")
	# facade details: flower boxes, awnings, flags, ivy
	for z in range(2, 12):
		var wz := z * 4.0 + 1.0
		if z % 2 == 0:
			D(20.0, wz + 1.0, 3.5, "ramen/bloembak", "E")
		if z % 4 == 1:
			D(20.0, wz + 2.0, 6.0, "gevel/vlag", "E")
		if z % 5 == 3:
			D(52.0, z * 4.0 + 2.0, 0.0, "gevel/klimop", "W")
	D(52.0, 22.0, 3.0, "gevel/uithangbord", "W")
	D(20.0, 30.0, 2.5, "gevel/buitenlamp", "E")


# ------------------------------------------------------------------ city block with sloped roofs

## Closed city block x 16..26, z 2..11: a ring two cells deep with sloped roofs that
## wrap around the corners, shops on the south side, a gateway, and a courtyard garden.
func _city_block() -> void:
	# ring 2 deep: x 16..26, z 2..11; courtyard x 18..24, z 4..9
	var s := "klassiek_rood"
	var p := s + "/" + s + "_"
	var x0 := 16
	var x1 := 26
	var z0 := 2
	var z1 := 11
	var roof_variants := ["dak_schuin", "dak_schuin", "dak_schuin_dakkapel", "dak_schuin", "dak_schuin_schoorsteen", "dak_schuin_dakraam", "dak_schuin_zonnepanelen"]
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var outer_ring := x == x0 or x == x1 or z == z0 or z == z1
			var inner_ring := x == x0 + 1 or x == x1 - 1 or z == z0 + 1 or z == z1 - 1
			if not outer_ring and not inner_ring:
				continue
			var k := (x * 13 + z * 7) % 7
			var front := ""
			var roof: String = roof_variants[k]
			var gf_tile := "bg_deur" if k % 2 == 0 else "bg_raam"
			var upper_tile: String = ["verd_raam", "verd_drie_ramen", "verd_luiken", "verd_balkon"][k % 4]
			if outer_ring:
				var corner := _corner_of(x, z, x0, z0, x1 - x0 + 1, z1 - z0 + 1)
				if corner != "":
					B(x, 0, z, p + ("bg_winkel_hoek" if z == z1 else "bg_raam_hoek"), corner)
					B(x, 1, z, p + "verd_raam_hoek", corner)
					B(x, 2, z, p + "dak_schuin_hoek_buiten", corner)
					continue
				if z == z0: front = "N"
				elif z == z1: front = "S"
				elif x == x0: front = "W"
				else: front = "E"
				if z == z1:
					gf_tile = "bg_winkel_luifel" if k % 3 != 1 else "bg_winkel"
				if z == z1 and x == 21:
					gf_tile = "bg_poort"
			else:
				# inner ring: facades face the courtyard
				var corner := ""
				if x == x0 + 1 and z == z0 + 1: corner = "SE"
				elif x == x1 - 1 and z == z0 + 1: corner = "WS"
				elif x == x0 + 1 and z == z1 - 1: corner = "EN"
				elif x == x1 - 1 and z == z1 - 1: corner = "NW"
				if corner != "":
					B(x, 0, z, p + "blok_dicht", "S")
					B(x, 1, z, p + "blok_dicht", "S")
					B(x, 2, z, p + "dak_schuin_hoek_binnen", corner)
					continue
				if z == z0 + 1: front = "S"
				elif z == z1 - 1: front = "N"
				elif x == x0 + 1: front = "E"
				else: front = "W"
				gf_tile = "bg_raam" if k % 2 else "bg_deur"
				if z == z1 - 1 and x == 21:
					gf_tile = "bg_poort"
				if roof == "dak_schuin_zonnepanelen" or roof == "dak_schuin_dakraam":
					roof = "dak_schuin_dakterras" if k % 2 else "dak_schuin_half_plat"
			B(x, 0, z, p + gf_tile, front)
			B(x, 1, z, p + upper_tile, front)
			B(x, 2, z, p + roof, front)
	# courtyard
	for x in range(x0 + 2, x1 - 1):
		for z in range(z0 + 2, z1 - 1):
			var t := "natuur/gras"
			if z == z0 + 2 or z == z1 - 2:
				t = "plein/plein_tegels"
			elif x == 21:
				t = "natuur/pad_grind"
			elif (x + z) % 5 == 0:
				t = "natuur/gras"
			G(x, z, t)
	G(21, z1 - 2, "natuur/pad_grind")
	Pr(19 * 4 + 2, 6 * 4 + 2, "bomen/bloesemboom")
	Pr(24 * 4 + 2, 7 * 4 + 2, "bomen/linde")
	Pr(19 * 4 + 2, 8 * 4 + 2, "straat/picknicktafel", "E")
	Pr(23 * 4, 5 * 4 + 2, "planten/hortensia")
	Pr(20 * 4, 5 * 4 + 2, "hekken/haag", "S")
	Pr(22 * 4 + 2, 9 * 4, "hekken/haag", "S")
	Pr(18 * 4 + 2, 4 * 4 + 2, "fietsen/fietsenrek_vol", "E")
	Pr(24 * 4, 9 * 4, "straat/rolcontainer_groen")
	Pr(24.5 * 4, 9 * 4, "straat/rolcontainer_grijs")
	Pr(20 * 4, 7 * 4 + 2, "planten/plantenbak_hout")
	# awnings and details on the outside
	D(17 * 4 + 2.0, 12 * 4.0, 2.0, "luifels/luifel_groen_smal", "S")
	D(26 * 4 + 4.0, 6 * 4 + 2.0, 0.0, "gevel/klimop", "E")
	D(16 * 4.0, 7 * 4 + 2.0, 1.0, "gevel/regenpijp", "W")


# ------------------------------------------------------------------ square

## Town square x 16..26, z 18..25 with a natural-stone centre, fountain, kiosk, trees,
## benches and lanterns.
func _square() -> void:
	for x in range(16, 27):
		for z in range(18, 26):
			var t := "plein/plein_klinkers"
			if x >= 19 and x <= 23 and z >= 19 and z <= 23:
				t = "plein/plein_patroon" if (x == 21 and z == 21) else "plein/plein_natuursteen"
			elif (x == 17 or x == 25) and (z == 19 or z == 24):
				t = "stoep/stoep_boomrooster"
			G(x, z, t)
	G(16, 18, "plein/plein_dambord")
	Pr(21 * 4 + 2, 21 * 4 + 2, "straat/fontein")
	Pr(24 * 4 + 2, 21 * 4 + 2, "straat/kiosk")
	for pos in [Vector2(17, 19), Vector2(25, 19), Vector2(17, 24), Vector2(25, 24)]:
		Pr(pos.x * 4 + 2, pos.y * 4 + 2, "bomen/linde")
	for x in [19, 23]:
		Pr(x * 4 + 2, 19 * 4, "straat/bank_hout", "S")
		Pr(x * 4 + 2, 24 * 4 + 3, "straat/bank_hout", "N")
	Pr(19 * 4, 21 * 4 + 2, "straat/bank_beton", "E")
	Pr(18 * 4 + 2, 22 * 4, "verlichting/lantaarn_klassiek")
	Pr(24 * 4 + 2, 19 * 4, "verlichting/lantaarn_klassiek")
	Pr(20 * 4, 24 * 4, "verlichting/lantaarn_klassiek")
	Pr(22 * 4 + 2, 18 * 4 + 1, "straat/prullenbak_rond")
	Pr(16 * 4 + 2, 21 * 4, "ov/reclamezuil")
	Pr(26 * 4 + 1, 22 * 4, "straat/vlaggenmast")
	Pr(18 * 4, 25 * 4, "planten/plantenbak_beton")
	Pr(24 * 4, 25 * 4, "planten/plantenbak_beton")
	Pr(21 * 4 + 2, 25 * 4 + 1, "planten/pot_terracotta")
	Pr(17 * 4, 21 * 4, "straat/afvalcontainer_ondergronds")


# ------------------------------------------------------------------ modern blocks

## Modern terraced block south of the square (x 16..26, z 26..27, 3 storeys, flat roofs)
## with back gardens and roof equipment.
func _modern_block() -> void:
	# south side of the square: x 16..26, z 26..27
	var styles := ["modern_wit", "modern_hout", "modern_donker"]
	for x in range(16, 27):
		var s: String = styles[((x - 16) / 4) % 3]
		var p := s + "/" + s + "_"
		var k := x % 4
		for z in [26, 27]:
			var front := "N" if z == 26 else "S"
			var corner := _corner_of(x, z, 16, 26, 11, 2)
			for v in range(0, 3):
				var tile_name := ""
				if corner != "":
					tile_name = ["bg_raam_hoek", "verd_raam_hoek", "verd_balkon_hoek"][v]
					B(x, v, z, p + tile_name, corner)
				else:
					if v == 0:
						tile_name = ["bg_deur", "bg_raam", "bg_winkel", "bg_garage"][k] if z == 26 else ["bg_deur", "bg_raam", "bg_raam", "bg_garage"][k]
					else:
						tile_name = ["verd_raam", "verd_balkon", "verd_raam_breed", "verd_frans", "verd_dicht"][(k + v) % 5]
					B(x, v, z, p + tile_name, front)
			if corner != "":
				B(x, 3, z, p + "dak_plat_hoek", corner)
			else:
				var roof := "dak_plat_rand"
				if z == 27 and k == 1:
					roof = "dak_terras_rand"
				B(x, 3, z, p + roof, front)
	# back gardens
	for x in range(16, 27):
		G(x, 28, "natuur/gras" if x % 3 else "plein/plein_vlonder")
		G(x, 29, "natuur/gras")
		Pr(x * 4 + 2, 29 * 4 + 3.5, "hekken/schutting_hout", "S")
	for x in [17, 21, 25]:
		Pr(x * 4 + 2, 28 * 4 + 2, "planten/struik_bloei")
	# solar panels and dishes on the roofs (details layer, height = top of 3rd storey)
	for x in [18, 22, 24]:
		D(x * 4 + 2.0, 27 * 4 + 2.0, 9.0, "dak/zonnepanelen", "S")
	D(19 * 4 + 2.0, 26 * 4.0, 7.0, "gevel/airco", "N")
	D(23 * 4 + 2.0, 26 * 4.0, 4.0, "dak/schotel", "N")


## Glass office tower (x 31..32, z 18..20, 6 storeys) and a lower concrete office
## (z 22..23), with the pavements around them.
func _office() -> void:
	# office tower x 31..32, z 18..20, 6 storeys, front west
	var s := "kantoor_glas"
	var p := s + "/" + s + "_"
	var height := 6
	for x in [31, 32]:
		for z in [18, 19, 20]:
			var corner := _corner_of(x, z, 31, 18, 2, 3)
			var front := "W" if x == 31 else "E"
			for v in range(0, height):
				if corner != "":
					var n := "bg_glas_hoek" if v == 0 else ("verd_vliesgevel_hoek" if v % 2 else "verd_band_hoek")
					B(x, v, z, p + n, corner)
				else:
					var n := ("bg_entree" if x == 31 else "bg_glas") if v == 0 else ("verd_vliesgevel" if v % 2 else "verd_band")
					B(x, v, z, p + n, front)
			if corner != "":
				B(x, height, z, p + "dak_plat_hoek", corner)
			else:
				B(x, height, z, p + "dak_installatie_rand", front)
	# lower office (concrete) next to it
	var s2 := "kantoor_beton"
	var p2 := s2 + "/" + s2 + "_"
	for x in [31, 32]:
		for z in [22, 23]:
			# 2x2: every cell is a corner
			var corner := _corner_of(x, z, 31, 22, 2, 2)
			for v in range(0, 3):
				B(x, v, z, p2 + ("bg_glas_hoek" if v == 0 else "verd_band_hoek"), corner)
			B(x, 3, z, p2 + "dak_plat_hoek", corner)
	for z in [21, 24, 25]:
		G(31, z, "stoep/stoep_vol")
		G(32, z, "stoep/stoep_vol")
	Pr(31 * 4 + 2, 21 * 4 + 2, "planten/boombak")
	Pr(31 * 4 + 1, 24 * 4 + 2, "fietsen/fietsenrek_vol", "E")
	Pr(31 * 4 + 1, 19 * 4 + 2, "paaltjes/paal_rvs")
	Pr(30 * 4 + 3, 18 * 4 + 1, "paaltjes/paal_rvs")


## Modern terraced houses x 31..32, z 2..10 (3 storeys, flat roofs), fronts facing west and east.
func _modern_east() -> void:
	# modern terraced houses x 31..32, z 2..10, front west
	var s := "modern_donker"
	var p := s + "/" + s + "_"
	for z in range(2, 11):
		for x in [31, 32]:
			var corner := _corner_of(x, z, 31, 2, 2, 9)
			var front := "W" if x == 31 else "E"
			for v in range(0, 3):
				if corner != "":
					B(x, v, z, p + ["bg_deur_hoek", "verd_raam_hoek", "verd_raam_breed_hoek"][v], corner)
				else:
					var n: String = ["bg_deur", "bg_garage", "bg_deur", "bg_raam"][z % 4] if v == 0 else ["verd_raam", "verd_balkon", "verd_frans", "verd_raam_breed"][(z + v) % 4]
					B(x, v, z, p + n, front)
			if corner != "":
				B(x, 3, z, p + "dak_plat_hoek", corner)
			else:
				B(x, 3, z, p + "dak_plat_rand", front)
	G(31, 11, "natuur/gras")
	G(32, 11, "natuur/gras")
	Pr(31 * 4 + 2, 11 * 4 + 2, "planten/struik")
	Pr(32 * 4 + 2, 11 * 4 + 2, "hekken/haag_laag", "S")


# ------------------------------------------------------------------ railway with viaduct

## Railway x 33-34: level crossing at z 0, ramps up to a viaduct deck on level 5 over
## Main Street and down again, piers, overhead line masts and a platform at z 26..29.
func _railway() -> void:
	var tracks := [33, 34]
	for x in tracks:
		# flat track at the ends (level crossing in North Street)
		G(x, 0, "spoor/trein_overweg", "E")
		for z in [1, 2, 3, 26, 27, 28, 29]:
			G(x, z, "spoor/trein_recht")
		# ramp up (north -> south) to level 5
		for i in range(5):
			var z := 4 + i
			var tile_name := "helling/helling_brug_trein_recht_rand" if x == 34 else "helling/helling_brug_trein_recht"
			G(x, z, tile_name, "N", i)
		# bridge deck at level 5
		for z in range(9, 21):
			G(x, z, "brug/brug_dek_trein_rand", "S" if x == 33 else "N", 5)
		# ramp down
		for i in range(5):
			var z := 21 + i
			var tile_name := "helling/helling_brug_trein_recht_rand" if x == 33 else "helling/helling_brug_trein_recht"
			G(x, z, tile_name, "S", 4 - i)
		# piers: on grass, and on the Main Street pavements
		for z in [10, 19]:
			_pier(x, z, "brug/brug_pijler_gras", 0, 4)
		for z in [12, 17]:
			_pier(x, z, "brug/brug_pijler_stoep", 0, 4)
		for z in [9, 11, 18, 20]:
			G(x, z, "brug/brug_ligger", "S", 4)
	# under the viaduct: grass, and Main Street passes through (see _main_street)
	for x in tracks:
		for z in range(4, 26):
			if z >= 12 and z <= 17:
				continue
			if not occupied.has(Vector2i(x, z)):
				G(x, z, "natuur/gras")
	# overhead line
	for z in range(0, OLD_H, 3):
		var wy := 0.5
		if z >= 9 and z <= 20:
			wy = 5.0
		elif (z >= 4 and z < 9) or (z > 20 and z <= 25):
			continue
		Pr(33 * 4 - 0.5, z * 4 + 2, "spoor/bovenleidingmast", "S", wy)
	# level crossing in North Street
	Pr(32 * 4 + 1, 0 * 4 + 3.5, "spoor/spoorboom", "S")
	Pr(35 * 4 + 3, 0 * 4 + 0.5, "spoor/andreaskruis", "N")
	Pr(32 * 4 + 1, 2 * 4, "spoor/seinpaal", "N")
	G(35, 0, "weg/weg_vlak")
	# platform
	for z in range(26, 30):
		G(32, z, "spoor/perron", "E")
		G(31, z, "spoor/perron_midden")
	G(31, 26, "spoor/perron_trap", "N")
	Pr(31 * 4 + 2, 28 * 4, "ov/abri", "E", 1.0)
	Pr(32 * 4 + 1, 27 * 4, "straat/bank_modern", "E", 1.0)
	Pr(31 * 4 + 3, 29 * 4 + 2, "verlichting/lantaarn_modern", "S", 1.0)
	G(30, 26, "stoep/stoep_vol")
	for z in range(4, 12):
		G(35, z, "natuur/gras")


# ------------------------------------------------------------------ park with pond

## Park x 0..5, z 18..29 with a pond, gravel and sand paths, flower beds, trees and benches.
func _park() -> void:
	for x in range(0, 5):
		for z in range(18, OLD_H):
			var t := "natuur/gras"
			if (x + z) % 6 == 0:
				t = "natuur/gras"
			G(x, z, t)
	# pond x 1..4, z 20..25
	for x in [2, 3]:
		G(x, 20, "water/water_oever", "S")
		G(x, 25, "water/water_oever", "N")
		for z in range(21, 25):
			G(x, z, "water/water" if (x + z) % 3 else "water/water_lelies")
	for z in range(21, 25):
		G(1, z, "water/water_oever", "E")
		G(4, z, "water/water_oever", "W")
	G(1, 20, "water/water_oever_hoek_buiten", "SE")
	G(4, 20, "water/water_oever_hoek_buiten", "WS")
	G(1, 25, "water/water_oever_hoek_buiten", "EN")
	G(4, 25, "water/water_oever_hoek_buiten", "NW")
	G(3, 22, "water/water_riet")
	# paths
	for z in range(18, OLD_H):
		if z < 20 or z > 25:
			G(0, z, "natuur/pad_grind")
	column(5, 18, 29, "natuur/pad_grind")
	row(0, 4, 27, "natuur/pad_grind", "E")
	G(5, 27, "natuur/pad_grind")
	G(0, 27, "natuur/pad_grind")
	row(0, 4, 18, "natuur/pad_zand", "E")
	G(1, 28, "natuur/bloemperk_tulpen")
	G(2, 28, "natuur/bloemperk_tulpen", "E")
	G(3, 28, "natuur/bloemperk_tulpen")
	# quay pavement on the park side
	column(6, 18, 29, "weg/straat_klinkers")
	Pr(0 * 4 + 2, 23 * 4, "bomen/treurwilg")
	Pr(4 * 4 + 3, 19 * 4, "bomen/eik")
	Pr(1 * 4, 29 * 4, "bomen/den")
	Pr(4 * 4 + 2, 29 * 4 + 1, "bomen/populier")
	Pr(3 * 4 + 2, 29 * 4 + 2, "bomen/populier")
	Pr(2 * 4, 19 * 4, "bomen/berk")
	Pr(1 * 4, 19 * 4 + 2, "bomen/berk")
	Pr(4 * 4 + 2, 26 * 4 + 2, "bomen/herfstboom")
	Pr(5 * 4 + 2, 21 * 4, "bomen/conifeer")
	Pr(5 * 4 + 2, 24 * 4, "bomen/conifeer")
	Pr(0 * 4 + 2, 26 * 4 + 2, "straat/bank_hout", "E")
	Pr(2 * 4 + 2, 26 * 4 + 3, "straat/bank_hout", "N")
	Pr(1 * 4 + 1, 26 * 4, "verlichting/lantaarn_park")
	Pr(4 * 4 + 2, 18 * 4 + 2, "verlichting/lantaarn_park")
	Pr(0 * 4 + 2, 21 * 4, "straat/prullenbak_rond")
	Pr(3 * 4, 25 * 4 + 1, "water/steiger", "N", -0.0)
	Pr(2 * 4, 20 * 4 + 2, "planten/riet")
	Pr(4 * 4 + 1, 23 * 4, "planten/riet")
	Pr(3 * 4 + 2, 27 * 4 + 2, "planten/struik_bloei")
	Pr(5 * 4 + 2, 26 * 4 + 2, "water/reddingsboei")
	Pr(0 * 4 + 2, 28 * 4 + 2, "planten/graspol")
	Pr(2 * 4 + 2, 27 * 4 + 1, "planten/varen")


## Grass on every ground cell of the main map (x < W, z < H) that is still empty.
func _fill_grass() -> void:
	for x in range(0, W):
		for z in range(0, H):
			if not occupied.has(Vector2i(x, z)):
				G(x, z, "natuur/gras")


