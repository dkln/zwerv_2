extends "res://tools/build/city/base.gd"
## Example-map builder, part 2 of 7: reusable build helpers (see base.gd for the chain):
## building blocks and rings with facades and roofs, towers, street profiles, piers,
## masts, halls, parking decks, pools, hills and trenches, and the style kits.


const ORDER := ["S", "E", "N", "W"]  # directions in rotation order


## Deterministic hash of (a, b) mapped to 0 .. n-1; used for repeatable variation.
func _r(a: int, b: int, n: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663) ^ 0x5bd1e995) % maxi(n, 1)


## True if tile_name exists in the library of gm (default: the buildings layer).
func _has(tile_name: String, gm: GridMap = null) -> bool:
	var g := gm if gm else buildings
	return g.mesh_library.find_item_by_name(tile_name) >= 0


## Open sides of cell (x, z) within the rectangle (x0, z0, w, d): the edges of the
## rectangle the cell lies on, in the order N, S, W, E.
func _sides(x: int, z: int, x0: int, z0: int, w: int, d: int) -> Array:
	var s := []
	if z == z0: s.append("N")
	if z == z0 + d - 1: s.append("S")
	if x == x0: s.append("W")
	if x == x0 + w - 1: s.append("E")
	return s


## Corner key (from CORNER) formed by two of the given sides, or "" if none. When
## several fit (narrow shapes), the one whose front letter equals front is preferred.
func _corner_pair(sides: Array, front: String) -> String:
	var candidates := []
	for key in ["SE", "EN", "NW", "WS"]:
		if sides.has(key[0]) and sides.has(key[1]):
			candidates.append(key)
	for key in candidates:
		if key[0] == front:
			return key
	return candidates[0] if candidates.size() > 0 else ""


## Corner key of a cell that is a corner of the rectangle (x0, z0, w, d), else "".
## Only for rectangles at least 2 cells wide and deep.
func _corner_of(x: int, z: int, x0: int, z0: int, w: int, d: int) -> String:
	var sides := _sides(x, z, x0, z0, w, d)
	return _corner_pair(sides, "") if sides.size() == 2 else ""


## Flat roof tile on one cell at storey y, chosen by its open sides (p = style prefix).
## A free-standing cell falls back to the end piece if the style has no "los" tile.
func _flat_roof(x: int, y: int, z: int, p: String, sides: Array) -> void:
	var e := _edge(sides)
	var kind: String = e[0]
	if kind == "los" and not _has(p + "dak_plat_los"):
		kind = "eind"
	B(x, y, z, p + "dak_plat_" + kind, e[1])


