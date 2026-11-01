extends "res://tools/build/city/expansion.gd"
## Example-map builder, part 5 of 7 (see base.gd for the chain): demo districts on a
## street grid: packing the districts in rows (_district, _finish_row), the streets
## between them with markings, roundabouts, signalised intersections and kerbs, and the
## city blocks and buildings that fill the space along the streets.


## Claims a rectangle of w x d tiles for a demo district (named _district_name) in the
## current row, wrapping to a new row at the map edge, and records it in `districts`.
## Lays a kerb with grass inside; the streets around it (2 lanes, shared with the
## neighbours) and the buildings along them follow when the row is complete
## (_finish_row). Returns the north-west tile.
func _district(w: int, d: int) -> Vector2i:
	if _wx + w > W - 2:
		_finish_row()
	var o := Vector2i(_wx, _wz)
	districts.append({"name": _district_name, "x": o.x, "z": o.y, "w": w, "d": d})
	_row.append([o, w, d, _infill_style(_district_name)])
	_wx += w + 2
	_wrow = maxi(_wrow, d)
	_kerb_block(o.x, o.y, w, d)
	return o


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


## Completes the current row of districts: the street along its north side and between
## the districts, a side street and a city block under districts shallower than the row,
## a city block in the space left at the east end, and buildings along the streets in
## every district. Moves the cursor to the next row.
func _finish_row() -> void:
	if _row.is_empty():
		return
	var top := _wz
	var bottom := _wz + _wrow   # first row below the districts
	_h_street(0, W - 1, top - 2)
	_h_rows.append(top - 2)
	for e in _row:
		var o: Vector2i = e[0]
		var w: int = e[1]
		var d: int = e[2]
		_v_street(o.x - 2, top - 2, bottom + 1)
		_line_streets(o.x, o.y, w, d, e[3])
		var left := _wrow - d
		if left >= 3:
			_h_street(o.x, o.x + w - 1, o.y + d)
			_filler_block(o.x, o.y + d + 2, w, left - 2)
		elif left > 0:
			_filler_block(o.x, o.y + d, w, left)
	_v_street(_wx - 2, top - 2, bottom + 1)
	if _wx < W:
		_filler_block(_wx, top, W - _wx, _wrow)
	_row.clear()
	_wz = bottom + 2
	_wx = 2
	_wrow = 0


## Cells of a 2-lane east-west street from x0 to x1 in rows z (westbound) and z+1.
func _h_street(x0: int, x1: int, z: int) -> void:
	for x in range(maxi(x0, 0), mini(x1, W - 1) + 1):
		_street_h[Vector2i(x, z)] = 0
		_street_h[Vector2i(x, z + 1)] = 1


## Cells of a 2-lane north-south street in columns x and x+1 from z0 to z1.
func _v_street(x: int, z0: int, z1: int) -> void:
	for z in range(z0, z1 + 1):
		for k in 2:
			if x + k >= 0 and x + k < W:
				_street_v[Vector2i(x + k, z)] = k


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


## Two avenues from the campus road (z 82-83) down to the first street of the demo city
## (rows z0, z0+1), so the districts are part of the town: a lane each way with a
## pavement island (x 19..21) or a divider and a grass median (x 57..59) in the middle,
## pavements on both sides, and a roundabout where they meet the first city street.
func _connect_to_town(z0: int) -> void:
	for a in [[19, "island", ""], [57, "divider", "goot_"]]:
		var x: int = a[0]
		for z in [82, 83]:
			for k in 3:
				G(x + k, z, "weg/kruising_vlak")
		for z in range(84, z0 - 1):
			G(x, z, "weg/rijstrook_geen_kant", "N")
			G(x + 2, z, "weg/rijstrook_geen_kant", "S")
			_special[Vector2i(x, z)] = true
			_special[Vector2i(x + 2, z)] = true
			if z > 84:
				for side in [x - 1, x + 3]:
					G(side, z, "stoep/stoep_vol")
					_pavement[Vector2i(side, z)] = a[2]
				if z % 3 == 0:
					Pr(x * 4 - 2.5, z * 4 + 2.0, "verlichting/lantaarn_modern", "E")
					Pr((x + 3) * 4 + 2.5, z * 4 + 2.0, "verlichting/lantaarn_modern", "W")
		# the middle: from the campus road to the roundabout
		for z in range(84, z0 - 1):
			var c := Vector2i(x + 1, z)
			_special[c] = true
			if a[1] == "island":
				if z == 84:
					G(c.x, c.y, "weg/weg_vlak")
				else:
					G(c.x, c.y, "stoep/stoep_vol")
					_pavement[c] = a[2]
					if z % 4 == 2:
						Pr(c.x * 4 + 2.0, z * 4 + 2.0, "bomen/linde")
			else:
				var mid := "weg/middengeleider"
				var rot := "S"
				if z == 84:
					mid = "weg/middengeleider_kop"
					rot = "N"
				elif z < 89:
					mid = "weg/middengeleider"
				elif z < 92:
					mid = "weg/middengeleider_breed"
				elif z == 92:
					mid = "weg/middenberm_gras_kop"
					rot = "N"
				elif z == z0 - 2:
					mid = "weg/middenberm_gras_kop"
				else:
					mid = "weg/middenberm_gras"
				G(c.x, c.y, mid, rot)
		_roundabout(x + 1, z0, a[2])


