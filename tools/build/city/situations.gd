extends "res://tools/build/city/neighbourhoods.gd"
## Example-map builder, part 7 of 7 (see base.gd for the chain): demo districts with
## fixed situations: cycle/tram loops and rail yard, river dike, tunnel park, canal with
## all bridges, nature park, industrial estate, tint demo, slopes, flyovers, rounded
## curves and the village centre; plus the check for unused tiles.


# ------------------------------------------------------------------ cycle loop, tram loop and rail yard

## Square 5x5 loop of track/path at tile (x0, z0): curve tiles in the corners, straight
## tiles (cycled from straight_list) on the sides, T pieces in the middle of each side,
## a crossing in the centre and an end piece (or straight) sticking out at the bottom.
func _loop(x0: int, z0: int, curve: String, straight_list: Array, t: String, crossing: String, ending: String) -> void:
	var x1 := x0 + 4
	var z1 := z0 + 4
	G(x0, z0, curve, "S")
	G(x1, z0, curve, "W")
	G(x1, z1, curve, "N")
	G(x0, z1, curve, "E")
	var i := 0
	for x in range(x0 + 1, x1):
		if x == x0 + 2:
			continue
		G(x, z0, straight_list[i % straight_list.size()], "E"); i += 1
		G(x, z1, straight_list[i % straight_list.size()], "E"); i += 1
	for z in range(z0 + 1, z1):
		if z == z0 + 2:
			continue
		G(x0, z, straight_list[i % straight_list.size()], "S"); i += 1
		G(x1, z, straight_list[i % straight_list.size()], "S"); i += 1
	G(x0 + 2, z0, t, "W")
	G(x0, z0 + 2, t, "S")
	G(x1, z0 + 2, t, "N")
	G(x0 + 2, z1, t, "W")
	G(x0 + 2, z1 + 1, ending if ending != "" else straight_list[0], "N")
	G(x0 + 2, z0 + 2, crossing, "S")
	G(x0 + 2, z0 + 1, straight_list[0], "S")
	G(x0 + 2, z0 + 3, straight_list[0], "S")
	G(x0 + 1, z0 + 2, straight_list[0], "E")
	G(x0 + 3, z0 + 2, straight_list[0], "E")
	for c in [[x0 + 1, z0 + 1], [x0 + 3, z0 + 1], [x0 + 1, z0 + 3], [x0 + 3, z0 + 3]]:
		G(c[0], c[1], "natuur/gras")


## District with a cycle loop, tram loop (with stops and large 3x3 curve) and a rail
## yard (switch, level crossings, platform, buffer stop, large curve).
func _loops_and_rail() -> void:
	_district_name = "lussen"
	var o := _district(40, 12)
	var x0 := o.x + 2
	var z0 := o.y + 2
	fill_rect(o.x + 1, o.y + 1, o.x + 38, o.y + 10, "natuur/gras")
	# cycle loop
	var fr := []
	for nm in _names(ground, "fietspad/"):
		var k: String = nm.split("/")[1]
		if not (k.contains("bocht") or k.ends_with("_t") or k.contains("kruising") or k.contains("eind")):
			fr.append(nm)
	_loop(x0, z0, "fietspad/fietspad_bocht", fr, "fietspad/fietspad_t", "fietspad/fietspad_kruising", "fietspad/fietspad_eind")
	_prop((x0 + 1) * 4 + 2.0, (z0 + 1) * 4 + 2.0, "green")
	# tram loop
	var tr := ["tram/tram_recht", "tram/tram_klinker_recht", "tram/tram_gras_recht", "tram/trambaan_vrij", "tram/trambaan_vrij_gras"]
	var tx := x0 + 7
	_loop(tx, z0, "tram/tram_bocht", tr, "tram/tram_t", "tram/tram_kruising", "")
	G(tx, z0 + 4, "tram/tram_gras_bocht", "E")
	G(tx - 1, z0 + 1, "tram/tram_halte_perron", "E")
	G(tx + 5, z0 + 1, "tram/tramhalte_middenperron", "S")
	G(tx + 7, z0 + 2, "tram/tram_bocht_groot_3x3", "S")
	for x in range(tx + 6, tx + 9):
		for z in range(z0 + 1, z0 + 4):
			if not (x == tx + 7 and z == z0 + 2):
				ground.set_cell_item(Vector3i(x, 0, z), GridMap.INVALID_CELL_ITEM)
	# rail yard: loop with small curves, level crossing, switch, platform, buffer stop, large curve
	var sx := x0 + 18
	_loop(sx, z0, "spoor/trein_bocht", ["spoor/trein_recht", "spoor/trein_bovenleiding_recht"], "spoor/trein_recht", "spoor/trein_recht", "spoor/trein_stootblok")
	G(sx + 4, z0 + 5, "spoor/tram_gras_kruising_weg", "E")
	G(sx + 2, z0, "spoor/trein_overweg", "S")
	G(sx + 2, z0 - 1, "weg/weg_vlak")
	G(sx + 2, z0 + 4, "spoor/trein_overweg_fiets", "S")
	G(sx, z0 + 2, "spoor/trein_wissel", "S")
	G(sx + 2, z0 + 2, "spoor/trein_recht", "S")
	G(sx - 1, z0 + 1, "spoor/perron", "E")
	G(sx - 1, z0 + 2, "spoor/perron_midden")
	G(sx - 1, z0 + 3, "spoor/perron_trap", "N")
	G(sx + 8, z0 + 2, "spoor/trein_bocht_groot_3x3", "S")
	for x in range(sx + 7, sx + 10):
		for z in range(z0 + 1, z0 + 4):
			if not (x == sx + 8 and z == z0 + 2):
				ground.set_cell_item(Vector3i(x, 0, z), GridMap.INVALID_CELL_ITEM)
	_prop((sx + 1) * 4 + 2.0, (z0 - 1) * 4 + 3.0, "street")


# ------------------------------------------------------------------ dike with all ramps as driveways

## River dike: a gentle north slope, a dike road on the crown (level 1) and a steep south
## slope down to the floodplain with sand, gravel and grass hills. Roads, a cycle path and
## a little square climb the gentle side on gentle ramps; a street, a one-way cycle path,
## a tram, a railway and a motorway link cross the steep side on steep ramps; four
## viaducts (road, tram, cycle path, motorway link) pass over the dike on bridge ramps;
## a raised square (terp) juts out of the crown with outer and inner slope corners.
## Everything continues to the city streets north and south of the district.
const FLAT_OF := {"stoep_rand": "stoep/stoep_rand", "stoep_goot_rand": "stoep/stoep_goot_rand", "stoep_vol": "stoep/stoep_vol",
	"stoep_hoek_buiten": "stoep/stoep_hoek_buiten", "rijstrook_geen_kant": "weg/rijstrook_geen_kant",
	"rijstrook_onderbroken_kant": "weg/rijstrook_onderbroken_kant", "rijstrook_streep_kant": "weg/rijstrook_streep_kant",
	"rijstrook_onderbroken_geen": "weg/rijstrook_onderbroken_geen", "weg_vlak": "weg/weg_vlak", "straat_klinkers": "weg/straat_klinkers",
	"plein_tegels": "plein/plein_tegels", "fietspad_recht": "fietspad/fietspad_recht", "fietspad_eenrichting": "fietspad/fietspad_eenrichting",
	"tram_recht": "tram/tram_recht", "trein_recht": "spoor/trein_recht", "snelweg_rijstrook": "snelweg/snelweg_rijstrook",
	"snelweg_vluchtstrook": "snelweg/snelweg_vluchtstrook", "snelweg_aansluiting": "snelweg/snelweg_aansluiting"}