## Rectangular building at tile (x0, z0), w x d tiles, `floors` storeys of the given style.
## Facade tiles are chosen per cell from its open sides (corner pieces on corners).
## opts: front, gf (ground floor, Array), gf_side, gf_corner, upper (upper floors, Array), upper_corner,
## roof ("flat"/"sloped"/"gable"/"cornice"/"battlements"/"none"), roof_extra (Array of sloped-roof
## variants), top (tile on the front edge instead of a roof), y0 (first storey),
## gap (Array of Vector2i cells without roof).
func block(x0: int, z0: int, w: int, d: int, style: String, floors: int, opts := {}) -> void:
	var p := style + "/" + style + "_"
	var front: String = opts.get("front", "S")
	var gf: Array = opts.get("gf", ["bg_raam"])
	var gf_side: String = opts.get("gf_side", gf[0])
	var gf_corner: String = opts.get("gf_corner", "bg_raam_hoek")
	var upper: Array = opts.get("upper", ["verd_raam"])
	var upper_corner: String = opts.get("upper_corner", "verd_raam_hoek")
	var roof: String = opts.get("roof", "flat")
	var roof_extra: Array = opts.get("roof_extra", [])
	var top: String = opts.get("top", "")
	var y0: int = opts.get("y0", 0)
	var gap: Array = opts.get("gap", [])
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			var sides := _sides(x, z, x0, z0, w, d)
			for v in range(floors):
				var tile_name := "blok_dicht"
				var rot = "S"
				if sides.size() == 0:
					pass
				elif sides.size() == 1 or (sides.size() == 2 and _corner_pair(sides, front) == ""):
					var s: String = front if sides.has(front) else sides[0]
					if v == 0:
						tile_name = gf[_r(x, z, gf.size())] if s == front else gf_side
					else:
						tile_name = upper[_r(x * 7 + v, z, upper.size())]
					rot = s
				else:
					var key := _corner_pair(sides, front)
					tile_name = gf_corner if v == 0 else upper_corner
					rot = CORNER[key]
				B(x, y0 + v, z, p + tile_name, rot)
			var yd := y0 + floors
			if gap.has(Vector2i(x, z)):
				continue
			if top != "" and sides.has(front):
				B(x, yd, z, p + top, front)
				continue
			match roof:
				"flat":
					_flat_roof(x, yd, z, p, sides)
				"cornice", "battlements":
					var base_tile := "dak_plat_kroonlijst_" if roof == "cornice" else "dak_kantelen_"
					if not _has(p + base_tile + "rand"):
						base_tile = "dak_kroonlijst_"
					if sides.size() == 1:
						B(x, yd, z, p + base_tile + "rand", sides[0])
					elif sides.size() >= 2 and _corner_pair(sides, front) != "":
						B(x, yd, z, p + base_tile + "hoek", CORNER[_corner_pair(sides, front)])
					else:
						B(x, yd, z, p + "dak_plat_midden", "S")
				"sloped":
					if sides.size() == 1:
						var nm := "dak_schuin"
						# roughly one in three edge cells gets a variant (dormer, chimney, ...)
						if roof_extra.size() > 0 and _r(x, z * 3, 3) == 0:
							nm = roof_extra[_r(x, z, roof_extra.size())]
						B(x, yd, z, p + nm, sides[0])
					elif _corner_pair(sides, front) != "":
						B(x, yd, z, p + "dak_schuin_hoek_buiten", CORNER[_corner_pair(sides, front)])
					else:
						B(x, yd, z, p + "dak_plat_midden", "S")
				"gable":
					var along_x := front == "N" or front == "S"
					var end_a := (x == x0) if along_x else (z == z0)
					var end_b := (x == x0 + w - 1) if along_x else (z == z0 + d - 1)
					if along_x:
						if end_b: B(x, yd, z, p + "dak_zadel_schild", "S")
						elif end_a: B(x, yd, z, p + "dak_zadel_schild", "N")
						else: B(x, yd, z, p + "dak_zadel", "S")
					else:
						if end_a: B(x, yd, z, p + "dak_zadel_schild", "E")
						elif end_b: B(x, yd, z, p + "dak_zadel_schild", "W")
						else: B(x, yd, z, p + "dak_zadel", "E")