## Roundabout of 3 x 3 cells around a round pavement island at (cx, cz): the avenue comes
## in from the north, the street of rows cz, cz+1 passes east-west.
func _roundabout(cx: int, cz: int, variant: String) -> void:
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var c := Vector2i(cx + dx, cz + dz)
			_special[c] = true
			if dx == 0 and dz == 0:
				G(c.x, c.y, "stoep/stoep_vol")
				_pavement[c] = variant
			else:
				G(c.x, c.y, "weg/weg_vlak")
	Pr(cx * 4 + 2.0, cz * 4 + 2.0, "planten/struik")


## Parking bays cut into the pavement on the north side of a city block (beside the
## eastbound lane of the street north of it): the pavement steps back one cell behind
## each bay; two bays with a strip of pavement between them where the block is wide.
func _parking_bays(x0: int, z0: int, w: int, d: int) -> void:
	if w < 8 or d < 5:
		return
	var kinds := ["parkeren/parkeerstrook_langs", "parkeren/parkeerstrook_langs_klinkers", "parkeren/parkeervak_klinkers", "weg/parkeerstrook"]
	var starts := [x0 + 2] if w < 12 else [x0 + 2, x0 + 6]
	for i in starts.size():
		var bx: int = starts[i]
		var kind: String = kinds[(_kerb_count + i) % kinds.size()]
		for x in range(bx, bx + 3):
			G(x, z0, kind, "W" if kind.begins_with("parkeren/parkeerstrook") or kind == "weg/parkeerstrook" else "S")
			_pavement.erase(Vector2i(x, z0))
			_taken[Vector2i(x, z0)] = true
			G(x, z0 + 1, "stoep/stoep_vol")
			_pavement[Vector2i(x, z0 + 1)] = _pavement.get(Vector2i(x0, z0), "")
			_taken[Vector2i(x, z0 + 1)] = true
	if starts.size() == 2:
		# the pavement between the two bays reaches back to the stepped-back pavement
		var gap := Vector2i(x0 + 5, z0 + 1)
		G(gap.x, gap.y, "stoep/stoep_vol")
		_pavement[gap] = _pavement.get(Vector2i(x0, z0), "")
		_taken[gap] = true


## Driveway from the street south of a city block into its courtyard: a lowered kerb (or
## a wide entrance / exit construction) in the pavement and a lane through a gap in the
## buildings to a few parking spaces in the courtyard.
func _driveway(x0: int, z0: int, w: int, d: int) -> void:
	if w < 6 or d < 7:
		return
	var x := x0 + w / 2
	var kerb: Vector2i = Vector2i(x, z0 + d - 1)
	var kind: String = ["stoep/stoep_oprit", "stoep/stoep_goot_oprit", "stoep/stoep_inrit_breed", "weg/uitritconstructie"][_kerb_count % 4]
	G(kerb.x, kerb.y, kind, "S")
	_pavement.erase(kerb)
	_taken[kerb] = true
	for z in range(z0 + d - 4, z0 + d - 1):
		G(x, z, "parkeren/parkeerplaats_rijbaan", "S")
		_taken[Vector2i(x, z)] = true
	for dx in [-1, 1]:
		G(x + dx, z0 + d - 4, "parkeren/parkeervak_haaks", "W" if dx < 0 else "E")
		_taken[Vector2i(x + dx, z0 + d - 4)] = true


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
## street section between two intersections gets a theme (bicycle street, cycle lanes,
## no overtaking, one-way with parking, old asphalt with a speed table, drains and
## manholes, other line types); one street carries a tram.
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
				var theme: String = "tram" if horizontal and run[0].y == tram_row else STREET_THEMES[section % STREET_THEMES.size()]
				# bike lanes and bike streets only on sections long enough to read as such
				if run.size() < 6 and theme in ["fietsstraat", "fietsstroken", "fietsstrook"]:
					theme = "standaard"
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
		if c.y == tram_row or c.y == tram_row + 1:
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


