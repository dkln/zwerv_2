extends RefCounted
## Merges the tiles of a GridMap into large meshes ("baking"), used by
## level_of_detail.gd at startup for the Grond and Gebouwen layers.
##
## Cells are grouped into chunks of `chunk_cells` x `chunk_cells` (CHUNK by default; the
## finest LOD level uses smaller ones, so a close view does not draw a whole 32 m chunk for
## the corner of it that is on screen); each chunk becomes one MeshInstance3D
## with one surface per material, so there are far fewer draw calls. Faces that lie
## against a solid face of a neighbour cell are left out, as are all bottom faces, so
## there are also fewer triangles. This relies on the importer grouping each
## surface's triangles per cell face (mesh meta "face_ranges" and "solid_faces", see
## vox_mesher.gd). Tiles whose shaders work in mesh-local coordinates (flag, wind,
## floating) cannot be merged and are added as separate MeshInstance3Ds. What happens to a
## tile is up to its metadata "bake" (tile_metadata.gd, tools/voxgen/bake.py): "merge" false
## leaves any extra-layer tile separate; "merge" true bakes a flag as well, with the point
## it waves around in CUSTOM1 (x, z in the chunk's space, w = 1) for voxel_flag.gdshader;
## "building_part" false gives a detail no owner; "shadow" sets the library's shadow.
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
## hangs on. The see-through buildings (scripts/world/town/building_fade.gd,
## voxel_fade.gdshaderinc) fade by that cell, so parts that stick out of their cell (bay
## windows, shop fronts, awnings, signs) fade with their own building. Packed in 4 bytes
## (RGBA8): world x and z in whole metres, each + 32768 as 16 bits (low byte first).
##
## Filled shadows (filled_shadows on, for the buildings): facades with windows don't cast
## their own detailed shadow. Tiles with opaque "interior" windows (library_builder.gd)
## are drawn without shadow and cast a filled block instead, built from FILL_CELL cubes
## and kept FACADE_DEPTH behind every open side, so sun still reaches the window
## recesses in front of it. These blocks go into shadow-only chunks ("Schaduw" nodes).
## Extra-layer details cast the shadow of their library item (metadata "bake": details that
## lie flat on the wall cast none).

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

## The arrays of a chunk surface and of a face group (the last two only in a chunk surface).
const VERTICES := 0
const NORMALS := 1
const COLOURS := 2
const UVS := 3
const UV2S := 4
const OWNERS := 5
const WAVE_CENTRES := 6

## Default chunk size in cells (along x and z).
const CHUNK := 8
## Triangles lower than this (metres above the bottom of their tile, on the lowest row of
## cells) cast no shadow; the same height as SHADOW_MIN_HEIGHT in library_builder.gd.
const LOW_SHADOW := 0.7
## Bump when the output changes (invalidates the cache in user://merged).
const VERSION := 13
## Metres around an extra layer's cell centre searched for the main-layer cell it hangs on.
const OWNER_REACH := 1.0
## Compute time per frame in microseconds; the rest continues in following frames.
const BUDGET_USEC := 6000
## Filled shadows: size in metres of the cubes a block is made of.
const FILL_CELL := 0.5
## Filled shadows: metres a block stays behind an open side of its tile, more than the
## deepest window recess (0.375 m).
const FACADE_DEPTH := 0.4


## Everything one bake works on and collects.
class BakeJob:
	var grid: GridMap
	var library: MeshLibrary
	var chunk_cells := CHUNK
	var hide_tops: bool
	var owners: bool
	var filled_shadows: bool
	var progress: Callable
	var output: Node3D
	var split_meshes := {}      # mesh -> its surfaces in face groups (_split)
	var chunks := {}            # Vector3i(chunk x, chunk z, cast shadow) -> {material: surface arrays (_new_surface)}
	var loose_meshes := []      # [mesh, placement, cast shadow] of tiles that stay a separate mesh
	var shadow_of_item := {}    # item -> cast shadow setting
	var fill_grids := {}        # mesh -> its filled cubes (_fill_grid)
	var fill_blocks := {}       # [mesh, open sides] -> triangles of its block (_fill_block)
	var shadow_blocks := {}     # Vector2i(chunk x, chunk z) -> PackedVector3Array of triangles
	var basis_cache := {}       # orthogonal index -> Basis
	var frame_start := Time.get_ticks_usec()


