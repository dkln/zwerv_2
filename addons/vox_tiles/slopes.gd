@tool
extends RefCounted
## Slope variants of flat ground tiles, made while importing the flat tile.
##
## A flat tile lists the shapes it should also exist as in its metadata:
##
##     {"id": 5, "slopes": ["steil", "flauw_a", "flauw_b", "brug", "brug_rand"]}
##
## A cell of a flat curve (grond/bocht/<profile>_<i>_<j>) also says where it lies in
## the curve, for the curve shapes: {"slopes": ["bocht", ...], "curve": [i, j, parts]}.
##
## The importer (vox_import_plugin.gd) builds each shape from the tile's voxels and
## stores the meshes as meta "slopes" ({shape: ArrayMesh}, each with its own "lod"
## and "lod2"); library_builder.gd turns them into items named by item_name().
## The shapes follow shear() in tools/voxgen/ground.py and curve_cell() in
## tools/voxgen/ground4.py (the tiles the generator used to write as .vox files), but
## with a smooth surface instead of 1-voxel steps (plan(), build(), smooth()).

const Parser = preload("res://addons/vox_tiles/vox_parser.gd")
const Mesher = preload("res://addons/vox_tiles/vox_mesher.gd")

## Straight shapes, rising towards the back: steil: 1 m (one ground layer) over the
## tile; flauw_a / flauw_b: lower and upper half of a 1 m rise over two tiles;
## hoek_buiten / hoek_binnen: corners of a steep embankment (high only at the back
## right / low only at the front left); brug / brug_rand / brug_rand_rechts: steep bridge
## ramp (thin deck on a concrete slab), with a parapet on the left / right.
const SHAPES := ["steil", "flauw_a", "flauw_b", "hoek_buiten", "hoek_binnen", "brug", "brug_rand", "brug_rand_rechts"]
## Curve shapes (need "curve"), see tools/voxgen/ground4.py: bocht / bocht_rechts:
## embankment rising along the curve (climbing you turn left / right); brug_bocht /
## brug_bocht_rechts: the same as a thin bridge deck with parapets and a pier stub;
## brug_vlak: flat curved bridge deck.
const CURVE_SHAPES := ["bocht", "bocht_rechts", "brug_bocht", "brug_bocht_rechts", "brug_vlak"]

## Shapes a tile can be smoothed into itself ("smooth" in its metadata, see
## own_plan()): the straight ones and heuvel_top, a rounded hill top (up to 4 voxels).
const OWN_SHAPES := ["steil", "flauw_a", "flauw_b", "hoek_buiten", "hoek_binnen", "heuvel_top"]

## Voxels in one ground layer: a straight slope rises FLOOR over the tile.
const FLOOR := 8
## Top of sidewalk / grass (voxels); parapets are WALK + 4 high.
const WALK := 3
## Inner radius of curves in tiles (CURVE_RADIUS in tools/voxgen/ground3.py).
const CURVE_RADIUS := 1
## Radius (voxels) of a bridge pier (PIER_R in tools/voxgen/ground4.py).
const PIER_R := 5.2

## Colours as the generator writes them (palette.py, numbered groups damped by
## VARIATION), with the material they get, and the random mixes of ground.py.
const COLOURS := {
	"aarde1": [Color8(110, 82, 58), Parser.MAT_OPAQUE],
	"aarde2": [Color8(101, 74, 53), Parser.MAT_OPAQUE],
	"aarde3": [Color8(119, 90, 63), Parser.MAT_OPAQUE],
	"aarde_donker": [Color8(72, 54, 40), Parser.MAT_OPAQUE],
	"beton1": [Color8(171, 170, 165), Parser.MAT_STONE],
	"beton2": [Color8(161, 161, 156), Parser.MAT_STONE],
	"beton3": [Color8(180, 179, 175), Parser.MAT_STONE],
	"beton_donker": [Color8(120, 120, 116), Parser.MAT_STONE],
	"metaal2": [Color8(120, 122, 126), Parser.MAT_METAL],
	"metaal3": [Color8(160, 162, 166), Parser.MAT_METAL],
}
## [names, weights (empty = uniform), seed]
const EARTH := [["aarde1", "aarde2", "aarde3", "aarde_donker"], [3, 3, 2, 1], 10]
const CONCRETE := [["beton1", "beton2", "beton3"], [3, 2, 1], 13]
const CONCRETE_DARK := [["beton2", "beton_donker"], [], 14]
## Sub-surface earth of the flat tiles; becomes dark concrete on curved bridge decks.
const EARTH_SUB := "aarde2"


