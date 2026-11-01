@tool
extends RefCounted
## Stamps: structures that span several levels of the Grond GridMap (canals,
## bridges, viaducts, tunnels), placed in one go along a straight line.
##
## A stamp is planned in a local frame: u runs along the line (0 .. length-1),
## v runs across it, to the left seen in the drawing direction (0 = the first
## lane). plan() turns that into cells of the Grond layer for one of the four
## directions; build_tools.gd applies them with undo.
## Levels are Grond floors of 1 m: 0 = street level, water lies on -2,
## tunnels on -6 (see INSTRUCTIONS.md, "Hoogtes en lagen").
##
## Rotations follow the scene builder: 0 = front facing +Z ("S"), 1 = +X ("E"),
## 2 = -Z ("N"), 3 = -X ("W").

## Every stamp: label, minimum length in tiles and its parameters:
## name -> [label, default int, min, max] (number), [label, default, [options]]
## (fixed list) or [label, default, "prefix", "excluded suffix"] (library tiles).
const STAMPS := {
	"canal": {"label": "Canal / river", "min_length": 1, "params": {
		"width": ["Water width", 2, 1, 12],
		"water": ["Water", "water/water_gracht", ["water/water_gracht", "water/water"]],
	}},
	"bridge": {"label": "Bridge (street level)", "min_length": 1, "params": {
		"deck": ["Deck", "brug/brug_dek_weg_beide", "brug/brug_dek_"],
		"width": ["Width", 1, 1, 2],
	}},
	"viaduct": {"label": "Viaduct on pillars", "min_length": 3, "params": {
		"deck": ["Deck", "brug/brug_dek_weg_beide", "brug/brug_dek_"],
		"width": ["Width", 1, 1, 2],
		"height": ["Deck level", 3, 2, 10],
		"spacing": ["Pillar spacing", 2, 1, 8],
		"ends": ["Ends", "abutments", ["abutments", "ramps"]],
		"ramp": ["Ramp", "helling/helling_brug_weg_vlak", "helling/helling_brug_", "_rand"],
	}},
	"tunnel": {"label": "Car tunnel (3 lanes)", "min_length": 19, "params": {}},
}

const WATER_LEVEL := -2
## placeholder in a local plan: a pillar column below level y (see _pillar)
const PILLAR := "<pillar>"
const TUNNEL_DEPTH := 6
## tunnel cross-section (left wall, middle, right wall); %s = name part, %d = depth
const TUNNEL_LANES := ["%s_wand", "%s", "%s_wand_rechts"]


## Direction (0..3) and length (tiles) of a line dragged from one cell to another.
## The line follows the dominant axis.
static func line(from: Vector3i, to: Vector3i) -> Vector2i:
	var dx := to.x - from.x
	var dz := to.z - from.z
	var k := (0 if dz >= 0 else 2) if absi(dz) >= absi(dx) else (1 if dx > 0 else 3)
	return Vector2i(k, maxi(absi(dx), absi(dz)) + 1)


## Minimum line length (tiles) of a stamp with these parameters.
static func min_length(stamp: String, params: Dictionary) -> int:
	if stamp == "viaduct" and params.get("ends") == "ramps":
		return 2 * int(params.height) + 1
	return STAMPS[stamp].min_length


## Default parameter values of a stamp.
static func defaults(stamp: String) -> Dictionary:
	var out := {}
	var params: Dictionary = STAMPS[stamp].params
	for p in params:
		out[p] = params[p][1]
	return out


## The cells a stamp sets: an Array of {cell: Vector3i, item: String ("" = clear),
## rot: 0..3}. grond is read to adapt to what is already there (pillar feet).
static func plan(stamp: String, params: Dictionary, start: Vector3i, direction: int, length: int, grond: GridMap) -> Array:
	var local: Array
	match stamp:
		"canal":
			local = _plan_canal(params, length)
		"bridge":
			local = _plan_bridge(params, length)
		"viaduct":
			local = _plan_viaduct(params, length)
		"tunnel":
			local = _plan_tunnel(params, length)
	var u_dir := _rotate(Vector2i(0, 1), direction)
	var v_dir := _rotate(Vector2i(1, 0), direction)
	var out := []
	for e in local:
		var xz: Vector2i = Vector2i(start.x, start.z) + u_dir * e.u + v_dir * e.v
		var rot: int = e.rot if e.absolute else (e.rot + direction) % 4
		if e.item == PILLAR:
			# no room for a pillar (e.g. a road below): a girder instead
			var column := _pillar(grond, xz, e.y)
			if column.is_empty():
				column = [[e.y - 1, "brug/brug_ligger"]]
			for part in column:
				out.append({"cell": Vector3i(xz.x, part[0], xz.y), "item": part[1], "rot": rot})
		else:
			out.append({"cell": Vector3i(xz.x, e.y, xz.y), "item": e.item, "rot": rot})
	return out


## Rotates an (x, z) offset by k quarter turns, the same way rotation k turns a tile.
static func _rotate(o: Vector2i, k: int) -> Vector2i:
	for i in k:
		o = Vector2i(o.y, -o.x)
	return o


static func _e(u: int, v: int, y: int, item: String, rot := 0, absolute := false) -> Dictionary:
	return {"u": u, "v": v, "y": y, "item": item, "rot": rot, "absolute": absolute}