## Bakes the GridMap `grid`, rendered with `library` (the normal library or one of its LOD
## copies with the same item IDs), into a new Node3D called `output_name` with the GridMap's
## transform. hide_tops: top faces may also be dropped when a solid cell sits on top
## (for layers whose tiles are as tall as the cell). progress (optional) is called with
## the fraction done (0..1) whenever the work pauses for a frame. extras: [GridMap,
## MeshLibrary] pairs of layers baked into the same chunks (see the top). Coroutine:
## await it. Returns null if `grid` is freed before it is done. owners, filled_shadows:
## see the top. chunk_cells: the chunk size in cells.
static func bake(grid: GridMap, library: MeshLibrary, output_name: String, hide_tops: bool, progress := Callable(), extras := [], owners := false, filled_shadows := false, chunk_cells := CHUNK) -> Node3D:
	var job := BakeJob.new()
	job.grid = grid
	job.library = library
	job.chunk_cells = chunk_cells
	job.hide_tops = hide_tops
	job.owners = owners or not extras.is_empty()
	job.filled_shadows = filled_shadows
	job.progress = progress
	job.output = Node3D.new()
	job.output.name = output_name
	job.output.transform = grid.transform
	var finished: bool = await _bake_main_layer(job)
	for extra: Array in extras:
		finished = finished and await _bake_extra_layer(job, extra[0], extra[1])
	if not finished:
		job.output.free()   # a layer was freed meanwhile (another map part loaded)
		return null
	await _add_chunks(job)
	_add_loose_meshes(job)
	_add_shadow_blocks(job)
	return job.output


# ------------------------------------------------------------------ the main layer

## All cells of the main layer. False if the layer was freed before it was done.
static func _bake_main_layer(job: BakeJob) -> bool:
	var cells := job.grid.get_used_cells()
	var ground_row := 0x7fffffff
	for cell: Vector3i in cells:
		ground_row = mini(ground_row, cell.y)
	var cells_done := 0
	for cell: Vector3i in cells:
		cells_done += 1
		if cells_done % 64 == 0 and _over_budget(job):
			# collecting the cells is most of the work; building the chunks the last 10%
			if job.progress.is_valid():
				job.progress.call(0.9 * cells_done / cells.size())
			await _next_frame(job)
			if not is_instance_valid(job.grid):
				return false
		_bake_main_cell(job, cell, ground_row)
	return true


static func _bake_main_cell(job: BakeJob, cell: Vector3i, ground_row: int) -> void:
	var grid := job.grid
	var item := grid.get_cell_item(cell)
	var mesh := job.library.get_item_mesh(item) as ArrayMesh
	if mesh == null:
		return
	var cell_basis := _basis(grid, grid.get_cell_item_orientation(cell), job.basis_cache)
	var placement := Transform3D(cell_basis, grid.map_to_local(cell)) * job.library.get_item_mesh_transform(item)
	var surfaces := _split_cached(job, mesh)
	if surfaces.is_empty():
		job.loose_meshes.append([mesh, placement, GeometryInstance3D.SHADOW_CASTING_SETTING_ON])
		return
	var hidden_groups := _hidden_face_groups(job, cell, cell_basis, mesh)
	var cast := _item_shadow(job, item)
	if job.filled_shadows and cast != 0 and _add_filled_shadow(job, cell, cell_basis, mesh, placement):
		cast = 0
	# chunks are split by shadow setting too, as cast_shadow is per MeshInstance3D
	var key := _chunk_key(job, cell, cast)
	# the low triangles of a shadow caster on the ground row cast none
	var low_key := _chunk_key(job, cell, 0) if cell.y == ground_row else key
	var normal_rotation := Transform3D(placement.basis, Vector3.ZERO)
	var owner = _owner_bytes(grid.transform * grid.map_to_local(Vector3i(cell.x, 0, cell.z))) if job.owners else null
	for surface: Dictionary in surfaces:
		for face_group in Mesher.GROUPS:
			if (hidden_groups >> face_group) & 1:
				continue
			_append_faces(job.chunks, key, surface.material, surface.groups[face_group], placement, normal_rotation, owner)
			_append_faces(job.chunks, low_key, surface.material, surface.low[face_group], placement, normal_rotation, owner)


