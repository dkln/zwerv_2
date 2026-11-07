extends "res://tools/build/city/kit.gd"
## City builder, part 3 of 3 (see base.gd for the chain): the streets with their markings,
## signalised intersections and kerbs.


## Pavement ring with grass inside over the block x0..x0+w-1, z0..z0+d-1.
func _kerb_block(x0: int, z0: int, w: int, d: int) -> void:
	_kerb_count += 1
	var variant: String = ["", "goot_", "klinker_"][_kerb_count % 3]
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			var sides: Array = _sides(x, z, x0, z0, w, d)
			if sides.size() > 0:
				_pavement[Vector2i(x, z)] = variant
			if sides.size() == 0:
				G(x, z, "natuur/gras")
			elif sides.size() == 1:
				G(x, z, "stoep/stoep_rand", sides[0])
			elif sides.size() == 2 and _corner_pair(sides, "") != "":
				G(x, z, "stoep/stoep_hoek_buiten", CORNER[_corner_pair(sides, "")])
			else:
				G(x, z, "stoep/stoep_vol")   # a block one tile wide or deep


## Lays all recorded streets: lanes with markings, plain asphalt where streets cross,
## and street lights and trees on the pavements beside them.
func _paint_streets() -> void:
	var cells := {}
	for c in _street_h:
		cells[c] = true
	for c in _street_v:
		cells[c] = true
	for c in cells:
		if _street_h.has(c) and _street_v.has(c):
			G(c.x, c.y, "weg/kruising_vlak")
		elif _street_h.has(c):
			if _street_h[c] == 0:
				G(c.x, c.y, "weg/rijstrook_onderbroken_kant", "E")
			else:
				G(c.x, c.y, "weg/rijstrook_geen_kant", "W")
		elif _street_v[c] == 0:
			G(c.x, c.y, "weg/rijstrook_geen_kant", "N")
		else:
			G(c.x, c.y, "weg/rijstrook_onderbroken_kant", "S")
	# lights and trees on the pavement next to the kerb, alternating every 3 tiles
	var trees := ["bomen/linde", "bomen/plataan", "bomen/eik", "bomen/kastanje"]
	for c in cells:
		if _street_h.has(c) and _street_v.has(c):
			continue
		var side: Vector2i = Vector2i(0, -1) if _street_h.get(c, -1) == 0 else (Vector2i(0, 1) if _street_h.get(c, -1) == 1 else (Vector2i(-1, 0) if _street_v.get(c, -1) == 0 else Vector2i(1, 0)))
		var along: int = c.x if _street_h.has(c) else c.y
		if along % 3 != 0:
			continue
		var p: Vector2i = c + side
		if not _is_pavement(p) or _taken.has(p):
			continue
		var wx: float = p.x * 4 + 2.0 - side.x * 1.5
		var wz: float = p.y * 4 + 2.0 - side.y * 1.5
		var face: String = {Vector2i(0, -1): "S", Vector2i(0, 1): "N", Vector2i(-1, 0): "E", Vector2i(1, 0): "W"}[side]
		if along % 6 == 0:
			Pr(wx, wz, "verlichting/lantaarn_modern", face)
		else:
			Pr(wx, wz, trees[_r(p.x, p.y, trees.size())])


## True if ground cell p (level 0) is a pavement tile.
func _is_pavement(p: Vector2i) -> bool:
	var id := ground.get_cell_item(Vector3i(p.x, 0, p.y))
	return id >= 0 and ground.mesh_library.get_item_name(id).begins_with("stoep/")


## True if ground cell c (level 0) carries traffic: a road, tram, parking or motorway tile.
func _is_road(c: Vector2i) -> bool:
	var id := ground.get_cell_item(Vector3i(c.x, 0, c.y))
	if id < 0:
		return false
	var nm := ground.mesh_library.get_item_name(id)
	return nm.begins_with("weg/") or nm.begins_with("tram/") or nm.begins_with("parkeren/") or nm.begins_with("snelweg/")


## Pavement shapes (tools/voxgen/tiles/ground.py SIDEWALK_SHAPES): sides with road (Front,
## Right, Back, Left of the tile) and corners cut by road (FR = front-right, ...).
const KERB_SHAPES := [["vol", [], []], ["rand", ["F"], []], ["hoek_buiten", ["F", "R"], []], ["hoek_binnen", [], ["FR"]],
	["rand_hoek_binnen", ["F"], ["BR"]], ["dubbel_hoek_binnen", [], ["FR", "FL"]], ["eiland", ["F", "B"], []],
	["eiland_eind", ["F", "B", "R"], []], ["smal_eind", ["F", "R", "L"], []], ["eiland_rond", ["F", "R", "B", "L"], []]]