func _dike_with_ramps() -> void:
	_district_name = "dijk"
	var o := _district(60, 13)
	var r := func(i: int) -> int: return o.y + i   # row i of the district
	var x0 := o.x + 1
	var x1 := o.x + 58
	# the dike: gentle north slope (rows 4, 5), crown road (6, 7, level 1), steep south slope (8)
	for x in range(x0, x1 + 1):
		G(x, r.call(4), "helling/flauw_gras_a", "N")
		G(x, r.call(5), "helling/flauw_gras_b", "N")
		for z in [r.call(6), r.call(7)]:
			G(x, z, "terrein/grond_blok")
		G(x, r.call(6), "weg/rijstrook_onderbroken_kant", "E", 1)
		G(x, r.call(7), "weg/rijstrook_geen_kant", "W", 1)
		G(x, r.call(8), "helling/helling_gras", "S")
		for z in range(o.y + 4, o.y + 9):
			_taken[Vector2i(x, z)] = true
		if x % 6 == 0:
			Pr(x * 4 + 2.0, r.call(6) * 4 + 0.5, "verlichting/lantaarn_modern", "S", 1.0)
	# a route across one side of the dike: flat tiles from the city street, then the ramp
	var route := func(x: int, part: String, north: bool) -> void:
		var flat: String = FLAT_OF[part]
		var rows: Array = [0, 1, 2, 3] if north else [9, 10, 11, 12]
		for i in rows:
			var c := Vector2i(x, r.call(i))
			G(c.x, c.y, flat, "N" if north else "S")
			_pavement.erase(c)
			_taken[c] = true
		if north:
			G(x, r.call(4), "helling/flauw_%s_a" % part, "N")
			G(x, r.call(5), "helling/flauw_%s_b" % part, "N")
		else:
			G(x, r.call(8), "helling/helling_" + part, "S")
	# gentle side: a street with pavements, a clinker street with a cycle path, a road with a square
	var north_routes := [[o.x + 2, ["stoep_rand", "rijstrook_geen_kant", "rijstrook_onderbroken_kant", "stoep_goot_rand"]],
		[o.x + 18, ["fietspad_recht", "straat_klinkers", "stoep_vol"]], [o.x + 28, ["weg_vlak", "plein_tegels"]]]
	for nr in north_routes:
		for k in nr[1].size():
			route.call(nr[0] + k, nr[1][k], true)
	# steep side: a street, a one-way cycle path, a square, a tram, a railway, a motorway link
	var south_routes := [[o.x + 2, ["stoep_rand", "rijstrook_streep_kant", "rijstrook_onderbroken_geen", "rijstrook_geen_kant", "rijstrook_onderbroken_kant", "stoep_goot_rand"]],
		[o.x + 11, ["fietspad_eenrichting", "stoep_hoek_buiten"]], [o.x + 14, ["plein_tegels"]], [o.x + 16, ["tram_recht"]],
		[o.x + 18, ["trein_recht"]], [o.x + 20, ["snelweg_vluchtstrook", "snelweg_rijstrook", "snelweg_aansluiting"]]]
	for sr in south_routes:
		for k in sr[1].size():
			route.call(sr[0] + k, sr[1][k], false)
	# the tram and the train cross the crown on their own track
	for c in [[o.x + 16, "tram/tram_recht"], [o.x + 18, "spoor/trein_recht"]]:
		for z in [r.call(6), r.call(7)]:
			G(c[0], z, c[1], "S", 1)
	# viaducts over the dike: bridge ramps up (rows 1..3), deck on level 3 (rows 4..8), down (9..11)
	var viaducts := [[o.x + 8, ["rijstrook_geen_kant", "rijstrook_onderbroken_kant"], ["brug/brug_dek_rijstrook_kant_rand", "brug/brug_dek_rijstrook_onderbroken"]],
		[o.x + 24, ["tram_recht", "tram_recht"], ["brug/brug_dek_tram_rand", "brug/brug_dek_tram_rand"]],
		[o.x + 40, ["stoep_vol", "fietspad_recht"], ["brug/brug_dek_stoep_rand", "brug/brug_dek_fietspad_rand"]],
		[o.x + 54, ["snelweg_aansluiting", "snelweg_aansluiting"], ["brug/brug_dek_weg_rand", "brug/brug_dek_weg_rand"]]]
	for v in viaducts:
		for k in 2:
			var x: int = v[0] + k
			var part: String = v[1][k]
			# parapets on the outer edge: east going up from the north, west coming down south
			var up := "helling/helling_brug_%s%s" % [part, "_rand" if k == 1 else ""]
			var down := "helling/helling_brug_%s%s" % [part, "_rand" if k == 0 else ""]
			for i in 3:
				G(x, r.call(1 + i), up, "N", i)
				G(x, r.call(11 - i), down, "S", i)
			for z in range(r.call(4), r.call(9)):
				G(x, z, v[2][k], "S" if k == 0 else "N", 3)
			for i in [0, 12]:
				var c := Vector2i(x, r.call(i))
				G(c.x, c.y, FLAT_OF[part], "N" if i == 0 else "S")
				_pavement.erase(c)
			for z in range(o.y, o.y + 13):
				_taken[Vector2i(x, z)] = true
	# terp: a raised square on the crown, steep slopes with outer and inner corners
	var tx := o.x + 12
	for x in range(tx, tx + 3):
		for z in [r.call(4), r.call(5)]:
			G(x, z, "terrein/grond_blok")
			G(x, z, "plein/plein_tegels", "S", 1)
		G(x, r.call(3), "helling/helling_gras", "N")
		_taken[Vector2i(x, r.call(3))] = true
	G(tx - 1, r.call(4), "helling/helling_gras", "W")
	G(tx + 3, r.call(4), "helling/helling_gras", "E")
	G(tx - 1, r.call(3), "helling/helling_gras_hoek_buiten", "W")
	G(tx + 3, r.call(3), "helling/helling_gras_hoek_buiten", "N")
	G(tx - 1, r.call(5), "helling/helling_gras_hoek_binnen", "W")
	G(tx + 3, r.call(5), "helling/helling_gras_hoek_binnen", "N")
	for c in [Vector2i(tx - 1, r.call(3)), Vector2i(tx + 3, r.call(3))]:
		_taken[c] = true
	Pr((tx + 1) * 4 + 2.0, r.call(4) * 4 + 2.0, "straat/bank_hout", "N", 1.0)
	Pr((tx + 1) * 4 + 2.0, r.call(5) * 4 + 2.0, "bomen/linde", "S", 1.0)
	# floodplain hills: grass, sand and gravel, each with a spur (inner corner)
	var hx := o.x + 27
	for mat in ["gras", "zand", "grind"]:
		_hill(hx, r.call(9), mat)
		G(hx + 3, r.call(10), "heuvel/heuvel_" + mat + "_hoek_binnen", "S")
		for x in range(hx, hx + 4):
			for z in range(r.call(9), r.call(12)):
				_taken[Vector2i(x, z)] = true
		hx += 5 if mat == "gras" else 12


# ------------------------------------------------------------------ tunnel park: sunken roads and tunnels