## Bit g set = face group g of the mesh in `cell` is hidden: the bottom, and every side
## against a neighbour whose side there is solid (in mesh space, Mesher.DIRECTIONS).
static func _hidden_face_groups(job: BakeJob, cell: Vector3i, cell_basis: Basis, mesh: ArrayMesh) -> int:
	var hidden_groups: int = 1 << Mesher.BOTTOM
	if not mesh.has_meta("face_ranges"):
		return hidden_groups
	var grid := job.grid
	for face_group in 6:
		if face_group == Mesher.BOTTOM or (face_group == Mesher.TOP and not job.hide_tops):
			continue
		var direction := Vector3i((cell_basis * Vector3(Mesher.DIRECTIONS[face_group])).round())
		var neighbour := cell + direction
		var neighbour_item := grid.get_cell_item(neighbour)
		if neighbour_item < 0:
			continue
		var neighbour_mesh := job.library.get_item_mesh(neighbour_item)
		if neighbour_mesh == null or not neighbour_mesh.has_meta("solid_faces"):
			continue
		# the neighbour's face pointing back at us, in the neighbour's mesh space
		var neighbour_basis := _basis(grid, grid.get_cell_item_orientation(neighbour), job.basis_cache)
		var back_direction := Vector3i((neighbour_basis.inverse() * Vector3(-direction)).round())
		var back_group: int = Mesher.DIRECTIONS.find(back_direction)
		if back_group >= 0 and (int(neighbour_mesh.get_meta("solid_faces")) >> back_group) & 1:
			hidden_groups |= 1 << face_group
	return hidden_groups


## The library's shadow setting of an item.
static func _item_shadow(job: BakeJob, item: int) -> int:
	if not job.shadow_of_item.has(item):
		job.shadow_of_item[item] = job.library.get_item_mesh_cast_shadow(item) if job.library.has_method("get_item_mesh_cast_shadow") else 1
	return job.shadow_of_item[item]


## Adds the filled shadow block of a tile with opaque windows. False for all other tiles.
static func _add_filled_shadow(job: BakeJob, cell: Vector3i, cell_basis: Basis, mesh: ArrayMesh, placement: Transform3D) -> bool:
	if not job.fill_grids.has(mesh):
		job.fill_grids[mesh] = _fill_grid(mesh, job.grid.cell_size)
	if job.fill_grids[mesh].is_empty():
		return false
	var open_sides := _open_sides(job.grid, cell, cell_basis)
	var block_key := [mesh, open_sides]
	if not job.fill_blocks.has(block_key):
		job.fill_blocks[block_key] = _fill_block(job.fill_grids[mesh], open_sides, job.grid.cell_size)
	var chunk := Vector2i(floori(cell.x / float(job.chunk_cells)), floori(cell.z / float(job.chunk_cells)))
	var triangles: PackedVector3Array = job.shadow_blocks.get(chunk, PackedVector3Array())
	triangles.append_array(placement * (job.fill_blocks[block_key] as PackedVector3Array))
	job.shadow_blocks[chunk] = triangles
	return true


# ------------------------------------------------------------------ the extra layers

## All cells of an extra layer, into the chunk of the main-layer cell they are in, with the
## cell they hang on. False if a layer was freed before it was done.
static func _bake_extra_layer(job: BakeJob, extra_grid: GridMap, extra_library: MeshLibrary) -> bool:
	var occupied_columns := {}
	for cell: Vector3i in job.grid.get_used_cells():
		occupied_columns[Vector2i(cell.x, cell.z)] = true
	var to_main := job.grid.transform.affine_inverse() * extra_grid.transform
	var bake_rules: Dictionary = extra_library.get_meta("bake", {})
	for cell: Vector3i in extra_grid.get_used_cells():
		if _over_budget(job):
			await _next_frame(job)
			if not is_instance_valid(job.grid) or not is_instance_valid(extra_grid):
				return false
		var item := extra_grid.get_cell_item(cell)
		var mesh := extra_library.get_item_mesh(item) as ArrayMesh
		if mesh != null:
			var rule: Dictionary = bake_rules.get(extra_library.get_item_name(item), {})
			_bake_extra_cell(job, extra_grid, extra_library, cell, item, mesh, rule, to_main, occupied_columns)
	return true


