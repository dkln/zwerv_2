extends RefCounted
## Merges the tiles of a GridMap into large meshes ("baking"), used by
## level_of_detail.gd at startup for the Grond and Gebouwen layers.
##
## Cells are grouped into CHUNK x CHUNK chunks; each chunk becomes one MeshInstance3D
## with one surface per material, so there are far fewer draw calls. Faces that lie
## against a solid face of a neighbour cell are left out, as are all bottom faces, so
## there are also fewer triangles. This relies on the importer grouping each
## surface's triangles per cell face (mesh meta "face_ranges" and "solid_faces", see
## vox_mesher.gd). Tiles whose shaders work in mesh-local coordinates (flag, wind,
## floating) cannot be merged and are added as separate MeshInstance3Ds.
## On the lowest row of cells, the low triangles of shadow-casting tiles (water, banks,
## floors: lower than LOW_SHADOW above the tile's bottom) go into chunks without shadow;
## a ditch or quay then only casts the shadow of its reeds or wall.
##
## The work is spread over frames (BUDGET_USEC per frame), so `bake` must be awaited.
##
## Extra layers (the Details GridMap: balconies, awnings, signs on the facades) can be
## baked into the same chunks: no separate layer to draw, and fewer draw calls. With
## owners on (always with extra layers) every vertex carries the centre of the cell it
## belongs to in CUSTOM0: its own cell, or for an extra layer the main-layer cell it
## hangs on. The see-through buildings (scripts/world/building_fade.gd,
## voxel_fade.gdshaderinc) fade by that cell, so parts that stick out of their cell (bay
## windows, shop fronts, awnings, signs) fade with their own building. Packed in 4 bytes
## (RGBA8): world x and z in whole metres, each + 32768 as 16 bits (low byte first).

const Mesher = preload("res://addons/vox_tiles/importer/vox_mesher.gd")
const Model = preload("res://addons/vox_tiles/importer/voxel_model.gd")

## Materials whose shaders compute in mesh-local coordinates: tiles using them stay separate.
const LOCAL_MATERIALS := [
	Mesher.MATERIAL_PATHS[Model.MAT_FLAG],
	Mesher.WIND_MATERIAL,
	Mesher.FLOWER_MATERIAL,
	Mesher.FLOAT_MATERIAL,
	Mesher.FLOAT_PLANT_MATERIAL,
]

## Chunk size in cells (along x and z).
const CHUNK := 8
## Triangles lower than this (metres above the bottom of their tile, on the lowest row of
## cells) cast no shadow; the same height as SHADOW_MIN_HEIGHT in library_builder.gd.
const LOW_SHADOW := 0.7
## Bump when the output changes (invalidates the cache in user://merged).
const VERSION := 9
## Metres around an extra layer's cell centre searched for the main-layer cell it hangs on.
const OWNER_REACH := 1.0
## Compute time per frame in microseconds; the rest continues in following frames.
const BUDGET_USEC := 6000