## District with sunken roads: a 3-lane car tunnel (ramp, trough, portal, road on top),
## a road getting deeper step by step, an underpass with pavements and a cycle tunnel.
func _tunnel_park() -> void:
	_district_name = "tunnelpark"
	var o := _district(40, 26)
	fill_rect(o.x + 1, o.y + 1, o.x + 38, o.y + 24, "natuur/gras")
	var z0 := o.y + 2
	# A: car tunnel (3 lanes) with ramp, open trough, portal and tunnel with a road above it
	var x := o.x + 2
	for d in range(1, 7):
		_trench(x, z0 + d - 1, "tunnel/tunnel_toerit_wand_d%d" % d, d)
		_trench(x + 1, z0 + d - 1, "tunnel/tunnel_toerit_d%d" % d, d)
		_trench(x + 2, z0 + d - 1, "tunnel/tunnel_toerit_wand_rechts_d%d" % d, d)
	for r in range(2):
		_trench(x, z0 + 6 + r, "tunnel/tunnelbak_rijstrook_wand_d6", 6)
		_trench(x + 1, z0 + 6 + r, "tunnel/tunnelbak_rijstrook_d6", 6)
		_trench(x + 2, z0 + 6 + r, "tunnel/tunnelbak_rijstrook_wand_rechts_d6", 6)
	G(x, z0 + 8, "tunnel/tunnel_rijstrook_wand_portaal", "S", -6)
	G(x + 1, z0 + 8, "tunnel/tunnel_rijstrook_portaal", "S", -6)
	G(x + 2, z0 + 8, "tunnel/tunnel_rijstrook_wand_rechts_portaal", "S", -6)
	for r in range(9, 14):
		G(x, z0 + r, "tunnel/tunnel_rijstrook_wand", "S", -6)
		G(x + 1, z0 + r, "tunnel/tunnel_middenwand" if r == 11 else "tunnel/tunnel_rijstrook", "S", -6)
		G(x + 2, z0 + r, "tunnel/tunnel_rijstrook_wand_rechts", "S", -6)
	# road on top of the tunnel
	for xx in range(o.x + 1, o.x + 12):
		for zz in [z0 + 10, z0 + 11]:
			G(xx, zz, "weg/rijstrook_onderbroken_kant" if zz == z0 + 10 else "weg/rijstrook_geen_kant", "E" if zz == z0 + 10 else "W")
	# B: sunken road that gets deeper step by step (car + bicycle), without roof
	x = o.x + 8
	var z := z0
	for d in range(1, 7):
		_trench(x, z, "tunnel/tunnel_toerit_wand_d%d" % d, d)
		_trench(x + 1, z, "tunnel/tunnel_toerit_d%d" % d, d)
		_trench(x + 2, z, "tunnel/fietstunnel_toerit_wand_rechts_d%d" % d, d)
		_trench(x, z + 1, "tunnel/tunnelbak_rijstrook_wand_d%d" % d, d)
		_trench(x + 1, z + 1, "tunnel/tunnelbak_rijstrook_d%d" % d, d)
		_trench(x + 2, z + 1, "tunnel/tunnelbak_fietspad_wand_rechts_d%d" % d, d)
		z += 2
	# C: pedestrian/cycle underpass with pavement and cycle troughs at every depth
	x = o.x + 14
	for d in range(1, 7):
		var zz: int = z0 + (d - 1) * 2
		_trench(x, zz, "tunnel/tunnelbak_stoep_wand_d%d" % d, d)
		_trench(x + 1, zz, "tunnel/tunnelbak_stoep_d%d" % d, d)
		_trench(x + 2, zz, "tunnel/tunnelbak_fietspad_d%d" % d, d)
		_trench(x + 3, zz, "tunnel/tunnelbak_fietspad_wand_d%d" % d, d)
		_trench(x + 4, zz, "tunnel/tunnelbak_stoep_wand_rechts_d%d" % d, d)
		_trench(x, zz + 1, "tunnel/tunnelbak_rijstrook_wand_d%d" % d, d)
		_trench(x + 4, zz + 1, "tunnel/tunnelbak_rijstrook_wand_rechts_d%d" % d, d)
		_trench(x + 1, zz + 1, "tunnel/tunnelbak_stoep_d%d" % d, d)
		_trench(x + 2, zz + 1, "tunnel/tunnelbak_fietspad_d%d" % d, d)
		_trench(x + 3, zz + 1, "tunnel/tunnelbak_stoep_d%d" % d, d)
	# D: cycle tunnel with ramps and portals
	x = o.x + 21
	for d in range(1, 7):
		_trench(x, z0 + d - 1, "tunnel/fietstunnel_toerit_wand_d%d" % d, d)
		_trench(x + 1, z0 + d - 1, "tunnel/fietstunnel_toerit_wand_rechts_d%d" % d, d)
	G(x, z0 + 6, "tunnel/tunnel_fiets_wand_portaal", "N", -6)
	G(x + 1, z0 + 6, "tunnel/tunnel_fiets_wand_rechts_portaal", "N", -6)
	G(x + 2, z0 + 6, "tunnel/tunnel_fietspad", "S", -6)
	for r in range(7, 11):
		G(x, z0 + r, "tunnel/tunnel_fiets_wand", "S", -6)
		G(x + 1, z0 + r, "tunnel/tunnel_fiets_wand_rechts", "S", -6)
	for xx in range(x - 1, x + 3):
		for zz in range(z0 + 7, z0 + 11):
			G(xx, zz, "natuur/gras")


# ------------------------------------------------------------------ canal with all bridges