static func _bake_extra_cell(job: BakeJob, extra_grid: GridMap, extra_library: MeshLibrary, cell: Vector3i, item: int,
		mesh: ArrayMesh, rule: Dictionary, to_main: Transform3D, occupied_columns: Dictionary) -> void:
	var cell_basis := _basis(extra_grid, extra_grid.get_cell_item_orientation(cell), job.basis_cache)
	var placement := to_main * Transform3D(cell_basis, extra_grid.map_to_local(cell)) * extra_library.get_item_mesh_transform(item)
	var cast: int = extra_library.get_item_mesh_cast_shadow(item) if extra_library.has_method("get_item_mesh_cast_shadow") else 1
	var surfaces: Array = [] if rule.get("merge", true) == false else _split_cached(job, mesh, rule.get("merge", false))
	if surfaces.is_empty():
		job.loose_meshes.append([mesh, placement, cast])
		return
	var centre := to_main * extra_grid.map_to_local(cell)
	var owner := _owner(job.grid, occupied_columns, centre) if rule.get("building_part", true) else PackedByteArray([0, 0, 0, 0])
	var key := _chunk_key(job, job.grid.local_to_map(centre), cast)
	var normal_rotation := Transform3D(placement.basis, Vector3.ZERO)
	for surface: Dictionary in surfaces:
		var is_flag := _is_flag(surface.material)
		var wave_centre = placement.origin if is_flag else null
		for face_group in Mesher.GROUPS:
			# a flag hangs free, so its bottom can be seen
			if face_group == Mesher.BOTTOM and not is_flag:
				continue
			_append_faces(job.chunks, key, surface.material, surface.groups[face_group], placement, normal_rotation, owner, wave_centre)
			_append_faces(job.chunks, key, surface.material, surface.low[face_group], placement, normal_rotation, owner, wave_centre)


# ------------------------------------------------------------------ the output

## One mesh per chunk, one surface per material.
static func _add_chunks(job: BakeJob) -> void:
	var chunks_built := 0
	for key: Vector3i in job.chunks:
		chunks_built += 1
		var mesh := _chunk_mesh(job.chunks[key])
		if mesh.get_surface_count() == 0:
			continue
		if _over_budget(job):
			if job.progress.is_valid():
				job.progress.call(0.9 + 0.1 * chunks_built / job.chunks.size())
			await _next_frame(job)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.cast_shadow = _shadow_casting(key.z)
		job.output.add_child(instance)


static func _chunk_mesh(chunk: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for material: Material in chunk:
		var surface: Array = chunk[material]
		if surface[VERTICES].is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surface[VERTICES]
		arrays[Mesh.ARRAY_NORMAL] = surface[NORMALS]
		arrays[Mesh.ARRAY_COLOR] = surface[COLOURS]
		if surface[UVS].size() == surface[VERTICES].size():
			arrays[Mesh.ARRAY_TEX_UV] = surface[UVS]
		if surface[UV2S].size() == surface[VERTICES].size():
			arrays[Mesh.ARRAY_TEX_UV2] = surface[UV2S]
		var format_flags := 0
		if surface.size() > OWNERS:
			arrays[Mesh.ARRAY_CUSTOM0] = surface[OWNERS]
			format_flags = Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		if surface.size() > WAVE_CENTRES:
			arrays[Mesh.ARRAY_CUSTOM1] = surface[WAVE_CENTRES]
			format_flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format_flags)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