## Item name of a slope of tile `key` (path below the category), e.g. for "weg/weg_vlak":
## "helling/helling_weg_vlak", "helling/flauw_weg_vlak_a", "helling/helling_brug_weg_vlak_rand";
## for the curve cell "bocht/straat_1_2": "helling_bocht/straat_rechts_1_2",
## "helling_bocht/brug_straat_1_2", "brug/bocht_straat_1_2".
static func item_name(key: String, shape: String) -> String:
	var base := key.get_file()
	match shape:
		"steil":
			return "helling/helling_" + base
		"flauw_a", "flauw_b":
			return "helling/flauw_%s_%s" % [base, shape.right(1)]
		"brug":
			return "helling/helling_brug_" + base
		"brug_rand":
			return "helling/helling_brug_%s_rand" % base
		"brug_rand_rechts":
			return "helling/helling_brug_%s_rand_rechts" % base
		"hoek_buiten", "hoek_binnen":
			return "helling/helling_%s_%s" % [base, shape]
	# curve cell "<profile>_<i>_<j>"
	var parts := base.rsplit("_", true, 2)
	var cell := "_%s_%s" % [parts[1], parts[2]]
	match shape:
		"bocht":
			return "helling_bocht/" + base
		"bocht_rechts":
			return "helling_bocht/%s_rechts%s" % [parts[0], cell]
		"brug_bocht":
			return "helling_bocht/brug_" + base
		"brug_bocht_rechts":
			return "helling_bocht/brug_%s_rechts%s" % [parts[0], cell]
	return "brug/bocht_" + base


## The shapes in a tile's metadata, without unknown ones (with a warning).
static func shapes_of(meta: Dictionary, path := "") -> Array[String]:
	var out: Array[String] = []
	var list = meta.get("slopes", [])
	if not list is Array:
		push_warning("vox: %s: \"slopes\" must be a list of %s" % [path, ", ".join(SHAPES + CURVE_SHAPES)])
		return out
	var curve = meta.get("curve")
	var has_curve: bool = curve is Array and curve.size() == 3
	for shape in list:
		if str(shape) in SHAPES or str(shape) in CURVE_SHAPES and has_curve:
			out.append(str(shape))
		elif str(shape) in CURVE_SHAPES:
			push_warning("vox: %s: slope '%s' needs \"curve\": [i, j, parts]" % [path, shape])
		else:
			push_warning("vox: %s: unknown slope '%s' (use %s)" % [path, shape, ", ".join(SHAPES + CURVE_SHAPES)])
	return out


