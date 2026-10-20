extends SceneTree
## Isometric screenshot of a scene (tour off, free-camera script removed), taken once
## DetailNiveau has finished merging.
## usage: Godot --script tools/shot_iso.gd -- <scene> <out.png> focus_x focus_z view_size
## focus in world metres; view_size = metres in view (see scripts/iso_camera.gd). For
## the tour scene the map part around the focus is loaded.

const Common = preload("res://tools/tool_common.gd")


func _init() -> void:
	Common.watchdog(self)
	var sc := Common.instantiate(Common.arg(0))
	var out := Common.arg(1)
	Common.load_part_at(sc, Common.arg_float(3))
	get_root().add_child(sc)
	Common.render_size(self, Vector2i(1920, 1080))
	await process_frame
	await Common.wait_for_merge(sc)
	Common.place_iso(sc, Vector3(Common.arg_float(2), 0, Common.arg_float(3)), Common.arg_float(4))
	await Common.wait_frames(self, 15)
	Common.save_screenshot(self, out)
	print("saved ", out)
	quit()
