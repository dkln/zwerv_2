@tool
extends RefCounted
## Turns a parsed .vox model into an ArrayMesh with greedy meshing,
## vertex colours and baked ambient occlusion.
##
## Per axis and direction, every slice of voxels gets a mask of visible faces
## (keyed by colour group + the AO of the 4 corners); equal neighbours in the
## mask are merged into rectangles (greedy meshing), which become two triangles.
## There is one surface per material (Parser.MAT_*), with the triangles sorted
## into the 7 GROUPS so scripts/layer_baker.gd can drop hidden cell sides.
##
## Axes: MagicaVoxel (x, y, z-up) -> Godot (x, z, -y).
## Origin: centre of the model in x/z, bottom in y.

const Parser = preload("res://addons/vox_tiles/vox_parser.gd")

## indexed by Parser.MAT_*
const MATERIAL_PATHS := [
	"res://addons/vox_tiles/materials/voxel_opaque.tres",
	"res://addons/vox_tiles/materials/voxel_metal.tres",
	"res://addons/vox_tiles/materials/voxel_glass.tres",
	"res://addons/vox_tiles/materials/voxel_emit.tres",
	"res://addons/vox_tiles/materials/voxel_water.tres",
	"res://addons/vox_tiles/materials/voxel_vlag.tres",
	"res://addons/vox_tiles/materials/voxel_paneel.tres",
	"res://addons/vox_tiles/materials/voxel_asfalt.tres",
	"res://addons/vox_tiles/materials/voxel_steen.tres",
	"res://addons/vox_tiles/materials/voxel_baksteen.tres",
	"res://addons/vox_tiles/materials/voxel_grind.tres",
	"res://addons/vox_tiles/materials/voxel_gelakt.tres",
]

const WIND_MATERIAL := "res://addons/vox_tiles/materials/voxel_wind.tres"
const FLOAT_MATERIAL := "res://addons/vox_tiles/materials/voxel_drijf.tres"
## floating ground tiles (water with plants): only what lies above the water bobs
const FLOAT_PLANT_MATERIAL := "res://addons/vox_tiles/materials/voxel_drijf_plant.tres"

const AO_CURVE := [0.34, 0.56, 0.79, 1.0]

## triangle groups: the 6 sides of the cell (+x, -x, top, bottom, +z, -z) and the rest
const GROUPS := 7
const TOP := 2
const BOTTOM := 3
const REST := 6
const DIRECTIONS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