## How a shape is made of a tile (see build() and smooth()): the tile on a
## padded block (every column raised by "lift" voxels and filled up with earth, or a
## concrete slab for the bridge shapes), and the smooth surface height height() that
## smooth() moves the meshed block onto. Curve shapes also have the curve geometry
## and "ring": per column 1 if it lies on the curve. brug_vlak stays flat ("smooth" false).
static func plan(vox, shape: String, meta: Dictionary) -> Dictionary:
	var sx: int = vox.size.x
	var sy: int = vox.size.y
	var p := {"shape": shape, "sx": sx, "sy": sy, "deck": shape.begins_with("brug"),
		"curve": shape in CURVE_SHAPES, "smooth": shape != "brug_vlak", "grid": false}
	if not p.curve:
		# lift: the anchor (fill top, or slab bottom for decks) lands on an even voxel,
		# so the downscaled lod2 keeps it on a block boundary
		p.lift = 1 if p.deck else 2
		p.grid = shape.begins_with("hoek")   # folded along the diagonal: split per voxel
		p.anchor = p.lift - 1 if p.deck else p.lift
		return p
	var c: Array = meta.curve
	p.i = int(c[0])
	p.j = int(c[1])
	p.w = int(c[2])
	p.rin = float(CURVE_RADIUS * sx)
	var rmid: float = p.rin + p.w * sx / 2.0
	p.floors = maxi(1, roundi(rmid * PI / 2.0 / sx))
	p.right = shape.ends_with("_rechts")
	p.grid = true
	var ring := PackedByteArray()
	ring.resize(sx * sy)
	# the cell sits on the floor of its lowest column (generator: integer heights at
	# the column centres), the same table tools/voxgen/ground4.py gives the map builder
	var lowest := INF
	for y in sy:
		for x in sx:
			var r := Vector2(p.i * sx + x + 0.5, p.j * sy + y + 0.5).length()
			if r >= p.rin and r < p.rin + p.w * sx:
				ring[y * sx + x] = 1
				var stepped := clampi(int(_global_height(p, x + 0.5, y + 0.5)), 0, p.floors * FLOOR - 1)
				lowest = minf(lowest, stepped)
	p.ring = ring
	p.base = 0 if lowest == INF or not p.smooth else int(lowest) / FLOOR * FLOOR
	var highest := 0.0
	if p.smooth:
		for y in sy + 1:
			for x in sx + 1:
				highest = maxf(highest, height(p, x, y))
	# lift above the highest surface point, so the walls between the raised curve and
	# the flat ground beside it (cells on the ground) sink into that ground
	var lift := ceili(highest) + 1
	if p.deck:
		lift += 1 - lift % 2   # odd: slab bottom (lift - 1) on an even voxel
	else:
		lift += lift % 2
	p.lift = lift if p.smooth else 0
	p.anchor = maxi(p.lift - 1, 0) if p.deck else p.lift
	return p


## Plan for a tile that is itself the padded block of a slope (the generator writes
## it so, for slopes without a flat tile of their own, e.g. hills and tunnel access
## ramps): metadata "smooth": {"shape": one of OWN_SHAPES, "lift": voxels the tile
## is raised by (fill below), "keep_x": voxel columns x that stay put (a wall)}.
## Empty if the tile has no (valid) "smooth".
static func own_plan(vox, meta: Dictionary, path := "") -> Dictionary:
	var spec = meta.get("smooth")
	if spec == null:
		return {}
	if not spec is Dictionary or not str(spec.get("shape")) in OWN_SHAPES:
		push_warning("vox: %s: \"smooth\" must be {\"shape\": %s, \"lift\": n}" % [path, " / ".join(OWN_SHAPES)])
		return {}
	var shape := str(spec.shape)
	var lift := int(spec.get("lift", 2))
	var keep := PackedByteArray()
	keep.resize(vox.size.x)
	for x in spec.get("keep_x", []):
		if int(x) >= 0 and int(x) < keep.size():
			keep[int(x)] = 1
	return {"shape": shape, "sx": vox.size.x, "sy": vox.size.y, "deck": false, "curve": false, "smooth": true,
		"grid": shape.begins_with("hoek") or shape == "heuvel_top", "lift": lift, "anchor": lift, "keep_x": keep}


## Smooth surface height (voxels above the cell floor) at tile-local voxel position
## (x, y) (MagicaVoxel axes, y = 0 at the front), before the 1-voxel surface steps.
static func height(p: Dictionary, x: float, y: float) -> float:
	if not p.curve:
		match p.shape:
			"flauw_a":
				return y / 8.0
			"flauw_b":
				return 4.0 + y / 8.0
			"hoek_buiten":
				return minf(x, y) / 4.0
			"hoek_binnen":
				return maxf(x, y) / 4.0
			"heuvel_top":
				# _hill_top() of extras4.py without the steps (and not below the edges)
				return clampf(4.0 - Vector2(x - 16.0, y - 16.0).length() / 4.0, 0.0, 4.0)
		return y / 4.0   # steil, brug, brug_rand
	if not p.smooth:
		return 0.0
	return _global_height(p, x, y) - p.base


## Curve: rise along the angle, from 0 at the start to floors * FLOOR at the end
## (rise_height() of ground4.py without the steps).
static func _global_height(p: Dictionary, x: float, y: float) -> float:
	var f := atan2(p.j * p.sy + y, p.i * p.sx + x) / (PI / 2.0)
	if p.right:
		f = 1.0 - f
	return clampf(f, 0.0, 1.0) * p.floors * FLOOR