## Canal ring (grachtengordel) on level -2: canal houses on both quays facing a quay
## street, every bridge type spread along the canal linking the two quays, a few side
## streets through the rows of houses to the city streets, a viaduct carrying a through
## road over houses and canal (bridge ramps up to level 3), quay walls round the ends of
## the canal (inner quay corners) and a landing jutting into the water (outer corners).
func _canal_with_bridges() -> void:
	_district_name = "kanaal"
	var o := _district(90, 19)
	var x0 := o.x + 1
	var x1 := o.x + 88          # last column inside the kerb
	var zq := o.y + 4           # north quay street
	var zw := o.y + 6           # first water row (5 rows)
	var zs := o.y + 12          # south quay street
	var houses_n := [o.y + 1, o.y + 2]
	var houses_s := [o.y + 14, o.y + 15]
	# canal with quay walls; the ends of the canal are walled too
	for x in range(x0, x1 + 1):
		var end := x == x0 or x == x1
		for z in range(zw, zw + 5):
			if end:
				_quay(x, z, "stoep/stoep_kade", "E" if x == x0 else "W")
			else:
				_trench(x, z, "water/water_gracht", 2)
		for z in [zw - 1, zw + 5]:
			var kind := "stoep/stoep_kade" if x % 4 else "stoep/stoep_kade_klinker"
			var rot := "S" if z == zw - 1 else "N"
			if end:
				# inner quay corner: the water only lies diagonally
				kind = "stoep/stoep_kade_hoek_binnen"
				rot = {Vector2i(0, 0): "S", Vector2i(0, 1): "E", Vector2i(1, 0): "W", Vector2i(1, 1): "N"}[Vector2i(0 if x == x0 else 1, 0 if z == zw - 1 else 1)]
			_quay(x, z, kind, rot)
		# quay streets and pavements in front of the houses
		G(x, zq, "weg/straat_klinkers", "E")
		G(x, zs, "weg/straat_klinkers", "E")
		for z in [zq - 1, zs + 1]:
			G(x, z, "stoep/stoep_vol")
			_pavement[Vector2i(x, z)] = "klinker_"
	# a landing jutting into the canal from the south quay (outer quay corners)
	var lx := o.x + 44
	for k in 2:
		_quay(lx + k, zw + 4, "stoep/stoep_kade_hoek_buiten", "N" if k == 0 else "E")
		G(lx + k, zw + 5, "stoep/stoep_vol")
	G(lx + 2, zw + 5, "waterkant/kadetrap", "N", -2)
	# side streets through the rows of houses to the city streets north and south
	var side := [o.x + 12, o.x + 34, o.x + 58, o.x + 80]
	for sx in side:
		for z in range(o.y, zq):
			G(sx, z, "weg/straat_klinkers", "S")
			_pavement.erase(Vector2i(sx, z))
			_taken[Vector2i(sx, z)] = true
		for z in range(zs + 1, o.y + 19):
			G(sx, z, "weg/straat_klinkers", "S")
			_pavement.erase(Vector2i(sx, z))
			_taken[Vector2i(sx, z)] = true
	# bridges, each linking the two quay streets, spread along the canal
	var bridges := []   # [width, callable(x)]
	for nm in _names(ground, "brug/brug_dek_"):
		var k: String = nm.split("/")[1]
		var twin: bool = k.ends_with("_rand") or k.contains("_rand_")
		bridges.append([2 if twin else 1, func(bx: int) -> void:
			for z in range(zw, zw + 5):
				G(bx, z, nm)
				if twin:
					G(bx + 1, z, nm, "N")])
	bridges.append([3, func(bx: int) -> void:
		for i in 3:
			for z in range(zw, zw + 5):
				G(bx + i, z, ["brug/brug_boog_gracht_rand", "brug/brug_boog_gracht_midden", "brug/brug_boog_gracht_rand"][i], ["S", "S", "N"][i], -2)])
	bridges.append([1, func(bx: int) -> void:
		for z in range(zw, zw + 5):
			G(bx, z, "brug/brug_boog_gracht_beide", "S", -2)])
	bridges.append([1, func(bx: int) -> void:
		for i in 5:
			G(bx, zw + i, "brug/ophaalbrug_portaal" if i in [1, 3] else "brug/ophaalbrug_dek", "N" if i == 1 else "S")])
	bridges.append([1, func(bx: int) -> void:
		for i in 5:
			G(bx, zw + i, "brug/voetbrug_modern", "S")])
	bridges.append([4, func(bx: int) -> void:
		for i in 5:
			G(bx, zw + 4 - i, "brug/staalboog_%d" % (i + 1), "S")
			G(bx + 2, zw + 4 - i, "brug/staalboog_rand_%d" % (i + 1), "S")
			G(bx + 3, zw + i, "brug/staalboog_rand_%d" % (i + 1), "N")])
	bridges.append([1, func(bx: int) -> void:
		G(bx, zw + 2, "brug/tuibrug_0", "S")
		for i in range(1, 4):
			G(bx, zw + 2 - i, "brug/tuibrug_%d" % i, "S")
			G(bx, zw + 2 + i, "brug/tuibrug_%d_achter" % i, "S")])
	var total := 0
	for b in bridges:
		total += b[0]
	var free_cols := []
	for x in range(x0 + 2, x1 - 1):
		if not (x in side) and absi(x - lx) > 2 and x != o.x + 70:
			free_cols.append(x)
	var gap := maxi(1, (free_cols.size() - total) / bridges.size())
	var at := 0
	for b in bridges:
		at += gap / 2
		while at < free_cols.size() - b[0] and free_cols[at + b[0] - 1] - free_cols[at] != b[0] - 1:
			at += 1
		if at >= free_cols.size() - b[0]:
			push_warning("canal too short for every bridge")
			break
		b[1].call(free_cols[at])
		at += b[0] + gap - gap / 2
	# viaduct: a through road at level 3 over the houses, quays and canal
	var vx := o.x + 70
	for z in range(o.y, o.y + 19):
		var c := Vector2i(vx, z)
		_pavement.erase(c)
		_taken[c] = true
		if z < o.y + 3:
			G(vx, z, "helling/helling_brug_weg_vlak", "N", z - o.y)
		elif z > o.y + 15:
			G(vx, z, "helling/helling_brug_weg_vlak", "S", o.y + 18 - z)
		else:
			G(vx, z, "brug/brug_dek_weg_beide", "S", 3)
			if z >= zw and z < zw + 5 and (z - zw) % 2 == 1:
				_pier(vx, z, "brug/brug_pijler_water", -2, 2)
			elif z == zw - 3 or z == zs + 3:
				# abutment where the ramp reaches the deck, on a pier
				_pier(vx, z, "brug/brug_pijler_stoep" if z == zw - 3 else "brug/brug_pijler_gras", 0, 1)
				G(vx, z, "brug/brug_landhoofd", "S", 2)
	G(vx, zw - 1, "brug/brug_ligger", "S", 2)
	G(vx, zw + 5, "brug/brug_ligger", "S", 2)
	# canal houses on both quays: narrow fronts with gable and cornice tops, gardens behind
	var tops := ["gevel_klok", "gevel_hals", "top_lijstgevel", "top_lijstgevel_fronton"]
	for rows in [[houses_n, "S"], [houses_s, "N"]]:
		var front: int = rows[0][1] if rows[1] == "S" else rows[0][0]
		var back: int = rows[0][0] if rows[1] == "S" else rows[0][1]
		for x in range(x0, x1 + 1):
			if x in side or x == vx:
				continue
			var p := "herenhuis_1600/herenhuis_1600_"
			for y in 3:
				B(x, y, front, p + ("bg_deur" if y == 0 and x % 2 == 0 else ("bg_raam" if y == 0 else "verd_raam")), rows[1])
				B(x, y, back, p + ("bg_raam" if y == 0 else "verd_raam"), "N" if rows[1] == "S" else "S")
			B(x, 3, front, p + tops[x % tops.size()], rows[1])
			B(x, 3, back, p + "dak_plat_midden", "S")
	# boats along the quays
	for i in range(0, 84, 7):
		_prop((x0 + 3 + i) * 4 + 0.0, (zw + 1 + (i / 7) % 3) * 4 + 2.0, "water", -2.0)


## A quay cell: pavement on top of a quay wall reaching down to the canal floor.
func _quay(x: int, z: int, tile_name: String, rot) -> void:
	G(x, z, "water/kademuur_alg", "S", -2)
	G(x, z, "water/kademuur", "S", -1)
	G(x, z, tile_name, rot)


# ------------------------------------------------------------------ nature and recreation park

## Nature park: pond with all bank types and wooden footbridges, a ditch with culvert,
## terraced garden with stairs, paths, a small wood, a planted bed, a boules court and an
## outdoor pool.
func _nature_park() -> void:
	_district_name = "natuurpark"
	var o := _district(48, 16)
	fill_rect(o.x + 1, o.y + 1, o.x + 46, o.y + 14, "natuur/gras")
	# pond (layer 0) with banks, beach, sheet piling, basalt, boulevard, reeds and lilies
	var px := o.x + 2
	var pz := o.y + 2
	for x in range(px + 1, px + 7):
		for z in range(pz + 1, pz + 5):
			G(x, z, ["water/water", "water/water_lelies", "water/water_riet", "water/water"][(x + z) % 4])
	for x in range(px + 1, px + 7):
		G(x, pz, ["water/water_oever", "waterkant/strand", "waterkant/beschoeiing", "waterkant/basalt_talud", "waterkant/boulevard", "water/water_oever"][x - px - 1], "S")
		G(x, pz + 5, "water/water_oever", "N")
	for z in range(pz + 1, pz + 5):
		G(px, z, "water/water_oever", "E")
		G(px + 7, z, "water/water_oever", "W")
	G(px, pz, "water/water_oever_hoek_buiten", "SE")
	G(px + 7, pz, "water/water_oever_hoek_buiten", "WS")
	G(px, pz + 5, "waterkant/strand_hoek", "EN")
	G(px + 7, pz + 5, "water/water_oever_hoek_buiten", "NW")
	G(px + 3, pz + 2, "brug/voetbrug_hout_boog", "E")
	G(px + 5, pz + 3, "brug/voetbrug_hout_vlak", "S")
	G(px + 2, pz + 4, "waterkant/aanlegplaats", "N")
	G(px + 6, pz + 1, "water/kademuur_water", "S")
	G(px + 8, pz + 2, "water/water_oever_hoek_binnen", "S")
	for i in 4:
		_prop((px + 2 + i * 1.5) * 4, (pz + 3) * 4 + 2.0, "water", 0.0)
	# ditch with bend and culvert
	var sx := o.x + 12
	for z in range(o.y + 2, o.y + 8):
		G(sx, z, "water/duiker" if z == o.y + 5 else "water/sloot")
	G(sx, o.y + 8, "water/sloot_bocht", "N")
	for xx in range(sx - 2, sx + 3):
		G(xx, o.y + 5, "weg/berm" if xx != sx else "water/duiker", "N")
	# terraced garden with ground blocks and stairs
	var tx := o.x + 16
	var tz := o.y + 2
	for x in range(tx, tx + 4):
		G(x, tz, ["terrein/grond_blok", "terrein/grond_blok_beton", "terrein/grond_blok_baksteen", "terrein/grond_blok"][x - tx])
		G(x, tz, "natuur/gras", "S", 1)
	G(tx, tz + 1, "terrein/trap_1m", "S")
	G(tx + 1, tz + 1, "terrein/trap_1m_breed", "S")
	G(tx + 2, tz + 1, "terrein/trap_1m_fietsgoot", "S")
	G(tx + 3, tz + 1, "helling/helling_dijk_beton", "S")
	# gravel path from the pond to the outdoor pool, bending south; a sand path along the
	# south of the pond; a small wood with its edge along the path; a freshly planted
	# bed of bare earth with young trees and a gravel boules court with benches
	for x in range(o.x + 21, o.x + 29):
		G(x, o.y + 3, "natuur/pad_grind", "E")
	G(o.x + 29, o.y + 3, "natuur/pad_grind_bocht", "W")
	for z in range(o.y + 4, o.y + 8):
		G(o.x + 29, z, "natuur/pad_grind", "S")
	for x in range(o.x + 1, o.x + 12):
		G(x, o.y + 9, "natuur/zandpad", "E")
	for x in range(o.x + 31, o.x + 46):
		for z in range(o.y + 1, o.y + 4):
			G(x, z, "natuur/bos")
		G(x, o.y + 4, "natuur/bosrand", "S")
		if x % 3 == 0:
			Pr(x * 4 + 2.0, (o.y + 2) * 4 + 2.0, ["bomen/eik", "bomen/den", "bomen/berk"][(x / 3) % 3])
	for x in range(o.x + 22, o.x + 25):
		for z in [o.y + 5, o.y + 6]:
			G(x, z, "natuur/aarde")
			Pr(x * 4 + 2.0, z * 4 + 2.0, "bomen/jonge_boom")
	for x in range(o.x + 25, o.x + 28):
		for z in [o.y + 5, o.y + 6]:
			G(x, z, "plein/plein_grind")
	Pr((o.x + 26) * 4 + 2.0, (o.y + 7) * 4 + 0.5, "straat/bank_hout", "N")
	# outdoor pool with all pool tiles
	var zx := o.x + 22
	var zz := o.y + 8
	fill_rect(zx, zz, zx + 7, zz + 5, "zwembad/zwembad_kant_tegels")
	_pool_basin(zx + 1, zz + 1, 5, 3, true, true)
	_trench(zx + 6, zz + 2, "zwembad/zwembad_eind", 1, "E")
	G(zx + 7, zz + 4, "zwembad/kinderbad")
	for i in 4:
		_prop((zx + 1 + i * 1.5) * 4, (zz + 5) * 4 + 1.0, "water", 0.0)


