extends "res://tools/build/city/street_grid.gd"
## Example-map builder, part 6 of 7 (see base.gd for the chain): demo districts with
## buildings: one neighbourhood per building style, the detail building, the roofs
## district and the halls district.


# ------------------------------------------------------------------ neighbourhood per building style

## Demo neighbourhood for one building style: sorts all tiles of the style by kind
## (ground floors, upper floors, roofs, tops, towers, specials) and builds block A (all
## facades and flat or sloped roofs), a second row with courtyard ring, gable and T roofs,
## small rows, narrow buildings with each top, towers and special roofs, plus a detail building.
func _style_neighbourhood(style: String) -> void:
	var p := style + "/" + style + "_"
	var gf := []
	var gf_corners := []
	var upper := []
	var upper_corners := []
	var flat_kinds := {"midden": [], "rand": [], "hoek": [], "tegenover": [], "eind": [], "los": []}
	var sloped := []
	var outer_corners := []
	var inner_corners := []
	var gable := []
	var gable_hip := []
	var gable_corner := []
	var gable_t := []
	var tops := []
	var tower := []
	var penthouse := {}
	var special := []
	# sort the tiles of the style by role (names without the style prefix)
	for nm in _names(buildings, style + "/"):
		var k := _short(style, nm)
		if k == "blok_dicht":
			continue
		if k.begins_with("bg_"):
			(gf_corners if k.contains("hoek") else gf).append(k)
		elif k.begins_with("verd_"):
			(upper_corners if k.contains("hoek") else upper).append(k)
		elif k.begins_with("toren_"):
			tower.append(k)
		elif k.begins_with("penthouse_"):
			penthouse[k.trim_prefix("penthouse_")] = k
		elif k.begins_with("gevel_") or k.begins_with("top_"):
			tops.append(k)
		elif k.contains("koepel") or k.contains("dakruiter") or k.contains("overstek") or k.contains("liftopbouw") or k == "luchtboog":
			special.append(k)
		elif k.begins_with("dak_schuin") or k == "dak_lessenaar" or k == "dak_piramide":
			if k.contains("hoek_buiten"):
				outer_corners.append(k)
			elif k.contains("hoek_binnen"):
				inner_corners.append(k)
			else:
				sloped.append(k)
		elif k.begins_with("dak_zadel"):
			if k.contains("schild"):
				gable_hip.append(k)
			elif k.contains("hoek"):
				gable_corner.append(k)
			elif k.ends_with("_t"):
				gable_t.append(k)
			else:
				gable.append(k)
		elif k.begins_with("dak_"):
			# flat roof: the edge kind is part of the name (dak_plat_rand, dak_x_hoek_y, ...)
			var kind := "midden"
			for s in ["rand", "hoek", "tegenover", "eind", "los"]:
				if k.ends_with("_" + s) or k.contains("_" + s + "_"):
					kind = s
			if k.contains("terras") or k.contains("zwembad") or k.contains("daktuin"):
				kind = "rand"
			if k == "dak_kantelen_toren":
				kind = "los"
			flat_kinds[kind].append(k)
		else:
			special.append(k)
	var floors := _floors_for(style)
	var has_flat: bool = not (flat_kinds["midden"].is_empty() and flat_kinds["rand"].is_empty())
	var has_sloped := not sloped.is_empty()
	# block A: wide enough to show every ground/upper floor variant on its front, and deep
	# enough (with flat roofs) to show every middle roof variant in its interior
	var nA := clampi(maxi(ceili(gf.size() / 2.0), ceili(upper.size() / 1.5)), 5, 14)
	var dA := 2
	if has_flat:
		dA = 2 + maxi(1, ceili(flat_kinds["midden"].size() / float(maxi(1, nA - 2))))
	# compute the width of the second row
	var row2 := 0
	if has_sloped and not inner_corners.is_empty():
		row2 += 6
	if not gable.is_empty() or not gable_hip.is_empty():
		row2 += 4
	if not gable_t.is_empty():
		row2 += 4
	row2 += 5                                  # small row for end/opposite/single
	row2 += tops.size() + 1
	if not tower.is_empty():
		row2 += 3
	row2 += special.size() * 2
	var w := maxi(nA + 6, mini(row2 + 2, 60)) + 2
	# depth: margin, block A, gardens, second row, detail building, extra sloped row if needed
	var d := 2 + dA + 2 + 5 + 2 + 3 + 1 + (3 if has_sloped and inner_corners.is_empty() else 0)
	var o := _district(w, d)
	var cx := o.x + 1
	var cz := o.y + 1
	# one shared counter, so consecutive buildings keep cycling through the variants
	var counter := {}
	var facades := func(cs: Array, n: int) -> void:
		_facades(cs, style, n, gf, upper, gf_corners, upper_corners, counter)
	# --- block A: front facing north (street), gardens at the back
	var cells := []
	for x in range(cx + 1, cx + 1 + nA):
		for z in range(cz + 1, cz + 1 + dA):
			cells.append(Vector2i(x, z))
	facades.call(cells, floors)
	var roof_y := floors
	if not penthouse.is_empty():
		# penthouse storey on top of block A (only the kinds the style has)
		var pt := {"rand": [penthouse.get("rand", "")], "hoek": [penthouse.get("hoek", "")], "tegenover": [penthouse.get("tegenover", "")], "midden": [penthouse.get("midden", "")]}
		for k in pt.keys():
			if pt[k][0] == "":
				pt.erase(k)
		_flat_roofs(cells, style, roof_y, pt, {})
		roof_y += 1
	if has_flat:
		_flat_roofs(cells, style, roof_y, flat_kinds, counter)
	elif has_sloped:
		for c in cells:
			var sides := _open_sides(c, cells)
			var key := _corner_pair(sides, "N")
			if key != "" and sides.size() >= 2:
				var nm := _next(outer_corners, counter, "outer")
				B(c.x, roof_y, c.y, p + (nm if nm != "" else sloped[0]), CORNER[key])
			else:
				B(c.x, roof_y, c.y, p + _next(sloped, counter, "slope"), sides[0])
	# gardens behind block A
	var zt := cz + 1 + dA
	fill_rect(cx + 1, zt, cx + nA, zt + 1, "natuur/gras")
	for x in range(cx + 1, cx + 1 + nA):
		_prop(x * 4 + 2.0, (zt + 2) * 4 - 0.5, "green")
	# a residential street (woonerf, clinkers) right through the district: the second
	# row of buildings stands along it, joined to the streets west and east
	for x in range(o.x, o.x + w):
		G(x, zt + 2, "weg/straat_klinkers", "E")
		_pavement.erase(Vector2i(x, zt + 2))
		_taken[Vector2i(x, zt + 2)] = true
	Pr((o.x + 1) * 4.0 + 1.0, (zt + 2) * 4.0 - 0.5, "borden/bord_woonerf", "E")
	# --- second row: courtyard, gable roofs, row, tops, tower, specials
	var rx := cx + 1
	var rz := cz + dA + 4
	if has_sloped and not inner_corners.is_empty():
		var ring_cells := []
		for x in range(rx, rx + 5):
			for z in range(rz, rz + 5):
				if x == rx + 2 and z == rz + 2:
					continue
				ring_cells.append(Vector2i(x, z))
		var yr := maxi(1, mini(floors, 3))
		facades.call(ring_cells, yr)
		for c in ring_cells:
			var sides := _open_sides(c, ring_cells)
			if sides.size() == 0:
				# inner corner (diagonal to the courtyard): valley piece turned towards it
				var dx: int = (rx + 2) - c.x
				var dz: int = (rz + 2) - c.y
				var dk: String = ("S" if dz > 0 else "N") + ("E" if dx > 0 else "W")
				var map := {"SE": "SE", "SW": "WS", "NE": "EN", "NW": "NW"}
				B(c.x, yr, c.y, p + _next(inner_corners, counter, "inner"), CORNER[map[dk]])
			elif sides.size() >= 2:
				B(c.x, yr, c.y, p + _next(outer_corners, counter, "outer"), CORNER[_corner_pair(sides, "")])
			else:
				B(c.x, yr, c.y, p + _next(sloped, counter, "slope"), sides[0])
		G(rx + 2, rz + 2, "natuur/gras")
		_prop((rx + 2) * 4 + 2.0, (rz + 2) * 4 + 2.0, "green")
		rx += 5
	if not gable.is_empty() or not gable_hip.is_empty():
		# L shape (1 deep) with gable roofs, hipped ends and an L corner
		var lc := [Vector2i(rx, rz + 2), Vector2i(rx + 1, rz + 2), Vector2i(rx + 2, rz + 2), Vector2i(rx + 2, rz + 1), Vector2i(rx + 2, rz)]
		facades.call(lc, 1)
		var zs: String = gable_hip[0] if not gable_hip.is_empty() else gable[0]
		var zz: String = gable[counter.get("gable", 0) % gable.size()] if not gable.is_empty() else zs
		B(rx, 1, rz + 2, p + zs, "N")
		B(rx + 1, 1, rz + 2, p + zz, "S")
		B(rx + 2, 1, rz + 2, p + (gable_corner[0] if not gable_corner.is_empty() else zz), "SE")
		B(rx + 2, 1, rz + 1, p + (gable[1 % gable.size()] if not gable.is_empty() else zs), "E")
		B(rx + 2, 1, rz, p + zs, "E")
		# remaining gable variants on a separate row of 3
		var extra := gable.slice(2) if gable.size() > 2 else []
		var zr := rz + 4
		if not extra.is_empty():
			var rc := [Vector2i(rx, zr), Vector2i(rx + 1, zr), Vector2i(rx + 2, zr)]
			facades.call(rc, 1)
			B(rx, 1, zr, p + zs, "N")
			B(rx + 1, 1, zr, p + extra[0], "S")
			B(rx + 2, 1, zr, p + zs, "S")
		rx += 3
	if not gable_t.is_empty():
		var tc := [Vector2i(rx, rz + 1), Vector2i(rx + 1, rz + 1), Vector2i(rx + 2, rz + 1), Vector2i(rx + 1, rz)]
		facades.call(tc, 1)
		var zs2: String = gable_hip[0] if not gable_hip.is_empty() else gable_t[0]
		B(rx + 1, 1, rz + 1, p + gable_t[0], "S")
		B(rx, 1, rz + 1, p + zs2, "N")
		B(rx + 2, 1, rz + 1, p + zs2, "S")
		B(rx + 1, 1, rz, p + zs2, "E")
		rx += 3
	if has_sloped and inner_corners.is_empty():
		var sc := []
		var bw := maxi(2, ceili(sloped.size() / 2.0) + 2)
		for x in range(rx, rx + bw):
			for z in [rz, rz + 1]:
				sc.append(Vector2i(x, z))
		facades.call(sc, 1)
		var si := 0
		for c in sc:
			var sides := _open_sides(c, sc)
			if sides.size() >= 2 and not outer_corners.is_empty():
				B(c.x, 1, c.y, p + outer_corners[0], CORNER[_corner_pair(sides, "")])
			else:
				B(c.x, 1, c.y, p + sloped[si % sloped.size()], sides[0] if sides.size() == 1 else "N")
				si += 1
		rx += bw
	# small row (1 deep) + detached building: end / opposite / single
	var kc := [Vector2i(rx, rz), Vector2i(rx + 1, rz), Vector2i(rx + 2, rz)]
	var ky := maxi(1, mini(floors, 2))
	facades.call(kc, ky)
	if not penthouse.is_empty():
		var pt2 := {}
		for k2 in penthouse.keys():
			pt2[k2] = [penthouse[k2]]
		_flat_roofs(kc, style, ky, pt2, {})
		ky += 1
	if has_flat:
		_flat_roofs(kc, style, ky, flat_kinds, counter)
	facades.call([Vector2i(rx, rz + 2)], 1)
	if has_flat:
		_flat_roofs([Vector2i(rx, rz + 2)], style, 1, flat_kinds, counter)
	rx += 3
	# narrow buildings, each with a different top (canal gable, cornice gable, pediment, ...)
	for i in tops.size():
		var x: int = rx + i
		var hc := [Vector2i(x, rz), Vector2i(x, rz + 1)]
		var yt := maxi(2, mini(floors, 3))
		facades.call(hc, yt)
		B(x, yt, rz, p + tops[i], "N")
		if not gable.is_empty():
			B(x, yt, rz + 1, p + gable[0], "E")
		elif has_flat:
			B(x, yt, rz + 1, p + flat_kinds["rand"][0] if not flat_kinds["rand"].is_empty() else p + flat_kinds["midden"][0], "S")
	if not tops.is_empty():
		rx += tops.size()
	# tower(s)
	if not tower.is_empty():
		var order := ["toren_portaal", "toren_raam", "toren_galmgat", "toren_klok", "toren_spits_onder", "toren_spits_boven"]
		var t1 := []
		for t in order:
			if tower.has(t):
				t1.append(t)
		if t1.is_empty() or not t1[0] in ["toren_portaal", "toren_raam"]:
			t1.push_front("blok_dicht")
			t1.push_front("blok_dicht")
		tower(rx, rz + 1, style, t1, "N")
		if tower.has("toren_pinakels"):
			tower(rx + 1, rz + 1, style, ["blok_dicht", "toren_raam" if tower.has("toren_raam") else "blok_dicht", "toren_pinakels"], "N")
		if tower.has("toren_beton"):
			tower(rx + 1, rz + 3, style, ["toren_beton", "toren_beton", "toren_beton_klok" if tower.has("toren_beton_klok") else "toren_beton"], "N")
		rx += 2
	# special roofs on their own small buildings
	for k in special:
		if k.ends_with("3x3"):
			var dc := []
			for x in range(rx, rx + 3):
				for z in range(rz, rz + 3):
					dc.append(Vector2i(x, z))
			facades.call(dc, 1)
			B(rx + 1, 1, rz + 1, p + k, "S")
			rx += 3
		elif k == "luchtboog":
			facades.call([Vector2i(rx, rz + 1), Vector2i(rx + 1, rz + 1)], 2)
			B(rx, 0, rz, p + k, "N")
			B(rx + 1, 0, rz, p + k, "N")
			rx += 2
		else:
			facades.call([Vector2i(rx, rz)], 1)
			B(rx, 1, rz, p + k, "N")
			rx += 1
	# --- detail building at the end of the row: a blank building on which facade and
	# roof parts are placed
	if rx + 4 <= o.x + w - 1:
		_detail_building(rx, rz, style, "N")
	else:
		_detail_building(cx + 1, cz + d - 6, style)
	# street furniture along the north edge
	for x in range(o.x + 1, o.x + w - 1, 2):
		_prop(x * 4 + 2.0, o.y * 4 + 0.75, "street")