static func _add_loose_meshes(job: BakeJob) -> void:
	for loose: Array in job.loose_meshes:
		var instance := MeshInstance3D.new()
		instance.mesh = loose[0]
		instance.transform = loose[1]
		instance.cast_shadow = _shadow_casting(loose[2])
		job.output.add_child(instance)


static func _add_shadow_blocks(job: BakeJob) -> void:
	for chunk: Vector2i in job.shadow_blocks:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = job.shadow_blocks[chunk]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var instance := MeshInstance3D.new()
		instance.name = "Schaduw"
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		job.output.add_child(instance, true)


# ------------------------------------------------------------------ helpers

static func _over_budget(job: BakeJob) -> bool:
	return Time.get_ticks_usec() - job.frame_start > BUDGET_USEC


## Continues in the next frame, with a new time budget.
static func _next_frame(job: BakeJob) -> void:
	await Engine.get_main_loop().process_frame
	job.frame_start = Time.get_ticks_usec()


## Chunk of a main-layer cell, for one shadow setting.
static func _chunk_key(job: BakeJob, cell: Vector3i, cast: int) -> Vector3i:
	return Vector3i(floori(cell.x / float(job.chunk_cells)), floori(cell.z / float(job.chunk_cells)), cast)


static func _split_cached(job: BakeJob, mesh: ArrayMesh, bake_flags := false) -> Array:
	if not job.split_meshes.has(mesh):
		job.split_meshes[mesh] = _split(mesh, bake_flags)
	return job.split_meshes[mesh]


## Bit g set = no tile lies against face group g of the mesh placed in cell `cell` with
## basis `cell_basis` (Mesher.DIRECTIONS, in mesh space).
static func _open_sides(grid: GridMap, cell: Vector3i, cell_basis: Basis) -> int:
	var open_sides := 0
	for face_group in 6:
		var direction := Vector3i((cell_basis * Vector3(Mesher.DIRECTIONS[face_group])).round())
		if grid.get_cell_item(cell + direction) < 0:
			open_sides |= 1 << face_group
	return open_sides


## The cubes (FILL_CELL) of the filled shadow block of a tile with opaque windows: every
## cube a surface passes through, plus those between two of them along x or z. Mesh
## space, inside the cell: x and z -half..half, y from 0. Returns {} for all other tiles,
## and {size: Vector3i, cells: PackedByteArray (x + z * size.x + y * size.x * size.z)}.
static func _fill_grid(mesh: ArrayMesh, cell_size: Vector3) -> Dictionary:
	var has_windows := false
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface) as ShaderMaterial
		if material and mesh.surface_get_name(surface) == "glass" and material.get_shader_parameter("interior") == 1.0:
			has_windows = true
	if not has_windows:
		return {}
	var height := maxf(cell_size.y, mesh.get_aabb().end.y)
	var size := Vector3i(ceili(cell_size.x / FILL_CELL), ceili(height / FILL_CELL), ceili(cell_size.z / FILL_CELL))
	var filled := PackedByteArray()
	filled.resize(size.x * size.y * size.z)
	var mark := func(point: Vector3) -> void:
		var column_x := clampi(floori((point.x + cell_size.x * 0.5) / FILL_CELL), 0, size.x - 1)
		var row := clampi(floori(point.y / FILL_CELL), 0, size.y - 1)
		var column_z := clampi(floori((point.z + cell_size.z * 0.5) / FILL_CELL), 0, size.z - 1)
		filled[column_x + column_z * size.x + row * size.x * size.z] = 1
	for surface in mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for first in range(0, vertices.size() - 2, 3):
			var corner_a := vertices[first]
			var corner_b := vertices[first + 1]
			var corner_c := vertices[first + 2]
			# samples inside the triangle, closer together than a cube
			var longest := maxf(corner_a.distance_to(corner_b), maxf(corner_b.distance_to(corner_c), corner_c.distance_to(corner_a)))
			var steps := maxi(ceili(longest / (FILL_CELL * 0.5)), 1)
			for step_b in steps + 1:
				for step_c in steps - step_b + 1:
					var weight_b := (step_b + 0.02) / (steps + 0.1)
					var weight_c := (step_c + 0.02) / (steps + 0.1)
					mark.call(corner_a + (corner_b - corner_a) * weight_b + (corner_c - corner_a) * weight_c)
	# between two filled cubes on a row is filled too (the hollow inside of the building)
	for row in size.y:
		var at := func(column_x: int, column_z: int) -> int:
			return column_x + column_z * size.x + row * size.x * size.z
		for column_z in size.z:
			var first := -1
			for column_x in size.x:
				if filled[at.call(column_x, column_z)]:
					if first >= 0:
						for between in range(first + 1, column_x):
							filled[at.call(between, column_z)] = 1
					first = column_x
		for column_x in size.x:
			var first := -1
			for column_z in size.z:
				if filled[at.call(column_x, column_z)]:
					if first >= 0:
						for between in range(first + 1, column_z):
							filled[at.call(column_x, between)] = 1
					first = column_z
	return {"size": size, "cells": filled}