## The padded block of a shape (see plan()), to be meshed and then smooth()ed:
## as shear() of ground.py and curve_cell() of ground4.py, but every column raised
## by the same p.lift instead of its step height.
static func build(vox, p: Dictionary):
	if p.curve:
		return _curve(vox, p)
	var lift: int = p.lift
	var g := Grid.new(vox, vox.size + Vector3i(0, 0, lift + 1))
	for y in vox.size.y:
		for x in vox.size.x:
			g.copy_column(x, y, lift)
			if p.deck:
				g.mix(x, y, lift, CONCRETE_DARK)
				g.mix(x, y, lift - 1, CONCRETE_DARK)
			else:
				for z in lift:
					g.mix(x, y, z, EARTH)
	if p.shape.begins_with("brug_rand"):
		var rx: int = 0 if p.shape == "brug_rand" else vox.size.x - 1
		for y in vox.size.y:
			for z in range(lift, lift + WALK + 4):
				g.mix(rx, y, z, CONCRETE)
			_railing(g, rx, y, lift, y % 8 == 2)
	return g.to_vox()


## curve_cell() of ground4.py for the flat curve cell: the columns on the curve
## raised by p.lift, with a slab, parapets and a pier stub for the decks.
static func _curve(vox, p: Dictionary):
	var t: int = p.sx
	var lift: int = p.lift
	var ring: PackedByteArray = p.ring
	var last: int = p.w * t - 1
	var sub := COLOURS[EARTH_SUB][0] as Color
	var g := Grid.new(vox, Vector3i(t, t, mini(256, lift + maxi(vox.size.z, WALK + 9))))
	for y in t:
		for x in t:
			if ring[y * t + x] == 0:
				continue
			var px: float = p.i * t + x + 0.5
			var py: float = p.j * t + y + 0.5
			var r := Vector2(px, py).length()
			var u := mini(int(r - p.rin), last)
			g.copy_column(x, y, lift, sub if p.deck else Color(-1, -1, -1), CONCRETE_DARK)
			if p.deck:
				g.mix(x, y, lift, CONCRETE_DARK)
				if lift > 0:
					g.mix(x, y, lift - 1, CONCRETE_DARK)
				if u in [0, 1, last - 1, last]:
					for z in range(lift, lift + WALK + 4):
						g.mix(x, y, z, CONCRETE)
					if u == 0 or u == last:
						_railing(g, x, y, lift, int(atan2(py, px) * r) % 8 == 2)
			else:
				for z in lift:
					g.mix(x, y, z, EARTH)
	# pier stub under the centre of a deck cell when a whole pier fits under the deck
	var centre := Vector2(p.i * t + t / 2.0, p.j * t + t / 2.0).length()
	if p.deck and p.smooth and p.rin + PIER_R <= centre and centre <= p.rin + p.w * t - PIER_R:
		for y in t:
			for x in t:
				if ring[y * t + x] == 1 and Vector2(x + 0.5 - t / 2.0, y + 0.5 - t / 2.0).length() < PIER_R:
					for z in lift - 1:
						if (x + z) % 7:
							g.mix(x, y, z, CONCRETE)
						else:
							g.put(x, y, z, "beton_donker")
	# the rest of a cell on the ground keeps the flat tile's columns (no holes beside
	# the curve)
	if not p.deck and p.base == 0:
		for y in t:
			for x in t:
				if ring[y * t + x] == 0:
					g.copy_column(x, y, 0)
	return g.to_vox()