## Next detail name of a group from its rotating queue ("" if the group is empty).
func _take_detail(group: String) -> String:
	if not _detail_queue.has(group) or _detail_queue[group].is_empty():
		return ""
	var list: Array = _detail_queue[group]
	var nm: String = list.pop_front()
	list.push_back(nm)  # keeps rotating
	return nm


## First detail of a group that has not been used yet; when all are used, falls back
## to the rotating queue.
func _take_new_detail(group: String) -> String:
	if not _detail_queue.has(group):
		return ""
	for nm in _detail_queue[group]:
		if not _detail_used.has(nm):
			_detail_used[nm] = true
			return nm
	return _take_detail(group)


## Blank 4x2 building at tile (x0, z0) (2 storeys + flat roof) on which unused doors,
## awnings, windows, facade parts, texts, a balcony and roof details are placed.
func _detail_building(x0: int, z0: int, style: String, front := "S") -> void:
	var base_tile := style + "/" + style + "_blok_dicht"
	if not _has(base_tile):
		base_tile = "klassiek_rood/klassiek_rood_blok_dicht"
	for x in range(x0, x0 + 4):
		for z in range(z0, z0 + 2):
			B(x, 0, z, base_tile, "S")
			B(x, 1, z, base_tile, "S")
			B(x, 2, z, "modern_wit/modern_wit_dak_plat_" + ("hoek" if (x == x0 or x == x0 + 3) else "rand"),
				("WS" if x == x0 else "SE") if (x == x0 or x == x0 + 3) else "S")
	# the facade with the parts faces `front` (the street), the back gets the second text
	var fz := z0 * 4.0 if front == "N" else (z0 + 2) * 4.0
	var back := "S" if front == "N" else "N"
	var bz := (z0 + 2) * 4.0 if front == "N" else z0 * 4.0
	for i in 4:
		var mx := (x0 + i) * 4 + 2.0
		var door := _take_new_detail("deuren")
		if door != "":
			D(mx, fz, 0.0, door, front)
		var above := _take_new_detail("luifels") if i % 2 == 0 else _take_new_detail("zonwering")
		if above != "":
			D(mx, fz, 2.5, above, front)
		var window := _take_new_detail("ramen")
		if window != "":
			D(mx, fz, 3.5, window, front)
		var g := _take_new_detail("gevel")
		if g != "":
			D((x0 + i) * 4 + 0.5, fz, 1.0, g, front)
	var text := _take_new_detail("tekst")
	if text != "":
		D((x0 + 2) * 4.0, fz, 5.0, text, front)
	var text2 := _take_new_detail("tekst")
	if text2 != "":
		D((x0 + 2) * 4.0, bz, 5.0, text2, back)
	var balcony := _take_new_detail("balkons")
	if balcony != "":
		D(x0 * 4.0, (z0 + 1) * 4.0, 3.0, balcony, "W")
	for i in 2:
		var dk := _take_new_detail("dak")
		if dk != "":
			D((x0 + 1 + i * 2) * 4.0, (z0 + 1) * 4.0, 6.0, dk, "S")