## Triangles (mesh space) of the block of a _fill_grid result: cubes merged into boxes,
## pulled FACADE_DEPTH back from the sides in `open_sides` (_open_sides); never from the
## bottom, which stands on the ground or on the floor below.
static func _fill_block(grid: Dictionary, open_sides: int, cell_size: Vector3) -> PackedVector3Array:
	var size: Vector3i = grid.size
	var left: PackedByteArray = grid.cells.duplicate()
	var low_limit := Vector3(-cell_size.x * 0.5, 0.0, -cell_size.z * 0.5)
	var high_limit := Vector3(cell_size.x * 0.5, size.y * FILL_CELL, cell_size.z * 0.5)
	for face_group in 6:
		if face_group == Mesher.BOTTOM or not (open_sides >> face_group) & 1:
			continue
		var direction := Vector3(Mesher.DIRECTIONS[face_group])
		if direction.x + direction.y + direction.z > 0.0:
			high_limit -= direction * FACADE_DEPTH
		else:
			low_limit -= direction * FACADE_DEPTH
	var triangles := PackedVector3Array()
	var index := func(column_x: int, column_z: int, row: int) -> int:
		return column_x + column_z * size.x + row * size.x * size.z
	# whether all cubes from `from` up to (not including) `to` are still left
	var all_left := func(from: Vector3i, to: Vector3i) -> bool:
		for row in range(from.y, to.y):
			for column_z in range(from.z, to.z):
				for column_x in range(from.x, to.x):
					if not left[index.call(column_x, column_z, row)]:
						return false
		return true
	for row in size.y:
		for column_z in size.z:
			for column_x in size.x:
				if not left[index.call(column_x, column_z, row)]:
					continue
				var from := Vector3i(column_x, row, column_z)
				var to := from + Vector3i.ONE
				while to.x < size.x and all_left.call(Vector3i(to.x, from.y, from.z), Vector3i(to.x + 1, to.y, to.z)):
					to.x += 1
				while to.z < size.z and all_left.call(Vector3i(from.x, from.y, to.z), Vector3i(to.x, to.y, to.z + 1)):
					to.z += 1
				while to.y < size.y and all_left.call(Vector3i(from.x, to.y, from.z), Vector3i(to.x, to.y + 1, to.z)):
					to.y += 1
				for clear_row in range(from.y, to.y):
					for clear_z in range(from.z, to.z):
						for clear_x in range(from.x, to.x):
							left[index.call(clear_x, clear_z, clear_row)] = 0
				var origin := Vector3(-cell_size.x * 0.5, 0.0, -cell_size.z * 0.5)
				var low := (origin + Vector3(from) * FILL_CELL).max(low_limit)
				var high := (origin + Vector3(to) * FILL_CELL).min(high_limit)
				if low.x < high.x and low.y < high.y and low.z < high.z:
					_append_box(triangles, low, high)
	return triangles


