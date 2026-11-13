extends SceneTree
## What makes a bake cache of user://merged (LevelOfDetail, layer_baker.gd) so big: its
## meshes, surfaces, vertices and triangles, whether they are indexed, which arrays each
## surface has and how many bytes they take (as stored: the surface's vertex, attribute and
## index buffers), and how many vertices could be shared (the same position, normal, colour).
##   tools/godot.sh --headless --script tools/check/cache_audit.gd -- stad_Grond__
const Common = preload("res://tools/tool_common.gd")


func _init() -> void:
	Common.watchdog(self, 280)
	var wanted := Common.arg(0, "stad_Grond__")
	var path := ""
	for file_name in DirAccess.get_files_at("user://merged"):
		if file_name.begins_with(wanted):
			path = "user://merged/" + file_name
	print("bestand  ", path, "  ", FileAccess.get_file_as_bytes(path).size() / 1048576, " MB")
	var scene := (load(path) as PackedScene).instantiate()
	var meshes := 0
	var surfaces := 0
	var vertices := 0
	var triangles := 0
	var indexed := 0
	var vertex_bytes := 0
	var attribute_bytes := 0
	var index_bytes := 0
	var formats := {}
	var unique_sample := 0
	var sampled := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh as ArrayMesh
		if mesh == null:
			continue
		meshes += 1
		for surface in mesh.get_surface_count():
			surfaces += 1
			var count := mesh.surface_get_array_len(surface)
			var index_count := mesh.surface_get_array_index_len(surface)
			vertices += count
			triangles += (index_count if index_count > 0 else count) / 3
			if index_count > 0:
				indexed += 1
			var format := mesh.surface_get_format(surface)
			formats[format] = int(formats.get(format, 0)) + 1
			var data: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), surface)
			vertex_bytes += (data.get("vertex_data", PackedByteArray()) as PackedByteArray).size()
			attribute_bytes += (data.get("attribute_data", PackedByteArray()) as PackedByteArray).size()
			index_bytes += (data.get("index_data", PackedByteArray()) as PackedByteArray).size()
			# how many of its vertices are the same as another (could be shared with indices)
			if sampled < 0:
				var arrays := mesh.surface_get_arrays(surface)
				var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
				var seen := {}
				for vertex_index in positions.size():
					seen[[positions[vertex_index], normals[vertex_index], colours[vertex_index] if vertex_index < colours.size() else Color()]] = true
				unique_sample += seen.size()
				sampled += positions.size()
	print("meshes %d, surfaces %d (%d met index)" % [meshes, surfaces, indexed])
	print("hoekpunten %d, driehoeken %d (%.1f hoekpunten per driehoek)" % [vertices, triangles, float(vertices) / maxf(triangles, 1.0)])
	print("bytes: hoekpunten %d MB, attributen %d MB, index %d MB" % [vertex_bytes / 1048576, attribute_bytes / 1048576, index_bytes / 1048576])
	print("bytes per hoekpunt: %.1f" % (float(vertex_bytes + attribute_bytes) / maxf(vertices, 1.0)))
	print("formaten: ", formats)
	print("uniek in steekproef: %d van %d (%.0f%%)" % [unique_sample, sampled, 100.0 * unique_sample / maxf(sampled, 1.0)])
	Common.finish(self, 0)
