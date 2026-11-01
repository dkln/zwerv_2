extends "res://tools/build/city/old_town.gd"
## Example-map builder, part 4 of 7 (see base.gd for the chain): the districts east
## and south of the old town (x 36..95 and z 30..98): churches, museums, 1930s and 1960s
## districts, high-rise, river with bridges, farm, motorway with tunnels and junction,
## campus with the shopping street, and the polder around the whole town.


## Polder around the whole town (POLDER tiles wide), so it doesn't end in the void:
## meadows of tall grass in parcels between ditches, now and then a pollard willow by a
## ditch, and a
## bulb field (tulips) west of the park.
const POLDER := 10


func _polder(z_end: int) -> void:
	for x in range(-POLDER, W + POLDER):
		for z in range(-POLDER, z_end + POLDER):
			if x >= 0 and x < W and z >= 0 and z < z_end:
				continue
			var px := posmod(x, 9)
			var pz := posmod(z, 12)
			if x >= -8 and x < 0 and z >= 13 and z <= 23:
				# bulb field west of the park: long parallel rows of tulips
				G(x, z, "natuur/bloemperk_tulpen", "E")
			elif px == 0:
				G(x, z, "water/sloot")
				if pz == 6 and _r(x, z, 3) == 0:
					Pr(x * 4 + 3.5, z * 4 + 2.0, "bomen/treurwilg")
			elif pz == 0:
				G(x, z, "water/sloot", "E")
			else:
				G(x, z, "natuur/gras_hoog")   # meadows: tall grass (the town keeps short grass)


## Church Street (z 0, pavement z 1, x 36..95) and Cross Street 2 (x 60-61, pavements
## x 59 and 62, z 2..39) with its signalised intersection with Main Street.
func _church_street_and_cross_street2() -> void:
	# Church Street (z=0) and pavement (z=1) from x 36 to 95
	for x in range(36, W):
		if x == 60 or x == 61:
			G(x, 0, "weg/kruising_stop")
			continue
		G(x, 0, "weg/rijstrook_onderbroken_geen" if x % 2 else "weg/weg_vlak", "E")
		if x == 59:
			G(x, 1, "stoep/stoep_hoek_buiten", "EN")
		elif x == 62:
			G(x, 1, "stoep/stoep_hoek_buiten", "NW")
		else:
			G(x, 1, "stoep/stoep_rand", "N")
	Pr(45 * 4, 1 * 4 + 1, "borden/bord_max_30", "N")
	Pr(70 * 4, 1 * 4 + 1, "borden/bord_drempel", "N")
	G(72, 0, "weg/drempel_plateau", "E")
	G(48, 0, "weg/drempel_punaise", "E")
	# Cross Street 2 (x 60,61) with pavements 59 and 62, from z 2 to 39
	for z in range(2, 40):
		if z >= 12 and z <= 17:
			continue
		if z == 10 or z == 20:
			G(60, z, "weg/zebrapad")
			G(61, z, "weg/zebrapad")
			G(59, z, "stoep/stoep_ribbel", "E")
			G(62, z, "stoep/stoep_ribbel", "W")
			continue
		if z == 11:
			G(60, z, "weg/rijstrook_stop_tekst", "N")
			G(61, z, "weg/rijstrook_pijl_rechtdoor_rechts", "S")
		elif z == 18:
			G(60, z, "weg/rijstrook_pijl_links", "N")
			G(61, z, "weg/rijstrook_stopstreep", "S")
		elif z % 7 == 3:
			G(60, z, "weg/drempel_bus", "N")
			G(61, z, "weg/drempel_bus", "S")
		else:
			G(60, z, "weg/rijstrook_geen_kant", "N")
			G(61, z, "weg/rijstrook_doorgetrokken_dubbel" if z > 30 else "weg/rijstrook_onderbroken_kant", "S")
		G(59, z, "stoep/stoep_goot_kolk" if z % 9 == 4 else "stoep/stoep_goot_rand", "E")
		G(62, z, "stoep/stoep_goot_rand", "W")
		if z % 4 == 2:
			Pr(59 * 4 + 1, z * 4 + 2, "verlichting/lantaarn_modern", "W")
			Pr(62 * 4 + 3, z * 4 + 2, "bomen/linde")
	# intersection with Main Street: traffic lights for cars, bicycles, buses and pedestrians
	for x in [60, 61]:
		G(x, 12, "weg/zebrapad")
		G(x, 13, "weg/fietsoversteek")
		G(x, 14, "weg/kruis_markering")
		G(x, 15, "weg/weg_vlak")
		G(x, 16, "weg/fietsoversteek")
		G(x, 17, "weg/zebrapad")
	Pr(59 * 4 + 3, 12 * 4 + 3.5, "verkeer/verkeerslicht_set", "N")
	Pr(62 * 4 + 1, 17 * 4 + 0.5, "verkeer/verkeerslicht_set", "S")
	Pr(62 * 4 + 0.5, 12 * 4 + 3.5, "verkeer/verkeerslicht_bus", "W")
	Pr(59 * 4 + 3.5, 17 * 4 + 0.5, "verkeer/verkeerslicht_bus", "E")
	Pr(59 * 4 + 2, 13 * 4 + 1, "verkeer/drukknop_fiets", "E")
	Pr(62 * 4 + 2, 16 * 4 + 3, "verkeer/drukknop_fiets", "W")
	Pr(59 * 4 + 1, 12 * 4 + 1, "verkeer/drukknop_voetganger", "N")
	Pr(62 * 4 + 3, 17 * 4 + 3, "verkeer/drukknop_voetganger", "S")
	Pr(59 * 4 + 1, 11 * 4, "borden/bord_voorrangskruispunt", "N")
	Pr(62 * 4 + 3, 19 * 4, "borden/bord_verplicht_rechtsaf", "S")
	# tram overhead line along Main Street
	for x in range(40, W, 6):
		Pr(x * 4, 12 * 4 + 3.5, "ov/tram_bovenleiding_mast", "N")


## South Road along x at z 40..46 (pavement, cycle path, two lanes, bus lane, cycle path,
## pavement) with a bridge over the canal, bus stops and signs.
func _south_road() -> void:
	# profile z: 40 pavement, 41 cycle path, 42 lane west, 43 lane east, 44 bus lane east, 45 cycle path, 46 pavement
	for x in range(0, W):
		if x == 8 or x == 9:
			G(x, 40, "brug/brug_dek_weg_rand", "W")
			for z in range(41, 46):
				G(x, z, "brug/brug_dek_weg_midden", "E")
			G(x, 46, "brug/brug_dek_weg_rand", "E")
			continue
		if x == 28 or x == 29 or x == 60 or x == 61:
			G(x, 40, "weg/zebrapad")
			G(x, 41, "weg/fietsoversteek")
			G(x, 42, "weg/weg_vlak")
			G(x, 43, "weg/weg_vlak")
			G(x, 44, "weg/weg_vlak")
			G(x, 45, "weg/fietsoversteek")
			G(x, 46, "stoep/stoep_goot_rand", "N")
			continue
		# north pavement: corners at the side streets, road at the quay streets
		if x == 27 or x == 59:
			G(x, 40, "stoep/stoep_hoek_buiten", "SE")
		elif x == 30 or x == 62:
			G(x, 40, "stoep/stoep_hoek_buiten", "WS")
		elif x == 6 or x == 11:
			G(x, 40, "weg/weg_vlak")
		else:
			G(x, 40, "stoep/stoep_goot_rand", "S")
		G(x, 41, "fietspad/fietspad_recht", "E")
		G(x, 42, "weg/rijstrook_onderbroken_kant", "E")
		G(x, 43, "weg/rijstrook_geen_geen", "W")
		var bus := "weg/rijstrook_bus_leeg"
		if x % 16 == 3:
			bus = "weg/rijstrook_bus"
		elif x == 20 or x == 50:
			bus = "weg/busstrook_halte"
		G(x, 44, bus, "W")
		G(x, 45, "fietspad/fietspad_recht", "E")
		G(x, 46, "stoep/stoep_goot_rand", "N")
	# median lanterns, bus stops, signs
	for x in range(2, W, 8):
		Pr(x * 4 + 2, 43 * 4, "verlichting/lantaarn_middenberm", "E")
	Pr(20 * 4, 46 * 4 + 2, "ov/abri", "N")
	Pr(50 * 4, 46 * 4 + 2, "ov/bushokje", "N")
	Pr(22 * 4, 46 * 4 + 3, "ov/bushalte_paal", "N")
	Pr(52 * 4, 46 * 4 + 3, "ov/bushalte_paal", "N")
	Pr(14 * 4, 46 * 4 + 3, "borden/bord_busbaan", "W")
	Pr(70 * 4, 40 * 4 + 1, "borden/bord_max_50", "E")
	Pr(80 * 4, 46 * 4 + 3, "borden/bord_informatie", "W")
	Pr(90 * 4, 40 * 4 + 1, "borden/bord_ziekenhuis", "E")
	Pr(66 * 4, 40 * 4 + 1, "verkeer/wegafzetting_paal_flitser", "E")
	# traffic bollards on the traffic island at the intersection
	for x in [27, 30, 59, 62]:
		Pr(x * 4 + 2, 43 * 4, "verkeer/verkeerszuil", "E")