# ------------------------------------------------------------------ city blocks and buildings along the streets

## Districts that stay open (no buildings along their streets): the structures in them
## need to be seen from the street.
const OPEN_DISTRICTS := ["keerlussen", "viaductbochten"]


## Residential style for the buildings along the streets of a district: the district's
## own style where that makes a street (houses, flats, offices, industry), else a
## residential style that changes from block to block.
func _infill_style(district: String) -> String:
	if district in OPEN_DISTRICTS:
		return ""
	var own := district.trim_prefix("stijl:")
	if district.begins_with("stijl:") and not (own.begins_with("kerk") or own.begins_with("museum") or own in
			["universiteit", "hogeschool", "school", "overheid", "schuur_rood", "schuur_zwart"]):
		return own
	var styles := ["herenhuis_1900", "jaren30", "klassiek_rood", "modern_wit", "jaren60", "klassiek_geel", "modern_hout", "appartement_modern"]
	_city_blocks += 1
	return styles[_city_blocks % styles.size()]


## A block of the city between the demo districts: kerb, buildings along the streets
## and a garden in the middle.
func _filler_block(x0: int, z0: int, w: int, d: int) -> void:
	if w <= 0 or d <= 0:
		return
	if w > 16:
		var half := w / 2 - 1
		_v_street(x0 + half, z0, z0 + d - 1)
		_filler_block(x0, z0, half, d)
		_filler_block(x0 + half + 2, z0, w - half - 2, d)
		return
	if d > 16:
		var half := d / 2 - 1
		_h_street(x0, x0 + w - 1, z0 + half)
		_filler_block(x0, z0, w, half)
		_filler_block(x0, z0 + half + 2, w, d - half - 2)
		return
	_kerb_block(x0, z0, w, d)
	_parking_bays(x0, z0, w, d)
	_driveway(x0, z0, w, d)
	_line_streets(x0, z0, w, d, _infill_style(""))


## Buildings along the streets of the block x0..x0+w-1, z0..z0+d-1 (inside its kerb):
## a band two cells deep wherever it and one cell behind it are still empty, in runs of
## at least 3 cells; built as one perimeter block in `style` (facades all round, flat
## or sloped roofs), with a back garden behind it.
func _line_streets(x0: int, z0: int, w: int, d: int, style: String) -> void:
	if style == "":
		return
	var inner := Rect2i(x0 + 1, z0 + 1, w - 2, d - 2)
	if inner.size.x < 3 or inner.size.y < 3:
		return
	var band := {}
	# the four sides: (first cell, step along the side, step inwards)
	var sides := [[inner.position, Vector2i(1, 0), Vector2i(0, 1), inner.size.x],
		[Vector2i(inner.position.x, inner.end.y - 1), Vector2i(1, 0), Vector2i(0, -1), inner.size.x],
		[inner.position, Vector2i(0, 1), Vector2i(1, 0), inner.size.y],
		[Vector2i(inner.end.x - 1, inner.position.y), Vector2i(0, 1), Vector2i(-1, 0), inner.size.y]]
	for sd in sides:
		var run := []
		for k in sd[3] + 1:
			var c: Vector2i = sd[0] + sd[1] * k
			var ok: bool = k < sd[3]
			if ok:
				for depth in 3:
					var q: Vector2i = c + sd[2] * depth
					if not inner.has_point(q) or _taken.has(q):
						ok = false
			if ok:
				run.append(c)
			else:
				if run.size() >= 3:
					for rc in run:
						band[rc] = true
						band[rc + sd[2]] = true
				run = []
	if band.is_empty():
		return
	var cells := band.keys()
	var kit := _style_kit(style)
	var floors := mini(_floors_for(style), 4)
	var counter := {}
	_facades(cells, style, floors, kit.gf, kit.upper, kit.gf_corners, kit.upper_corners, counter)
	_roof(cells, style, floors, kit, counter)
	# back gardens: short grass behind the band
	for c in cells:
		for dir in DIR_OFFSET.values():
			var q: Vector2i = c + dir
			if inner.has_point(q) and not band.has(q) and not _taken.has(q):
				G(q.x, q.y, "natuur/gras")


