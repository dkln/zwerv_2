extends SceneTree
## A trial for a smaller bake cache: loads a cache of user://merged, gives every surface an
## index (SurfaceTool.index: vertices that are the same in everything are shared), saves the
## result beside it (user://proef_index.scn) and says what it saves: vertices, bytes, the
## file, and how long each takes to load.
##   tools/godot.sh --headless --script tools/check/cache_index_trial.gd -- stad_Grond__
const Common = preload("res://tools/tool_common.gd")


func _init() -> void:
	Common.watchdog(self, 290)
	var wanted := Common.arg(0, "stad_Grond__")
	var path := ""
	for file_name in DirAccess.get_files_at("user://merged"):
		if file_name.begins_with(wanted):
			path = "user://merged/" + file_name
	var started := Time.get_ticks_msec()
	var scene := (load(path) as PackedScene).instantiate()
	print("laden oud   %d ms" % (Time.get_ticks_msec() - started))
	var before := 0
	var after := 0
	var index_count := 0
	var with_tangent := 0
	started = Time.get_ticks_msec()
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var mesh := instance.mesh as ArrayMesh
		if mesh == null:
			continue
		var indexed := ArrayMesh.new()
		for surface in mesh.get_surface_count():
			before += mesh.surface_get_array_len(surface)
			if mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_TANGENT:
				with_tangent += 1
			var tool := SurfaceTool.new()
			tool.create_from(mesh, surface)
			tool.index()
			tool.commit(indexed, mesh.surface_get_format(surface) & ~Mesh.ARRAY_FORMAT_INDEX)
			var last := indexed.get_surface_count() - 1
			indexed.surface_set_material(last, mesh.surface_get_material(surface))
			after += indexed.surface_get_array_len(last)
			index_count += indexed.surface_get_array_index_len(last)
		instance.mesh = indexed
	print("indexeren   %d ms" % (Time.get_ticks_msec() - started))
	print("hoekpunten  %d -> %d (%.0f%%), indices %d, surfaces met tangent %d" % [before, after, 100.0 * after / maxf(before, 1.0), index_count, with_tangent])
	for node in scene.find_children("*", "", true, false):
		node.owner = scene
	var packed := PackedScene.new()
	packed.pack(scene)
	var trial := "user://proef_index.scn"
	ResourceSaver.save(packed, trial, ResourceSaver.FLAG_COMPRESS)
	print("bestand     %d MB -> %d MB" % [FileAccess.get_file_as_bytes(path).size() / 1048576, FileAccess.get_file_as_bytes(trial).size() / 1048576])
	scene.free()
	started = Time.get_ticks_msec()
	var again := (ResourceLoader.load(trial, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	print("laden nieuw %d ms" % (Time.get_ticks_msec() - started))
	again.free()
	Common.finish(self, 0)