## Gothic cathedral x 36..45, z 2..11 (nave, aisles with flying buttresses, west towers)
## and a school with playground x 47..57.
func _churches_and_school() -> void:
	# cathedral (kerk_steen) x 36..45, z 3..10, front facade facing west
	var k := "kerk_steen"
	var p := k + "/" + k + "_"
	fill_rect(36, 2, 45, 11, "plein/plein_natuursteen")
	# nave (2 deep) x 38..45, z 5..6, three storeys high
	for x in range(38, 46):
		for z in [5, 6]:
			var facing := "N" if z == 5 else "S"
			B(x, 0, z, p + "blok_dicht", "S")
			B(x, 1, z, p + "verd_spitsraam", facing)
			B(x, 2, z, p + "verd_spitsraam", facing)
			B(x, 3, z, p + ("dak_schuin_hoek_buiten" if x == 45 else "dak_schuin"), (("EN" if z == 5 else "SE") if x == 45 else facing))
	# side aisles (1 storey) with buttresses and flying buttresses
	for x in range(38, 46):
		for z in [4, 7]:
			var facing := "N" if z == 4 else "S"
			B(x, 0, z, p + ("verd_steunbeer" if x % 2 else "bg_spitsraam"), facing)
			if x % 2:
				B(x, 1, z, p + "luchtboog", facing)
			else:
				B(x, 1, z, p + "dak_schuin", facing)
	# west front with two towers and rose window
	for z in [5, 6]:
		B(37, 0, z, p + "bg_portaal", "W")
		B(37, 1, z, p + "verd_roosvenster" if z == 5 else p + "verd_spitsraam", "W")
		B(37, 2, z, p + "verd_spitsraam", "W")
		B(37, 3, z, p + "gevel_spits" if z == 5 else p + "dak_plat_midden", "W")
	for z in [4, 7]:
		tower(37, z, k, ["toren_portaal", "toren_raam", "toren_raam", "toren_galmgat", "toren_klok", "toren_pinakels"], "W")
	tower(44, 3, k, ["toren_raam", "toren_raam", "toren_galmgat", "toren_spits_onder", "toren_spits_boven"], "N")
	for z in [3, 8]:
		Pr(36 * 4 + 2, z * 4 + 2, "bomen/linde")
	Pr(41 * 4, 9 * 4 + 2, "straat/bank_hout", "N")
	Pr(43 * 4, 9 * 4 + 2, "straat/bank_hout", "N")
	# school with playground x 47..57
	block(48, 2, 8, 2, "school", 3, {"front": "S", "gf": ["bg_raam", "bg_entree", "bg_raam"], "gf_side": "bg_raam",
		"upper": ["verd_raam"], "roof": "flat"})
	B(52, 3, 2, "school/school_dak_zonnepanelen", "S")
	fill_rect(47, 4, 57, 10, "natuur/speeltuin_rubber")
	fill_rect(55, 7, 57, 10, "natuur/speeltuin_zand")
	fill_rect(47, 2, 47, 3, "stoep/stoep_vol")
	fill_rect(56, 2, 57, 3, "stoep/stoep_vol")
	Pr(49 * 4, 6 * 4, "speeltuin/klimrek")
	Pr(51 * 4 + 2, 8 * 4, "speeltuin/schommel", "E")
	Pr(53 * 4 + 2, 6 * 4, "speeltuin/glijbaan", "E")
	Pr(56 * 4, 8 * 4 + 2, "speeltuin/zandbak")
	Pr(49 * 4, 9 * 4 + 2, "speeltuin/wipwap")
	Pr(54 * 4, 9 * 4 + 2, "speeltuin/draaimolen")
	Pr(57 * 4, 5 * 4, "speeltuin/speelhuisje")
	Pr(51 * 4, 4 * 4 + 1, "speeltuin/basketbalpaal", "S")
	Pr(47 * 4 + 2, 7 * 4 + 2, "speeltuin/voetbaldoel", "E")
	Pr(55 * 4, 4 * 4 + 2, "speeltuin/pingpongtafel")
	for x in range(47, 58, 2):
		Pr(x * 4 + 2, 11 * 4 + 3.5, "hekken/schoolhek", "S")
	Pr(47 * 4 + 1, 11 * 4, "fietsen/fietsenrek_vol", "E")
	Pr(58 * 4 - 1, 9 * 4, "borden/bord_let_op_kinderen", "E")


## Square x 63..95, z 2..11 with a classical museum with dome, the town hall with clock
## tower and flags, and a modern museum.
func _museum_and_town_hall() -> void:
	fill_rect(63, 2, 95, 11, "plein/plein_tegels")
	# classical museum with dome (x 64..70, z 4..10)
	var gap := []
	for x in range(66, 69):
		for z in range(6, 9):
			gap.append(Vector2i(x, z))
	block(64, 4, 7, 7, "museum_klassiek", 2, {"front": "S", "gf": ["bg_raam_boog", "bg_zuilen", "bg_raam_boog"],
		"gf_side": "bg_raam_boog", "gf_corner": "bg_raam_boog_hoek", "upper": ["verd_raam_boog", "verd_relief"],
		"upper_corner": "verd_raam_boog_hoek", "roof": "cornice", "gap": gap})
	B(67, 2, 7, "museum_klassiek/museum_klassiek_dak_koepel_3x3", "S")
	B(67, 2, 10, "museum_klassiek/museum_klassiek_top_fronton", "S")
	Pr(66 * 4, 11 * 4 + 1, "planten/plantenbak_beton")
	Pr(69 * 4, 11 * 4 + 1, "planten/plantenbak_beton")
	# town hall (government) x 73..79, z 6..10 + clock tower
	block(73, 6, 7, 5, "overheid", 3, {"front": "S", "gf": ["bg_raam", "bg_entree", "bg_raam"], "gf_side": "bg_raam",
		"upper": ["verd_raam_hoog", "verd_balkon"], "upper_corner": "verd_raam_hoog_hoek", "roof": "battlements"})
	B(76, 3, 10, "overheid/overheid_top_fronton", "S")
	B(75, 3, 10, "overheid/overheid_top_naambord", "S")
	tower(76, 7, "overheid", ["blok_dicht", "blok_dicht", "blok_dicht", "blok_dicht", "toren_klok", "toren_spits_onder", "toren_spits_boven"])
	for i in 3:
		Pr(74 * 4 + i * 8, 11 * 4 + 2, ["straat/vlaggenmast_nl", "straat/vlaggenmast_regenboog", "straat/vlaggenmast_denhaag"][i], "S")
	D(73 * 4.0, 8 * 4.0, 4.0, "gevel/vlag_regenboog", "W")
	D(80 * 4.0, 8 * 4.0, 4.0, "gevel/vlag_denhaag", "E")
	# modern museum x 83..93, z 4..10
	block(83, 4, 11, 6, "museum_modern", 2, {"front": "S", "gf": ["bg_dicht", "bg_entree", "bg_dicht"], "gf_side": "bg_dicht",
		"gf_corner": "bg_entree_hoek", "upper": ["verd_lichtstrook", "verd_dicht"], "upper_corner": "verd_lichtstrook_hoek", "roof": "flat"})
	for x in range(84, 93):
		B(x, 2, 10, "museum_modern/museum_modern_dak_overstek", "S")
	Pr(88 * 4, 11 * 4 + 2, "planten/boombak")
	Pr(92 * 4, 11 * 4 + 2, "planten/boombak")