## Bakes the GridMap `gm`, rendered with `lib` (the normal library or one of its LOD
## copies with the same item IDs), into a new Node3D called `name` with the GridMap's
## transform. hide_tops: top faces may also be dropped when a solid cell sits on top
## (for layers whose tiles are as tall as the cell). progress (optional) is called with
## the fraction done (0..1) whenever the work pauses for a frame. extras: [GridMap,
## MeshLibrary] pairs of layers baked into the same chunks (see the top). Coroutine:
## await it. Returns null if `gm` is freed before it is done. owners: see the top.
static func bake(gm: GridMap, lib: MeshLibrary, name: String, hide_tops: bool, progress := Callable(), extras := [], owners := false) -> Node3D:
	owners = owners or not extras.is_empty()
	var out := Node3D.new()
	out.name = name
	out.transform = gm.transform
	var cache := {}   # mesh -> [{mat, groups: [[v, n, c, uv, uv2] x Mesher.GROUPS]}]
	var chunks := {}  # Vector3i(chunk x, chunk z, cast shadow) -> {material: [v, n, c, uv, uv2]}
	var shadow := {}  # item -> cast shadow setting
	var loose := []   # [mesh, transform] of tiles that stay a separate mesh
	var basis_cache := {}  # orthogonal index -> Basis
	var start := Time.get_ticks_usec()
	var counter := 0
	var cells := gm.get_used_cells()
	var ground_row := 0x7fffffff
	for c: Vector3i in cells:
		ground_row = mini(ground_row, c.y)
	for c: Vector3i in cells:
		counter += 1
		if counter % 64 == 0 and Time.get_ticks_usec() - start > BUDGET_USEC:
			# collecting the cells is most of the work; building the chunks the last 10%
			if progress.is_valid():
				progress.call(0.9 * counter / cells.size())
			await Engine.get_main_loop().process_frame
			if not is_instance_valid(gm):
				out.free()   # the layer was freed meanwhile (another map part loaded)
				return null
			start = Time.get_ticks_usec()
		var id := gm.get_cell_item(c)
		var mesh := lib.get_item_mesh(id) as ArrayMesh
		if mesh == null:
			continue
		var b := _basis(gm, gm.get_cell_item_orientation(c), basis_cache)
		var xf := Transform3D(b, gm.map_to_local(c)) * lib.get_item_mesh_transform(id)
		if not cache.has(mesh):
			cache[mesh] = _split(mesh)
		var parts: Array = cache[mesh]
		if parts.is_empty():
			loose.append([mesh, xf])
			continue
		# which faces are hidden? bit g = face group g (Mesher.DIRECTIONS, in mesh space)
		var hidden: int = 1 << Mesher.BOTTOM
		if mesh.has_meta("face_ranges"):
			for g in 6:
				if g == Mesher.BOTTOM or (g == Mesher.TOP and not hide_tops):
					continue
				# face direction in grid space -> neighbour cell
				var w := Vector3i((b * Vector3(Mesher.DIRECTIONS[g])).round())
				var neighbour := c + w
				var nid := gm.get_cell_item(neighbour)
				if nid < 0:
					continue
				var nm := lib.get_item_mesh(nid)
				if nm == null or not nm.has_meta("solid_faces"):
					continue
				# the neighbour's face pointing back at us, in the neighbour's mesh space
				var nb := _basis(gm, gm.get_cell_item_orientation(neighbour), basis_cache)
				var local := Vector3i((nb.inverse() * Vector3(-w)).round())
				var ng: int = Mesher.DIRECTIONS.find(local)
				if ng >= 0 and (int(nm.get_meta("solid_faces")) >> ng) & 1:
					hidden |= 1 << g
		if not shadow.has(id):
			shadow[id] = lib.get_item_mesh_cast_shadow(id) if lib.has_method("get_item_mesh_cast_shadow") else 1
		# chunks are split by shadow setting too, as cast_shadow is per MeshInstance3D
		var key := Vector3i(floori(c.x / float(CHUNK)), floori(c.z / float(CHUNK)), shadow[id])
		# the low triangles (part.low) of a shadow caster on the ground row cast none
		var low_key := Vector3i(key.x, key.y, 0) if c.y == ground_row else key
		var rot := Transform3D(xf.basis, Vector3.ZERO)   # for normals
		var own_cell = _owner_bytes(gm.transform * gm.map_to_local(Vector3i(c.x, 0, c.z))) if owners else null
		for part in parts:
			for g in Mesher.GROUPS:
				if (hidden >> g) & 1:
					continue
				_append(chunks, key, part.mat, part.groups[g], xf, rot, own_cell)
				_append(chunks, low_key, part.mat, part.low[g], xf, rot, own_cell)
	# the extra layers: into the chunk of the main-layer cell they are in, every face
	# but the bottom, with the cell they hang on
	var columns := {}
	for c: Vector3i in cells:
		columns[Vector2i(c.x, c.z)] = true
	var to_main := gm.transform.affine_inverse()
	for extra: Array in extras:
		var grid: GridMap = extra[0]
		var extra_lib: MeshLibrary = extra[1]
		for c: Vector3i in grid.get_used_cells():
			if Time.get_ticks_usec() - start > BUDGET_USEC:
				await Engine.get_main_loop().process_frame
				if not is_instance_valid(gm) or not is_instance_valid(grid):
					out.free()
					return null
				start = Time.get_ticks_usec()
			var id := grid.get_cell_item(c)
			var mesh := extra_lib.get_item_mesh(id) as ArrayMesh
			if mesh == null:
				continue
			var b := _basis(grid, grid.get_cell_item_orientation(c), basis_cache)
			var xf := to_main * grid.transform * Transform3D(b, grid.map_to_local(c)) * extra_lib.get_item_mesh_transform(id)
			if not cache.has(mesh):
				cache[mesh] = _split(mesh)
			var parts: Array = cache[mesh]
			if parts.is_empty():
				loose.append([mesh, xf])
				continue
			var centre := to_main * grid.transform * grid.map_to_local(c)   # in the main layer's space
			var owner := _owner(gm, columns, centre)
			var cell := gm.local_to_map(centre)
			var cast: int = extra_lib.get_item_mesh_cast_shadow(id) if extra_lib.has_method("get_item_mesh_cast_shadow") else 1
			var key := Vector3i(floori(cell.x / float(CHUNK)), floori(cell.z / float(CHUNK)), cast)
			var rot := Transform3D(xf.basis, Vector3.ZERO)
			for part in parts:
				for g in Mesher.GROUPS:
					if g == Mesher.BOTTOM:
						continue
					_append(chunks, key, part.mat, part.groups[g], xf, rot, owner)
					_append(chunks, key, part.mat, part.low[g], xf, rot, owner)
	# build one mesh per chunk, one surface per material
	var built := 0
	for key in chunks:
		built += 1
		var chunk: Dictionary = chunks[key]
		var mesh := ArrayMesh.new()
		for surface_key in chunk:
			var d: Array = chunk[surface_key]
			if d[0].is_empty():
				continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = d[0]
			arrays[Mesh.ARRAY_NORMAL] = d[1]
			arrays[Mesh.ARRAY_COLOR] = d[2]
			if d[3].size() == d[0].size():
				arrays[Mesh.ARRAY_TEX_UV] = d[3]
			if d[4].size() == d[0].size():
				arrays[Mesh.ARRAY_TEX_UV2] = d[4]
			var flags := 0
			if d.size() > 5:
				arrays[Mesh.ARRAY_CUSTOM0] = d[5]
				flags = Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
			mesh.surface_set_material(mesh.get_surface_count() - 1, surface_key)
		if mesh.get_surface_count() == 0:
			continue
		if Time.get_ticks_usec() - start > BUDGET_USEC:
			if progress.is_valid():
				progress.call(0.9 + 0.1 * built / chunks.size())
			await Engine.get_main_loop().process_frame
			start = Time.get_ticks_usec()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = key.z
		out.add_child(mi)
	for l in loose:
		var mi := MeshInstance3D.new()
		mi.mesh = l[0]
		mi.transform = l[1]
		out.add_child(mi)
	return out