## Places the next prop of a kind ("street", "green" or "water") at (wx, wz) metres,
## height wy, cycling through all props of that kind.
func _prop(wx: float, wz: float, kind: String, wy := 0.0) -> void:
	var list: Array = _prop_lists[kind]
	if list.is_empty():
		return
	Pr(wx, wz, _next(list, _prop_counter, kind), "S", wy)


# ------------------------------------------------------------------ roofs district: all roof tile kinds and roof shapes

## One district per roof material in the "daken" group: a sloped row, L shapes with
## valleys, gable roofs with L corner and T, and pyramid / lean-to sheds.
func _roofs_district() -> void:
	var kinds := []
	for nm in _names(buildings, "daken/"):
		var s: String = nm.split("/")[1]
		if not kinds.has(s):
			kinds.append(s)
	for s in kinds:
		var p: String = "daken/" + s + "/" + s + "_"
		var shapes := []
		for nm in _names(buildings, "daken/" + s + "/"):
			shapes.append(nm.split("/")[2].trim_prefix(s + "_"))
		_district_name = "dak:" + s
		var o := _district(22, 10)
		# walls under the roofs: tile roofs on 1930s brick, the rest on classic red brick
		var wall: String = "jaren30" if s.begins_with("pannen") else "klassiek_rood"
		var cx := o.x + 2
		var cz := o.y + 2
		# row 2 deep: sloped roofs with hip ridges, variants in the middle
		var row := []
		for x in range(cx, cx + 6):
			for z in [cz, cz + 1]:
				row.append(Vector2i(x, z))
		_plain_facades(row, wall, 2)
		var vi := 0
		var mid := []
		for v in ["schuin", "schuin_dakkapel", "schuin_schoorsteen", "schuin_afgeplat"]:
			if shapes.has(v):
				mid.append(v)
		for c in row:
			var sides := _open_sides(c, row)
			if sides.size() >= 2:
				var corner: String = "schuin_afgeplat_hoek_buiten" if (c.x == cx and shapes.has("schuin_afgeplat_hoek_buiten")) else "schuin_hoek_buiten"
				B(c.x, 2, c.y, p + corner, CORNER[_corner_pair(sides, "")])
			else:
				B(c.x, 2, c.y, p + mid[vi % mid.size()], sides[0])
				vi += 1
		# L shape with inner corner (valley)
		_l_building(cx + 7, cz, wall, p, "schuin")
		# second L shape with truncated roofs
		if shapes.has("schuin_afgeplat_hoek_binnen"):
			_l_building(cx, cz + 4, wall, p, "schuin_afgeplat", true)
		# gable roofs (1 deep), L corner and T
		var zx := cx + 12
		var zc := [Vector2i(zx, cz + 2), Vector2i(zx + 1, cz + 2), Vector2i(zx + 2, cz + 2), Vector2i(zx + 2, cz + 1), Vector2i(zx + 2, cz)]
		_plain_facades(zc, wall, 1)
		B(zx, 1, cz + 2, p + "zadel_schild", "N")
		B(zx + 1, 1, cz + 2, p + ("zadel_afgeplat" if shapes.has("zadel_afgeplat") else "zadel"), "S")
		B(zx + 2, 1, cz + 2, p + "zadel_hoek", "SE")
		B(zx + 2, 1, cz + 1, p + "zadel", "E")
		B(zx + 2, 1, cz, p + "zadel_schild", "E")
		var tx := cx + 16
		if shapes.has("zadel_t"):
			var tc := [Vector2i(tx, cz + 1), Vector2i(tx + 1, cz + 1), Vector2i(tx + 2, cz + 1), Vector2i(tx + 1, cz)]
			_plain_facades(tc, wall, 1)
			B(tx + 1, 1, cz + 1, p + "zadel_t", "S")
			B(tx, 1, cz + 1, p + "zadel_schild", "N")
			B(tx + 2, 1, cz + 1, p + "zadel_schild", "S")
			B(tx + 1, 1, cz, p + "zadel_schild", "E")
		# pyramid and lean-to roof on separate sheds
		for i in 2:
			var nm2: String = ["piramide", "lessenaar"][i]
			if shapes.has(nm2):
				_plain_facades([Vector2i(tx + i * 2, cz + 4)], wall, 1)
				B(tx + i * 2, 1, cz + 4, p + nm2, "S")
		for x in range(o.x + 1, o.x + 21, 3):
			_prop(x * 4 + 2.0, (o.y + 9) * 4 + 3.0, "green")


