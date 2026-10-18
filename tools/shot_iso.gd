extends SceneTree
## Isometrische screenshot van een scene.
## gebruik: Godot --script tools/shot_iso.gd -- <scene> <uit.png> focus_x focus_z grootte
func _init():
	var a := OS.get_cmdline_user_args()
	var sc: Node = load(a[0]).instantiate()
	var cam: Camera3D = sc.get_node("Camera")
	cam.set_script(null)
	get_root().add_child(sc)
	get_root().size = Vector2i(1920, 1080)
	await process_frame
	var focus := Vector3(float(a[2]), 0, float(a[3]))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(a[4])
	cam.far = 4000.0
	cam.near = 1.0
	cam.rotation_degrees = Vector3(-35.264, 45, 0)
	cam.global_position = focus + Vector3(1, 1, 1).normalized() * 500.0
	for i in 15:
		await process_frame
	get_root().get_texture().get_image().save_png(a[1])
	print("saved ", a[1])
	quit()
