extends SceneTree
## Screenshot of a scene from a free camera position (tour off, free-camera script
## removed), taken once DetailNiveau has finished merging.
## usage: Godot --script tools/shot_scene.gd -- <scene> <out.png> px py pz tx ty tz [fov]
## p = camera position, t = point looked at (world metres); fov in degrees (default 60).

const Common = preload("res://tools/tool_common.gd")


func _init() -> void:
	Common.watchdog(self)
	var sc := Common.instantiate(Common.arg(0))
	var out := Common.arg(1)
	get_root().add_child(sc)
	get_root().size = Vector2i(1920, 1080)
	var cam: Camera3D = sc.get_node("Camera")
	await process_frame
	await Common.wait_for_merge(sc)
	cam.fov = Common.arg_float(8, 60.0)
	cam.look_at_from_position(Vector3(Common.arg_float(2), Common.arg_float(3), Common.arg_float(4)),
		Vector3(Common.arg_float(5), Common.arg_float(6), Common.arg_float(7)))
	await Common.wait_frames(self, 12)
	Common.save_screenshot(self, out)
	print("saved ", out)
	quit()