# ------------------------------------------------------------------ check: every tile in the town

## Sorted names of the library items of gm that are not placed in gm yet.
func _unused_list(gm: GridMap) -> Array:
	var present := {}
	for c in gm.get_used_cells():
		present[gm.get_cell_item(c)] = true
	var result := []
	for id in gm.mesh_library.get_item_list():
		if not present.has(id):
			result.append(gm.mesh_library.get_item_name(id))
	result.sort()
	return result


# ------------------------------------------------------------------ industrial estate: sheds, warehouse, factory

## Industrial building at tile (x0, z0), w x d tiles, `floors` storeys, ground floor
## tiles gf and roof "barrel", "sawtooth" or anything else for a flat roof with skylights.
func _ind_block(x0: int, z0: int, w: int, d: int, style: String, floors: int, gf: Array, roof: String) -> void:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			cells.append(Vector2i(x, z))
	var upper := ["verd_wand", "verd_lichtstraat", "verd_wand", "verd_logo"]
	if style == "fabriek":
		upper = ["verd_raam_hoog"]
	_facades(cells, style, floors, gf, upper, ["bg_dicht_hoek", "bg_roldeur_hoek", "bg_kantoor_hoek"],
		["verd_lichtstraat_hoek"] if style != "fabriek" else ["verd_raam_hoog_hoek"], {})
	var p := style + "/" + style + "_"
	match roof:
		"barrel":
			for c in cells:
				B(c.x, floors, c.y, p + "dak_ton", "S")
		"sawtooth":
			for c in cells:
				B(c.x, floors, c.y, p + ("dak_shed_rand" if c.y == z0 else "dak_shed"), "N" if c.y == z0 else "N")
		_:
			var kinds := {"midden": ["dak_lichtstraten", "dak_plat_midden", "dak_lichtstraten"], "rand": ["dak_plat_rand"],
				"hoek": ["dak_plat_hoek"], "tegenover": ["dak_plat_tegenover"], "eind": ["dak_plat_eind"]}
			_flat_roofs(cells, style, floors, kinds, {})


## Industrial estate with sheds, warehouses, a factory with chimney, small units,
## a yard full of props, a staff car park and fencing.
func _industrial_estate() -> void:
	_district_name = "bedrijventerrein"
	var o := _district(62, 26)
	fill_rect(o.x + 1, o.y + 1, o.x + 60, o.y + 24, "plein/plein_tegels")
	var x0 := o.x + 2
	var z0 := o.y + 2
	# large steel shed (10x6, 9 m high) with loading docks and roller doors
	_ind_block(x0, z0, 10, 6, "loods_staal", 3, ["bg_dock", "bg_dock", "bg_roldeur", "bg_dock", "bg_loopdeur"], "flat")
	# shed with stone plinth and barrel roof
	_ind_block(x0 + 12, z0, 6, 4, "loods_steen", 2, ["bg_roldeur", "bg_loopdeur", "bg_kantoor"], "barrel")
	# warehouse with a row of loading docks
	_ind_block(x0 + 20, z0, 8, 6, "magazijn", 3, ["bg_dock"], "flat")
	# factory with sawtooth roof and factory chimney
	_ind_block(x0 + 30, z0, 8, 4, "fabriek", 2, ["bg_poort", "bg_dicht", "bg_loopdeur"], "sawtooth")
	_mast(x0 + 39, z0 + 1, "overig/fabrieksschoorsteen", 9)
	# small business units (various sizes and materials)
	_ind_block(x0 + 42, z0, 3, 2, "loods_staal", 1, ["bg_roldeur", "bg_loopdeur"], "flat")
	_ind_block(x0 + 46, z0, 4, 2, "loods_steen", 2, ["bg_roldeur", "bg_kantoor"], "flat")
	_ind_block(x0 + 51, z0, 5, 3, "magazijn", 2, ["bg_dock", "bg_kantoor", "bg_roldeur"], "flat")
	_ind_block(x0 + 42, z0 + 4, 6, 3, "fabriek", 2, ["bg_poort", "bg_loopdeur"], "flat")
	_ind_block(x0 + 50, z0 + 5, 6, 2, "loods_staal", 2, ["bg_kantoor", "bg_roldeur", "bg_dock"], "barrel")
	# yard: containers, pallets, forklift, silos, tank, cable reels, loading platform, fencing and gate
	var yz := (z0 + 8) * 4.0
	Pr((x0 + 2) * 4.0, yz + 6.0, "industrie/zeecontainer_stapel", "S")
	Pr((x0 + 8) * 4.0, yz + 4.0, "industrie/zeecontainer", "S")
	Pr((x0 + 8) * 4.0, yz + 8.0, "industrie/zeecontainer", "S")
	for i in 5:
		Pr((x0 + 12 + i) * 4.0, yz + 3.0, "industrie/pallet_stapel")
	Pr((x0 + 14) * 4.0, yz + 9.0, "industrie/heftruck", "W")
	Pr((x0 + 22) * 4.0, yz + 8.0, "industrie/silo")
	Pr((x0 + 26) * 4.0, yz + 8.0, "industrie/silo")
	Pr((x0 + 33) * 4.0, yz + 9.0, "industrie/opslagtank")
	Pr((x0 + 38) * 4.0, yz + 4.0, "industrie/kabelhaspel")
	Pr((x0 + 39) * 4.0, yz + 4.0, "industrie/kabelhaspel")
	Pr((x0 + 24) * 4.0, (z0 + 6) * 4.0 + 2.0, "industrie/laadperron", "S")
	# second row: distribution centre (12x8) and a stone shed, with loading docks facing the yard
	_ind_block(x0 + 22, z0 + 14, 14, 8, "magazijn", 4, ["bg_dock"], "flat")
	_ind_block(x0 + 38, z0 + 15, 8, 5, "loods_steen", 3, ["bg_roldeur", "bg_dock", "bg_loopdeur"], "barrel")
	_ind_block(x0 + 48, z0 + 15, 8, 6, "loods_staal", 3, ["bg_dock", "bg_roldeur", "bg_kantoor"], "flat")
	# staff car park and a green strip with trees
	for x in range(x0, x0 + 18):
		G(x, z0 + 15, "parkeren/parkeervak_haaks", "N")
		G(x, z0 + 16, "parkeren/parkeerplaats_rijbaan", "E")
		G(x, z0 + 17, "parkeren/parkeervak_haaks", "S")
	for x in range(x0, x0 + 18):
		G(x, z0 + 19, "natuur/gras")
		G(x, z0 + 20, "natuur/gras")
		if x % 3 == 0:
			Pr(x * 4 + 2.0, (z0 + 19) * 4 + 4.0, "bomen/populier" if x % 2 else "bomen/linde")
	for x in [x0 + 4, x0 + 9, x0 + 14]:
		Pr(x * 4.0, (z0 + 15) * 4 + 1.0, "paaltjes/laadpaal", "N")
	# more yard furnishing: container rows, pallets and cable reels at the docks
	for i in 3:
		Pr((x0 + 2 + i * 6) * 4.0, (z0 + 11) * 4.0, "industrie/zeecontainer_stapel", "S")
	for i in 8:
		Pr((x0 + 22 + i * 1.5) * 4.0, (z0 + 12) * 4.0, "industrie/pallet_stapel")
	Pr((x0 + 30) * 4.0, (z0 + 12) * 4.0, "industrie/heftruck", "E")
	Pr((x0 + 44) * 4.0, (z0 + 12) * 4.0, "industrie/zeecontainer", "E")
	Pr((x0 + 50) * 4.0, (z0 + 12) * 4.0, "industrie/opslagtank")
	for x in range(o.x + 1, o.x + 60, 6):
		Pr(x * 4 + 3.0, (o.y + 25) * 4 - 0.5, "hekken/hek_industrie", "S")
	Pr((o.x + 30) * 4.0, (o.y + 25) * 4 - 1.0, "hekken/schuifpoort_industrie", "S")
	Pr((o.x + 44) * 4.0, (o.y + 25) * 4 - 1.5, "hekken/slagboom", "S")


