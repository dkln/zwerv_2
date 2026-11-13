extends RefCounted
## Unit tests of the streamed finest level of the merged town (scripts/world/town/region_stream.gd):
## a baked layer saved per region with its materials shared, only the regions near an anchor
## loaded, those far off dropped again, and `regions_changed` when chunks come or go.

const RegionStream = preload("res://scripts/world/town/region_stream.gd")
const FOLDER := "user://proef_regios"

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## A baked layer of `count` chunks in a row along x, 100 m apart, all with one material.
func _baked(count: int) -> Node3D:
	var baked := Node3D.new()
	var material := StandardMaterial3D.new()
	for chunk_index in count:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(8.0, 2.0, 8.0)
		var arrays := mesh.get_mesh_arrays()
		var chunk_mesh := ArrayMesh.new()
		chunk_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		chunk_mesh.surface_set_material(0, material)
		var chunk := MeshInstance3D.new()
		chunk.mesh = chunk_mesh
		chunk.position = Vector3(chunk_index * 100.0, 0.0, 0.0)
		baked.add_child(chunk)
	return baked


func _clean() -> void:
	for file_name in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(FOLDER.path_join(file_name))
	DirAccess.remove_absolute(FOLDER)


func _load_until_settled(stream: Node3D, anchors: Array) -> void:
	for attempt in 400:
		stream.update(anchors)
		if stream.is_ready_around(anchors):
			break
		OS.delay_msec(5)
	stream.update(anchors)


## A baked layer is saved per region with its material shared; only the regions near an
## anchor (camera, player) are loaded and those far off dropped again.
func test_saved_per_region_and_loaded_only_near(test) -> void:
	_clean()
	var baked := _baked(6)
	test.check(not RegionStream.is_saved(FOLDER), "nog niet bewaard")
	RegionStream.save_regions(baked, FOLDER)
	test.check(RegionStream.is_saved(FOLDER), "bewaard: de index staat er")
	var files := DirAccess.get_files_at(FOLDER)
	var region_files := Array(files).filter(func(file_name: String) -> bool: return file_name.begins_with("regio_"))
	var material_files := Array(files).filter(func(file_name: String) -> bool: return file_name.begins_with("materiaal_"))
	test.check(region_files.size() == 6, "elke chunk ver uit elkaar in een eigen regio (%d)" % region_files.size())
	test.check(material_files.size() == 1, "het materiaal één keer, gedeeld (%d)" % material_files.size())
	baked.free()
	var stream: Node3D = RegionStream.open(FOLDER, "Proef_merged", Transform3D.IDENTITY)
	tree.root.add_child(stream)
	var changes := [0]
	stream.regions_changed.connect(func() -> void: changes[0] += 1)
	test.check(stream.region_counts() == Vector2i(6, 0), "zes regio's, nog niets geladen")
	var near_first: Array = [Vector3(0.0, 0.0, 0.0)]
	test.check(not stream.is_ready_around(near_first), "bij de eerste: nog niet klaar")
	_load_until_settled(stream, near_first)
	test.check(stream.is_ready_around(near_first) and stream.region_counts().y == 1, "alleen de regio dichtbij geladen (%d)" % stream.region_counts().y)
	test.check(stream.find_children("*", "MeshInstance3D", true, false).size() == 1 and changes[0] >= 1, "zijn chunk staat erin, en het is gemeld")
	var materials := {}
	var near_last: Array = [Vector3(500.0, 0.0, 0.0)]
	_load_until_settled(stream, near_last)
	test.check(stream.region_counts().y == 1 and stream.is_ready_around(near_last), "verderop: die regio erin, de eerste weer weg")
	var both: Array = [Vector3(0.0, 0.0, 0.0), Vector3(500.0, 0.0, 0.0)]
	_load_until_settled(stream, both)
	test.check(stream.region_counts().y == 2, "twee ankers (camera en speler): beide regio's")
	for chunk: MeshInstance3D in stream.find_children("*", "MeshInstance3D", true, false):
		materials[chunk.mesh.surface_get_material(0)] = true
	test.check(materials.size() == 1, "de regio's delen hetzelfde materiaal")
	stream.free()
	_clean()