## Gives every pavement cell of the demo city the kerb shape its neighbours ask for: an
## edge towards each road, outer corners, inner corners where only a diagonal is road,
## islands and island ends, in the variant of its block (plain, gutter or clinker).
func _auto_kerbs() -> void:
	var dirs := {"S": Vector2i(0, 1), "E": Vector2i(1, 0), "N": Vector2i(0, -1), "W": Vector2i(-1, 0)}
	for c in _pavement:
		var id := ground.get_cell_item(Vector3i(c.x, 0, c.y))
		if id < 0 or not ground.mesh_library.get_item_name(id).begins_with("stoep/"):
			continue
		var road := {}
		for d in dirs:
			road[d] = _is_road(c + dirs[d])
		var options := []
		for shape in KERB_SHAPES:
			for k in 4:
				var side := {"F": ORDER[k], "R": ORDER[(k + 1) % 4], "B": ORDER[(k + 2) % 4], "L": ORDER[(k + 3) % 4]}
				var ok := true
				for d in dirs:
					var want := false
					for e in shape[1]:
						if side[e] == d:
							want = true
					if want != road[d]:
						ok = false
				if not ok:
					continue
				# diagonal cuts: a road diagonal with pavement on both sides next to it
				for pair in [["F", "R"], ["R", "B"], ["B", "L"], ["L", "F"]]:
					var a: String = side[pair[0]]
					var b: String = side[pair[1]]
					var cut: bool = not road[a] and not road[b] and _is_road(c + dirs[a] + dirs[b])
					var key: String = pair[0] + pair[1]
					var rkey: String = pair[1] + pair[0]
					var listed: bool = shape[2].has(key) or shape[2].has(rkey)
					if cut != listed:
						ok = false
				if ok:
					options.append([shape[0], k])
		if options.is_empty():
			# no exact shape (unusual cut): match the road sides only
			for shape in KERB_SHAPES:
				if not shape[2].is_empty():
					continue
				for k in 4:
					var side := {"F": ORDER[k], "R": ORDER[(k + 1) % 4], "B": ORDER[(k + 2) % 4], "L": ORDER[(k + 3) % 4]}
					var ok := true
					for d in dirs:
						var want := false
						for e in shape[1]:
							if side[e] == d:
								want = true
						if want != road[d]:
							ok = false
					if ok:
						options.append([shape[0], k])
		if options.is_empty():
			continue
		var pick: Array = options[_r(c.x, c.y, options.size())]
		var variant: String = _pavement[c]
		var nm: String = "stoep/stoep_" + variant + pick[0]
		if not _has(nm, ground):
			nm = "stoep/stoep_" + pick[0]
		G(c.x, c.y, nm, pick[1])


## Dresses the lanes of the demo city streets: every intersection gets a control on its
## north-south approaches (stop line with STOP, give-way teeth, zebra crossing with piano
## stripes) and turn arrows with block markings on its east-west approaches; every
## street gets a theme for its whole length (bicycle street, cycle lanes, no overtaking,
## one-way with parking, old asphalt with speed tables, drains and manholes, other line
## types), dressed section by section between the intersections; one street carries a tram.
const STREET_THEMES := ["standaard", "fietsstraat", "fietsstroken", "inhaalverbod", "eenrichting", "oud", "lijnen", "fietsstrook", "klinkers"]
const ARROWS := ["rijstrook_pijl_rechtdoor", "rijstrook_pijl_links", "rijstrook_pijl_rechts", "rijstrook_pijl_rechtdoor_links", "rijstrook_pijl_rechtdoor_rechts"]