## Closed city block (ring 2 deep) at tile (x0, z0), w x d tiles, with sloped roofs that
## wrap around the corners. The outer ring faces the street, the inner ring the courtyard.
## opts: gf, upper (street facades), back (courtyard facades), roof_extra (roof variants).
func ring(x0: int, z0: int, w: int, d: int, style: String, floors: int, opts := {}) -> void:
	var p := style + "/" + style + "_"
	var gf: Array = opts.get("gf", ["bg_raam"])
	var upper: Array = opts.get("upper", ["verd_raam"])
	var back: Array = opts.get("back", ["verd_raam"])
	var roof_variants: Array = opts.get("roof_extra", [])
	var x1 := x0 + w - 1
	var z1 := z0 + d - 1
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var outer := x == x0 or x == x1 or z == z0 or z == z1
			var inner := not outer and (x == x0 + 1 or x == x1 - 1 or z == z0 + 1 or z == z1 - 1)
			if not outer and not inner:
				continue
			if outer:
				var sides := _sides(x, z, x0, z0, w, d)
				var key := _corner_pair(sides, "") if sides.size() == 2 else ""
				for v in range(floors):
					if key != "":
						B(x, v, z, p + ("bg_raam_hoek" if v == 0 else "verd_raam_hoek"), CORNER[key])
					else:
						var nm: String = gf[_r(x, z, gf.size())] if v == 0 else upper[_r(x + v, z, upper.size())]
						B(x, v, z, p + nm, sides[0])
				if key != "":
					B(x, floors, z, p + "dak_schuin_hoek_buiten", CORNER[key])
				else:
					var dn := "dak_schuin"
					if roof_variants.size() > 0 and _r(x, z, 3) == 0:
						dn = roof_variants[_r(z, x, roof_variants.size())]
					B(x, floors, z, p + dn, sides[0])
			else:
				var court := []
				if z == z0 + 1 and x > x0 + 1 and x < x1 - 1: court.append("S")
				if z == z1 - 1 and x > x0 + 1 and x < x1 - 1: court.append("N")
				if x == x0 + 1 and z > z0 + 1 and z < z1 - 1: court.append("E")
				if x == x1 - 1 and z > z0 + 1 and z < z1 - 1: court.append("W")
				if court.size() == 0:
					var dk := ""
					if x == x0 + 1 and z == z0 + 1: dk = "SE"
					elif x == x1 - 1 and z == z0 + 1: dk = "WS"
					elif x == x0 + 1 and z == z1 - 1: dk = "EN"
					else: dk = "NW"
					for v in range(floors):
						B(x, v, z, p + "blok_dicht", "S")
					B(x, floors, z, p + "dak_schuin_hoek_binnen", dk)
				else:
					for v in range(floors):
						B(x, v, z, p + back[_r(x + v, z, back.size())], court[0])
					B(x, floors, z, p + "dak_schuin", court[0])


## Tower of stacked parts at tile (x, z) (list of names without style prefix, bottom
## first), starting at storey y0.
func tower(x: int, z: int, style: String, parts: Array, rot = "S", y0 := 0) -> void:
	var p := style + "/" + style + "_"
	for i in parts.size():
		B(x, y0 + i, z, p + parts[i], rot)


## Street profile along x from x0 to x1: rows = Array of [z, tile, rot] from north to
## south; x values in skip are left out (e.g. intersections).
func profile_x(x0: int, x1: int, rows: Array, skip := []) -> void:
	for x in range(x0, x1 + 1):
		if skip.has(x):
			continue
		for r in rows:
			G(x, r[0], r[1], r[2])


## Street profile along z from z0 to z1: columns = Array of [x, tile, rot] from west to
## east; z values in skip are left out.
func profile_z(z0: int, z1: int, columns: Array, skip := []) -> void:
	for z in range(z0, z1 + 1):
		if skip.has(z):
			continue
		for c in columns:
			G(c[0], z, c[1], c[2])


## Fills the rectangle x0..x1, z0..z1 (inclusive, tiles) with one ground tile on level y.
func fill_rect(x0: int, z0: int, x1: int, z1: int, tile_name: String, rot = "S", y := 0) -> void:
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			G(x, z, tile_name, rot, y)


## Classifies a cell by its open sides (see _sides / _open_sides) into the suffixes
## used by roof, deck and pool tiles. Returns [kind, rotation]:
##   "midden" no open side; "rand" one open side (rotated towards it);
##   "hoek" two adjacent open sides; "tegenover" two opposite open sides;
##   "eind" three open sides; "los" all four sides open (free-standing cell).
func _edge(sides: Array) -> Array:
	match sides.size():
		0:
			return ["midden", "S"]
		1:
			return ["rand", sides[0]]
		2:
			var key := _corner_pair(sides, "")
			if key != "":
				return ["hoek", CORNER[key]]
			return ["tegenover", "S" if sides.has("N") else "E"]
		3:
			# rotate so that the closed end faces the single closed side
			var absent := ""
			for d in ORDER:
				if not sides.has(d):
					absent = d
			return ["eind", (ORDER.find(absent) + 1) % 4]
	return ["los", "S"]