## color_tolerance > 0: colours that differ less than this (0..255 per channel)
## are merged into larger faces (for the coarse LOD version).
## animation: "" (none), "wind" (sways in the wind) or "float" (bobs on the water).
## block: size of the grid cell (e.g. 4x3x4). Triangles are then grouped per side
## of that cell (meta "face_ranges" and "solid_faces"), so merging
## (scripts/layer_baker.gd) can drop faces that lie against a neighbouring block.
## textured: faces are merged by material and AO only, regardless of colour; the colour
## of every voxel goes into a small texture per tile (meta "albedo", an Image; UV points
## into it) and the vertex colour only carries the AO. library_builder.gd packs these
## textures into one atlas per library. Without it the colour is in the vertex colours.
## UV2 always holds tile-local voxel coordinates for the relief shaders (_face_uv).
static func build(vox, voxel_size: float, use_ao: bool, color_tolerance := 0, animation := "", block := Vector3.ZERO, textured := false) -> ArrayMesh:
	var sx: int = vox.size.x
	var sy: int = vox.size.y
	var sz: int = vox.size.z
	# volume with a 1 voxel border so we never read outside the array
	var SX := sx + 2
	var SY := sy + 2
	var SZ := sz + 2
	var vol := PackedByteArray()
	vol.resize(SX * SY * SZ)
	var vx: PackedByteArray = vox.voxels
	for i in range(0, vx.size(), 4):
		var x := vx[i]
		var y := vx[i + 1]
		var z := vx[i + 2]
		if x < sx and y < sy and z < sz:
			vol[(x + 1) + (y + 1) * SX + (z + 1) * SX * SY] = vx[i + 3]

	var mats: PackedByteArray = vox.materials
	# opaque lookup per colour index
	var opaque := PackedByteArray()
	opaque.resize(256)
	for c in range(1, 256):
		opaque[c] = 1 if Parser.is_opaque(mats[c]) else 0

	var lin := PackedColorArray()
	lin.resize(256)
	for c in 256:
		lin[c] = vox.palette[c].srgb_to_linear()
	# colour groups: every colour points to a representative, which gets the average colour
	var group := PackedByteArray()
	group.resize(256)
	for c in 256:
		group[c] = c
	if color_tolerance > 0:
		var used := {}
		for i in range(3, vx.size(), 4):
			used[vx[i]] = true
		var reps := []
		var sums := {}
		var tol := color_tolerance / 255.0
		for c in used.keys():
			var col: Color = vox.palette[c]
			var found := -1
			for r in reps:
				var rc: Color = vox.palette[r]
				if mats[r] == mats[c] and absf(rc.r - col.r) <= tol and absf(rc.g - col.g) <= tol and absf(rc.b - col.b) <= tol:
					found = r
					break
			if found < 0:
				reps.append(c)
				found = c
				sums[c] = [Color(0, 0, 0), 0]
			group[c] = found
			sums[found][0] += col
			sums[found][1] += 1
		for r in reps:
			var avg: Color = sums[r][0] / float(sums[r][1])
			lin[r] = Color(avg.r, avg.g, avg.b).srgb_to_linear()

	var dims := [sx, sy, sz]
	var strides := [1, SX, SX * SY]
	var surf := []
	for m in MATERIAL_PATHS.size():
		var groups := []
		for g in GROUPS:
			groups.append({"v": [], "n": [], "c": [], "u": [], "u2": []})
		surf.append(groups)
	var covered := PackedFloat32Array()
	covered.resize(GROUPS)

	var center := Vector3(sx * 0.5, sy * 0.5, 0.0)
	var base0 := 1 + SX + SX * SY
	var quads := []   # textured: [key, a, sgn, i, ju, jv, w, hgt, texel colours] per merged face

	for a in 3:
		var u := (a + 1) % 3
		var v := (a + 2) % 3
		var du: int = dims[u]
		var dv: int = dims[v]
		var da: int = dims[a]
		var sa: int = strides[a]
		var su: int = strides[u]
		var sv: int = strides[v]
		for sgn in [1, -1]:
			var mask := PackedInt32Array()
			mask.resize(du * dv)
			var normal_vox := Vector3.ZERO
			normal_vox[a] = sgn
			for i in da:
				mask.fill(0)
				var any := false
				for jv in dv:
					for ju in du:
						var idx: int = base0 + i * sa + ju * su + jv * sv
						var c: int = vol[idx]
						if c == 0:
							continue
						var cg: int = (mats[c] + 1) if textured else group[c]
						var nidx: int = idx + sgn * sa
						var n: int = vol[nidx]
						var vis := false
						if n == 0:
							vis = true
							# don't draw water sides at the edge of the model
							if mats[c] == Parser.MAT_WATER and a != 2:
								var na: int = i + sgn
								if na < 0 or na >= da:
									vis = false
						elif opaque[c] == 1:
							vis = opaque[n] == 0
						else:
							vis = opaque[n] == 0 and mats[n] != mats[c]
						if not vis:
							continue
						var key := cg
						if use_ao and mats[c] != Parser.MAT_EMIT and mats[c] != Parser.MAT_FLAG and opaque[c] == 1:
							# 4 corners: (u-,v-), (u+,v-), (u+,v+), (u-,v+)
							var b := nidx
							var um: int = opaque[vol[b - su]]
							var up: int = opaque[vol[b + su]]
							var vm: int = opaque[vol[b - sv]]
							var vp: int = opaque[vol[b + sv]]
							var a0 := _ao(um, vm, opaque[vol[b - su - sv]])
							var a1 := _ao(up, vm, opaque[vol[b + su - sv]])
							var a2 := _ao(up, vp, opaque[vol[b + su + sv]])
							var a3 := _ao(um, vp, opaque[vol[b - su + sv]])
							key |= (a0 << 8) | (a1 << 10) | (a2 << 12) | (a3 << 14)
						else:
							key |= (3 << 8) | (3 << 10) | (3 << 12) | (3 << 14)
						mask[ju + jv * du] = key
						any = true
				if not any:
					continue
				# greedy merge
				for jv in dv:
					var ju := 0
					while ju < du:
						var key: int = mask[ju + jv * du]
						if key == 0:
							ju += 1
							continue
						var w := 1
						# don't merge water: a fine grid lets the wave shader deform the surface
						var single: bool = _key_material(key, mats, textured) == Parser.MAT_WATER
						while not single and ju + w < du and mask[ju + w + jv * du] == key:
							w += 1
						var hgt := 1
						var done := single
						while jv + hgt < dv and not done:
							for k in w:
								if mask[ju + k + (jv + hgt) * du] != key:
									done = true
									break
							if not done:
								hgt += 1
						for yy in hgt:
							for k in w:
								mask[ju + k + (jv + yy) * du] = 0
						if textured:
							var texels := PackedColorArray()
							for yy in hgt:
								for k in w:
									texels.append(vox.palette[vol[base0 + i * sa + (ju + k) * su + (jv + yy) * sv]])
							quads.append([key, a, sgn, i, ju, jv, w, hgt, texels])
						else:
							_emit_quad(surf, key, a, u, v, sgn, i, ju, jv, w, hgt, lin, mats, center, voxel_size, normal_vox, block, covered)
						ju += w

	var mesh := ArrayMesh.new()
	if textured:
		mesh.set_meta("albedo", _pack_texels(quads, surf, mats, center, voxel_size, block, covered))
	var face_ranges := []
	for m in MATERIAL_PATHS.size():
		var s := {"v": [], "n": [], "c": [], "u": [], "u2": []}
		var bounds := PackedInt32Array([0])
		for g in GROUPS:
			var d: Dictionary = surf[m][g]
			s.v.append_array(d.v)
			s.n.append_array(d.n)
			s.c.append_array(d.c)
			s.u.append_array(d.u)
			s.u2.append_array(d.u2)
			bounds.append(s.v.size())
		if s.v.size() == 0:
			continue
		face_ranges.append(bounds)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(s.v)
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(s.n)
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray(s.c)
		if textured:
			arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(s.u)
		arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array(s.u2)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var path: String = MATERIAL_PATHS[m]
		if animation == "float" and Parser.is_opaque(m) and m != Parser.MAT_EMIT:
			path = FLOAT_MATERIAL if block == Vector3.ZERO else FLOAT_PLANT_MATERIAL
		elif animation == "wind" and m == Parser.MAT_OPAQUE:
			path = WIND_MATERIAL
		var mat = load(path)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
		mesh.surface_set_name(mesh.get_surface_count() - 1, Parser.MATERIAL_NAMES[m])
	if block != Vector3.ZERO:
		# sides that are completely closed (opaque) hide the side of the neighbouring cell
		var solid := 0
		for g in 6:
			var area: float = block.x * block.z if g == BOTTOM or g == TOP else (block.z * block.y if g < 2 else block.x * block.y)
			if covered[g] >= area - 0.001:
				solid |= 1 << g
		mesh.set_meta("face_ranges", face_ranges)
		mesh.set_meta("solid_faces", solid)
	return mesh