func _dress_streets() -> void:
	var inter := {}
	for c in _street_h:
		if _street_v.has(c):
			inter[c] = true
	var tram_row: int = _h_rows[mini(2, _h_rows.size() - 1)] if not _h_rows.is_empty() else -1
	var section := 0
	# sections: runs of non-intersection cells of a street's first lane
	for horizontal in [true, false]:
		var lanes: Dictionary = _street_h if horizontal else _street_v
		var cells := []
		for c in lanes:
			if lanes[c] == 0 and not inter.has(c) and not _special.has(c):
				cells.append(c)
		if horizontal:
			cells.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
		else:
			cells.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
		var run := []
		for i in cells.size() + 1:
			var c: Vector2i = cells[i] if i < cells.size() else Vector2i(-9999, -9999)
			var prev: Vector2i = run[-1] if not run.is_empty() else Vector2i(-9999, -9999)
			var step := Vector2i(1, 0) if horizontal else Vector2i(0, 1)
			if not run.is_empty() and c != prev + step:
				# one theme for the whole street (its row or column), so its lines and lanes
				# run on from crossing to crossing instead of changing at every one
				var street_line: int = run[0].y if horizontal else run[0].x
				var theme: String = "tram" if horizontal and run[0].y == tram_row else STREET_THEMES[(street_line * 7 + (0 if horizontal else 4)) % STREET_THEMES.size()]
				_dress_section(run, horizontal, theme, inter, section)
				section += 1
				run = []
			if i < cells.size():
				run.append(c)
	# the tram crosses the intersections of its street
	if tram_row >= 0:
		for c in inter:
			if c.y == tram_row or c.y == tram_row + 1:
				G(c.x, c.y, "tram/tram_recht", "E")
	# two busy intersections get traffic lights (all light types; green and amber north-south)
	var candidates := []
	for c in inter:
		if c.y == tram_row or c.y == tram_row + 1 or c.x > lights_last_column:
			continue
		if not (inter.has(c + Vector2i(1, 0)) and inter.has(c + Vector2i(0, 1)) and inter.has(c + Vector2i(1, 1))):
			continue
		var ok := true
		for i in [-4, -3, -2, -1, 2, 3, 4, 5]:
			for cell in [c + Vector2i(0, i), c + Vector2i(1, i), c + Vector2i(i, 0), c + Vector2i(i, 1)]:
				if inter.has(cell) or _special.has(cell) or not (_street_h.has(cell) or _street_v.has(cell)):
					ok = false
		if ok:
			candidates.append(c)
	candidates.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	if candidates.size() >= 2:
		var c1: Vector2i = candidates[candidates.size() / 3]
		var c2: Vector2i = candidates[candidates.size() * 2 / 3]
		_intersection_with_lights(c1.x, c1.y, "groen", "rood", "rijden", "stop", "groen", "rood")
		_intersection_with_lights(c2.x, c2.y, "oranje", "rood", "attentie", "stop", "oranje", "rood")
		# the 2 x 2 crossing cells start at c: its centre lies on the far corner of c
		places["verkeerslichten"] = Vector2(c1 + Vector2i.ONE) * 4.0
		places["verkeerslichten_2"] = Vector2(c2 + Vector2i.ONE) * 4.0


