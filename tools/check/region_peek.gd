extends SceneTree
## What is in one region file of a streamed level (RegionStream): its chunks, vertices, and
## where its materials come from (shared with the libraries, or a copy of their own).
const Common = preload("res://tools/tool_common.gd")
func _init() -> void:
	Common.watchdog(self, 100)
	var folder := "user://merged/" + Common.arg(0, "")
	var biggest := ""
	var biggest_size := 0
	for file_name in DirAccess.get_files_at(folder):
		var size := FileAccess.open(folder.path_join(file_name), FileAccess.READ).get_length()
		if file_name.ends_with(".scn") and size > biggest_size:
			biggest_size = size
			biggest = file_name
	var scene := (load(folder.path_join(biggest)) as PackedScene).instantiate()
	var vertices := 0
	var material_paths := {}
	var chunks := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		chunks += 1
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			vertices += mesh.surface_get_array_len(surface)
			var material := mesh.surface_get_material(surface)
			var where := material.resource_path if material else "geen"
			material_paths[where.get_slice("::", 0)] = int(material_paths.get(where.get_slice("::", 0), 0)) + 1
	print(biggest, " ", biggest_size / 1048576, " MB, chunks ", chunks, ", hoekpunten ", vertices)
	print("materialen uit: ", material_paths)
	Common.finish(self, 0)
