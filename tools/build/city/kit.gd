extends "res://tools/build/city/base.gd"
## City builder, part 2 (see base.gd for the chain): reusable build helpers: building
## blocks and rings with facades and roofs, towers, halls, parking decks and style helpers.


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
						if y0 == 0 and _faces_building(x, z, s):
							tile_name = _closed_ground_floor(p, tile_name)
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


## Cells of one building along a side of a closed block: each such stretch gets its own
## height (_ring_floors).
const RING_SEGMENT := 4
## Storeys a stretch of a closed block differs from the block's own height, by chance.
const RING_HEIGHT_STEPS := [0, 1, 0, -1, 0, 1]


## Storeys of the closed-block cell (x, z): along each side the block is a row of
## buildings of RING_SEGMENT cells, each a storey higher or lower now and then (never
## under 3), the courtyard side as high as the street side; the corners keep the block's
## height so the roofs turn the corner.
func _ring_floors(x: int, z: int, x0: int, z0: int, x1: int, z1: int, floors: int) -> int:
	if floors < 3:
		return floors
	var north := z <= z0 + 1
	var south := z >= z1 - 1
	var west := x <= x0 + 1
	var east := x >= x1 - 1
	if (north or south) and (west or east):
		return floors
	var band := 0 if north else (1 if south else (2 if west else 3))
	var along := (x - x0) if (north or south) else (z - z0)
	var step: int = RING_HEIGHT_STEPS[_r(x0 * 13 + band * 7 + along / RING_SEGMENT, z0 * 5 + floors, RING_HEIGHT_STEPS.size())]
	return maxi(floors + step, 3)


## Closed city block (ring 2 deep) at tile (x0, z0), w x d tiles, with sloped roofs that
## wrap around the corners. The outer ring faces the street, the inner ring the courtyard.
## The height varies a little along the sides (_ring_floors; opts "vary": false keeps it even).
## opts: gf, upper (street facades), back (courtyard facades), roof_extra (roof variants).
func ring(x0: int, z0: int, w: int, d: int, style: String, base_floors: int, opts := {}) -> void:
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
			var floors := _ring_floors(x, z, x0, z0, x1, z1, base_floors) if opts.get("vary", true) else base_floors
			if outer:
				var sides := _sides(x, z, x0, z0, w, d)
				var key := _corner_pair(sides, "") if sides.size() == 2 else ""
				for v in range(floors):
					if key != "":
						B(x, v, z, p + ("bg_raam_hoek" if v == 0 else "verd_raam_hoek"), CORNER[key])
					else:
						var nm: String = gf[_r(x, z, gf.size())] if v == 0 else upper[_r(x + v, z, upper.size())]
						if v == 0 and _faces_building(x, z, sides[0]):
							nm = _closed_ground_floor(p, nm)
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


## Bridge pier on the ground layer: foot tile at level y0, plain shaft segments
## in between and a pier head at level y_top (the deck goes on y_top + 1).
func _pier(x: int, z: int, foot: String, y0: int, y_top: int) -> void:
	G(x, z, foot, "S", y0)
	for y in range(y0 + 1, y_top):
		G(x, z, "brug/brug_pijler", "S", y)
	G(x, z, "brug/brug_pijler_kop", "S", y_top)


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


# ------------------------------------------------------------------ library names and style kits

const DIR_OFFSET := {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "W": Vector2i(-1, 0), "E": Vector2i(1, 0)}


## True if a building already stands on the ground in front of side `side` of cell (x, z):
## a facade there lies against its wall.
func _faces_building(x: int, z: int, side: String) -> bool:
	var offset: Vector2i = DIR_OFFSET[side]
	return buildings.get_cell_item(Vector3i(x + offset.x, 0, z + offset.y)) >= 0


## The ground-floor piece for a facade against another building's wall: no door, porch or
## shop front there, but plain windows (the first of them the style has), else `wanted`.
func _closed_ground_floor(p: String, wanted: String) -> String:
	for option: String in ["bg_raam", "bg_raam_boog", "bg_glas", "bg_dicht"]:
		if _has(p + option):
			return option
	return wanted

## Sunk ground tile: empties level 0 at (x, z) and places tile_name on level -depth.
func _trench(x: int, z: int, tile_name: String, depth: int, rot = "S") -> void:
	ground.set_cell_item(Vector3i(x, 0, z), GridMap.INVALID_CELL_ITEM)
	G(x, z, tile_name, rot, -depth)
	occupied[Vector2i(x, z)] = true


## Chooses lanes (world headings) and, if given, the road users for the tile in ground
## cell (x, level, z), as the Build dock does (RoadNetwork.LANE_CHOICES): the headings are
## turned into the sides of the tile as it is placed. A choice counts while that tile stays.
func _choose_lanes(x: int, z: int, headings: Array, kinds := [], level := 0) -> void:
	var cell := Vector3i(x, level, z)
	var item := ground.get_cell_item(cell)
	if item < 0:
		return
	var turn := ground.get_basis_with_orthogonal_index(ground.get_cell_item_orientation(cell))
	var sides := []
	for heading: Vector2i in headings:
		for side: String in RoadNetwork.LOCAL_HEADINGS:
			var world: Vector3 = turn * RoadNetwork.LOCAL_HEADINGS[side]
			if Vector2i(roundi(world.x), roundi(world.z)) == heading:
				sides.append(side)
	var choice := {"tile": ground.mesh_library.get_item_name(item), "lanes": sides, "by_builder": true}
	if not kinds.is_empty():
		choice["kinds"] = kinds
	var choices: Dictionary = ground.get_meta(RoadNetwork.LANE_CHOICES, {})
	choices[cell] = choice
	ground.set_meta(RoadNetwork.LANE_CHOICES, choices)


## One narrow canal house at tile (x, z) facing front: a ground floor picked by rnd,
## floors - 1 upper storeys from facades and a gable top ("gevel_" + gable_top) on storey floors.
func _house(x: int, z: int, front: String, style: String, floors: int, facades: Array, gable_top: String, rnd: int) -> void:
	var p := style + "/" + style + "_"
	var gf: String = ["bg_deur", "bg_deur", "bg_winkel_luifel", "bg_raam", "bg_winkel"][rnd % 5]
	B(x, 0, z, p + gf, front)
	for v in range(1, floors):
		B(x, v, z, p + facades[(rnd + v) % facades.size()], front)
	B(x, floors, z, p + "gevel_" + gable_top, front)


## First option that exists as p + option in the buildings library, else "blok_dicht".
func _first(p: String, options: Array) -> String:
	for o in options:
		if _has(p + o):
			return o
	return "blok_dicht"


## A quay cell: pavement on top of a quay wall reaching down to the canal floor.
func _quay(x: int, z: int, tile_name: String, rot) -> void:
	G(x, z, "water/kademuur_alg", "S", -2)
	G(x, z, "water/kademuur", "S", -1)
	G(x, z, tile_name, rot)


## 3-lane tunnel cross-section, from the "wand" side to the "wand_rechts" side.
const TUNNEL_LANES := ["%s_wand%s", "%s%s", "%s_wand_rechts%s"]