## Open sides of cell c within an arbitrary set of cells (Array or Dictionary keyed
## by Vector2i), in the order N, S, W, E (same order as _sides).
func _open_sides(c: Vector2i, cells) -> Array:
	var sides := []
	for d in ["N", "S", "W", "E"]:
		if not cells.has(c + DIR_OFFSET[d]):
			sides.append(d)
	return sides


## Round-robin pick: returns list[counter[key]] (wrapping) and advances that counter.
## The counter always advances; returns "" for an empty list.
func _next(list: Array, counter: Dictionary, key: String) -> String:
	var i: int = counter.get(key, 0)
	counter[key] = i + 1
	return "" if list.is_empty() else list[i % list.size()]


## Bridge pier on the ground layer: foot tile at level y0, plain shaft segments
## in between and a pier head at level y_top (the deck goes on y_top + 1).
func _pier(x: int, z: int, foot: String, y0: int, y_top: int) -> void:
	G(x, z, foot, "S", y0)
	for y in range(y0 + 1, y_top):
		G(x, z, "brug/brug_pijler", "S", y)
	G(x, z, "brug/brug_pijler_kop", "S", y_top)


## Stacked mast on the buildings layer (radio tower, factory chimney): prefix + "_voet"
## at storey 0, "_segment" up to height - 1 and "_top" at storey height.
func _mast(x: int, z: int, prefix: String, height: int) -> void:
	B(x, 0, z, prefix + "_voet", "S")
	for v in range(1, height):
		B(x, v, z, prefix + "_segment", "S")
	B(x, height, z, prefix + "_top", "S")


## Hollow hall of w x d cells (one storey, roof included) from the "hallen" group.
## door = the edge cell that gets the wall with a door; column_x = x of the interior
## cells that get a roof with a column (-1 = none).
func _hall(x0: int, z0: int, w: int, d: int, hall: String, door: Vector2i, column_x := -1) -> void:
	var st := "hallen/" + hall + "_"
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			var sides := _sides(x, z, x0, z0, w, d)
			if sides.size() == 0:
				B(x, 0, z, st + ("dak_kolom" if x == column_x else "dak"), "S")
			elif sides.size() == 1:
				B(x, 0, z, st + ("wand_deur_dak" if Vector2i(x, z) == door else "wand_dak"), sides[0])
			else:
				B(x, 0, z, st + "hoek_dak", CORNER[_corner_pair(sides, "")])


## Parking garage of w x d cells with the given number of levels: parking decks
## ("dek") with a roof deck ("dak") on top, edges and corners chosen per cell.
func _parking_decks(x0: int, z0: int, w: int, d: int, levels: int) -> void:
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			var e := _edge(_sides(x, z, x0, z0, w, d))
			for v in range(levels):
				var kind := "dak" if v == levels - 1 else "dek"
				B(x, v, z, "parkeergarage/parkeergarage_%s_%s" % [kind, e[0]], e[1])


## Swimming pool basin of w x d cells on ground level -1. stairs: the north edge
## cell at x0 + 2 gets the edge with a ladder. clear_top: also empty level 0
## above the basin (otherwise the surrounding tiles stay there, as in a covered pool).
func _pool_basin(x0: int, z0: int, w: int, d: int, stairs: bool, clear_top: bool) -> void:
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			var es := _sides(x, z, x0, z0, w, d)
			var e := _edge(es)
			var nm: String = "zwembad/zwembad_" + e[0]
			if stairs and es.size() == 1 and x == x0 + 2 and es[0] == "N":
				nm = "zwembad/zwembad_rand_trap"
			if clear_top:
				_trench(x, z, nm, 1, e[1])
			else:
				G(x, z, nm, e[1], -1)
				occupied[Vector2i(x, z)] = true