## Makes a coarser version of the model: every block of f x f x f voxels becomes one voxel
## (most common colour of the filled voxels; empty if all are empty).
static func downscale(vox, f: int):
	var out = Parser.new()
	out.palette = vox.palette
	out.materials = vox.materials
	var sx: int = vox.size.x
	var sy: int = vox.size.y
	var sz: int = vox.size.z
	var nx := ceili(sx / float(f))
	var ny := ceili(sy / float(f))
	var nz := ceili(sz / float(f))
	out.size = Vector3i(nx, ny, nz)
	# only the top layer of each block counts: what you see from above
	# (asphalt, grass) wins over the ground layer below
	var counts := {}
	var top := {}
	var vx: PackedByteArray = vox.voxels
	for i in range(0, vx.size(), 4):
		var k := Vector3i(vx[i] / f, vx[i + 1] / f, vx[i + 2] / f)
		var z: int = vx[i + 2]
		if z > top.get(k, -1):
			top[k] = z
			counts[k] = {}
		elif z < top[k]:
			continue
		var d: Dictionary = counts[k]
		d[vx[i + 3]] = d.get(vx[i + 3], 0) + 1
	var uv := PackedByteArray()
	for k in counts:
		var d: Dictionary = counts[k]
		var best := 0
		var n := -1
		for c in d:
			if d[c] > n:
				n = d[c]
				best = c
		uv.append(k.x)
		uv.append(k.y)
		uv.append(k.z)
		uv.append(best)
	out.voxels = uv
	return out


