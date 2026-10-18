@tool
extends RefCounted
## Zet een geparsed .vox model om naar een ArrayMesh met greedy meshing,
## vertex-kleuren en ingebakken ambient occlusion.
##
## Assen: MagicaVoxel (x, y, z-omhoog) -> Godot (x, z, -y).
## Oorsprong: midden van het model in x/z, onderkant in y.

const Parser = preload("res://addons/vox_tiles/vox_parser.gd")

const MATERIAL_PATHS := [
	"res://addons/vox_tiles/materials/voxel_opaque.tres",
	"res://addons/vox_tiles/materials/voxel_metal.tres",
	"res://addons/vox_tiles/materials/voxel_glass.tres",
	"res://addons/vox_tiles/materials/voxel_emit.tres",
	"res://addons/vox_tiles/materials/voxel_water.tres",
	"res://addons/vox_tiles/materials/voxel_vlag.tres",
]

const AO_CURVE := [0.34, 0.56, 0.79, 1.0]


## kleur_tolerantie > 0: kleuren die minder dan zoveel (0..255 per kanaal) verschillen
## worden samengevoegd tot grotere vlakken (voor de grove LOD-versie).
static func build(vox, voxel_size: float, use_ao: bool, kleur_tolerantie := 0) -> ArrayMesh:
	var sx: int = vox.size.x
	var sy: int = vox.size.y
	var sz: int = vox.size.z
	# volume met 1 voxel rand zodat we nooit buiten de array lezen
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
	# opaque lookup per kleurindex
	var opaque := PackedByteArray()
	opaque.resize(256)
	for c in range(1, 256):
		opaque[c] = 1 if (mats[c] != Parser.MAT_GLASS and mats[c] != Parser.MAT_WATER) else 0

	var lin := PackedColorArray()
	lin.resize(256)
	for c in 256:
		lin[c] = vox.palette[c].srgb_to_linear()
	# kleurgroepen: elke kleur verwijst naar een representant; die krijgt de gemiddelde kleur
	var groep := PackedByteArray()
	groep.resize(256)
	for c in 256:
		groep[c] = c
	if kleur_tolerantie > 0:
		var gebruikt := {}
		for i in range(3, vx.size(), 4):
			gebruikt[vx[i]] = true
		var reps := []
		var som := {}
		var tol := kleur_tolerantie / 255.0
		for c in gebruikt.keys():
			var col: Color = vox.palette[c]
			var gevonden := -1
			for r in reps:
				var rc: Color = vox.palette[r]
				if mats[r] == mats[c] and absf(rc.r - col.r) <= tol and absf(rc.g - col.g) <= tol and absf(rc.b - col.b) <= tol:
					gevonden = r
					break
			if gevonden < 0:
				reps.append(c)
				gevonden = c
				som[c] = [Color(0, 0, 0), 0]
			groep[c] = gevonden
			som[gevonden][0] += col
			som[gevonden][1] += 1
		for r in reps:
			var gem: Color = som[r][0] / float(som[r][1])
			lin[r] = Color(gem.r, gem.g, gem.b).srgb_to_linear()

	var dims := [sx, sy, sz]
	var strides := [1, SX, SX * SY]
	var surf := []
	for m in MATERIAL_PATHS.size():
		surf.append({"v": [], "n": [], "c": []})

	var center := Vector3(sx * 0.5, sy * 0.5, 0.0)
	var base0 := 1 + SX + SX * SY

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
						var cg: int = groep[c]
						var nidx: int = idx + sgn * sa
						var n: int = vol[nidx]
						var vis := false
						if n == 0:
							vis = true
							# water-zijkanten aan de rand van het model niet tekenen
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
							# 4 hoeken: (u-,v-), (u+,v-), (u+,v+), (u-,v+)
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
				# greedy samenvoegen
				for jv in dv:
					var ju := 0
					while ju < du:
						var key: int = mask[ju + jv * du]
						if key == 0:
							ju += 1
							continue
						var w := 1
						# water niet samenvoegen: een fijn raster laat de golf-shader het oppervlak vervormen
						var los: bool = mats[key & 0xFF] == Parser.MAT_WATER
						while not los and ju + w < du and mask[ju + w + jv * du] == key:
							w += 1
						var hgt := 1
						var done := los
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
						_emit_quad(surf, key, a, u, v, sgn, i, ju, jv, w, hgt, lin, mats, center, voxel_size, normal_vox)
						ju += w

	var mesh := ArrayMesh.new()
	for m in MATERIAL_PATHS.size():
		var s: Dictionary = surf[m]
		if s.v.size() == 0:
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(s.v)
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(s.n)
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray(s.c)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat = load(MATERIAL_PATHS[m])
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
		mesh.surface_set_name(mesh.get_surface_count() - 1, ["opaque", "metal", "glass", "emit", "water", "vlag"][m])
	return mesh


