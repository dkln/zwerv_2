extends SceneTree
## Telt driehoeken per tile (fijn / grof / heel grof) en toont de zwaarste tiles.
## gebruik: Godot --headless --script tools/driehoeken.gd
func _tris(m: Mesh) -> int:
	if m == null: return 0
	var n := 0
	for s in m.get_surface_count():
		n += m.surface_get_array_len(s) / 3
	return n

func _init():
	for cat in ["grond", "gebouwen", "props", "details"]:
		var lib: MeshLibrary = load("res://assets/libraries/%s.res" % cat)
		var tot := [0, 0, 0]
		var lijst := []
		for id in lib.get_item_list():
			var m := lib.get_item_mesh(id)
			var t0 := _tris(m)
			var t1 := _tris(m.get_meta("lod") if m.has_meta("lod") else null)
			var t2 := _tris(m.get_meta("lod2") if m.has_meta("lod2") else null)
			tot[0] += t0; tot[1] += t1; tot[2] += t2
			lijst.append([t0, lib.get_item_name(id), t1, t2])
		lijst.sort()
		lijst.reverse()
		var n := lib.get_item_list().size()
		print("%s: gemiddeld per tile  fijn %d  grof %d  heel grof %d" % [cat, tot[0] / n, tot[1] / n, tot[2] / n])
		for i in 4:
			print("    ", lijst[i][1], ": ", lijst[i][0], " / ", lijst[i][2], " / ", lijst[i][3])
	quit()