## Appends the 12 triangles of the box low..high, front faces outwards (clockwise).
static func _append_box(triangles: PackedVector3Array, low: Vector3, high: Vector3) -> void:
	var corner := func(on_x: bool, on_y: bool, on_z: bool) -> Vector3:
		return Vector3(high.x if on_x else low.x, high.y if on_y else low.y, high.z if on_z else low.z)
	# per side: four corners going round it, seen from outside clockwise
	var sides := [
		[corner.call(true, true, true), corner.call(true, true, false), corner.call(true, false, false), corner.call(true, false, true)],
		[corner.call(false, true, false), corner.call(false, true, true), corner.call(false, false, true), corner.call(false, false, false)],
		[corner.call(false, true, false), corner.call(true, true, false), corner.call(true, true, true), corner.call(false, true, true)],
		[corner.call(false, false, true), corner.call(true, false, true), corner.call(true, false, false), corner.call(false, false, false)],
		[corner.call(false, true, true), corner.call(true, true, true), corner.call(true, false, true), corner.call(false, false, true)],
		[corner.call(true, true, false), corner.call(false, true, false), corner.call(false, false, false), corner.call(true, false, false)],
	]
	for side: Array in sides:
		triangles.append_array(PackedVector3Array([side[0], side[1], side[2], side[0], side[2], side[3]]))


## Empty arrays of a chunk surface, in the order VERTICES .. WAVE_CENTRES.
static func _new_surface(with_owners: bool, with_wave_centres: bool) -> Array:
	var surface := [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array(), PackedVector2Array()]
	if with_owners:
		surface.append(PackedByteArray())
	if with_wave_centres:
		surface.append(PackedFloat32Array())
	return surface


## Appends `faces` (a face group of _split, mesh space) to the surface of `material` in chunk
## `key`, moved by `placement` (normals by `normal_rotation`). `owner`: the 4 CUSTOM0 bytes
## of the cell the faces belong to (_owner_bytes), or null when baking without owners.
## `wave_centre`: for a flag (always with an owner) the point it waves around, for CUSTOM1.
static func _append_faces(chunks: Dictionary, key: Vector3i, material: Material, faces: Array, placement: Transform3D,
		normal_rotation: Transform3D, owner = null, wave_centre = null) -> void:
	var vertex_count: int = faces[VERTICES].size()
	if vertex_count == 0:
		return
	var chunk: Dictionary = chunks.get(key, {})
	chunks[key] = chunk
	var surface: Array = chunk.get(material, [])
	if surface.is_empty():
		surface = _new_surface(owner != null, wave_centre != null)
		chunk[material] = surface
	if owner != null:
		var owners: PackedByteArray = surface[OWNERS]
		var first_owner := owners.size()
		owners.resize(first_owner + vertex_count * 4)
		for vertex in vertex_count:
			for byte_index in 4:
				owners[first_owner + vertex * 4 + byte_index] = owner[byte_index]
	if wave_centre != null:
		var wave_centres: PackedFloat32Array = surface[WAVE_CENTRES]
		var first_centre := wave_centres.size()
		wave_centres.resize(first_centre + vertex_count * 4)
		for vertex in vertex_count:
			wave_centres[first_centre + vertex * 4] = wave_centre.x
			wave_centres[first_centre + vertex * 4 + 1] = wave_centre.z
			wave_centres[first_centre + vertex * 4 + 3] = 1.0
	surface[VERTICES].append_array(placement * faces[VERTICES])
	surface[NORMALS].append_array(normal_rotation * faces[NORMALS])
	surface[COLOURS].append_array(faces[COLOURS])
	surface[UVS].append_array(faces[UVS])     # atlas UVs
	surface[UV2S].append_array(faces[UV2S])   # tile-local voxel coordinates (relief) stay valid in the chunk


## The main-layer cell an extra layer's cell (centre `centre`, main layer space) hangs
## on: the occupied column under it, or the nearest one within OWNER_REACH metres. As
## CUSTOM0 bytes (_owner_bytes) of that cell's centre, or all 0 if there is none (the
## shader then uses the pixel's own cell).
static func _owner(grid: GridMap, occupied_columns: Dictionary, centre: Vector3) -> PackedByteArray:
	var best_column := Vector2i.ZERO
	var best_distance := INF
	for offset_x in [0.0, -OWNER_REACH, OWNER_REACH]:
		for offset_z in [0.0, -OWNER_REACH, OWNER_REACH]:
			var cell := grid.local_to_map(centre + Vector3(offset_x, 0.0, offset_z))
			var column := Vector2i(cell.x, cell.z)
			var distance: float = offset_x * offset_x + offset_z * offset_z
			if occupied_columns.has(column) and distance < best_distance:
				best_column = column
				best_distance = distance
	if best_distance == INF:
		return PackedByteArray([0, 0, 0, 0])
	return _owner_bytes(grid.transform * grid.map_to_local(Vector3i(best_column.x, 0, best_column.y)))