## Appends the face group `gr` ([v, n, c, uv, uv2], mesh space) to the surface of `mat`
## in chunk `key`, transformed by `xf` (normals by `rot`). `owner`: the 4 CUSTOM0 bytes
## of the cell the faces belong to (_owner_bytes), or null when baking without owners.
static func _append(chunks: Dictionary, key: Vector3i, mat: Material, gr: Array, xf: Transform3D, rot: Transform3D, owner = null) -> void:
	if gr[0].is_empty():
		return
	var chunk: Dictionary = chunks.get(key, {})
	chunks[key] = chunk
	var target: Array = chunk.get(mat, [])
	if target.is_empty():
		target = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array(), PackedVector2Array()]
		if owner != null:
			target.append(PackedByteArray())
		chunk[mat] = target
	if owner != null:
		var custom: PackedByteArray = target[5]
		var start := custom.size()
		custom.resize(start + gr[0].size() * 4)
		for vertex in gr[0].size():
			for byte_index in 4:
				custom[start + vertex * 4 + byte_index] = owner[byte_index]
	target[0].append_array(xf * gr[0])
	target[1].append_array(rot * gr[1])
	target[2].append_array(gr[2])
	target[3].append_array(gr[3])   # atlas UVs
	target[4].append_array(gr[4])   # tile-local voxel coordinates (relief) stay valid in the chunk


