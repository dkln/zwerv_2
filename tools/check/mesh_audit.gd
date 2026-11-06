extends SceneTree
## Checks how well the voxel models are meshed and baked. Per library: triangles, vertices,
## the merging (voxel faces per quad of the greedy mesher), faces that lie exactly against
## each other (they can never be seen) and the worst tiles. Then it bakes the city layers as
## the game does and prints what the bake saves.
## usage: Godot --headless --script tools/check/mesh_audit.gd

const Common = preload("res://tools/tool_common.gd")
const Baker = preload("res://scripts/world/layer_baker.gd")
const LIBRARIES := ["grond", "gebouwen", "props", "details"]
const VOXEL_FACE_AREA := 0.125 * 0.125


func _init() -> void:
	Common.watchdog(self, 550)
	for library_name in LIBRARIES:
		_audit_library(library_name)
	await _audit_bake()
	quit()


func _audit_library(library_name: String) -> void:
	for suffix: String in ["", "_lod", "_lod2"]:
		var library: MeshLibrary = load("res://assets/libraries/%s%s.res" % [library_name, suffix])
		var total_triangles := 0
		var total_vertices := 0
		var total_area := 0.0
		var indexed_surfaces := 0
		var surfaces := 0
		var hidden_pairs := 0
		var per_tile := []
		var seen := {}
		for id in library.get_item_list():
			var mesh := library.get_item_mesh(id)
			if mesh == null or seen.has(mesh):
				continue   # an alias shares its tile's mesh
			seen[mesh] = true
			var triangles := 0
			var area := 0.0
			var faces := {}
			for surface in mesh.get_surface_count():
				surfaces += 1
				var arrays := mesh.surface_get_arrays(surface)
				var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				if arrays[Mesh.ARRAY_INDEX] != null:
					indexed_surfaces += 1
					continue
				total_vertices += positions.size()
				triangles += positions.size() / 3
				for corner in range(0, positions.size(), 3):
					var edge_cross := (positions[corner + 1] - positions[corner]).cross(positions[corner + 2] - positions[corner])
					area += edge_cross.length() * 0.5
					# a triangle and its mirror image on the same spot: back to back
					var middle := (positions[corner] + positions[corner + 1] + positions[corner + 2]) / 3.0
					var spot := Vector3i((middle * 1000.0).round())
					faces[spot] = faces.get(spot, 0) + 1
			for spot in faces:
				if faces[spot] > 1:
					hidden_pairs += 1
			total_triangles += triangles
			total_area += area
			var voxel_faces := area / VOXEL_FACE_AREA
			per_tile.append([triangles, library.get_item_name(id), voxel_faces / maxf(triangles * 0.5, 1.0)])
		per_tile.sort()
		per_tile.reverse()
		print("%s%s: %d meshes, %d surfaces (%d indexed), %d triangles, %d vertices, %.1f voxel faces per quad, %d back-to-back triangles" % [
			library_name, suffix, seen.size(), surfaces, indexed_surfaces, total_triangles, total_vertices,
			(total_area / VOXEL_FACE_AREA) / maxf(total_triangles * 0.5, 1.0), hidden_pairs])
		if suffix == "":
			for row in 4:
				if row < per_tile.size():
					print("    %s: %d triangles, %.1f faces per quad" % [per_tile[row][1], per_tile[row][0], per_tile[row][2]])


func _audit_bake() -> void:
	var scene := Common.instantiate("res://scenes/stad.tscn")
	for node_name in ["DetailNiveau", "Rook", "Grassprieten"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	get_root().add_child(scene)
	await process_frame
	var buildings: GridMap = scene.get_node("Gebouwen")
	var details: GridMap = scene.get_node("Details")
	var ground: GridMap = scene.get_node("Grond")
	for job: Array in [["Gebouwen + Details", buildings, [[details, details.mesh_library]], true, true, true], ["Grond", ground, [], false, false, false]]:
		var grid: GridMap = job[1]
		var unbaked := _cell_triangles(grid)
		for extra: Array in job[2]:
			unbaked += _cell_triangles(extra[0])
		var baked: Node3D = await Baker.bake(grid, grid.mesh_library, "Audit", job[5], Callable(), job[2], job[3], job[4])
		var drawn := 0
		var shadow_only := 0
		var casting := 0
		var surfaces := 0
		var loose_meshes := 0
		var chunks := 0
		for child in baked.get_children():
			if not child is MeshInstance3D:
				continue
			var mesh: Mesh = child.mesh
			var triangles := 0
			for surface in mesh.get_surface_count():
				triangles += mesh.surface_get_array_len(surface) / 3 if mesh.surface_get_array_index_len(surface) <= 0 else mesh.surface_get_array_index_len(surface) / 3
			if child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				shadow_only += triangles
				continue
			chunks += 1
			surfaces += mesh.get_surface_count()
			drawn += triangles
			if child.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				casting += triangles
			if child.position != Vector3.ZERO:
				loose_meshes += 1
		print("%s: cells draw %d triangles, baked %d (%.0f%%); of those cast a shadow %d; shadow blocks %d; %d mesh instances (%d loose), %d surfaces (draw calls)" % [
			job[0], unbaked, drawn, 100.0 * drawn / maxf(unbaked, 1.0), casting, shadow_only, chunks, loose_meshes, surfaces])
		baked.free()


func _cell_triangles(grid: GridMap) -> int:
	var per_item := {}
	var total := 0
	for cell in grid.get_used_cells():
		var item := grid.get_cell_item(cell)
		if not per_item.has(item):
			var mesh := grid.mesh_library.get_item_mesh(item)
			var triangles := 0
			if mesh != null:
				for surface in mesh.get_surface_count():
					triangles += mesh.surface_get_array_len(surface) / 3
			per_item[item] = triangles
		total += per_item[item]
	return total