## 1930s district x 36..48, z 18..39: a closed block of 4 storeys with shops and
## terraces on Main Street, porch flats along an E-W street and a one-way street.
func _district_1930s() -> void:
	# streets: N-S residential street x=47 (pavements 46 and 48), E-W street z=29 (pavements 28 and 30)
	profile_z(18, 39, [[46, "stoep/stoep_rand", "E"], [47, "weg/straat_eenrichting", "S"], [48, "stoep/stoep_rand", "W"]], [28, 29, 30])
	profile_x(36, 58, [[28, "stoep/stoep_rand", "S"], [29, "weg/weg_vlak", "E"], [30, "stoep/stoep_rand", "N"]], [46, 47, 48])
	G(46, 29, "weg/weg_vlak")
	G(47, 29, "weg/kruising_haaientanden")
	G(48, 29, "weg/weg_vlak")
	for c in [[46, 28, "SE"], [48, 28, "WS"], [46, 30, "EN"], [48, 30, "NW"]]:
		G(c[0], c[1], "stoep/stoep_hoek_buiten", c[2])
	Pr(46 * 4 + 1, 20 * 4, "borden/bord_eenrichtingsweg", "E")
	Pr(48 * 4 + 3, 38 * 4, "borden/bord_verboden_in_te_rijden", "W")
	Pr(48 * 4 + 3, 37 * 4, "borden/bord_onderbord_uitgezonderd", "W")
	for z in [21, 33]:
		G(47, z, "weg/drempel_asfalt")
	# tall upstairs flats (4 storeys) as a closed city block with shops/restaurants on Main Street
	ring(36, 18, 10, 10, "jaren30", 4, {"gf": ["bg_portiek", "bg_raam", "bg_erker"], "upper": ["verd_raam", "verd_erker", "verd_balkon", "verd_trappenhuis"],
		"back": ["verd_raam", "verd_balkon"], "roof_extra": ["dak_schuin_dakkapel", "dak_schuin_schoorsteen"]})
	var shops := ["bg_kleding", "bg_restaurant", "bg_cafe", "bg_bar", "bg_telefoon", "bg_winkel_luifel", "bg_cafe", "bg_restaurant"]
	for i in range(1, 9):
		B(36 + i, 0, 18, "jaren30/jaren30_" + shops[i - 1], "N")
	fill_rect(38, 20, 43, 25, "natuur/gras")
	Pr(40 * 4 + 2, 22 * 4 + 2, "bomen/bloesemboom")
	Pr(42 * 4, 24 * 4, "speeltuin/zandbak")
	# terraces on the Main Street pavement
	for i in range(1, 9):
		var wx := (36 + i) * 4 + 2.0
		if shops[i - 1] in ["bg_restaurant", "bg_cafe"]:
			Pr(wx, 17 * 4 + 1.5, "terras/terras_set_parasol" if i % 2 else "terras/terras_set_parasol_groen")
			Pr(wx - 1.5, 17 * 4 + 3.5, "terras/terras_scherm", "S")
		elif shops[i - 1] == "bg_bar":
			Pr(wx, 17 * 4 + 2, "terras/statafel")
		if i % 3 == 0:
			Pr(wx + 1.5, 17 * 4 + 0.5, "terras/stoepbord", "S")
	# medium-height upstairs flats (3 storeys), porch dwellings on street z=30
	block(36, 31, 10, 2, "jaren30", 3, {"front": "N", "gf": ["bg_portiek", "bg_raam", "bg_erker"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_erker", "verd_balkon"], "roof": "sloped", "roof_extra": ["dak_schuin_dakkapel"]})
	block(36, 35, 10, 2, "jaren30", 3, {"front": "S", "gf": ["bg_portiek", "bg_raam"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_trappenhuis"], "roof": "flat"})
	fill_rect(36, 33, 45, 34, "natuur/gras")
	for x in range(36, 46, 2):
		Pr(x * 4 + 2, 34 * 4 + 0.5, "muurtjes/tuinmuur_middel" if x % 4 else "muurtjes/tuinmuur_poort", "S")
	fill_rect(36, 37, 45, 39, "stoep/stoep_vol")
	for x in range(36, 46, 3):
		Pr(x * 4 + 2, 38 * 4 + 2, "bomen/linde")


## Mansions (1600 and 1900 styles) on Main Street x 49..58 with front steps and gardens.
func _mansions() -> void:
	# mansions 1600 (x 49..53) and 1900 (x 54..58) on Main Street (front north)
	block(49, 18, 5, 2, "herenhuis_1600", 3, {"front": "N", "gf": ["bg_deur", "bg_raam"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_balkon"], "roof": "sloped", "top": "top_lijstgevel_fronton"})
	B(51, 3, 18, "herenhuis_1600/herenhuis_1600_gevel_klok", "N")
	block(54, 18, 5, 2, "herenhuis_1900", 3, {"front": "N", "gf": ["bg_deur", "bg_raam_boog"], "gf_side": "bg_raam_boog",
		"gf_corner": "bg_raam_boog_hoek", "upper": ["verd_raam_boog", "verd_erker", "verd_balkon"], "upper_corner": "verd_raam_boog_hoek", "roof": "sloped",
		"top": "dak_mansarde_rand"})
	# front steps and gardens with walls and gates
	for x in [49, 51, 53]:
		D(x * 4 + 2.0, 18 * 4.0, 0.0, "deuren/bordes_klassiek", "N")
	for x in range(49, 59):
		fill_rect(x, 20, x, 27, "natuur/gras")
		Pr(x * 4 + 2, 27 * 4 + 3.5, "muurtjes/tuinmuur_hoog_poort" if x % 3 == 0 else "muurtjes/tuinmuur_hoog", "S")
		Pr(x * 4 + 0.5, 23 * 4 + 2, "hekken/haag", "E")
	Pr(50 * 4 + 2, 24 * 4, "bomen/kastanje")
	Pr(55 * 4 + 2, 25 * 4, "bomen/plataan")
	Pr(57 * 4, 22 * 4, "planten/bosje_klein")
	Pr(52 * 4, 22 * 4, "terras/terras_set")


## Village church with tower and a modern church with detached bell tower (x 49..58, z 31..39).
func _small_churches() -> void:
	fill_rect(49, 31, 58, 39, "natuur/gras")
	# village church (small) x 51..55, z 33, gable roof, tower at x=50
	var k := "kerk_baksteen"
	block(51, 33, 5, 1, k, 2, {"front": "S", "gf": ["bg_spitsraam"], "gf_side": "bg_spitsraam", "gf_corner": "bg_spitsraam_hoek",
		"upper": ["verd_dicht"], "upper_corner": "verd_spitsraam_hoek", "roof": "gable"})
	tower(50, 33, k, ["toren_portaal", "toren_raam", "toren_klok", "toren_spits_onder", "toren_spits_boven"], "W")
	fill_rect(49, 32, 56, 34, "natuur/gras")
	G(49, 33, "natuur/grindpad")
	# modern (reformed) church x 53..57, z 36..38 with a detached bell tower
	block(53, 36, 5, 3, "kerk_modern", 2, {"front": "N", "gf": ["bg_entree", "bg_dicht"], "gf_side": "bg_dicht",
		"gf_corner": "bg_entree_hoek", "upper": ["verd_spleet", "verd_kruis"], "upper_corner": "verd_spleet_hoek", "roof": "flat"})
	tower(51, 37, "kerk_modern", ["toren_beton", "toren_beton", "toren_beton_klok"])
	Pr(50 * 4, 36 * 4, "bomen/treurwilg")
	Pr(57 * 4, 31 * 4 + 2, "bomen/den")


## High-rise district x 63..95, z 18..39: offices, apartment towers, a gallery flat,
## parking garage, radio tower, glass canopy, pillars and a footbridge at level 4.
func _high_rise() -> void:
	fill_rect(63, 18, 76, 39, "plein/plein_tegels")
	fill_rect(80, 18, 95, 39, "plein/plein_tegels")
	profile_z(18, 39, [[77, "stoep/stoep_rand", "E"], [78, "weg/rijstrook_onderbroken_kant", "S"], [79, "stoep/stoep_rand", "W"]])
	# 1980s office (10 storeys)
	block(64, 19, 3, 3, "kantoor_80", 10, {"front": "S", "gf": ["bg_entree"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_spiegelband", "verd_band"], "upper_corner": "verd_spiegelband_hoek", "roof": "flat"})
	B(65, 10, 20, "kantoor_80/kantoor_80_dak_installatie", "S")
	D(64 * 4 + 4.0, 19 * 4 + 3.0, 30.0, "dak/koelinstallatie", "S")
	D(66 * 4 + 2.0, 21 * 4 + 2.0, 30.0, "dak/luchtbehandeling", "E")
	D(71 * 4 + 2.0, 20 * 4 + 2.0, 42.0, "dak/koelinstallatie", "E")
	D(65 * 4 + 2.0, 26 * 4 + 2.0, 21.0, "dak/koelinstallatie", "S")
	D(67 * 4 + 2.0, 26 * 4 + 2.0, 21.0, "dak/zonnepanelen_schuin_rij", "S")
	D(73 * 4 + 4.0, 33 * 4 + 4.0, 30.0, "dak/koelinstallatie", "S")
	# 2000s office (14 storeys) with crown
	block(70, 19, 3, 3, "kantoor_2000", 14, {"front": "S", "gf": ["bg_entree"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_zonwering", "verd_vliesgevel"], "upper_corner": "verd_zonwering_hoek", "roof": "flat"})
	for x in range(70, 73):
		B(x, 14, 21, "kantoor_2000/kantoor_2000_dak_kroon_rand", "S")
	# modern office (7 storeys, louvres) and one with large windows
	block(64, 25, 5, 3, "kantoor_modern", 7, {"front": "S", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_lamellen", "verd_raam_groot"], "upper_corner": "verd_lamellen_hoek", "roof": "flat"})
	block(70, 25, 2, 2, "kantoor_glas", 5, {"front": "S", "gf": ["bg_entree"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_raam_klein"], "upper_corner": "verd_band_hoek", "roof": "flat"})
	# modern apartment building (16 storeys)
	block(73, 24, 3, 4, "appartement_modern", 16, {"front": "W", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_glas", "verd_loggia", "verd_balkon", "verd_paneel", "verd_raam_groot", "verd_raam_klein"], "upper_corner": "verd_balkon_hoek", "roof": "flat"})
	B(74, 16, 25, "appartement_modern/appartement_modern_dak_daktuin", "S")
	# gallery flat (1950s/60s, 10 storeys)
	block(64, 33, 12, 2, "galerijflat", 10, {"front": "N", "gf": ["bg_bergingen", "bg_entree", "bg_bergingen"], "gf_side": "bg_bergingen",
		"gf_corner": "bg_bergingen_hoek", "upper": ["verd_galerij"], "upper_corner": "verd_galerij_hoek", "roof": "flat"})
	for x in range(64, 76):
		for v in range(1, 10):
			B(x, v, 34, "galerijflat/galerijflat_" + ("verd_balkons_hoek" if x == 64 or x == 75 else "verd_balkons"),
				("WS" if x == 64 else "SE") if (x == 64 or x == 75) else "S")
	tower(76, 33, "galerijflat", ["bg_entree", "verd_trappenhuis", "verd_trappenhuis", "verd_trappenhuis", "verd_trappenhuis",
		"verd_trappenhuis", "verd_trappenhuis", "verd_trappenhuis", "verd_trappenhuis", "verd_trappenhuis", "dak_liftopbouw"], "E")
	# parking garage (4 decks) x 81..86, z 19..24
	_parking_decks(81, 19, 6, 6, 4)
	B(81, 0, 21, "parkeergarage/parkeergarage_inrit", "W")
	for v in range(3):
		B(84, v, 21 + (v % 2), "parkeergarage/parkeergarage_helling", "N" if v % 2 == 0 else "S")
	for v in range(4):
		B(87, v, 19, "parkeergarage/parkeergarage_trappenhuis", "S")
	Pr(80 * 4 + 1, 21 * 4, "hekken/slagboom", "W")
	Pr(80 * 4 + 1, 23 * 4, "paaltjes/parkeerautomaat", "W")
	# radio tower
	_mast(92, 20, "overig/radiotoren", 12)
	# glass canopy with terrace
	for x in range(88, 95):
		for z in range(24, 29):
			B(x, 0, z, "overkapping/overkapping_glas_kolom" if (x % 2 == 0 and z % 2 == 0) else "overkapping/overkapping_glas", "S")
	for x in [89, 91, 93]:
		Pr(x * 4, 26 * 4, "terras/terras_set")
	Pr(90 * 4, 27 * 4 + 2, "terras/bloembak_terras")
	# pillars and colonnade
	for x in [64, 67, 70]:
		B(x, 0, 30, "pilaren/pilaar_klassiek" if x == 64 else ("pilaren/pilaar_beton" if x == 67 else "pilaren/pilaar_staal"), "S")
	B(72, 0, 30, "pilaren/pilaar_baksteen", "S")
	for x in range(64, 70):
		B(x, 0, 31, "pilaren/zuilengang_klassiek", "N")
	# footbridge over street x=78 (from apartments to parking garage), at level 4 with stairs
	for x in range(76, 81):
		G(x, 30, "brug/loopbrug_overdekt", "E", 4)
	for i in range(4):
		G(80, 34 - i, "brug/loopbrug_trap", "S", i)


## Indoor pool (hollow hall over a sunken basin), a glass hall and an outdoor pool
## (x 80..94, z 28..39).
func _swimming_and_halls() -> void:
	# indoor pool: hollow hall (glass/pool) x 88..94, z 31..37 with pool tiles on layer -1
	var h0 := 88
	var z0 := 31
	_hall(h0, z0, 7, 7, "hal_zwembad", Vector2i(91, z0))
	fill_rect(h0, z0, h0 + 6, z0 + 6, "zwembad/zwembad_kant_tegels")
	_pool_basin(h0 + 1, z0 + 2, 5, 3, true, false)
	# glass hall next to it x 81..86, z 28..31 (door on the south side)
	_hall(81, 28, 6, 4, "hal_glas", Vector2i(83, 31))
	Pr(83 * 4, 29 * 4 + 2, "planten/boombak")
	Pr(85 * 4, 29 * 4 + 2, "terras/terras_set")
	D(83 * 4 + 2.0, 32 * 4.0, 0.0, "deuren/draaideur", "S")
	# outdoor pool x 81..86, z 33..38
	fill_rect(80, 33, 87, 39, "zwembad/zwembad_kant_tegels")
	_pool_basin(81, 34, 6, 4, false, false)
	G(87, 38, "zwembad/kinderbad")
	Pr(81 * 4 + 2, 33 * 4 + 3, "zwembad/duikplank", "S")
	Pr(84 * 4, 33 * 4 + 3.5, "zwembad/zwembadtrap", "S")
	Pr(86 * 4 + 2, 38 * 4 + 2, "zwembad/badmeesterstoel", "N")
	for x in [81, 83, 85]:
		Pr(x * 4 + 2, 39 * 4, "zwembad/ligstoel", "N")
	Pr(87 * 4 + 2, 35 * 4, "zwembad/parasol")
	for z in range(33, 40, 2):
		Pr(80 * 4, z * 4 + 2, "hekken/hek_gaas_hoog", "E")


## River z 49..53 across the whole map (water on level -2, quays z 48 and 54) with a
## steel arch bridge, cable-stayed bridge, drawbridge, footbridge, quay stairs and boats.
func _river_and_bridges() -> void:
	# river z 49..53 on layer -2, quays at z 48 and 54
	for x in range(0, W):
		for z in range(49, 54):
			G(x, z, "water/water", "S", -2)
			occupied[Vector2i(x, z)] = true
		for z in [48, 54]:
			if (x == 8 or x == 9) and z == 48:
				G(x, z, "water/water_gracht", "S", -2)
				occupied[Vector2i(x, z)] = true
				continue
			G(x, z, "water/kademuur_alg", "S", -2)
			G(x, z, "water/kademuur", "S", -1)
			G(x, z, "stoep/stoep_kade" if x % 6 else "stoep/stoep_kade_klinker", "S" if z == 48 else "N")
			if x % 3 == 0:
				Pr(x * 4 + 2, z * 4 + (1 if z == 48 else 3), "paaltjes/bolder")
			if x % 6 == 3:
				Pr(x * 4 + 2, z * 4 + (2.5 if z == 48 else 1.5), "verlichting/lantaarn_klassiek")
	# steel arch bridge in Cross Street 2 (x 60,61)
	for i in range(5):
		G(60, 53 - i, "brug/staalboog_rand_%d" % (i + 1), "S")
		G(61, 49 + i, "brug/staalboog_rand_%d" % (i + 1), "N")
	for z in [48, 54]:
		G(60, z, "weg/rijstrook_geen_kant", "N")
		G(61, z, "weg/rijstrook_onderbroken_kant", "S")
	# cable-stayed bridge at x 40,41
	G(40, 51, "brug/tuibrug_0", "S")
	for i in range(1, 4):
		G(40, 51 - i, "brug/tuibrug_%d" % i, "S")
		G(40, 51 + i, "brug/tuibrug_%d_achter" % i, "S")
	for z in range(48, 55):
		G(41, z, "brug/brug_dek_weg_rand", "N")
	# drawbridge (classic, narrow) at x=20
	G(20, 49, "brug/ophaalbrug_dek", "S")
	G(20, 50, "brug/ophaalbrug_portaal", "N")
	G(20, 51, "brug/ophaalbrug_dek", "S")
	G(20, 52, "brug/ophaalbrug_portaal", "S")
	G(20, 53, "brug/ophaalbrug_dek", "S")
	Pr(19 * 4 + 2, 48 * 4 + 2, "water/brugwachtershuisje_klassiek")
	# modern footbridge and footbridge-style bridge at x=75
	for z in range(49, 54):
		G(75, z, "brug/voetbrug_modern", "S")
	Pr(76 * 4 + 2, 54 * 4 + 2, "water/brugwachtershuisje_modern")
	# quay stairs and boats
	G(30, 54, "waterkant/kadetrap", "N", -2)
	occupied[Vector2i(30, 54)] = true
	for x in [12, 26, 50, 68, 88]:
		Pr(x * 4, 52 * 4 + 2, "water/woonboot", "E", -2.0)
	Pr(34 * 4, 50 * 4, "water/sloep", "W", -2.0)
	Pr(56 * 4, 50 * 4 + 2, "water/roeiboot", "E", -2.0)


## 1960s district x 0..30, z 55..71: residential streets, single-family homes, a low
## gallery flat, car park, playground and a pond with different banks.
func _district_1960s() -> void:
	# residential streets z=56 and z=64 (with speed bumps), N-S street x=15
	profile_x(0, 30, [[55, "stoep/stoep_rand", "S"], [56, "weg/weg_vlak", "E"], [57, "stoep/stoep_rand", "N"]], [15])
	profile_x(0, 30, [[63, "stoep/stoep_rand", "S"], [64, "weg/weg_vlak", "E"], [65, "stoep/stoep_rand", "N"]], [15])
	profile_z(55, 71, [[14, "stoep/stoep_rand", "E"], [15, "weg/weg_vlak", "S"], [16, "stoep/stoep_rand", "W"]], [55, 56, 57, 63, 64, 65])
	for z in [56, 64]:
		G(15, z, "weg/kruising_vlak")
		G(5, z, "weg/drempel_punaise", "E")
		G(25, z, "weg/verkeersdrempel", "E")
	for c in [[14, 55], [16, 55], [14, 57], [16, 57], [14, 63], [16, 63], [14, 65], [16, 65]]:
		G(c[0], c[1], "weg/weg_vlak")
	for z in [55, 57, 63, 65]:
		G(15, z, "weg/weg_vlak")
	Pr(14 * 4, 58 * 4, "borden/bord_woonerf", "E")
	# single-family homes (2 storeys, sloped roof, bay windows and dormers)
	block(1, 58, 12, 2, "jaren60", 2, {"front": "N", "gf": ["bg_deur", "bg_raam", "bg_erker"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_raam_klein"], "roof": "sloped", "roof_extra": ["dak_schuin_dakkapel", "dak_schuin_dakkapel", "dak_schuin_schoorsteen"]})
	block(1, 61, 12, 2, "jaren60", 2, {"front": "S", "gf": ["bg_deur", "bg_erker", "bg_berging"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_balkon"], "roof": "sloped", "roof_extra": ["dak_schuin_dakkapel"]})
	fill_rect(0, 58, 0, 62, "natuur/gras")
	for x in range(1, 13):
		G(x, 60, "natuur/gras")
		Pr(x * 4 + 0.5, 60 * 4 + 2, "hekken/schutting_hout", "E")
	# garage doors and details
	D(3 * 4 + 2.0, 63 * 4.0, 0.0, "deuren/garagedeur_kanteldeur", "S")
	D(7 * 4 + 2.0, 63 * 4.0, 0.0, "deuren/garagedeur_sectionaal", "S")
	D(11 * 4 + 2.0, 63 * 4.0, 0.0, "deuren/garagedeur_roldeur", "S")
	for x in [2, 6, 10]:
		D(x * 4 + 2.0, 58 * 4.0, 3.5, "zonwering/knikarmscherm_streep", "N")
		D(x * 4 + 2.0, 58 * 4.0, 6.0, "zonwering/uitvalscherm_oranje", "N")
	# maisonettes / low gallery flat (4 storeys) x 17..28
	block(17, 58, 12, 2, "jaren60", 4, {"front": "N", "gf": ["bg_deur", "bg_raam", "bg_berging"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_galerij_deur", "verd_raam_klein"], "upper_corner": "verd_raam_hoek", "roof": "flat"})
	for x in range(18, 28):
		B(x, 2, 58, "jaren60/jaren60_verd_galerij_deur", "N")
		B(x, 3, 58, "jaren60/jaren60_verd_raam_klein", "N")
	# car park x 17..28, z 60..62
	for x in range(17, 29):
		G(x, 60, "parkeren/parkeervak_haaks" if x % 4 else "parkeren/parkeervak_laadpaal", "S")
		G(x, 61, "parkeren/parkeerplaats_rijbaan", "E")
		G(x, 62, "parkeren/parkeervak_schuin" if x < 23 else "parkeren/parkeervak_haaks_eind", "N")
	for x in [20, 24, 28]:
		Pr(x * 4, 60 * 4 + 0.5, "paaltjes/laadpaal", "S")
	Pr(17 * 4 + 1, 61 * 4 + 2, "paaltjes/parkeerautomaat", "E")
	Pr(22 * 4, 63 * 4 + 0.5, "straat/afvalcontainer_ondergronds")
	Pr(24 * 4, 63 * 4 + 1, "straat/glasbak")
	Pr(26 * 4, 63 * 4 + 1, "straat/kledingcontainer")
	Pr(28 * 4, 63 * 4 + 1, "straat/container_klein")
	# playground, shrubs and pond with waterside x 0..13 / 17..30, z 66..71
	fill_rect(0, 66, 13, 71, "natuur/gras")
	fill_rect(1, 67, 5, 70, "natuur/speeltuin_rubber")
	Pr(2 * 4, 68 * 4, "speeltuin/schommel", "E")
	Pr(4 * 4, 69 * 4, "speeltuin/glijbaan")
	Pr(3 * 4, 67 * 4 + 2, "speeltuin/wipwap")
	for x in [7, 9, 11]:
		Pr(x * 4 + 2, 68 * 4 + 2, "planten/bosje_groot" if x == 9 else "planten/bosje_klein")
	Pr(12 * 4, 71 * 4, "planten/braamstruik")
	fill_rect(17, 66, 30, 71, "natuur/gras")
	for x in range(19, 29):
		G(x, 67, "waterkant/strand" if x < 22 else ("waterkant/beschoeiing" if x < 25 else "waterkant/basalt_talud"), "S")
		for z in range(68, 71):
			G(x, z, "water/water")
		G(x, 71, "water/water_oever", "N")
	G(23, 69, "brug/voetbrug_hout_boog", "S")
	G(26, 69, "water/water_lelies")
	Pr(20 * 4, 69 * 4, "water/steiger_L", "S", 0.0)
	Pr(27 * 4, 68 * 4, "water/steiger_trap", "N", 0.0)
	Pr(18 * 4, 66 * 4 + 2, "terras/terras_set_parasol")
	G(18, 67, "waterkant/strand_hoek", "WS")
	G(29, 67, "waterkant/boulevard", "S")


## Motorway junction (aansluiting) on the northern carriageway (traffic towards the
## west): exit x 58..51 (shoulder becomes the exit lane, gore with crash cushion), exit
## ramp z 71 to a T-junction with a local road x 45..46 (z 64..71, from the farm track),
## on-ramp z 71 from there and the acceleration lane x 41..34 back into the shoulder.
## The ramp designs are 8 x 4 tiles (grond/snelweg/afrit_<i>_<j>, toerit_<i>_<j>, see
## tools/voxgen/ground5.py): tile (i, j) at (x0 + i, 73 - j).
func _motorway_junction() -> void:
	for i in 8:
		for j in 4:
			G(51 + i, 73 - j, "snelweg/afrit_%d_%d" % [i, j])
			G(34 + i, 73 - j, "snelweg/toerit_%d_%d" % [i, j])
	# ramps: one lane with a verge and guardrail on the outside
	for x in [42, 43, 44, 47, 48, 49, 50]:
		G(x, 71, "snelweg/snelweg_aansluiting", "E")
		G(x, 70, "snelweg/snelweg_berm_vangrail", "E")
	# local road from the farm track to the ramps, T-junction at z 71
	for z in range(64, 71):
		G(45, z, "weg/rijstrook_geen_kant", "N")
		G(46, z, "weg/rijstrook_onderbroken_kant", "S")
	G(45, 71, "weg/kruising_vlak")
	G(46, 71, "weg/kruising_vlak")
	# signs: exit sign at the gore, give way at the end of the exit ramp, motorway at the on-ramp
	Pr(54 * 4, 72 * 4 + 3, "borden/bord_afrit", "E")
	Pr(47 * 4 + 1, 70 * 4 + 3, "borden/bord_voorrang_verlenen", "E")
	Pr(44 * 4 + 2, 70 * 4 + 3, "borden/bord_autosnelweg", "E")


## Gallery flat (galerijflat) beside the motorway, x 31..42: a storage plinth and 10
## floors of flats, two wings with a kink (the east wing one tile further north),
## galleries on the motorway side, balconies at the back, a stairwell with a lift
## housing at the west end and at the kink, entrances onto a car park reached from the
## junction road (x 45..46), allotments behind it.
const FLAT_FLOORS := 10


func _gallery_flat() -> void:
	var p := "galerijflat/galerijflat_"
	var cells := []
	for x in range(31, 37):
		cells.append(Vector2i(x, 66))
		cells.append(Vector2i(x, 67))
	for x in range(37, 43):
		cells.append(Vector2i(x, 65))
		cells.append(Vector2i(x, 66))
	var stairs := [Vector2i(31, 67), Vector2i(37, 66)]   # gallery-side cells with the stairwell
	var entrances := [Vector2i(33, 67), Vector2i(39, 66), Vector2i(41, 66)]
	for c in cells:
		var sides := _open_sides(c, cells)
		# the main facade: gallery south, balconies north, else the gable end
		var main: String = "S" if sides.has("S") else ("N" if sides.has("N") else sides[0])
		var key := _corner_pair(sides, main)
		var corner: bool = sides.size() == 2 and key != "" and CORNER.has(key) and key[0] == main
		for y in FLAT_FLOORS + 1:
			var piece := ""
			if y == 0:
				piece = "bg_entree" if c in entrances else "bg_bergingen"
			elif c in stairs:
				piece = "verd_trappenhuis"
			elif main == "S":
				piece = "verd_galerij"
			elif main == "N":
				piece = "verd_balkons"
			else:
				piece = "verd_kopgevel"
			if corner and piece in ["bg_entree", "bg_bergingen", "verd_galerij", "verd_balkons"]:
				B(c.x, y, c.y, p + piece + "_hoek", CORNER[key])
			else:
				B(c.x, y, c.y, p + piece, main)
	# flat roof (gravel) with lift housings over the stairwells
	var kit := _style_kit("galerijflat")
	var kinds := {}
	for k in kit.flat:
		kinds[k] = kit.flat[k].filter(func(nm): return nm.begins_with("dak_grind"))
	_flat_roofs(cells, "galerijflat", FLAT_FLOORS + 1, kinds, {})
	for c in stairs:
		B(c.x, FLAT_FLOORS + 1, c.y, p + "dak_liftopbouw", "S")
	# pavement along the galleries, car park in front, reached from the junction road
	for x in range(37, 43):
		G(x, 67, "stoep/stoep_rand", "S")
	for x in range(31, 45):
		G(x, 68, "parkeren/parkeerplaats_rijbaan", "E")
		G(x, 69, "parkeren/parkeervak_haaks" if x % 5 else "parkeren/parkeervak_laadpaal", "N")
	G(43, 68, "water/duiker", "E")
	G(43, 69, "natuur/gras")
	G(44, 69, "natuur/gras")
	for x in [45, 46]:
		G(x, 68, "weg/kruising_vlak")
	for x in [35, 40]:
		Pr(x * 4.0, 69 * 4 + 0.5, "paaltjes/laadpaal", "N")
	Pr(32 * 4 + 2, 68 * 4 - 1, "straat/afvalcontainer_ondergronds")
	Pr(38 * 4 + 2, 67 * 4 + 2, "fietsen/fietsenrek_vol", "S")
	Pr(42 * 4 + 2, 67 * 4 + 2, "verlichting/lantaarn_modern", "S")
	Pr(34 * 4 + 2, 68 * 4 - 1, "verlichting/lantaarn_modern", "S")
	# trees in the heath on the balcony side
	for x in [38, 41]:
		Pr(x * 4 + 2, 64 * 4 + 2, "bomen/populier")


## Farm with barns, fields, a ditch with culvert, woods, hills, commercial buildings
## and a castle tower (x 31..58, z 55..71).
func _farm_and_businesses() -> void:
	# farm with barns x 32..44, hills and ditches
	fill_rect(31, 55, 58, 71, "natuur/gras")
	block(33, 58, 4, 2, "schuur_zwart", 1, {"front": "S", "gf": ["bg_deur_groot", "bg_raam"], "gf_side": "bg_raam",
		"gf_corner": "bg_raam_hoek", "upper": ["verd_hooideur"], "roof": "sloped"})
	block(39, 58, 3, 2, "schuur_rood", 2, {"front": "S", "gf": ["bg_deur_groot", "bg_raam"], "gf_side": "bg_raam",
		"gf_corner": "bg_deur_groot_hoek", "upper": ["verd_hooideur"], "upper_corner": "bg_raam_hoek", "roof": "sloped"})
	fill_rect(33, 61, 41, 62, "natuur/grind")
	# farm track to the motorway junction road (x 45..46, see _motorway_junction)
	fill_rect(33, 63, 47, 63, "natuur/grind")
	# allotments and heath behind the gallery flat (_gallery_flat)
	fill_rect(31, 64, 36, 64, "natuur/moestuin")
	fill_rect(37, 64, 42, 64, "natuur/heide")
	column(43, 56, 67, "water/sloot")
	G(43, 63, "water/duiker")
	fill_rect(44, 56, 50, 62, "natuur/bos")
	for i in 6:
		Pr((45 + i) * 4, (57 + (i % 3) * 2) * 4, ["bomen/den", "bomen/berk", "bomen/eik", "bomen/den", "bomen/berk", "bomen/populier"][i])
	Pr(47 * 4, 61 * 4, "planten/struikgewas")
	# hills: grass, sand and gravel
	_hill(47, 64, "gras")
	G(51, 67, "heuvel/heuvel_zand_top")
	G(52, 67, "heuvel/heuvel_zand_helling", "W")
	G(54, 67, "heuvel/heuvel_grind_top")
	G(55, 67, "heuvel/heuvel_grind_helling", "W")
	fill_rect(50, 68, 56, 69, "natuur/zand")
	# commercial buildings with industrial fencing
	block(52, 57, 5, 3, "bedrijfspand", 2, {"front": "S", "gf": ["bg_roldeur", "bg_kantoor", "bg_roldeur"], "gf_side": "bg_dicht",
		"gf_corner": "bg_kantoor_hoek", "upper": ["verd_lichtstraat", "verd_logo"], "upper_corner": "verd_lichtstraat_hoek", "roof": "flat"})
	fill_rect(52, 60, 57, 62, "natuur/grind")
	for x in range(51, 58, 3):
		Pr(x * 4, 63 * 4 + 3, "hekken/hek_industrie", "S")
	Pr(58 * 4 - 3, 61 * 4, "hekken/schuifpoort_industrie", "E")
	Pr(54 * 4, 61 * 4 + 2, "straat/container_groot", "E")
	Pr(56 * 4, 61 * 4, "straat/bouwkeet")
	Pr(53 * 4, 60 * 4 + 2, "trappen/brandtrap", "S")
	Pr(57 * 4, 56 * 4 + 1, "trappen/trap_staal_spiraal")
	# castle tower with battlements
	tower(31, 61, "klassiek_donker", ["blok_dicht", "verd_raam", "verd_dicht", "dak_kantelen_toren"])


## Southeast x 63..95, z 55..71: boulevard with central tram stop, a road with median
## under a viaduct, luxury apartments, an office with roof types, green-roof houses,
## bus station and a sports hall.
func _southeast() -> void:
	fill_rect(64, 55, 95, 71, "natuur/gras")
	# wide boulevard (layout: = = + - - + = =): 2 lanes, pavement with stop, 2 tram tracks,
	# pavement with stop, 2 lanes; outer pavements at x=63 and x=72
	for z in range(55, 72):
		var at_stop := z >= 60 and z <= 63
		G(63, z, "stoep/stoep_rand", "E")
		G(64, z, "weg/rijstrook_onderbroken_kant", "N")
		G(65, z, "weg/rijstrook_geen_geen", "N")
		G(66, z, "tram/tramhalte_middenperron" if at_stop else "stoep/stoep_eiland", "S" if at_stop else "E")
		G(67, z, "tram/trambaan_vrij", "S")
		G(68, z, "tram/trambaan_vrij", "S")
		G(69, z, "tram/tramhalte_middenperron" if at_stop else "stoep/stoep_eiland", "S" if at_stop else "E")
		G(70, z, "weg/rijstrook_geen_geen", "S")
		G(71, z, "weg/rijstrook_onderbroken_kant", "S")
		G(72, z, "stoep/stoep_rand", "W")
		if not at_stop and z % 3 == 0:
			Pr(66 * 4 + 2, z * 4 + 2, "verlichting/lantaarn_dubbel", "E")
			Pr(69 * 4 + 2, z * 4 + 2, "verlichting/lantaarn_dubbel", "E")
			Pr(72 * 4 + 2, z * 4 + 2, "bomen/linde")
	for z in [60, 62]:
		Pr(66 * 4 + 2, z * 4 + 2, "ov/abri", "E", 0.5)
		Pr(69 * 4 + 2, z * 4 + 2, "ov/abri", "W", 0.5)
	Pr(66 * 4 + 2, 63 * 4 + 2, "ov/tramhalte_paal", "E", 0.5)
	Pr(69 * 4 + 2, 63 * 4 + 2, "ov/tramhalte_paal", "W", 0.5)
	for x in [66, 69]:
		Pr(x * 4 + 2, 55 * 4 + 1, "verkeer/verkeerszuil", "N")
		Pr(x * 4 + 2, 71 * 4 + 3, "verkeer/verkeerszuil_geel", "S")
	# road with median (z 63..65) passing under a viaduct
	for x in range(73, W):
		G(x, 63, "weg/rijstrook_geen_kant", "E")
		G(x, 64, "weg/middenberm_gras" if x % 5 else "weg/middenberm_klinkers", "E")
		G(x, 65, "weg/rijstrook_geen_kant", "W")
		if x % 4 == 0:
			Pr(x * 4 + 2, 64 * 4 + 2, "verlichting/lantaarn_middenberm", "S")
	# viaduct: road x 74,75 goes over the median road (at level 5)
	for i in range(5):
		G(74, 57 + i, "helling/helling_brug_weg_vlak", "N", i)
		G(75, 57 + i, "helling/helling_brug_weg_vlak_rand", "N", i)
		G(74, 67 + i, "helling/helling_brug_weg_vlak_rand", "S", 4 - i)
		G(75, 67 + i, "helling/helling_brug_weg_vlak", "S", 4 - i)
	for z in range(62, 67):
		G(74, z, "brug/brug_dek_weg_rand", "S", 5)
		G(75, z, "brug/brug_dek_weg_rand", "N", 5)
	for z in [62, 66]:
		for x in [74, 75]:
			_pier(x, z, "brug/brug_pijler_gras", 0, 4)
	for x in [74, 75]:
		G(x, 56, "weg/weg_vlak")
		G(x, 55, "weg/weg_vlak")
	# luxury apartments with roof terrace and penthouse (8 storeys) x 77..82, z 56..59
	block(77, 56, 6, 4, "luxe_appartement", 8, {"front": "N", "gf": ["bg_glas", "bg_lobby", "bg_glas"], "gf_side": "bg_glas",
		"gf_corner": "bg_glas_hoek", "upper": ["verd_terras", "verd_glas"], "upper_corner": "verd_terras_hoek", "roof": "none"})
	for x in range(77, 83):
		for z in range(56, 60):
			var e := _edge(_sides(x, z, 77, 56, 6, 4))
			B(x, 8, z, "luxe_appartement/luxe_appartement_penthouse_" + e[0], e[1])
	B(79, 9, 57, "luxe_appartement/luxe_appartement_dak_zwembad", "N")
	B(80, 9, 57, "luxe_appartement/luxe_appartement_dak_terras", "N")
	for x in range(77, 83):
		if x != 79 and x != 80:
			B(x, 9, 57, "luxe_appartement/luxe_appartement_dak_groen_midden", "S")
	# office with gravel, bitumen and green roof, cooling units and solar panels x 85..88, z 56..59
	block(85, 56, 4, 4, "kantoor_glas", 4, {"front": "N", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_raam_groot", "verd_vliesgevel"], "upper_corner": "verd_vliesgevel_hoek", "roof": "none"})
	for x in range(85, 89):
		for z in range(56, 60):
			var kind := "grind_midden" if x < 86 else ("bitumen_midden" if x < 87 else "groen_midden")
			B(x, 4, z, "kantoor_glas/kantoor_glas_dak_" + kind, "S")
	D(85 * 4 + 4.0, 57 * 4 + 2.0, 12.0, "dak/koelinstallatie", "S")
	D(86 * 4 + 4.0, 58 * 4.0, 12.0, "dak/zonnepanelen_schuin_rij", "S")
	D(86 * 4 + 4.0, 59 * 4 + 2.0, 12.0, "dak/zonnepanelen_schuin_rij", "S")
	D(85 * 4.0, 59 * 4 + 2.0, 12.0, "dak/luchtbehandeling", "E")
	# terraced houses with green roof x 77..88, z 68..69
	block(77, 68, 12, 2, "modern_hout", 2, {"front": "N", "gf": ["bg_deur", "bg_raam"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_raam_breed"], "roof": "none"})
	for x in range(77, 89):
		for z in [68, 69]:
			# 2 deep: every cell has an open side, so only edges and corners
			var e := _edge(_sides(x, z, 77, 68, 12, 2))
			B(x, 2, z, "modern_hout/modern_hout_dak_groen_" + e[0], e[1])
	# bus station with canopy x 90..95, z 56..61
	fill_rect(90, 55, 95, 61, "weg/weg_vlak")
	for x in range(90, 96):
		G(x, 57, "weg/busbaan_vrij" if x == 92 else "weg/rijstrook_bus_leeg", "E")
		B(x, 0, 59, "overkapping/overkapping_glas_kolom" if x % 3 == 0 else "overkapping/overkapping_glas", "S")
		G(x, 59, "tram/tram_halte_perron", "N")
	Pr(91 * 4, 59 * 4 + 2, "straat/bank_modern", "N")
	Pr(94 * 4, 59 * 4 + 2, "straat/bank_modern", "N")
	Pr(90 * 4, 60 * 4, "ov/bushalte_paal", "N")
	# sports hall x 90..95, z 66..70
	_hall(90, 66, 6, 5, "hal_sport", Vector2i(92, 66))
	D(92 * 4 + 2.0, 66 * 4.0, 3.0, "tekst/tekst_sporthal", "N")


## Motorway z 72..79 across the map, with Cross Street 2 descending into a tunnel
## under it (ramp z 60..65 down to level -6) and a cycle tunnel at x 13.
func _motorway_and_tunnel() -> void:
	# motorway z 72..79, with a tunnel for Cross Street 2 underneath
	for x in range(0, W):
		G(x, 72, "snelweg/snelweg_berm_vangrail", "E")
		G(x, 73, "snelweg/snelweg_vluchtstrook", "E")
		G(x, 74, "weg/weg_vlak", "E")
		G(x, 75, "snelweg/snelweg_rijstrook_links", "E")
		# grass central reservation in the west, concrete barrier where the junction is
		G(x, 76, "snelweg/snelweg_middenberm" if x < 30 else "snelweg/snelweg_middenberm_beton", "E")
		G(x, 77, "snelweg/snelweg_rijstrook_links", "W")
		G(x, 78, "weg/weg_vlak", "W")
		G(x, 79, "snelweg/snelweg_vluchtstrook", "W")
	for x in range(4, W, 10):
		Pr(x * 4, 76 * 4 + 2, "verlichting/lantaarn_middenberm", "E")
		if x < 34 or x > 58:   # not in the junction (_motorway_junction)
			Pr(x * 4 + 6, 72 * 4 + 3, "borden/hectometerpaal", "N")
	Pr(30 * 4, 74 * 4 + 2, "borden/snelweg_portaal", "E")
	Pr(70 * 4, 78 * 4 + 2, "borden/snelweg_portaal", "W")
	Pr(12 * 4, 72 * 4 + 2, "borden/bord_autosnelweg", "N")
	# eastbound: the hard shoulder becomes a deceleration lane (block marking) at x 86..92,
	# the exit leaves in row 80 behind a hatched gore at x 93..95 (towards an exit east of the map)
	for x in range(86, 93):
		G(x, 79, "snelweg/snelweg_blokmarkering", "W")
	for x in range(93, W):
		G(x, 79, "snelweg/snelweg_puntstuk", "W")
		G(x, 80, "snelweg/snelweg_aansluiting", "E")
	_motorway_junction()
	_gallery_flat()
	# Cross Street 2 continues to the tunnel: z 55..59 normal, ramp 60..65, open trough 66..71, tunnel 72..79.
	# Next to the carriageway (x 60,61) runs a cycle path (x 62) in the same trough.
	for z in range(55, 60):
		G(59, z, "stoep/stoep_rand", "E")
		G(60, z, "weg/rijstrook_geen_kant", "N")
		G(61, z, "weg/rijstrook_onderbroken_kant", "S")
		G(62, z, "fietspad/fietspad_recht")
		G(63, z, "stoep/stoep_vol")
	for d in range(1, 7):
		var z := 59 + d
		_trench(60, z, "tunnel/tunnel_toerit_wand_d%d" % d, d)
		_trench(61, z, "tunnel/tunnel_toerit_d%d" % d, d)
		_trench(62, z, "tunnel/fietstunnel_toerit_wand_rechts_d%d" % d, d)
		G(59, z, "stoep/stoep_vol")
		G(63, z, "stoep/stoep_vol")
	for z in range(66, 72):
		_trench(60, z, "tunnel/tunnelbak_rijstrook_wand_d6", 6)
		_trench(61, z, "tunnel/tunnelbak_rijstrook_d6", 6, "N")
		_trench(62, z, "tunnel/tunnelbak_fietspad_wand_rechts_d6", 6)
		G(59, z, "natuur/gras")
		G(63, z, "natuur/gras")
	G(60, 72, "tunnel/tunnel_rijstrook_wand_portaal", "S", -6)
	G(61, 72, "tunnel/tunnel_rijstrook_portaal", "N", -6)
	G(62, 72, "tunnel/tunnel_fiets_wand_rechts_portaal", "S", -6)
	for z in range(73, 80):
		G(60, z, "tunnel/tunnel_rijstrook_wand", "S", -6)
		G(61, z, "tunnel/tunnel_rijstrook", "N", -6)
		G(62, z, "tunnel/tunnel_fiets_wand_rechts", "S", -6)
	Pr(59 * 4, 59 * 4, "borden/bord_tunnel", "E")
	# cycle tunnel under the motorway at x=13 (ramp 6 layers deep, tunnel on layer -6)
	for d in range(1, 7):
		_trench(13, 65 + d, "tunnel/fietstunnel_toerit_wand_d%d" % d, d)
	G(13, 72, "tunnel/tunnel_fiets_wand_portaal", "N", -6)
	for z in range(73, 80):
		G(13, z, "tunnel/tunnel_fiets_wand", "S", -6)


## Footbridge on level 4 along x 95 (z 35..47) with stairs at both ends.
func _pedestrian_bridge() -> void:
	for i in range(4):
		G(95, 35 + i, "brug/loopbrug_trap", "N", i)
	for z in range(39, 47):
		G(95, z, "brug/loopbrug_open", "S", 4)
	G(95, 47, "brug/loopbrug_open", "E", 4)
	for i in range(4):
		G(94 - i, 47, "brug/loopbrug_trap", "W", 3 - i)
	for z in [39, 46]:
		for y in range(0, 4):
			G(95, z, "brug/loopbrug_pijler", "S", y)


## Buffer stops at the south end of the railway (z 30).
func _rail_end() -> void:
	for x in [33, 34]:
		G(x, 30, "spoor/trein_stootblok", "S")
	G(31, 30, "natuur/gras")


## Statues, square terraces, classic lanterns and extra flags throughout the town.
func _decoration() -> void:
	# statues
	Pr(21 * 4 + 2, 18 * 4 + 2, "standbeelden/ruiterstandbeeld", "S")
	Pr(64 * 4, 3 * 4, "standbeelden/obelisk")
	Pr(80 * 4, 11 * 4, "standbeelden/standbeeld_persoon", "S")
	Pr(90 * 4, 11 * 4 + 2, "standbeelden/kunstwerk_modern")
	Pr(39 * 4 + 2, 2 * 4 + 2, "standbeelden/buste", "E")
	# terrace on the old town square
	for i in 4:
		Pr((18 + i * 2) * 4, 25 * 4 + 2, ["terras/tafel_rond_stoelen", "terras/tafel_vierkant_stoelen"][i % 2])
		Pr((18 + i * 2) * 4 + 2, 25 * 4 + 2, ["terras/parasol_rood", "terras/parasol_groen", "terras/parasol_blauw", "terras/parasol_naturel"][i])
	Pr(26 * 4, 23 * 4, "terras/parasol_groot")
	Pr(26 * 4, 23 * 4 + 2, "terras/tafel_rond")
	Pr(25 * 4, 23 * 4 + 2, "terras/bistrostoel")
	# classic lanterns along the mansions and the museum
	for x in range(49, 59, 2):
		Pr(x * 4 + 2, 17 * 4 + 3, "verlichting/lantaarn_gietijzer", "N")
	for x in [64, 70]:
		Pr(x * 4 + 2, 11 * 4 + 2, "verlichting/lantaarn_klassiek_dubbel", "S")
	for x in [84, 88, 92]:
		Pr(x * 4 + 2, 3 * 4, "verlichting/lantaarn_bol")
	# extra flags at the town hall
	for i in 4:
		Pr((82 + i * 2) * 4, 11 * 4 + 3, ["straat/vlaggenmast_eu", "straat/vlaggenmast_amsterdam", "straat/vlaggenmast_rotterdam", "straat/vlaggenmast_transgender"][i], "S")


# ------------------------------------------------------------------ campus below the motorway (z 80..98)

## Campus below the motorway (z 80..98): Campus Lane, university with courtyard, college,
## two office towers with a footbridge at 36 m, and the shopping street.
func _campus() -> void:
	fill_rect(0, 80, 95, 98, "natuur/gras")
	# Campus Lane: pavement 81, lanes 82-83, pavement 84
	profile_x(0, 95, [[81, "stoep/stoep_rand", "S"], [82, "weg/rijstrook_onderbroken_kant", "E"], [83, "weg/rijstrook_geen_kant", "W"], [84, "stoep/stoep_rand", "N"]])
	for x in range(2, W, 6):
		Pr(x * 4, 84 * 4 + 3, "verlichting/lantaarn_modern", "N")
	# university: main building + two wings around a courtyard
	block(4, 86, 15, 2, "universiteit", 3, {"front": "N", "gf": ["bg_raam_boog"], "gf_side": "bg_raam_boog", "gf_corner": "bg_raam_boog_hoek",
		"upper": ["verd_raam", "verd_raam_hoog"], "upper_corner": "verd_raam_hoek", "roof": "flat"})
	B(11, 0, 86, "universiteit/universiteit_bg_portaal", "N")
	B(11, 3, 87, "universiteit/universiteit_dak_dakruiter", "S")
	block(4, 89, 2, 6, "universiteit", 2, {"front": "E", "gf": ["bg_raam_boog"], "gf_side": "bg_raam_boog", "gf_corner": "bg_raam_boog_hoek",
		"upper": ["verd_raam"], "upper_corner": "verd_raam_hoek", "roof": "sloped"})
	block(17, 89, 2, 6, "universiteit", 2, {"front": "W", "gf": ["bg_raam_boog"], "gf_side": "bg_raam_boog", "gf_corner": "bg_raam_boog_hoek",
		"upper": ["verd_raam"], "upper_corner": "verd_raam_hoek", "roof": "sloped"})
	fill_rect(7, 89, 15, 95, "natuur/gras")
	column(11, 89, 95, "natuur/grindpad")
	row(7, 15, 92, "natuur/grindpad", "E")
	Pr(11 * 4 + 2, 92 * 4 + 2, "standbeelden/standbeeld_persoon", "N")
	D(11 * 4 + 2.0, 86 * 4.0, 7.0, "tekst/tekst_universiteit", "N")
	# college
	block(24, 86, 14, 6, "hogeschool", 5, {"front": "N", "gf": ["bg_glas", "bg_entree", "bg_kolonnade"], "gf_side": "bg_glas",
		"gf_corner": "bg_glas_hoek", "upper": ["verd_lamellen", "verd_vliesgevel", "verd_raam_groot"], "upper_corner": "verd_lamellen_hoek", "roof": "flat"})
	for x in range(26, 36, 3):
		B(x, 5, 89, "hogeschool/hogeschool_dak_zonnepanelen", "S")
	D(31 * 4.0, 86 * 4.0, 15.5, "tekst/tekst_hogeschool", "N")
	for x in range(25, 37, 3):
		Pr(x * 4, 85 * 4 + 2, "fietsen/fietsenrek_vol", "N")
	# two office towers with colonnade and a footbridge between them (at 36 m)
	for tx in [44, 54]:
		block(tx, 86, 4, 4, "kantoor_2000", 20, {"front": "N", "gf": ["bg_kolonnade", "bg_entree"], "gf_side": "bg_glas",
			"gf_corner": "bg_kolonnade_hoek", "upper": ["verd_zonwering", "verd_vliesgevel"], "upper_corner": "verd_zonwering_hoek", "roof": "flat"})
		D(tx * 4 + 6.0, 87 * 4 + 2.0, 60.0, "dak/koelinstallatie", "S")
		D(tx * 4 + 10.0, 88 * 4 + 2.0, 60.0, "dak/koelinstallatie", "S")
		D(tx * 4 + 8.0, 89 * 4 + 2.0, 60.0, "dak/luchtbehandeling", "S")
	block(48, 86, 6, 3, "kantoor_glas", 3, {"front": "N", "gf": ["bg_kolonnade"], "gf_side": "bg_glas", "gf_corner": "bg_kolonnade_hoek",
		"upper": ["verd_vliesgevel"], "upper_corner": "verd_vliesgevel_hoek", "roof": "flat"})
	for x in range(48, 54):
		G(x, 88, "brug/loopbrug_overdekt", "E", 36)
	fill_rect(44, 85, 57, 85, "plein/plein_natuursteen")
	for x in [45, 50, 55]:
		Pr(x * 4 + 2, 85 * 4 + 2, "standbeelden/kunstwerk_modern" if x == 50 else "planten/boombak")
	_shopping_street()


# ------------------------------------------------------------------ shopping street (pedestrian zone) near the campus

## Pedestrian shopping street x 62..95 (z 90..92) with two rows of shop buildings on
## each side (styles alternate every four), facade details, terraces and street furniture.
func _shopping_street() -> void:
	var x0 := 62
	var x1 := 95
	# pedestrian street z 90..92 with a central strip of natural stone
	fill_rect(x0, 86, x1, 97, "natuur/gras")
	for x in range(x0, x1 + 1):
		G(x, 90, "plein/plein_klinkers")
		G(x, 91, "plein/plein_natuursteen" if x % 6 else "plein/plein_patroon")
		G(x, 92, "plein/plein_klinkers")
	# entrances with bollards and signs
	for z in [90, 91, 92]:
		Pr(x0 * 4 + 0.5, z * 4 + 2.0, "paaltjes/paal_afzet")
		Pr((x1 + 1) * 4 - 0.5, z * 4 + 2.0, "paaltjes/paal_afzet")
	Pr(x0 * 4 + 1.0, 90 * 4 + 0.5, "borden/bord_voetpad", "W")
	Pr((x1 + 1) * 4 - 1.0, 92 * 4 + 3.5, "borden/bord_voetpad", "E")
	# shop buildings on both sides: alternating styles every four buildings
	var styles := ["klassiek_rood", "jaren30", "klassiek_geel", "herenhuis_1900", "modern_wit", "klassiek_donker", "modern_donker", "jaren30"]
	var shops := ["bg_bakker", "bg_cafe", "bg_kleding", "bg_boekhandel", "bg_restaurant", "bg_bloemist", "bg_juwelier", "bg_telefoon",
		"bg_ijssalon", "bg_slager", "bg_fietsenwinkel", "bg_bar", "bg_drogist", "bg_kapper", "bg_snackbar", "bg_supermarkt", "bg_dierenwinkel",
		"bg_winkel_luifel", "bg_kleding", "bg_cafe"]
	var upper_variants := ["verd_raam", "verd_balkon", "verd_raam", "verd_luiken", "verd_erker", "verd_raam_breed"]
	var roof_variants := ["dak_schuin", "dak_schuin_dakkapel", "dak_schuin", "dak_schuin_schoorsteen"]
	var wi := 0
	# two rows of 2 deep, first the one south of the street (front facing north, z 93..94),
	# then the one north of it (front facing south, z 88..89)
	for front in ["N", "S"]:
		var back := "N" if front == "S" else "S"
		var fz := 89 if front == "S" else 93
		var bz := 88 if front == "S" else 94
		for x in range(x0, x1 + 1):
			var style: String = styles[((x - x0) / 4) % styles.size()]
			var p := style + "/" + style + "_"
			var edge_x := x == x0 or x == x1
			# corner rotations of the front and back cell at the ends of the row
			var front_corner := ("WS" if x == x0 else "SE") if front == "S" else ("NW" if x == x0 else "EN")
			var back_corner := ("NW" if x == x0 else "EN") if front == "S" else ("WS" if x == x0 else "SE")
			# front row: shop on the ground floor, homes above
			var shop: String = shops[wi % shops.size()]
			wi += 1
			if not _has(p + shop):
				shop = _first(p, ["bg_winkel_luifel", "bg_winkel", "bg_raam_boog", "bg_raam"])
			if edge_x:
				B(x, 0, fz, p + ("bg_raam_hoek" if _has(p + "bg_raam_hoek") else "blok_dicht"), front_corner)
				for v in range(1, 3):
					B(x, v, fz, p + ("verd_raam_hoek" if _has(p + "verd_raam_hoek") else "blok_dicht"), front_corner)
			else:
				B(x, 0, fz, p + shop, front)
				for v in range(1, 3):
					var nm: String = upper_variants[(x + v) % upper_variants.size()]
					B(x, v, fz, p + (nm if _has(p + nm) else _first(p, ["verd_raam", "verd_raam_boog", "verd_glas"])), front)
			# back row: rear facades with windows and doors
			if edge_x:
				B(x, 0, bz, p + _first(p, ["bg_raam_hoek", "bg_raam_boog_hoek"]), back_corner)
				for v in range(1, 3):
					B(x, v, bz, p + _first(p, ["verd_raam_hoek", "verd_raam_boog_hoek"]), back_corner)
			else:
				B(x, 0, bz, p + _first(p, ["bg_deur", "bg_raam"] if x % 2 else ["bg_raam", "bg_raam_boog"]), back)
				for v in range(1, 3):
					B(x, v, bz, p + _first(p, ["verd_raam", "verd_raam_boog", "verd_glas"]), back)
			# roofs: a sloped roof if the style has one, otherwise flat with an edge on both sides
			if _has(p + "dak_schuin"):
				if edge_x:
					B(x, 3, fz, p + "dak_schuin_hoek_buiten", front_corner)
					B(x, 3, bz, p + "dak_schuin_hoek_buiten", back_corner)
				else:
					var dn: String = roof_variants[x % roof_variants.size()]
					B(x, 3, fz, p + (dn if _has(p + dn) else "dak_schuin"), front)
					B(x, 3, bz, p + "dak_schuin", back)
			else:
				B(x, 3, fz, p + "dak_plat_rand", front)
				B(x, 3, bz, p + "dak_plat_rand", back)
			# facade details above the shops (on the street-side face of the front cell)
			var facade_z := (fz + 1) * 4.0 if front == "S" else fz * 4.0
			if not edge_x and x % 3 == 0:
				D(x * 4 + 2.0, facade_z, 3.2, "ramen/bloembak", front)
			if not edge_x and x % 5 == 2:
				D(x * 4 + 0.5, facade_z, 2.6, "gevel/uithangbord", front)
			if not edge_x and x % 7 == 4:
				D(x * 4 + 2.0, facade_z, 6.0, "gevel/vlag_regenboog" if x % 2 else "gevel/vlag_nl", front)
	# street furniture and terraces in the pedestrian street
	for x in range(x0 + 1, x1, 2):
		var wx := x * 4 + 2.0
		match x % 8:
			1:
				Pr(wx, 90 * 4 + 1.5, "terras/tafel_rond_stoelen")
				Pr(wx, 90 * 4 + 1.5, "terras/parasol_rood")
			3:
				Pr(wx, 91 * 4 + 2.0, "bomen/linde")
				Pr(wx + 2.0, 91 * 4 + 2.0, "straat/bank_hout", "N")
			5:
				Pr(wx, 92 * 4 + 2.5, "terras/tafel_vierkant_stoelen")
				Pr(wx, 92 * 4 + 2.5, "terras/parasol_groen")
			7:
				Pr(wx, 91 * 4 + 2.0, "planten/plantenbak_beton")
				Pr(wx + 2.0, 91 * 4 + 1.0, "verlichting/lantaarn_klassiek")
	for x in range(x0 + 2, x1, 6):
		Pr(x * 4 + 2.0, 91 * 4 + 3.0, "straat/prullenbak_paal")
		if x % 12 == 2:
			Pr(x * 4 + 3.5, 92 * 4 + 3.0, "fietsen/fietsenrek", "E")
	Pr(78 * 4 + 2.0, 91 * 4 + 2.0, "straat/fontein")
	Pr(70 * 4 + 2.0, 90 * 4 + 1.0, "terras/stoepbord", "S")
	Pr(86 * 4 + 2.0, 92 * 4 + 3.0, "ov/reclamezuil")
	Pr(90 * 4 + 2.0, 91 * 4 + 2.0, "standbeelden/standbeeld_persoon", "S")


## First option that exists as p + option in the buildings library, else "blok_dicht".
func _first(p: String, options: Array) -> String:
	for o in options:
		if _has(p + o):
			return o
	return "blok_dicht"