## CUSTOM0 bytes for a cell centre at `world` (metres): x and z rounded to whole metres,
## + 32768, as 16 bits each, low byte first (see the top).
static func _owner_bytes(world: Vector3) -> PackedByteArray:
	var x := clampi(roundi(world.x) + 32768, 1, 65535)
	var z := clampi(roundi(world.z) + 32768, 1, 65535)
	return PackedByteArray([x & 255, x >> 8, z & 255, z >> 8])


## Cached Basis for a GridMap orthogonal orientation index.
static func _basis(grid: GridMap, orientation: int, cache: Dictionary) -> Basis:
	if not cache.has(orientation):
		cache[orientation] = grid.get_basis_with_orthogonal_index(orientation)
	return cache[orientation]


## True if `material` is the waving flag material (or its atlas copy).
static func _is_flag(material: Material) -> bool:
	return material.get_meta("base_path", material.resource_path) == Mesher.MATERIAL_PATHS[Model.MAT_FLAG]


## Splits each surface of `mesh` into its Mesher.GROUPS face groups:
## [{material, groups: [surface arrays (_new_surface) per group], low: the same for the
## triangles lower than LOW_SHADOW above the mesh's bottom}]. Returns an empty array
## if the mesh must stay separate (local-coordinate shader, indexed or uncoloured surface;
## bake_flags: flags don't count as local, metadata "bake" lets them be baked).
## Without "face_ranges" meta all triangles go into the last group (never hidden).
static func _split(mesh: ArrayMesh, bake_flags := false) -> Array:
	var surfaces := []
	var face_ranges: Array = mesh.get_meta("face_ranges", [])
	var low_limit := mesh.get_aabb().position.y + LOW_SHADOW
	for surface_index in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface_index)
		# atlas copies of the materials keep their original path in meta "base_path"
		if material == null or (material.get_meta("base_path", material.resource_path) in LOCAL_MATERIALS and not (bake_flags and _is_flag(material))):
			return []
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays[Mesh.ARRAY_INDEX] != null or arrays[Mesh.ARRAY_COLOR] == null:
			return []
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		uvs.resize(vertices.size())    # meshes without them get zeros
		uv2s.resize(vertices.size())
		var group_bounds: PackedInt32Array
		if surface_index < face_ranges.size():
			group_bounds = face_ranges[surface_index]
		else:
			group_bounds = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, vertices.size()])
		var groups := []
		var low := []
		for face_group in Mesher.GROUPS:
			var high_faces := _new_surface(false, false)
			var low_faces := _new_surface(false, false)
			for first in range(group_bounds[face_group], group_bounds[face_group + 1], 3):
				var highest := maxf(vertices[first].y, maxf(vertices[first + 1].y, vertices[first + 2].y))
				var target: Array = low_faces if highest < low_limit else high_faces
				target[VERTICES].append_array(vertices.slice(first, first + 3))
				target[NORMALS].append_array(normals.slice(first, first + 3))
				target[COLOURS].append_array(colours.slice(first, first + 3))
				target[UVS].append_array(uvs.slice(first, first + 3))
				target[UV2S].append_array(uv2s.slice(first, first + 3))
			groups.append(high_faces)
			low.append(low_faces)
		surfaces.append({"material": material, "groups": groups, "low": low})
	return surfaces


## How a merged mesh casts its shadow: what casts one casts it from both sides of its faces,
## so the light does not leak through the hollow buildings and the seams between merged
## faces (loose light pixels in a shadow); the rest as set.
static func _shadow_casting(setting: int) -> int:
	return GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED if setting == GeometryInstance3D.SHADOW_CASTING_SETTING_ON else setting