## Maakt een grovere versie van het model: elk blok van f x f x f voxels wordt één voxel
## (meest voorkomende kleur van de gevulde voxels; leeg als alles leeg is).
static func verklein(vox, f: int):
	var uit = Parser.new()
	uit.palette = vox.palette
	uit.materials = vox.materials
	var sx: int = vox.size.x
	var sy: int = vox.size.y
	var sz: int = vox.size.z
	var nx := ceili(sx / float(f))
	var ny := ceili(sy / float(f))
	var nz := ceili(sz / float(f))
	uit.size = Vector3i(nx, ny, nz)
	var tel := {}
	var vx: PackedByteArray = vox.voxels
	for i in range(0, vx.size(), 4):
		var k := Vector3i(vx[i] / f, vx[i + 1] / f, vx[i + 2] / f)
		var d: Dictionary = tel.get(k, {})
		d[vx[i + 3]] = d.get(vx[i + 3], 0) + 1
		tel[k] = d
	var uv := PackedByteArray()
	for k in tel:
		var d: Dictionary = tel[k]
		var beste := 0
		var n := -1
		for c in d:
			if d[c] > n:
				n = d[c]
				beste = c
		uv.append(k.x)
		uv.append(k.y)
		uv.append(k.z)
		uv.append(beste)
	uit.voxels = uv
	return uit


static func _ao(s1: int, s2: int, c: int) -> int:
	if s1 == 1 and s2 == 1:
		return 0
	return 3 - (s1 + s2 + c)


static func _to_godot(p: Vector3, center: Vector3, vs: float) -> Vector3:
	return Vector3(p.x - center.x, p.z, -(p.y - center.y)) * vs


static func _emit_quad(surf: Array, key: int, a: int, u: int, v: int, sgn: int, i: int,
		ju: int, jv: int, w: int, hgt: int, lin: PackedColorArray, mats: PackedByteArray,
		center: Vector3, vs: float, normal_vox: Vector3) -> void:
	var c := key & 0xFF
	var ao := [(key >> 8) & 3, (key >> 10) & 3, (key >> 12) & 3, (key >> 14) & 3]
	var plane := float(i + (1 if sgn > 0 else 0))
	var corners := [Vector2(ju, jv), Vector2(ju + w, jv), Vector2(ju + w, jv + hgt), Vector2(ju, jv + hgt)]
	var pts := []
	for k in 4:
		var p := Vector3.ZERO
		p[a] = plane
		p[u] = corners[k].x
		p[v] = corners[k].y
		pts.append(_to_godot(p, center, vs))
	var n := Vector3(normal_vox.x, normal_vox.z, -normal_vox.y)
	var base: Color = lin[c]
	var cols := []
	for k in 4:
		var f: float = AO_CURVE[ao[k]]
		cols.append(Color(base.r * f, base.g * f, base.b * f, 1.0))
	var tris: Array
	if ao[0] + ao[2] < ao[1] + ao[3]:
		tris = [[0, 1, 3], [1, 2, 3]]
	else:
		tris = [[0, 1, 2], [0, 2, 3]]
	var s: Dictionary = surf[mats[c]]
	for t in tris:
		var p0: Vector3 = pts[t[0]]
		var p1: Vector3 = pts[t[1]]
		var p2: Vector3 = pts[t[2]]
		var order := [t[0], t[1], t[2]]
		# Godot gebruikt clockwise front faces: kruisproduct moet van de normaal af wijzen
		if (p1 - p0).cross(p2 - p0).dot(n) > 0.0:
			order = [t[0], t[2], t[1]]
		for k in order:
			s.v.append(pts[k])
			s.n.append(n)
			s.c.append(cols[k])