## Material of a greedy-mesh key: textured keys store material + 1, others a colour.
static func _key_material(key: int, mats: PackedByteArray, textured: bool) -> int:
	return (key & 0xFF) - 1 if textured else mats[key & 0xFF]


## Textured mode: packs the texels of all merged faces into one image (rows of
## rectangles, tallest first, each with a 1-texel border copied from its edge so
## filtering and mipmaps don't bleed the neighbours in), then emits the faces with
## UVs into it. Returns the image (sRGB colours, RGBA8).
static func _pack_texels(quads: Array, surf: Array, mats: PackedByteArray, center: Vector3, vs: float,
		block: Vector3, covered: PackedFloat32Array) -> Image:
	var order := range(quads.size())
	order.sort_custom(func(p, q): return quads[p][7] > quads[q][7])
	var area := 0
	var widest := 0
	for q in quads:
		area += (q[6] + 2) * (q[7] + 2)
		widest = maxi(widest, q[6] + 2)
	# rows about as wide as the square root of the area (but never narrower than a face)
	var width := maxi(widest, ceili(sqrt(area * 1.15)))
	var pos := []   # texel position (inside the border) per quad
	pos.resize(quads.size())
	var x := 0
	var y := 0
	var row := 0
	for k in order:
		var w: int = quads[k][6] + 2
		var h: int = quads[k][7] + 2
		if x + w > width:
			x = 0
			y += row
			row = 0
		pos[k] = Vector2i(x + 1, y + 1)
		x += w
		row = maxi(row, h)
	# exact size, no power of two: the library atlas packs these images tightly
	var used_width := 0
	for k in order:
		used_width = maxi(used_width, pos[k].x - 1 + quads[k][6] + 2)
	var img := Image.create(maxi(used_width, 1), maxi(y + row, 1), false, Image.FORMAT_RGBA8)
	width = img.get_width()
	for k in quads.size():
		var q: Array = quads[k]
		var w: int = q[6]
		var h: int = q[7]
		var texels: PackedColorArray = q[8]
		var p: Vector2i = pos[k]
		for ty in range(-1, h + 1):
			for tx in range(-1, w + 1):
				img.set_pixel(p.x + tx, p.y + ty, texels[clampi(ty, 0, h - 1) * w + clampi(tx, 0, w - 1)])
		var a: int = q[1]
		var normal_vox := Vector3.ZERO
		normal_vox[a] = q[2]
		var uv_rect := Rect2(Vector2(p) / Vector2(width, img.get_height()), Vector2(w, h) / Vector2(width, img.get_height()))
		_emit_quad(surf, q[0], a, (a + 1) % 3, (a + 2) % 3, q[2], q[3], q[4], q[5], w, h, PackedColorArray(), mats,
			center, vs, normal_vox, block, covered, uv_rect)
	return img


## Ambient occlusion level (0 = darkest, 3 = none) of a face corner from its two
## side neighbours and the diagonal neighbour (1 = opaque voxel there).
static func _ao(s1: int, s2: int, c: int) -> int:
	if s1 == 1 and s2 == 1:
		return 0
	return 3 - (s1 + s2 + c)


## Which side of the cell does this face lie on (entirely within that side's rectangle)?
static func _cell_side(pts: Array, n: Vector3, block: Vector3) -> int:
	var half := Vector3(block.x * 0.5, block.y, block.z * 0.5)
	var lo := Vector3(-half.x, 0.0, -half.z)
	var g := -1
	for k in 6:
		if n.is_equal_approx(Vector3(DIRECTIONS[k])):
			g = k
	if g < 0:
		return REST
	var p0: Vector3 = pts[0]
	var plane_pos: float = [half.x, lo.x, half.y, lo.y, half.z, lo.z][g]
	var as_: int = [0, 0, 1, 1, 2, 2][g]
	if absf(p0[as_] - plane_pos) > 0.001:
		return REST
	for p in pts:
		for k in 3:
			if p[k] < lo[k] - 0.001 or p[k] > half[k] + 0.001:
				return REST
	return g


