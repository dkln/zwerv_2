extends "res://tools/build/city/streets.gd"
## City builder, part 6 (see base.gd for the chain): the old centre inside the singel,
## north (Noordeinde, Lange Voorhout, Denneweg), middle (Grote Kerk, Binnenhof, Plein) and
## south (Grote Markt, Grote Marktstraat, Spui).


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