# ------------------------------------------------------------------ tint demo: the same buildings with different tints

## Adds a tint area (tint_area.gd) to the tint map: pos in metres (centre), colour,
## area_size in tiles, brightness multiplier and node name.
func _tint_area(pos: Vector3, color: Color, area_size: Vector2i, brightness := 1.0, node_name := "TintVlak") -> void:
	var tv := Node3D.new()
	tv.name = node_name
	tv.set_script(load("res://scripts/world/tint_area.gd"))
	tv.position = pos
	tv.set("color", color)
	tv.set("size", area_size)
	tv.set("brightness", brightness)
	tint_map.add_child(tv, true)


## Tint demo: a residential street with three terraces of identical houses, each house
## with its own tint (warm, cool, greenish, lighter, darker, ochre, pink), facing a
## street through the district; gardens behind; on the corner a block whose tint
## also covers the ground in front of it.
func _tint_demo() -> void:
	_district_name = "tint"
	var o := _district(30, 18)
	var tints := [
		["origineel", Color(1, 1, 1), 1.0], ["warm", Color(1.0, 0.8, 0.62), 1.0], ["koel", Color(0.75, 0.86, 1.1), 1.0],
		["groenig", Color(0.82, 1.0, 0.78), 1.0], ["lichter", Color(1, 1, 1), 1.35], ["donkerder", Color(1, 1, 1), 0.65],
		["oker", Color(1.1, 0.95, 0.6), 1.0], ["rozig", Color(1.1, 0.82, 0.86), 1.0],
	]
	# the street (z 7, 8) right through the district, joining the streets west and east
	var zs := o.y + 7
	for x in range(o.x, o.x + 30):
		G(x, zs, "weg/rijstrook_onderbroken_kant", "E")
		G(x, zs + 1, "weg/rijstrook_geen_kant", "W")
		for z in [zs, zs + 1]:
			_pavement.erase(Vector2i(x, z))
			_taken[Vector2i(x, z)] = true
	for x in range(o.x + 1, o.x + 29):
		for z in [zs - 1, zs + 2]:
			G(x, z, "stoep/stoep_vol")
			_pavement[Vector2i(x, z)] = ""
			_taken[Vector2i(x, z)] = true
		if x % 3 == 0:
			Pr(x * 4 + 2.0, (zs - 1) * 4 + 1.0, "bomen/linde")
			Pr(x * 4 + 2.0, (zs + 3) * 4 - 1.0, "verlichting/lantaarn_modern", "N")
	# terraces: [style, front row, facing]; houses one cell wide, two deep
	var rows := [["klassiek_rood", zs - 3, "S"], ["modern_wit", zs + 3, "N"], ["jaren30", zs + 7, "N"]]
	for r in rows:
		var style: String = r[0]
		var front: int = r[1]
		var facing: String = r[2]
		var back := front - 1 if facing == "S" else front + 1
		var p := style + "/" + style + "_"
		for i in tints.size():
			var x := o.x + 2 + i
			for zz in [front, back]:
				var face := facing if zz == front else ("N" if facing == "S" else "S")
				var gf: String = (("bg_deur" if zz == front else "bg_raam") if _has(p + "bg_deur") else _first(p, ["bg_raam", "bg_portiek"]))
				B(x, 0, zz, p + gf, face)
				B(x, 1, zz, p + _first(p, ["verd_raam", "verd_balkon"]), face)
				if _has(p + "dak_schuin"):
					B(x, 2, zz, p + "dak_schuin", face)
				else:
					B(x, 2, zz, p + ("dak_plat_rand" if _has(p + "dak_plat_rand") else "dak_plat_midden"), face)
			var t: Array = tints[i]
			if t[0] != "origineel":
				_tint_area(Vector3(x * 4 + 2.0, 0, (mini(front, back) + 1) * 4.0), t[1], Vector2i(1, 2), t[2], "Tint_" + style + "_" + t[0])
			# back garden
			var garden := back - 1 if facing == "S" else back + 1
			G(x, garden, "natuur/gras")
			_taken[Vector2i(x, garden)] = true
	# corner block with a tint over the block and the ground in front of it
	var bx := o.x + 12
	var bz := zs - 4
	var cells := []
	for x in range(bx, bx + 2):
		for z in range(bz, bz + 3):
			cells.append(Vector2i(x, z))
	var kit := _style_kit("klassiek_geel")
	_facades(cells, "klassiek_geel", 3, ["bg_raam"], ["verd_raam"], ["bg_raam_hoek"], ["verd_raam_hoek"], {})
	_roof(cells, "klassiek_geel", 3, kit, {})
	_tint_area(Vector3(bx * 4 + 4.0, 0, (bz + 2) * 4.0), Color(0.7, 0.85, 1.15), Vector2i(2, 4), 1.0, "Tint_blok_inclusief_grond")


# ------------------------------------------------------------------ slopes and curves

## 3-lane tunnel cross-section, from the "wand" side to the "wand_rechts" side.
const TUNNEL_LANES := ["%s_wand%s", "%s%s", "%s_wand_rechts%s"]


