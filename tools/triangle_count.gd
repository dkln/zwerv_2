extends SceneTree
## Counts triangles per tile at each LOD level (fine / coarse / very coarse) and shows
## the four heaviest tiles per library. Coarse meshes come from the "lod"/"lod2" meta
## the importer stores on each tile mesh.
## usage: Godot --headless --script tools/triangle_count.gd

const Common = preload("res://tools/tool_common.gd")
const LIBRARIES := ["grond", "gebouwen", "props", "details"]


func _init() -> void:
	Common.watchdog(self)
	for cat in LIBRARIES:
		var lib: MeshLibrary = load("res://assets/libraries/%s.res" % cat)
		var tot := [0, 0, 0]
		var list := []   # [fine, name, coarse, very coarse]
		for id in lib.get_item_list():
			var m := lib.get_item_mesh(id)
			var t0 := _tris(m)
			var t1 := _tris(m.get_meta("lod", null))
			var t2 := _tris(m.get_meta("lod2", null))
			tot[0] += t0; tot[1] += t1; tot[2] += t2
			list.append([t0, lib.get_item_name(id), t1, t2])
		list.sort()
		list.reverse()
		var n := lib.get_item_list().size()
		print("%s: average per tile  fine %d  coarse %d  very coarse %d" % [cat, tot[0] / n, tot[1] / n, tot[2] / n])
		for i in 4:
			print("    ", list[i][1], ": ", list[i][0], " / ", list[i][2], " / ", list[i][3])
	quit()


## Number of triangles of a (non-indexed) mesh; 0 for null.
func _tris(m: Mesh) -> int:
	if m == null:
		return 0
	var n := 0
	for s in m.get_surface_count():
		n += m.surface_get_array_len(s) / 3
	return n