## Facades with plain windows (and window corners) for the test buildings in the roofs district.
func _plain_facades(cells: Array, style: String, floors: int) -> void:
	_facades(cells, style, floors, ["bg_raam"], ["verd_raam"], ["bg_raam_hoek"], ["verd_raam_hoek"], {})


## L-shaped one-storey building with a sloped roof that has an inner corner (valley):
## a 4x2 bar with a 2x2 leg below its west half; (x, z) = north-west cell.
## p = roof tile prefix ("daken/<kind>/<kind>_"), slope = "schuin" or "schuin_afgeplat".
## row_major: walls are placed row by row instead of per 2x2 quarter (only the
## placement order differs, which is kept so the saved scene stays the same).
func _l_building(x: int, z: int, wall: String, p: String, slope: String, row_major := false) -> void:
	var cells := [Vector2i(x, z), Vector2i(x + 1, z), Vector2i(x, z + 1), Vector2i(x + 1, z + 1),
		Vector2i(x + 2, z), Vector2i(x + 3, z), Vector2i(x + 2, z + 1), Vector2i(x + 3, z + 1),
		Vector2i(x, z + 2), Vector2i(x + 1, z + 2), Vector2i(x, z + 3), Vector2i(x + 1, z + 3)]
	if row_major:
		cells = [Vector2i(x, z), Vector2i(x + 1, z), Vector2i(x + 2, z), Vector2i(x + 3, z),
			Vector2i(x, z + 1), Vector2i(x + 1, z + 1), Vector2i(x + 2, z + 1), Vector2i(x + 3, z + 1),
			Vector2i(x, z + 2), Vector2i(x + 1, z + 2), Vector2i(x, z + 3), Vector2i(x + 1, z + 3)]
	_plain_facades(cells, wall, 1)
	var outer := p + slope + "_hoek_buiten"
	B(x, 1, z, outer, "NW")
	B(x + 1, 1, z, p + slope, "N")
	B(x + 2, 1, z, p + slope, "N")
	B(x + 3, 1, z, outer, "EN")
	B(x + 3, 1, z + 1, outer, "SE")
	B(x + 2, 1, z + 1, p + slope, "S")
	B(x + 1, 1, z + 1, p + slope + "_hoek_binnen", "SE")
	B(x, 1, z + 1, p + slope, "W")
	B(x, 1, z + 2, p + slope, "W")
	B(x + 1, 1, z + 2, p + slope, "E")
	B(x, 1, z + 3, outer, "WS")
	B(x + 1, 1, z + 3, outer, "SE")