## District with curves that change height: a tunnel with a bend in it (more to follow).
func _slopes_and_curves() -> void:
	_district_name = "hellingen_bochten"
	var o := _district(24, 24)
	_tunnel_with_bend(o.x + 15, o.y + 7, o)


# ------------------------------------------------------------------ flyovers: rising and elevated curves

## Straight ramp parts per curve profile (pavements without a kerb, which would lie across a ramp).
const RAMP_PARTS := {"straat": ["stoep_vol", "weg_vlak", "stoep_vol"], "klinkerstraat": ["stoep_vol", "straat_klinkers", "stoep_vol"],
	"weg": ["stoep_vol", "weg_vlak", "weg_vlak", "stoep_vol"], "fietspad": ["stoep_vol", "fietspad_recht", "stoep_vol"]}
const LOOP_PROFILES := ["straat", "klinkerstraat", "fietspad", "weg"]


## Two districts of turning loops over the rising and elevated curves of every profile
## that has them (tools/voxgen/ground4.py): per profile a loop on an embankment (a left-
## and a right-rising curve back to back, fill blocks under the high cells) and one as a
## bridge (embankment cells on the ground, bridge cells with piers above), and a district
## with flat curved bridges on piers, reached by straight bridge ramps. The legs run
## down to the street south of the district.
func _flyovers() -> void:
	_district_name = "keerlussen"
	var o := _district(78, 10)
	var x := o.x + 1
	for kind in ["dijk", "brug"]:
		for profile in LOOP_PROFILES:
			var n: int = 1 + PROFILES[profile].size()
			_curve_loop(x, o.y + 1, o.y + 9, profile, kind)
			x += 2 * n + 1
	_district_name = "viaductbochten"
	o = _district(40, 11)
	x = o.x + 1
	for profile in LOOP_PROFILES:
		var n: int = 1 + PROFILES[profile].size()
		_curve_loop(x, o.y + 1, o.y + 10, profile, "vlak")
		x += 2 * n + 1


## A turning loop of `profile` with its west edge at x0, top row z0, legs down to row z1
## (inclusive). Curve A (rotation 0) comes from the south and turns west, curve B
## (rotation 1, west of A) turns south again; kind "dijk": A rises, B descends, on an
## embankment two floors up (fill blocks below); "brug": the same as bridge decks (piers
## below); "vlak": flat curved bridge decks on floor 2. Ramps in the legs lead up.
func _curve_loop(x0: int, z0: int, z1: int, profile: String, kind: String) -> void:
	var parts: Array = PROFILES[profile]
	var w := parts.size()
	var n := 1 + w
	var a := Vector2i(x0 + n, z0 + n - 1)
	var lift: int = {"dijk": 2, "brug": 1, "vlak": 2, "plat": 0}[kind]
	for half in 2:
		var origin := a + Vector2i(-half, 0)
		var right := half == 1
		for i in n:
			for j in n:
				var c: Vector2i = origin + _rotate_offset(Vector2i(i, -j), half)
				var f: int = lift if kind in ["vlak", "plat"] else _rising_floor(profile, i, j, right) + lift
				var cell := "%s%s_%d_%d" % [profile, "_rechts" if right else "", i, j]
				var nm := "helling_bocht/" + ("brug_" if kind == "brug" else "") + cell
				if kind == "vlak":
					nm = "brug/bocht_%s_%d_%d" % [profile, i, j]
				elif kind == "plat":
					nm = "bocht/%s_%d_%d" % [profile, i, j]
				if not _has(nm, ground):
					continue
				G(c.x, c.y, nm, half, f)
				if kind == "plat":
					continue
				if kind == "dijk":
					if f > 0:
						G(c.x, c.y, "helling_bocht/ophoging_gras_%dx%d_%d_%d" % [n, n, i, j], half, 0)
						for y in range(1, f):
							G(c.x, c.y, "helling_bocht/ophoging_%dx%d_%d_%d" % [n, n, i, j], half, y)
				elif _pier_cell(i, j, w):
					if f == 1:
						G(c.x, c.y, "brug/brug_pijler_gras", "S", 0)
					else:
						_pier(c.x, c.y, "brug/brug_pijler_gras", 0, f - 1)
	# legs: lane d of A's start at x a.x+1+d, of B's end at x a.x-2-d, heading south
	var ramp: Array = RAMP_PARTS.get(profile, [])
	for r in range(1, z1 - a.y + 1):
		for d in w:
			for leg in 2:
				var c := Vector2i(a.x + 1 + d if leg == 0 else a.x - 2 - d, a.y + r)
				if r <= lift:
					# bridge ramp up to the deck, parapets on the outer edges
					var edge := ""
					if d == 0:
						edge = "_rand" if leg == 0 else "_rand_rechts"
					elif d == w - 1:
						edge = "_rand_rechts" if leg == 0 else "_rand"
					var part: String = ramp[d]
					if edge != "" and not _has("helling/helling_brug_%s%s" % [part, edge], ground):
						edge = ""
					if kind == "dijk":
						G(c.x, c.y, "helling/helling_" + part, "S", lift - r)
					else:
						G(c.x, c.y, "helling/helling_brug_%s%s" % [part, edge], "S", lift - r)
				else:
					G(c.x, c.y, parts[d][0], int(parts[d][1]) % 4)


## Floor of cell (i, j) of the rising curve of `profile` (left, or right with `right`):
## the floor of its lowest point, as curve_floors() in tools/voxgen/ground4.py.
func _rising_floor(profile: String, i: int, j: int, right: bool) -> int:
	var vox = VoxLib.new()
	vox.size = Vector3i(32, 32, 12)
	var plan: Dictionary = SlopesLib.plan(vox, "bocht_rechts" if right else "bocht", {"curve": [i, j, PROFILES[profile].size()]})
	return int(plan.base) / 8


## True if a round pier fits under the centre of cell (i, j) of the bridge curve of a
## w-part profile (pier_cell() in tools/voxgen/ground4.py).
func _pier_cell(i: int, j: int, w: int) -> bool:
	var r := Vector2(i * 32 + 16, j * 32 + 16).length()
	return 32 + 5.2 <= r and r <= 32 + w * 32 - 5.2


## Car tunnel on floor -6 that turns 90 degrees underground (tunnel/bocht_<i>_<j>, a 4x4
## curve whose centre is the south-west corner of tile (hx, hz)). Legs to the south and
## to the west, each: 3 covered tiles, portal, open trough, 6-step ramp, road to the
## district edge. Streets cross both covered legs on street level.
func _tunnel_with_bend(hx: int, hz: int, o: Vector2i) -> void:
	for i in 4:
		for j in 4:
			if i < 3 or j < 3:
				G(hx + i, hz - j, "tunnel/bocht_%d_%d" % [i, j], 0, -6)
	# south leg: lane d at x = hx+1+d; leaving the tunnel heading south
	_tunnel_leg(func(r, d): return Vector2i(hx + 1 + d, hz + r), 0, o.y + 24 - hz)
	# west leg: lane d at z = hz-1-d; leaving the tunnel heading west
	_tunnel_leg(func(r, d): return Vector2i(hx - r, hz - 1 - d), 1, hx - o.x + 1)
	# streets over the covered parts
	for x in range(hx - 3, o.x + 24):
		G(x, hz + 2, "weg/weg_vlak", "E")
	for z in range(o.y, hz + 2):
		G(hx - 2, z, "weg/weg_vlak", "S")


