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
##
## The work is spread over frames (BUDGET_USEC per frame), so `bake` must be awaited.

const Mesher = preload("res://addons/vox_tiles/vox_mesher.gd")
const Parser = preload("res://addons/vox_tiles/vox_parser.gd")

## Materials whose shaders compute in mesh-local coordinates: tiles using them stay separate.
const LOCAL_MATERIALS := [
	Mesher.MATERIAL_PATHS[Parser.MAT_FLAG],
	Mesher.WIND_MATERIAL,
	Mesher.FLOAT_MATERIAL,
	Mesher.FLOAT_PLANT_MATERIAL,
]

## Chunk size in cells (along x and z).
const CHUNK := 8
## Bump when the output changes (invalidates the cache in user://merged).
const VERSION := 4
## Compute time per frame in microseconds; the rest continues in following frames.
const BUDGET_USEC := 6000


## Bakes the GridMap `gm`, rendered with `lib` (the normal library or one of its LOD
## copies with the same item IDs), into a new Node3D called `name` with the GridMap's
## transform. hide_tops: top faces may also be dropped when a solid cell sits on top
## (for layers whose tiles are as tall as the cell). Coroutine: await it.
static func bake(gm: GridMap, lib: MeshLibrary, name: String, hide_tops: bool) -> Node3D:
	var out := Node3D.new()
	out.name = name
	out.transform = gm.transform
	var cache := {}   # mesh -> [{mat, groups: [[v, n, c] x Mesher.GROUPS]}]
	var chunks := {}  # Vector3i(chunk x, chunk z, cast shadow) -> {material: [v, n, c]}
	var shadow := {}  # item -> cast shadow setting
	var loose := []   # [mesh, transform] of tiles that stay a separate mesh
	var basis_cache := {}  # orthogonal index -> Basis
	var start := Time.get_ticks_usec()
	var counter := 0
	for c: Vector3i in gm.get_used_cells():
		counter += 1
		if counter % 64 == 0 and Time.get_ticks_usec() - start > BUDGET_USEC:
			await Engine.get_main_loop().process_frame
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
		var chunk: Dictionary = chunks.get(key, {})
		chunks[key] = chunk
		var rot := Transform3D(xf.basis, Vector3.ZERO)   # for normals
		for part in parts:
			var mat: Material = part.mat
			var target: Array = chunk.get(mat, [])
			if target.is_empty():
				target = [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
				chunk[mat] = target
			for g in Mesher.GROUPS:
				if (hidden >> g) & 1:
					continue
				var gr: Array = part.groups[g]
				if gr[0].is_empty():
					continue
				target[0].append_array(xf * gr[0])
				target[1].append_array(rot * gr[1])
				target[2].append_array(gr[2])
	# build one mesh per chunk, one surface per material
	for key in chunks:
		var chunk: Dictionary = chunks[key]
		var mesh := ArrayMesh.new()
		for mat in chunk:
			var d: Array = chunk[mat]
			if d[0].is_empty():
				continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = d[0]
			arrays[Mesh.ARRAY_NORMAL] = d[1]
			arrays[Mesh.ARRAY_COLOR] = d[2]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
		if mesh.get_surface_count() == 0:
			continue
		if Time.get_ticks_usec() - start > BUDGET_USEC:
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


## Cached Basis for a GridMap orthogonal orientation index.
static func _basis(gm: GridMap, orientation: int, cache: Dictionary) -> Basis:
	if not cache.has(orientation):
		cache[orientation] = gm.get_basis_with_orthogonal_index(orientation)
	return cache[orientation]


## Splits each surface of `mesh` into its Mesher.GROUPS face groups:
## [{mat, groups: [[vertices, normals, colours] per group]}]. Returns an empty array
## if the mesh must stay separate (local-coordinate shader, indexed or uncoloured surface).
## Without "face_ranges" meta all triangles go into the last group (never hidden).
static func _split(mesh: ArrayMesh) -> Array:
	var parts := []
	var face_ranges: Array = mesh.get_meta("face_ranges", [])
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s)
		if mat == null or mat.resource_path in LOCAL_MATERIALS:
			return []
		var a := mesh.surface_get_arrays(s)
		if a[Mesh.ARRAY_INDEX] != null or a[Mesh.ARRAY_COLOR] == null:
			return []
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var k: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var bounds: PackedInt32Array
		if s < face_ranges.size():
			bounds = face_ranges[s]
		else:
			bounds = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, v.size()])
		var groups := []
		for g in Mesher.GROUPS:
			groups.append([v.slice(bounds[g], bounds[g + 1]), n.slice(bounds[g], bounds[g + 1]), k.slice(bounds[g], bounds[g + 1])])
		parts.append({"mat": mat, "groups": groups})
	return parts