# ------------------------------------------------------------------ halls, canopies, pillars, parking garage, radio tower

## Sports complex: the three hollow halls (glass, swimming pool, sports, incl. open walls)
## on one paved forecourt with a glass entrance canopy and a colonnade of all pillars, a
## parking garage with all parts and a radio mast.
func _halls_and_misc() -> void:
	_district_name = "hallen"
	var o := _district(30, 14)
	var x0 := o.x + 2
	var z0 := o.y + 2
	# sports complex: one paved forecourt round the halls, the canopy and the colonnade
	fill_rect(o.x + 1, o.y + 1, o.x + 28, o.y + 12, "plein/plein_tegels")
	for i in 6:
		Pr((x0 + 1 + i * 4) * 4.0, (z0 + 5) * 4.0 + 2.0, "bomen/plataan" if i % 2 else "verlichting/lantaarn_modern")
	# three hollow halls side by side (glass, pool, sports) with roof variants
	var hs := ["hal_glas", "hal_zwembad", "hal_sport"]
	for i in 3:
		var hx := x0 + i * 6
		_hall(hx, z0, 5, 4, hs[i], Vector2i(hx + 2, z0 + 3), hx + 2)
		# open wall variants without roof as a tall hall (2 storeys)
		for x in range(hx, hx + 5):
			var sides2 := ["N"] if x != hx and x != hx + 4 else (["N", "W"] if x == hx else ["N", "E"])
			if sides2.size() == 1:
				B(x, 1, z0, "hallen/" + hs[i] + "_wand", "N")
			else:
				B(x, 1, z0, "hallen/" + hs[i] + "_hoek", CORNER[_corner_pair(sides2, "")])
		fill_rect(hx, z0, hx + 4, z0 + 3, "zwembad/zwembad_kant_tegels" if i == 1 else "plein/plein_tegels")
	# canopy and pillars
	for x in range(x0, x0 + 6):
		for z in range(z0 + 6, z0 + 9):
			B(x, 0, z, "overkapping/overkapping_glas_kolom" if (x - x0) % 2 == 0 and z == z0 + 6 else "overkapping/overkapping_glas", "S")
	var pil := _names(buildings, "pilaren/")
	for i in pil.size():
		B(x0 + 8 + i, 0, z0 + 7, pil[i], "N")
	# parking garage with all parts
	var gx := x0 + 18
	var gz := z0 + 6
	_parking_decks(gx, gz, 4, 4, 2)
	B(gx, 0, gz + 1, "parkeergarage/parkeergarage_inrit", "W")
	B(gx + 1, 0, gz + 1, "parkeergarage/parkeergarage_helling", "N")
	B(gx + 2, 0, gz + 2, "parkeergarage/parkeergarage_helling_rand", "S")
	B(gx + 4, 0, gz, "parkeergarage/parkeergarage_trappenhuis", "S")
	B(gx + 4, 1, gz, "parkeergarage/parkeergarage_trappenhuis", "S")
	# radio tower
	_mast(x0 + 26, z0 + 2, "overig/radiotoren", 8)