## One leg of a tunnel, counted outwards from the bend: r = 1..3 covered tunnel, then the
## portal, 2 trough tiles and a ramp of 6 steps up, then flat road until r = length - 1.
## cell(r, d) gives the tile of lane d at distance r. rot = rotation of the straight
## tunnel tiles in this leg (as in the curve guide, tools/voxgen/ground4.py). The
## portal, trough and ramp face into the tunnel: for the south leg (rot 0) that is the
## opposite way, so they turn 180 degrees and their lanes swap sides.
func _tunnel_leg(cell: Callable, rot: int, length: int) -> void:
	var into := rot if rot % 2 == 1 else (rot + 2) % 4
	for r in range(1, length):
		for d in 3:
			var c: Vector2i = cell.call(r, d)
			var lane: String = TUNNEL_LANES[d if into == rot else 2 - d]
			if r <= 3:
				G(c.x, c.y, TUNNEL_LANES[d] % ["tunnel/tunnel_rijstrook", ""], rot, -6)
			elif r == 4:
				G(c.x, c.y, lane % ["tunnel/tunnel_rijstrook", "_portaal"], into, -6)
			elif r <= 6:
				_trench(c.x, c.y, lane % ["tunnel/tunnelbak_rijstrook", "_d6"], 6, into)
			elif r <= 12:
				var depth := 13 - r
				_trench(c.x, c.y, lane % ["tunnel/tunnel_toerit", "_d%d" % depth], depth, into)
			else:
				G(c.x, c.y, "weg/weg_vlak", into)


# ------------------------------------------------------------------ rounded curves: streets that turn the corner

## Street profiles: parts from inner curve to outer curve, as [tile, rotation] for a
## straight road running from south to north.
const PROFILES := {
	"straat": [["stoep/stoep_rand", 1], ["weg/weg_vlak", 0], ["stoep/stoep_rand", 3]],
	"klinkerstraat": [["stoep/stoep_klinker_rand", 1], ["weg/straat_klinkers", 0], ["stoep/stoep_klinker_rand", 3]],
	"weg": [["stoep/stoep_goot_rand", 1], ["weg/rijstrook_geen_kant", 2], ["weg/rijstrook_onderbroken_kant", 0], ["stoep/stoep_goot_rand", 3]],
	"hoofdweg": [["stoep/stoep_goot_rand", 1], ["fietspad/fietspad_recht", 0], ["weg/rijstrook_geen_kant", 2],
		["weg/rijstrook_onderbroken_kant", 0], ["fietspad/fietspad_recht", 0], ["stoep/stoep_goot_rand", 3]],
	"tramweg": [["stoep/stoep_rand", 1], ["tram/tram_rijstrook_geen_kant", 2], ["tram/tram_rijstrook_onderbroken_kant", 0], ["stoep/stoep_rand", 3]],
	"laan": [["stoep/stoep_rand", 1], ["weg/rijstrook_onderbroken_kant", 2], ["weg/rijstrook_geen_geen", 2], ["weg/middenberm_gras", 1],
		["weg/rijstrook_geen_geen", 0], ["weg/rijstrook_onderbroken_kant", 0], ["stoep/stoep_rand", 3]],
	"fietspad": [["natuur/gras", 0], ["fietspad/fietspad_recht", 0], ["natuur/gras", 0]],
}


## Rotates a tile offset by k quarter turns (same direction as the tile rotations).
func _rotate_offset(o: Vector2i, k: int) -> Vector2i:
	var v := o
	for i in (k % 4 + 4) % 4:
		v = Vector2i(v.y, -v.x)
	return v


## Lays a rounded curve of a street profile. (hx, hz) = the tile whose north-west corner
## is the centre of the curve; k = rotation in quarter turns; straight = length in tiles
## of the straight sections. The road comes from the south and turns off to the west (k=0).
func curve(hx: int, hz: int, profile: String, k := 0, straight := 3) -> void:
	var parts: Array = PROFILES[profile]
	var n: int = 1 + parts.size()
	for i in n:
		for j in n:
			var o := _rotate_offset(Vector2i(i, -j), k)
			G(hx + o.x, hz + o.y, "bocht/%s_%d_%d" % [profile, i, j], k)
	# straight sections: to the south (below the curve) and to the west (left)
	for d in parts.size():
		var part: Array = parts[d]
		for r in range(1, straight + 1):
			var o1 := _rotate_offset(Vector2i(1 + d, r), k)
			G(hx + o1.x, hz + o1.y, part[0], (int(part[1]) + k) % 4)
			var o2 := _rotate_offset(Vector2i(-r, -(1 + d)), k)
			G(hx + o2.x, hz + o2.y, part[0], (int(part[1]) + 3 + k) % 4)


## District with a residential loop street for every street profile in PROFILES: two
## rounded curves back to back (a U), whose legs join the street south of the district;
## a small playground inside each loop.
func _curves() -> void:
	_district_name = "bochten"
	var o := _district(92, 12)
	var x := o.x + 1
	for profile in ["straat", "klinkerstraat", "weg", "tramweg", "fietspad", "hoofdweg", "laan"]:
		var n: int = 1 + PROFILES[profile].size()
		if x + 2 * n > o.x + 91:
			break
		_curve_loop(x, o.y + 11 - n - 2, o.y + 11, profile, "plat")
		# playground in the middle of the loop
		Pr((x + n - 1) * 4.0 + 2.0, (o.y + 11) * 4.0 - 4.0, "speeltuin/" + ["schommel", "glijbaan", "wipwap", "zandbak"][profile.length() % 4])
		x += 2 * n + 1


# ------------------------------------------------------------------ village centre with cobblestones

## Village centre with a cobbled green, cobblestone streets, a church tower and cottages.
func _village_centre() -> void:
	_district_name = "dorpskern"
	var o := _district(30, 20)
	fill_rect(o.x + 1, o.y + 1, o.x + 28, o.y + 18, "natuur/gras")
	var cx := o.x + 14
	var cz := o.y + 9
	# village green (village square) with cobblestones and a tree
	fill_rect(cx - 3, cz - 2, cx + 3, cz + 2, "plein/plein_keien")
	Pr(cx * 4 + 2.0, cz * 4 + 2.0, "bomen/linde")
	Pr((cx - 2) * 4 + 2.0, cz * 4 + 2.0, "straat/bank_hout", "E")
	Pr((cx + 2) * 4 + 2.0, cz * 4 + 2.0, "straat/bank_hout", "W")
	Pr((cx + 1) * 4 + 2.0, (cz - 1) * 4 + 2.0, "verlichting/lantaarn_klassiek")
	# cobblestone streets from the square, with cobblestone pavements and a central gutter
	for z in range(o.y + 1, cz - 2):
		G(cx, z, "weg/straat_keien_middengoot")
		G(cx - 1, z, "stoep/stoep_keien_rand", "E")
		G(cx + 1, z, "stoep/stoep_keien_rand", "W")
	for z in range(cz + 3, o.y + 19):
		G(cx, z, "weg/straat_keien")
		G(cx - 1, z, "stoep/stoep_keien_rand", "E")
		G(cx + 1, z, "stoep/stoep_keien_rand", "W")
	for x in range(o.x + 1, cx - 3):
		G(x, cz, "weg/straat_keien", "E")
		G(x, cz - 1, "stoep/stoep_keien_rand", "S")
		G(x, cz + 1, "stoep/stoep_keien_rand", "N")
	# cobblestone path to the church
	for x in range(cx + 4, o.x + 26):
		G(x, cz, "natuur/keienpad", "E")
	tower(o.x + 26, cz, "kerk_baksteen", ["toren_portaal", "toren_raam", "toren_klok", "toren_spits_onder", "toren_spits_boven"], "W")
	# classic cottages around the village green
	for i in range(4):
		var hx := cx - 3 + i * 2
		for zz in [cz - 4, cz + 4]:
			var facing := "S" if zz < cz else "N"
			B(hx, 0, zz, "klassiek_rood/klassiek_rood_" + ["bg_deur", "bg_raam", "bg_winkel_luifel", "bg_deur"][i], facing)
			B(hx, 1, zz, "klassiek_rood/klassiek_rood_dak_zadel", "E")
	Pr((cx - 3) * 4.0, (cz - 2) * 4.0, "paaltjes/amsterdammertje")
	Pr((cx + 4) * 4.0, (cz + 3) * 4.0, "paaltjes/amsterdammertje")