## Moves the meshed padded block (build()) onto the smooth surface: in every column
## of the shape, what lies above the anchor (the tile, slab and parapets) is shifted
## up by height() - lift, what lies below (earth fill, pier) is stretched from the
## ground up to there. Columns off a curve stay where they are. Faces are first split
## at the anchor (and per voxel column where the height isn't linear), normals follow
## the new faces, and the cell side groups / "solid_faces" of the mesher are redone.
## vs: voxel size of the full model in metres; f: voxels per mesh voxel (lod2: 2).
static func smooth(mesh: ArrayMesh, p: Dictionary, vs: float, block: Vector3, f := 1) -> void:
	if not p.smooth:
		return
	var half := Vector2(p.sx, p.sy) * 0.5
	var surfaces := []
	var covered := PackedFloat32Array()
	covered.resize(Mesher.GROUPS)
	var old_ranges: Array = mesh.get_meta("face_ranges", [])
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var mat_name := mesh.surface_get_name(s)
		var mat_index := Parser.MATERIAL_NAMES.find(mat_name)
		var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var col: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uv = arrays[Mesh.ARRAY_TEX_UV]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var bounds: PackedInt32Array = old_ranges[s] if s < old_ranges.size() else PackedInt32Array([0, 0, 0, 0, 0, 0, 0, pos.size()])
		var out := []
		for g in Mesher.GROUPS:
			out.append({"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "u": PackedVector2Array(), "u2": PackedVector2Array()})
		for g in Mesher.GROUPS:
			for k in range(bounds[g], bounds[g + 1], 3):
				var n: Vector3 = nrm[k]
				var poly := []
				for m in 3:
					var q: Vector3 = pos[k + m]
					# Godot metres -> MagicaVoxel voxel coordinates of the full model
					poly.append([Vector3(q.x / vs + half.x, -q.z / vs + half.y, q.y / vs), col[k + m],
						uv[k + m] if uv else Vector2.ZERO, uv2[k + m]])
				var n_vox := Vector3(n.x, -n.z, n.y)
				var pieces := [poly]
				if p.grid:
					pieces = _split_grid(pieces, 0, f)
					pieces = _split_grid(pieces, 1, f)
				for piece in pieces:
					var centre := Vector3.ZERO
					for v in piece:
						centre += v[0]
					centre = centre / piece.size() - n_vox * 0.5 * f
					var on_shape := _on_shape(p, centre, f)
					# a kept wall's face towards the moving surface: its bottom edge (where
					# the padded surface met it) follows that surface
					var follow := not on_shape and p.has("keep_x") and _on_shape(p, centre + n_vox * f, f)
					var lowest := INF
					if follow:
						for v in piece:
							lowest = minf(lowest, v[0].z)
					var parts := [piece]
					if on_shape and p.anchor > 0:
						parts = _split(piece, 2, float(p.anchor))
					for part in parts:
						if part.size() < 3:
							continue
						var pts := []
						for v in part:
							var q: Vector3 = v[0]
							var z: float = q.z
							if on_shape or follow and q.z <= lowest + 0.0001:
								z = _moved(p, q)
							pts.append(Vector3(q.x - half.x, z, half.y - q.y) * vs)
						for m in range(1, part.size() - 1):
							var tri := [0, m, m + 1]
							var a: Vector3 = pts[tri[0]]
							var b: Vector3 = pts[tri[1]]
							var c: Vector3 = pts[tri[2]]
							var cross := (b - a).cross(c - a)
							if cross.length() < 1e-9:
								continue
							var side: int = Mesher.REST
							if block != Vector3.ZERO and g != Mesher.REST:
								side = Mesher._cell_side([a, b, c], n, block)
								if side != Mesher.REST and Parser.is_opaque(mat_index):
									covered[side] += cross.length() * 0.5
							var d: Dictionary = out[side]
							for idx in tri:
								d.v.append(pts[idx])
								d.n.append(-cross.normalized())
								d.c.append(part[idx][1])
								d.u.append(part[idx][2])
								d.u2.append(part[idx][3])
		surfaces.append([out, mat_name, mesh.surface_get_material(s), uv != null])
	mesh.clear_surfaces()
	var ranges := []
	for entry in surfaces:
		var out: Array = entry[0]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var v := PackedVector3Array()
		var n := PackedVector3Array()
		var c := PackedColorArray()
		var u := PackedVector2Array()
		var u2 := PackedVector2Array()
		var bounds := PackedInt32Array([0])
		for d in out:
			v.append_array(d.v)
			n.append_array(d.n)
			c.append_array(d.c)
			u.append_array(d.u)
			u2.append_array(d.u2)
			bounds.append(v.size())
		if v.is_empty():
			continue
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		if entry[3]:
			arrays[Mesh.ARRAY_TEX_UV] = u
		arrays[Mesh.ARRAY_TEX_UV2] = u2
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, entry[2])
		mesh.surface_set_name(mesh.get_surface_count() - 1, entry[1])
		ranges.append(bounds)
	if block != Vector3.ZERO:
		var solid := 0
		for g in 6:
			var area: float = block.x * block.z if g == Mesher.BOTTOM or g == Mesher.TOP else (block.z * block.y if g < 2 else block.x * block.y)
			if covered[g] >= area - 0.001:
				solid |= 1 << g
		mesh.set_meta("face_ranges", ranges)
		mesh.set_meta("solid_faces", solid)


## True if the voxel column at voxel position q belongs to the shape (not the flat
## ground beside a curve, not a kept wall); for a coarse mesh (f > 1) if any column
## of its block does (kept walls: if none does).
static func _on_shape(p: Dictionary, q: Vector3, f: int) -> bool:
	if p.has("keep_x"):
		var keep: PackedByteArray = p.keep_x
		var bx := clampi(int(floor(q.x / f)), 0, p.sx / f - 1) * f
		for x in range(bx, mini(bx + f, p.sx)):
			if keep[x] == 1:
				return false
		return true
	if not p.curve:
		return true
	var bx := clampi(int(floor(q.x / f)), 0, p.sx / f - 1) * f
	var by := clampi(int(floor(q.y / f)), 0, p.sy / f - 1) * f
	var ring: PackedByteArray = p.ring
	for y in range(by, mini(by + f, p.sy)):
		for x in range(bx, mini(bx + f, p.sx)):
			if ring[y * p.sx + x] == 1:
				return true
	return false


## New height (voxels) of a point of the padded block in a column of the shape.
static func _moved(p: Dictionary, q: Vector3) -> float:
	var h := height(p, q.x, q.y)
	var lift: float = p.lift
	var anchor: float = p.anchor
	if q.z >= anchor - 0.0001 or anchor <= 0.0:
		return q.z - lift + h
	# stretched from the ground up to where the anchor goes
	return q.z * maxf(anchor - lift + h, 0.0) / anchor


## Splits every polygon of `polys` at the multiples of f along axis (0 = x, 1 = y).
static func _split_grid(polys: Array, axis: int, f: int) -> Array:
	var out := []
	for poly in polys:
		var lo := INF
		var hi := -INF
		for v in poly:
			lo = minf(lo, v[0][axis])
			hi = maxf(hi, v[0][axis])
		var rest: Array = poly
		var cut := (floorf(lo / f + 0.0001) + 1.0) * f
		while cut < hi - 0.0001:
			var two := _split(rest, axis, cut)
			if two[0].size() >= 3:
				out.append(two[0])
			rest = two[1]
			cut += f
		if rest.size() >= 3:
			out.append(rest)
	return out


## Splits a convex polygon (vertices [position, colour, uv, uv2]) at plane
## position[axis] = value into [below, above]; attributes are interpolated.
static func _split(poly: Array, axis: int, value: float) -> Array:
	var below := []
	var above := []
	for k in poly.size():
		var a: Array = poly[k]
		var b: Array = poly[(k + 1) % poly.size()]
		var da: float = a[0][axis] - value
		var db: float = b[0][axis] - value
		if da <= 0.0001:
			below.append(a)
		if da >= -0.0001:
			above.append(a)
		if (da < -0.0001 and db > 0.0001) or (da > 0.0001 and db < -0.0001):
			var t := da / (da - db)
			var mp: Vector3 = a[0].lerp(b[0], t)
			mp[axis] = value
			var m := [mp, a[1].lerp(b[1], t), a[2].lerp(b[2], t), a[3].lerp(b[3], t)]
			below.append(m)
			above.append(m)
	return [below, above]


## Railing of ground._parapet at (x, y) on a parapet starting at height o: a post
## (if `post`) and the top rail.
static func _railing(g: Grid, x: int, y: int, o: int, post: bool) -> void:
	if post:
		for z in range(o + WALK + 4, o + WALK + 8):
			g.put(x, y, z, "metaal2")
	g.put(x, y, o + WALK + 8, "metaal3")


## Dense voxel grid on top of a source vox: copy its columns, set named colours or
## random mixes (pick() of tools/voxgen/vox.py), then turn it back into a vox.
class Grid:
	var src
	var size: Vector3i
	var cells := PackedByteArray()   # palette slot per voxel, 0 = empty
	var source := {}                 # Vector2i column -> PackedByteArray of the source slots
	var palette: PackedColorArray
	var materials: PackedByteArray
	var slots := {}                  # colour name -> palette slot
	var free: Array[int] = []

	func _init(vox, grid_size: Vector3i) -> void:
		src = vox
		size = grid_size
		cells.resize(size.x * size.y * size.z)
		palette = vox.palette.duplicate()
		materials = vox.materials.duplicate()
		var used := {}
		var v: PackedByteArray = vox.voxels
		for k in range(0, v.size(), 4):
			used[v[k + 3]] = true
			var c := Vector2i(v[k], v[k + 1])
			if not source.has(c):
				var column := PackedByteArray()
				column.resize(vox.size.z)
				source[c] = column
			source[c][v[k + 2]] = v[k + 3]
		for s in range(Parser.WATER_START - 1, 0, -1):
			if not used.has(s):
				free.append(s)

	## Sets voxel (x, y, z) to palette slot `slot` (0 = empty); ignored outside the grid.
	func set_slot(x: int, y: int, z: int, slot: int) -> void:
		if x >= 0 and y >= 0 and z >= 0 and x < size.x and y < size.y and z < size.z:
			cells[(z * size.y + y) * size.x + x] = slot

	## Sets voxel (x, y, z) to colour `name` of COLOURS ("" = empty).
	func put(x: int, y: int, z: int, name: String) -> void:
		set_slot(x, y, z, _slot_of(name))

	## Sets voxel (x, y, z) to one colour of a mix ([names, weights, seed]), chosen per voxel.
	func mix(x: int, y: int, z: int, m: Array) -> void:
		set_slot(x, y, z, _slot_of(pick(m, x, y, z)))

	## Copies source column (x, y) raised by o; voxels with colour `replace` become `with`.
	func copy_column(x: int, y: int, o: int, replace := Color(-1, -1, -1), with := []) -> void:
		var column = source.get(Vector2i(x, y))
		if column == null:
			return
		for z in column.size():
			var s: int = column[z]
			if s == 0:
				continue
			if not with.is_empty() and palette[s].to_html(false) == replace.to_html(false):
				mix(x, y, z + o, with)
			else:
				set_slot(x, y, z + o, s)

	## pick() of tools/voxgen/vox.py: a deterministic choice from a mix for a voxel.
	static func pick(m: Array, x: int, y: int, z: int) -> String:
		var names: Array = m[0]
		var weights: Array = m[1]
		var r := hash01(x, y, z, m[2])
		if weights.is_empty():
			return names[int(r * names.size()) % names.size()]
		var total := 0.0
		for w in weights:
			total += w
		var acc := 0.0
		for k in names.size():
			acc += weights[k] / total
			if r < acc:
				return names[k]
		return names[-1]

	## h() of tools/voxgen/vox.py: deterministic hash of (x, y, z, seed) in [0, 1).
	static func hash01(x: int, y: int, z: int, seed: int) -> float:
		var n := (x * 374761393 + y * 668265263 + z * 2147483647 + seed * 974634281) & 0xFFFFFFFF
		n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
		n = n ^ (n >> 16)
		return float(n & 0xFFFFFF) / float(0x1000000)

	func _slot_of(name: String) -> int:
		if not slots.has(name):
			var s: int = free.pop_front()
			palette[s] = COLOURS[name][0]
			materials[s] = COLOURS[name][1]
			slots[name] = s
		return slots[name]

	func to_vox():
		var out = Parser.new()
		out.size = size
		out.palette = palette
		out.materials = materials
		var v := PackedByteArray()
		for z in size.z:
			for y in size.y:
				for x in size.x:
					var s := cells[(z * size.y + y) * size.x + x]
					if s != 0:
						v.append_array(PackedByteArray([x, y, z, s]))
		out.voxels = v
		return out
