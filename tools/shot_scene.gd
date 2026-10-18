extends SceneTree
## Screenshot van een scene vanaf een camerapositie.
## gebruik: Godot --script tools/shot_scene.gd -- <scene> <uit.png> px py pz tx ty tz [fov]
func _init():
	var a := OS.get_cmdline_user_args()
	var sc: Node = load(a[0]).instantiate()
	get_root().add_child(sc)
	get_root().size = Vector2i(1920, 1080)
	var cam: Camera3D = sc.get_node("Camera")
	cam.set_script(null)
	await process_frame
	cam.fov = float(a[8]) if a.size() > 8 else 60.0
	cam.look_at_from_position(Vector3(float(a[2]), float(a[3]), float(a[4])), Vector3(float(a[5]), float(a[6]), float(a[7])))
	for i in 12:
		await process_frame
	get_root().get_texture().get_image().save_png(a[1])
	print("saved ", a[1])
	quit()