## Small 3x3 hill of the given material ("gras", "zand", "grind"); (hx, hz) is the
## north-west cell. Block with a top in the centre, slopes on the sides, outer corners.
func _hill(hx: int, hz: int, mat: String) -> void:
	var p: String = "heuvel/heuvel_" + mat + "_"
	G(hx + 1, hz + 1, p + "blok")
	G(hx + 1, hz + 1, p + "top", "S", 1)
	G(hx + 1, hz, p + "helling", "S")
	G(hx + 1, hz + 2, p + "helling", "N")
	G(hx, hz + 1, p + "helling", "E")
	G(hx + 2, hz + 1, p + "helling", "W")
	G(hx, hz, p + "hoek_buiten", "SE")
	G(hx + 2, hz, p + "hoek_buiten", "WS")
	G(hx, hz + 2, p + "hoek_buiten", "EN")
	G(hx + 2, hz + 2, p + "hoek_buiten", "NW")


# ------------------------------------------------------------------ library names and style kits

const DIR_OFFSET := {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "W": Vector2i(-1, 0), "E": Vector2i(1, 0)}

## Sorted names of all items in the library of gm that start with prefix.
func _names(gm: GridMap, prefix: String) -> Array:
	var result := []
	for id in gm.mesh_library.get_item_list():
		var nm := gm.mesh_library.get_item_name(id)
		if nm.begins_with(prefix):
			result.append(nm)
	result.sort()
	return result


## Tile name without group folder and style prefix, e.g. "jaren30/jaren30_bg_deur" -> "bg_deur".
func _short(style: String, nm: String) -> String:
	return nm.split("/")[nm.split("/").size() - 1].trim_prefix(style + "_")


## The tiles of a building style sorted by role (names without the style prefix): ground
## and upper floor facades with their corners, flat roof kinds and sloped roofs.
func _style_kit(style: String) -> Dictionary:
	var kit := {"gf": [], "gf_corners": [], "upper": [], "upper_corners": [],
		"flat": {"midden": [], "rand": [], "hoek": [], "tegenover": [], "eind": [], "los": []}, "sloped": [], "outer": []}
	for nm in _names(buildings, style + "/"):
		var k := _short(style, nm)
		if k.begins_with("bg_"):
			kit[("gf_corners" if k.contains("hoek") else "gf")].append(k)
		elif k.begins_with("verd_"):
			kit[("upper_corners" if k.contains("hoek") else "upper")].append(k)
		elif k.begins_with("dak_schuin") and not k.contains("hoek_binnen"):
			kit[("outer" if k.contains("hoek_buiten") else "sloped")].append(k)
		elif k.begins_with("dak_plat") or k.begins_with("dak_bitumen") or k.begins_with("dak_grind"):
			for e in ["rand", "hoek", "tegenover", "eind", "los"]:
				if k.ends_with("_" + e):
					kit.flat[e].append(k)
					break
			if k.ends_with("_midden"):
				kit.flat.midden.append(k)
	return kit


## Flat roofs on storey y over a set of cells. kinds maps an edge kind (see _edge) to a list
## of tile names (without style prefix); variants alternate per kind via `counter`.
func _flat_roofs(cells: Array, style: String, y: int, kinds: Dictionary, counter: Dictionary) -> void:
	var p := style + "/" + style + "_"
	var cell_set := {}
	for c in cells:
		cell_set[c] = true
	for c in cells:
		var e := _edge(_open_sides(c, cell_set))
		var kind: String = e[0]
		# missing kinds fall back to an edge tile, then to a middle tile
		var list: Array = kinds.get(kind, [])
		if list.is_empty() and kind in ["tegenover", "eind", "los"]:
			list = kinds.get("rand", [])
		if list.is_empty():
			list = kinds.get("midden", [])
		if list.is_empty():
			continue
		B(c.x, y, c.y, p + _next(list, counter, kind), e[1])


## Sunk ground tile: empties level 0 at (x, z) and places tile_name on level -depth.
func _trench(x: int, z: int, tile_name: String, depth: int, rot = "S") -> void:
	ground.set_cell_item(Vector3i(x, 0, z), GridMap.INVALID_CELL_ITEM)
	G(x, z, tile_name, rot, -depth)
	occupied[Vector2i(x, z)] = true