## Roof on storey y over a set of cells: flat if the style has flat roofs, else sloped
## (outer corner tiles on the corners, slopes facing the open side).
func _roof(cells: Array, style: String, y: int, kit: Dictionary, counter: Dictionary) -> void:
	if not kit.flat.midden.is_empty():
		# one roof family (dak_plat, dak_grind, ...) for the whole building
		var mid: String = kit.flat.midden[_r(cells[0].x, cells[0].y, kit.flat.midden.size())]
		var fam := mid.trim_suffix("_midden") + "_"
		var kinds := {}
		for k in kit.flat:
			kinds[k] = []
			for nm in kit.flat[k]:
				if nm.begins_with(fam):
					kinds[k].append(nm)
		_flat_roofs(cells, style, y, kinds, counter)
		return
	if kit.sloped.is_empty():
		return
	var p := style + "/" + style + "_"
	for c in cells:
		var sides := _open_sides(c, cells)
		if sides.is_empty():
			B(c.x, y, c.y, p + kit.sloped[0], "S")
			continue
		var key := _corner_pair(sides, "N")
		if key != "" and sides.size() >= 2 and not kit.outer.is_empty():
			B(c.x, y, c.y, p + _next(kit.outer, counter, "outer"), CORNER[key])
		else:
			B(c.x, y, c.y, p + _next(kit.sloped, counter, "slope"), sides[0])


## Facades for an arbitrary set of cells (Array of Vector2i tiles), `floors` storeys from
## storey y0. Exposure is relative to the set itself; corner cells use the corner lists.
## Tiles are taken round-robin from the lists using `counter` (shared across calls).
func _facades(cells: Array, style: String, floors: int, gf: Array, upper: Array, gf_corners: Array, upper_corners: Array, counter: Dictionary, y0 := 0) -> void:
	var p := style + "/" + style + "_"
	var cell_set := {}
	for c in cells:
		cell_set[c] = true
	for c in cells:
		var sides := _open_sides(c, cell_set)
		var key := _corner_pair(sides, "N")
		for v in range(floors):
			# counters are kept separately for the ground floor (0) and upper floors (1)
			var level := mini(v, 1)
			var tile_name := "blok_dicht"
			var rot = "S"
			if sides.size() == 0:
				pass  # interior cell: closed block
			elif key == "" or sides.size() == 1:
				var list: Array = gf if v == 0 else upper
				if list.size() > 0:
					tile_name = _next(list, counter, "f%d" % level)
				rot = sides[0]
			else:
				var list: Array = gf_corners if v == 0 else upper_corners
				if list.size() > 0:
					tile_name = _next(list, counter, "c%d" % level)
				rot = CORNER[key]
			B(c.x, y0 + v, c.y, p + tile_name, rot)


## Number of storeys used for a style in its demo neighbourhood (default 3).
func _floors_for(style: String) -> int:
	var t := {"jaren30": 4, "jaren60": 2, "galerijflat": 6, "appartement_modern": 8, "luxe_appartement": 6,
		"kantoor_glas": 6, "kantoor_beton": 6, "kantoor_80": 7, "kantoor_2000": 8, "kantoor_modern": 6, "hogeschool": 4,
		"school": 2, "museum_klassiek": 2, "museum_modern": 2, "bedrijfspand": 2, "schuur_zwart": 2, "schuur_rood": 2,
		"kerk_baksteen": 2, "kerk_steen": 3, "kerk_modern": 2}
	return t.get(style, 3)


## Trees and shrubs on about 9% of the empty lawn cells between rows z0 and z1.
func _green_up(z0: int, z1: int) -> void:
	var grass_id := ground.mesh_library.find_item_by_name("natuur/gras")
	var trees := ["bomen/linde", "bomen/eik", "bomen/berk", "bomen/kastanje", "bomen/plataan", "planten/struik", "planten/bosje_klein", "bomen/bloesemboom"]
	for x in range(0, W):
		for z in range(z0, z1):
			if ground.get_cell_item(Vector3i(x, 0, z)) != grass_id:
				continue
			if buildings.get_cell_item(Vector3i(x, 0, z)) != GridMap.INVALID_CELL_ITEM:
				continue
			if _r(x * 3, z * 7, 100) < 9:
				Pr(x * 4 + 2.0, z * 4 + 2.0, trees[_r(x, z, trees.size())])


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