## Lane tiles of one street section (cells of its first lane, west to east or north to
## south; the second lane lies one cell south or east).
func _dress_section(run: Array, horizontal: bool, theme: String, inter: Dictionary, section: int) -> void:
	var n := run.size()
	var other := Vector2i(0, 1) if horizontal else Vector2i(1, 0)
	# lane 0: westbound (rotation E) or southbound (N); lane 1: eastbound (W) or northbound (S)
	var rot0 := "E" if horizontal else "N"
	var rot1 := "W" if horizontal else "S"
	for i in n:
		var c0: Vector2i = run[i]
		var c1: Vector2i = c0 + other
		var t0 := ""
		var t1 := ""
		var mid := i == n / 2
		match theme:
			"fietsstraat":
				t0 = "weg/fietsstraat"
				t1 = "weg/fietsstraat"
			"fietsstroken":
				# the pictogram every fourth cell, plain bike lane between
				t0 = "weg/rijstrook_fietsstrook" if i % 4 == 1 else "weg/fietsstrook"
				t1 = "weg/rijstrook_fietsstrook" if i % 4 == 3 else "weg/fietsstrook"
			"fietsstrook":
				t0 = "weg/fietsstrook"
				t1 = "weg/fietsstrook"
			"inhaalverbod":
				t0 = "weg/rijstrook_dubbel_kant" if i % 4 else "weg/rijstrook_dubbel_geen"
				t1 = "weg/rijstrook_dubbel_kant"
			"eenrichting":
				t0 = "weg/parkeervak_gehandicapt" if mid else "weg/parkeerstrook"
				t1 = "weg/straat_eenrichting" if i % 4 == 1 else "weg/weg_vlak"
			"oud":
				t0 = "weg/drempel_plateau" if mid else "weg/weg_vlak_oud"
				t1 = "weg/drempel_plateau" if mid else "weg/weg_vlak_oud"
			"lijnen":
				t0 = "weg/rijstrook_onderbroken_onderbroken" if i % 2 else "weg/rijstrook_streep_geen"
				t1 = "weg/rijstrook_geen_kant_onderbroken"
			"klinkers":
				t0 = "weg/straat_klinkers_middengoot" if mid else "weg/straat_klinkers"
				t1 = "weg/kruis_markering" if mid else "weg/straat_klinkers"
			"tram":
				var v := section % 3
				t0 = ["tram/tram_rijstrook_onderbroken_kant", "tram/tram_rijstrook_dubbel_kant", "tram/tram_rijstrook_streep_kant"][v]
				t1 = ["tram/tram_rijstrook_geen_kant", "tram/tram_rijstrook_geen_geen", "tram/tram_rijstrook_onderbroken_geen"][v]
			_:
				if mid:
					t0 = "weg/weg_putdeksel"
					t1 = "weg/weg_kolk"
		if t0 != "":
			G(c0.x, c0.y, t0, rot0)
		if t1 != "":
			G(c1.x, c1.y, t1, rot1)
	if theme in ["tram", "eenrichting", "fietsstraat"]:
		return
	# approaches: lane 0 drives towards +x/+z... (west/south): its last cell in driving
	# direction is run[0] - step for westbound, run[-1] for southbound; lane 1 the other way
	var step := Vector2i(1, 0) if horizontal else Vector2i(0, 1)
	var ends := []
	if horizontal:
		ends = [[run[0], rot0, run[0] - step, run[0] + step], [run[-1] + other, rot1, run[-1] + other + step, run[-1] + other - step]]
	else:
		ends = [[run[-1], rot0, run[-1] + step, run[-1] - step], [run[0] + other, rot1, run[0] + other - step, run[0] + other + step]]
	for e in ends:
		var cell: Vector2i = e[0]
		if not inter.has(e[2]) or n < 2:
			continue
		var before: Vector2i = e[3]
		var kind := _r(e[2].x, e[2].y, 4)
		if horizontal:
			G(cell.x, cell.y, "weg/" + ARROWS[(section + (0 if e[1] == rot0 else 2)) % ARROWS.size()], e[1])
			if n >= 3:
				G(before.x, before.y, "weg/rijstrook_blok_kant" if e[1] == rot0 else "weg/rijstrook_blok_geen", e[1])
		elif kind == 0:
			G(cell.x, cell.y, "weg/rijstrook_stopstreep", e[1])
			if n >= 3:
				G(before.x, before.y, "weg/rijstrook_stop_tekst", e[1])
		elif kind == 1:
			G(cell.x, cell.y, "weg/rijstrook_haaientanden", e[1])
		elif kind == 2:
			G(cell.x, cell.y, "weg/zebrapad", e[1])
			if n >= 3:
				G(before.x, before.y, "weg/pianostrepen", e[1])


# ------------------------------------------------------------------ traffic lights: all types in all states

