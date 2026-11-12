extends "res://tools/build/city/east.gd"
## City builder, part 8 (see base.gd for the chain): the town south of the viaducts: the
## Schenkkade, the Schilderswijk, Laak and the Binckhorst.


# ------------------------------------------------------------------ east of the singel

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
	_next_supermarket(72, south, 11, "jaren30")   # on the Schenkkade
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
	_next_supermarket(XC + 14, south, 9, "jaren30")
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
	_next_supermarket(13, south, 10, "jaren30")
	_fill(X2 + 3, south, X3 - 2, south + depth - 1, "plein/plein_tegels")
	block(X2 + 5, south + 1, 4, 5, "kerk_modern", 2, {"front": "E", "gf": ["bg_entree", "bg_dicht"], "gf_side": "bg_dicht", "gf_corner": "bg_entree_hoek",
		"upper": ["verd_spleet", "verd_kruis"], "upper_corner": "verd_spleet_hoek", "roof": "flat"})
	_fill(X2 + 12, south + 1, X3 - 3, south + depth - 2, "natuur/gras")
	_trees([Vector2i(X2 + 13, south + 2), Vector2i(X2 + 19, south + 2), Vector2i(X2 + 16, south + 4)], ["bomen/eik", "bomen/kastanje"])
	for x in [X2 + 11, X2 + 17]:
		Pr(x * 4 + 2.0, (south + depth - 1) * 4 + 2.0, "straat/bank_beton", "N")
	ring(X3 + 3, south, 7, depth, "jaren30", 4, flats)
	_next_supermarket(X3 + 3, south, 7, "jaren30")
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
			# a supermarket on the street side of the block's rings (the first row, both
			# columns), where its style has the storefronts (the brands take turns through the town)
			if row == 0 and _has(style + "/" + style + "_bg_derrek_raam"):
				_next_supermarket(ring_x, ring_z, ring_width, style)
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
	# the market: two rows of stalls facing each other across an aisle
	var stalls := ["kraam_groente", "kraam_fruit", "kraam_kaas", "kraam_vis", "kraam_bloemen", "kraam_stoffen"]
	for index in stalls.size():
		var x := middle + 3 + index
		Pr(x * 4 + 2.0, (second + 9) * 4 + 2.0, "markt/" + stalls[index], "S")
		Pr(x * 4 + 2.0, (second + 14) * 4 + 2.0, "markt/" + stalls[(index + 3) % stalls.size()], "N")
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