## The main-layer cell an extra layer's cell (centre `centre`, main layer space) hangs
## on: the occupied column under it, or the nearest one within OWNER_REACH metres. As
## CUSTOM0 bytes (_owner_bytes) of that cell's centre, or all 0 if there is none (the
## shader then uses the pixel's own cell).
static func _owner(gm: GridMap, columns: Dictionary, centre: Vector3) -> PackedByteArray:
	var best := Vector2i.ZERO
	var best_distance := INF
	for dx in [0.0, -OWNER_REACH, OWNER_REACH]:
		for dz in [0.0, -OWNER_REACH, OWNER_REACH]:
			var cell := gm.local_to_map(centre + Vector3(dx, 0.0, dz))
			var column := Vector2i(cell.x, cell.z)
			var distance: float = dx * dx + dz * dz
			if columns.has(column) and distance < best_distance:
				best = column
				best_distance = distance
	if best_distance == INF:
		return PackedByteArray([0, 0, 0, 0])
	return _owner_bytes(gm.transform * gm.map_to_local(Vector3i(best.x, 0, best.y)))


## CUSTOM0 bytes for a cell centre at `world` (metres): x and z rounded to whole metres,
## + 32768, as 16 bits each, low byte first (see the top).
static func _owner_bytes(world: Vector3) -> PackedByteArray:
	var x := clampi(roundi(world.x) + 32768, 1, 65535)
	var z := clampi(roundi(world.z) + 32768, 1, 65535)
	return PackedByteArray([x & 255, x >> 8, z & 255, z >> 8])


## Cached Basis for a GridMap orthogonal orientation index.
static func _basis(gm: GridMap, orientation: int, cache: Dictionary) -> Basis:
	if not cache.has(orientation):
		cache[orientation] = gm.get_basis_with_orthogonal_index(orientation)
	return cache[orientation]


## Splits each surface of `mesh` into its Mesher.GROUPS face groups:
## [{mat, groups: [[vertices, normals, colours, uvs, uv2s] per group], low: the same for the
## triangles lower than LOW_SHADOW above the mesh's bottom}]. Returns an empty array
## if the mesh must stay separate (local-coordinate shader, indexed or uncoloured surface).
## Without "face_ranges" meta all triangles go into the last group (never hidden).
static func _split(mesh: ArrayMesh) -> Array:
	var parts := []
	var face_ranges: Array = mesh.get_meta("face_ranges", [])
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s)
		# atlas copies of the materials keep their original path in meta "base_path"
		if mat == null or mat.get_meta("base_path", mat.resource_path) in LOCAL_MATERIALS:
			return []
		var a := mesh.surface_get_arrays(s)
		if a[Mesh.ARRAY_INDEX] != null or a[Mesh.ARRAY_COLOR] == null:
			return []
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var k: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2] if a[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		uv.resize(v.size())    # meshes without them get zeros
		uv2.resize(v.size())
		var bounds: PackedInt32Array
		if s < face_ranges.size():
			bounds = face_ranges[s]
		else:
			bounds = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, v.size()])
		var limit := mesh.get_aabb().position.y + LOW_SHADOW
		var groups := []
		var low := []
		for g in Mesher.GROUPS:
			var hi_part := [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array(), PackedVector2Array()]
			var lo_part := [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array(), PackedVector2Array()]
			for t in range(bounds[g], bounds[g + 1], 3):
				var dest: Array = lo_part if maxf(v[t].y, maxf(v[t + 1].y, v[t + 2].y)) < limit else hi_part
				dest[0].append_array(v.slice(t, t + 3))
				dest[1].append_array(n.slice(t, t + 3))
				dest[2].append_array(k.slice(t, t + 3))
				dest[3].append_array(uv.slice(t, t + 3))
				dest[4].append_array(uv2.slice(t, t + 3))
			groups.append(hi_part)
			low.append(lo_part)
		parts.append({"mat": mat, "groups": groups, "low": low})
	return parts