## Signalised intersection centred on tiles (cx..cx+1, cz..cz+1) with 4-tile arms,
## kerbs, stop lines and zebra crossings. ns/ew = car light state per direction,
## ov_ns/ov_ew = public-transport light state, mast_ns/mast_ew = mast light state ("" = none).
func _intersection_with_lights(cx: int, cz: int, ns: String, ew: String, ov_ns: String, ov_ew: String, mast_ns: String, mast_ew: String) -> void:
	# roads: N-S at x = cx, cx+1; E-W at z = cz, cz+1; 4 tiles long per arm
	for i in range(-4, 6):
		if i == 0 or i == 1:
			continue  # the intersection itself
		# the two cells nearest to the intersection get a solid line (no overtaking)
		var near := absi(i) < 3
		G(cx, cz + i, "weg/rijstrook_streep_kant" if near else "weg/rijstrook_geen_kant", "N")
		G(cx + 1, cz + i, "weg/rijstrook_streep_kant" if near else "weg/rijstrook_onderbroken_kant", "S")
		G(cx + i, cz, "weg/rijstrook_streep_kant" if near else "weg/rijstrook_onderbroken_kant", "E")
		G(cx + i, cz + 1, "weg/rijstrook_streep_kant" if near else "weg/rijstrook_geen_kant", "W")
		G(cx - 1, cz + i, "stoep/stoep_rand", "E")
		G(cx + 2, cz + i, "stoep/stoep_rand", "W")
		G(cx + i, cz - 1, "stoep/stoep_rand", "S")
		G(cx + i, cz + 2, "stoep/stoep_rand", "N")
	# each approach (driving on the right): stop line two cells out, the zebra between
	# it and the crossing, over the whole road. Southbound in column cx (from the
	# north), northbound in cx+1 (from the south), westbound in row cz (from the
	# east), eastbound in row cz+1 (from the west).
	G(cx, cz - 2, "weg/rijstrook_stopstreep", "N")
	G(cx + 1, cz + 3, "weg/rijstrook_stopstreep", "S")
	G(cx + 3, cz, "weg/rijstrook_stopstreep", "E")
	G(cx - 2, cz + 1, "weg/rijstrook_stopstreep", "W")
	for k in 2:
		G(cx + k, cz - 1, "weg/zebrapad", "S")
		G(cx + k, cz + 2, "weg/zebrapad", "S")
		G(cx + 2, cz + k, "weg/zebrapad", "E")
		G(cx - 1, cz + k, "weg/zebrapad", "E")
	for x in [cx, cx + 1]:
		for z in [cz, cz + 1]:
			G(x, z, "weg/weg_vlak")
	G(cx - 1, cz - 1, "stoep/stoep_hoek_buiten", "SE")
	G(cx + 2, cz - 1, "stoep/stoep_hoek_buiten", "WS")
	G(cx - 1, cz + 2, "stoep/stoep_hoek_buiten", "EN")
	G(cx + 2, cz + 2, "stoep/stoep_hoek_buiten", "NW")
	# pedestrians may cross a road while the traffic along the other road has green
	var ped_ns := "groen" if ns == "groen" else "rood"
	var ped_ew := "groen" if ew == "groen" else "rood"
	var L := "verkeerslichten/"
	# northbound traffic (coming from the south): lights on the southeast corner, facing south
	_light_corner(Vector2((cx + 2) * 4 + 1.0, (cz + 2) * 4 + 1.0), Vector2(1.5, 0), Vector2(0, 1.5), "S", ns, ov_ns, ped_ew, "W")
	if mast_ns != "":
		Pr((cx + 1) * 4 + 2.0, (cz + 4) * 4 + 2.0, L + "mast_" + mast_ns, "S")
	# southbound traffic: northwest corner
	_light_corner(Vector2((cx - 1) * 4 + 3.0, (cz - 1) * 4 + 3.0), Vector2(-1.5, 0), Vector2(0, -1.5), "N", ns, ov_ns, ped_ew, "E")
	# westbound traffic (coming from the east): northeast corner
	_light_corner(Vector2((cx + 2) * 4 + 1.0, (cz - 1) * 4 + 3.0), Vector2(0, -1.5), Vector2(1.5, 0), "E", ew, ov_ew, ped_ns, "S")
	if mast_ew != "":
		Pr((cx + 4) * 4 + 2.0, cz * 4 + 2.0, L + "mast_" + mast_ew, "E")
	# eastbound traffic: southwest corner
	_light_corner(Vector2((cx - 1) * 4 + 3.0, (cz + 2) * 4 + 1.0), Vector2(0, 1.5), Vector2(-1.5, 0), "W", ew, ov_ew, ped_ns, "N")


## One corner of a signalised intersection: car light at pos (metres), bicycle light at
## pos + bike, public-transport light at pos + ov and the pedestrian light diagonally at
## pos + bike + ov. phase / ov_phase / ped_phase are the light states in the tile names.
func _light_corner(pos: Vector2, bike: Vector2, ov: Vector2, rot: String, phase: String, ov_phase: String, ped_phase: String, ped_rot: String) -> void:
	var L := "verkeerslichten/"
	Pr(pos.x, pos.y, L + "auto_" + phase, rot)
	Pr(pos.x + bike.x, pos.y + bike.y, L + "fiets_" + phase, rot)
	Pr(pos.x + ov.x, pos.y + ov.y, L + "ov_" + ov_phase, rot)
	Pr(pos.x + bike.x + ov.x, pos.y + bike.y + ov.y, L + "voetganger_" + ped_phase, ped_rot)