## Water on level -2 over the full width, quay walls below the quays on both
## banks and quays (facing the water) at street level. Street level above the
## water is cleared.
static func _plan_canal(p: Dictionary, length: int) -> Array:
	var width: int = p.width
	var out := []
	for u in length:
		for v in width:
			out.append(_e(u, v, 0, ""))
			out.append(_e(u, v, WATER_LEVEL, p.water))
		for bank in [[-1, 1], [width, 3]]:
			out.append(_e(u, bank[0], -2, "water/kademuur_alg", 0, true))
			out.append(_e(u, bank[0], -1, "water/kademuur", 0, true))
			out.append(_e(u, bank[0], 0, "stoep/stoep_kade_klinker" if u % 5 == 0 else "stoep/stoep_kade", bank[1]))
	return out


## Deck tiles at street level along the line; with width 2 the second lane is
## the mirrored deck (for decks with a railing on one side).
static func _plan_bridge(p: Dictionary, length: int) -> Array:
	var out := []
	for u in length:
		out.append_array(_deck(p, u, 0))
	return out


## Deck on level `height` with pillars every `spacing` tiles and girders under
## the other cells. ends = "abutments": an abutment beyond both ends of the line.
## ends = "ramps": the line starts and ends with `height` ramp tiles from street
## level up to the deck (1 m per tile), so a road can go over another road.
static func _plan_viaduct(p: Dictionary, length: int) -> Array:
	var h: int = p.height
	var ramps: bool = p.ends == "ramps"
	var first := h if ramps else 0           # first deck cell
	var last := length - 1 - (h if ramps else 0)
	var out := []
	for u in range(first, last + 1):
		out.append_array(_deck(p, u, h))
	for v in p.width:
		if ramps:
			# up: low end faces back (rot 2); down: mirrored, so the railing
			# variant (_rand) swaps lanes, like the decks
			for i in h:
				out.append(_e(i, v, i, p.ramp + ("_rand" if v == 1 else ""), 2))
				out.append(_e(length - 1 - i, v, i, p.ramp + ("_rand" if v == 0 and p.width > 1 else ""), 0))
		else:
			out.append(_e(-1, v, h - 1, "brug/brug_landhoofd", 0))
			out.append(_e(length, v, h - 1, "brug/brug_landhoofd", 2))
		for u in range(first, last + 1):
			var j := u - first
			var at_end := ramps and (u == first or u == last)
			if j % p.spacing == 0 and (ramps or (u > 0 and u < length - 1)) or at_end:
				out.append(_e(u, v, h, PILLAR))
			elif not ramps or (u > first and u < last):
				out.append(_e(u, v, h - 1, "brug/brug_ligger"))
	return out


static func _deck(p: Dictionary, u: int, y: int) -> Array:
	var out := [_e(u, 0, y, p.deck, 0)]
	if p.width > 1:
		out.append(_e(u, 1, y, p.deck, 2))
	return out


## Ramp down (6 steps), open trough, portal and covered tunnel on level -6,
## mirrored at the far end. Street level above ramps and trough is cleared.
static func _plan_tunnel(p: Dictionary, length: int) -> Array:
	var out := []
	var ends := TUNNEL_DEPTH + 3   # ramp + 2 trough cells + portal
	for i in ends:
		for mirrored in [false, true]:
			var u := length - 1 - i if mirrored else i
			var rot := 2 if mirrored else 0
			for v in 3:
				# turned around, the tile's left wall ends up on the right
				var lane: String = TUNNEL_LANES[2 - v if mirrored else v]
				if i < TUNNEL_DEPTH:
					out.append(_e(u, v, 0, ""))
					out.append(_e(u, v, -(i + 1), lane % "tunnel/tunnel_toerit" + "_d%d" % (i + 1), rot))
				elif i < TUNNEL_DEPTH + 2:
					out.append(_e(u, v, 0, ""))
					out.append(_e(u, v, -TUNNEL_DEPTH, lane % "tunnel/tunnelbak_rijstrook" + "_d%d" % TUNNEL_DEPTH, rot))
				else:
					out.append(_e(u, v, -TUNNEL_DEPTH, lane % "tunnel/tunnel_rijstrook" + "_portaal", rot))
	for u in range(ends, length - ends):
		for v in 3:
			out.append(_e(u, v, -TUNNEL_DEPTH, TUNNEL_LANES[v] % "tunnel/tunnel_rijstrook"))
	return out


## A pillar column under a deck on level `deck`: [level, tile] pairs, or [] if a
## pillar can't stand here. The foot stands on the water bed if there is water,
## otherwise it replaces the grass or pavement tile at street level (foot and
## ground in one). Roads, rails etc. stay free: no pillar there.
static func _pillar(grond: GridMap, xz: Vector2i, deck: int) -> Array:
	var bottom := 0
	var foot := ""
	var street := _item_name(grond, Vector3i(xz.x, 0, xz.y))
	if _item_name(grond, Vector3i(xz.x, WATER_LEVEL, xz.y)).begins_with("water/"):
		bottom = WATER_LEVEL
		foot = "brug/brug_pijler_water"
	elif street.begins_with("stoep/"):
		foot = "brug/brug_pijler_stoep"
	elif street == "" or street.begins_with("natuur/") or street.begins_with("terrein/") or street.begins_with("brug/brug_pijler"):
		foot = "brug/brug_pijler_gras"
	if foot == "":
		return []
	var out := [[bottom, foot]]
	for y in range(bottom + 1, deck - 1):
		out.append([y, "brug/brug_pijler"])
	out.append([deck - 1, "brug/brug_pijler_kop"])
	return out


static func _item_name(gm: GridMap, cell: Vector3i) -> String:
	var id := gm.get_cell_item(cell)
	return gm.mesh_library.get_item_name(id) if id >= 0 else ""