## UV of a face corner: tile-local voxel coordinates in the plane of the face, in
## MagicaVoxel axes, so shaders can follow patterns the generator draws per voxel.
## Upward/downward faces get (x, y); side faces get (x + y, z), the same "along the
## wall" coordinate the generator's brick bond uses on both wall orientations. The
## coordinate across the face is that of the voxel itself (slice i), not of the face plane.
static func _face_uv(p: Vector3, a: int, i: int) -> Vector2:
	var q := p
	q[a] = float(i)
	return Vector2(q.x, q.y) if a == 2 else Vector2(q.x + q.y, q.z)


## MagicaVoxel voxel coordinates -> Godot metres, centred in x/z, bottom at y = 0.
static func _to_godot(p: Vector3, center: Vector3, vs: float) -> Vector3:
	return Vector3(p.x - center.x, p.z, -(p.y - center.y)) * vs


## Adds one merged rectangle (w x hgt voxels on slice i along axis a) as two
## triangles to the surface of its material, in the group of the cell side it
## lies on. key = colour index | AO of the 4 corners (2 bits each, from bit 8).
## Also adds the area of opaque faces to covered[side] for the "solid_faces" meta.
static func _emit_quad(surf: Array, key: int, a: int, u: int, v: int, sgn: int, i: int,
		ju: int, jv: int, w: int, hgt: int, lin: PackedColorArray, mats: PackedByteArray,
		center: Vector3, vs: float, normal_vox: Vector3, block := Vector3.ZERO, covered := PackedFloat32Array(),
		uv_rect := Rect2()) -> void:
	var textured := uv_rect.size != Vector2.ZERO
	var c := key & 0xFF
	var mat: int = c - 1 if textured else mats[c]
	var ao := [(key >> 8) & 3, (key >> 10) & 3, (key >> 12) & 3, (key >> 14) & 3]
	var plane := float(i + (1 if sgn > 0 else 0))
	var corners := [Vector2(ju, jv), Vector2(ju + w, jv), Vector2(ju + w, jv + hgt), Vector2(ju, jv + hgt)]
	var pts := []
	var uvs := []
	var uv2s := []
	for k in 4:
		var p := Vector3.ZERO
		p[a] = plane
		p[u] = corners[k].x
		p[v] = corners[k].y
		pts.append(_to_godot(p, center, vs))
		uv2s.append(_face_uv(p, a, i))
		# texture: corner k of the face = corner of its texel rectangle (u right, v down)
		uvs.append(uv_rect.position + uv_rect.size * (corners[k] - corners[0]) / Vector2(w, hgt))
	var n := Vector3(normal_vox.x, normal_vox.z, -normal_vox.y)
	var base: Color = Color.WHITE if textured else lin[c]
	var cols := []
	for k in 4:
		var f: float = AO_CURVE[ao[k]]
		cols.append(Color(base.r * f, base.g * f, base.b * f, 1.0))
	var tris: Array
	if ao[0] + ao[2] < ao[1] + ao[3]:
		tris = [[0, 1, 3], [1, 2, 3]]
	else:
		tris = [[0, 1, 2], [0, 2, 3]]
	var side := REST
	if block != Vector3.ZERO:
		side = _cell_side(pts, n, block)
		if side != REST and Parser.is_opaque(mat):
			covered[side] += w * hgt * vs * vs
	var s: Dictionary = surf[mat][side]
	for t in tris:
		var p0: Vector3 = pts[t[0]]
		var p1: Vector3 = pts[t[1]]
		var p2: Vector3 = pts[t[2]]
		var order := [t[0], t[1], t[2]]
		# Godot uses clockwise front faces: the cross product must point away from the normal
		if (p1 - p0).cross(p2 - p0).dot(n) > 0.0:
			order = [t[0], t[2], t[1]]
		for k in order:
			s.v.append(pts[k])
			s.n.append(n)
			s.c.append(cols[k])
			s.u.append(uvs[k])
			s.u2.append(uv2s[k])
