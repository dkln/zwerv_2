extends SceneTree
## temporary: -- <out.png> cx cz size pitch yaw [more views as groups of 6 args]
const Common = preload("res://tools/tool_common.gd")
func _init() -> void:
	Common.watchdog(self, 180.0)
	if OS.get_cmdline_user_args().size() % 6 != 0:
		push_error("usage: -- <out.png> cx cz size pitch yaw [...]")
		quit(1)
		return
	var sc: Node = load(Common.WORLD).instantiate()
	var root := Node3D.new()
	get_root().add_child(root)
	for c in sc.get_children():
		if c is GridMap or c is WorldEnvironment or c is DirectionalLight3D:
			sc.remove_child(c)
			root.add_child(c)
	sc.free()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 4000
	root.add_child(cam)
	Common.render_size(self, Vector2i(1500, 1000))
	await process_frame
	var args := OS.get_cmdline_user_args()
	if OS.get_environment("EDITOR_VIEW") == "1":
		RenderingServer.global_shader_parameter_set("zwervr_editor", 1.0)
	for i in range(0, args.size(), 6):
		cam.size = float(args[i + 3])
		var pitch := deg_to_rad(float(args[i + 4]))
		var yaw := deg_to_rad(float(args[i + 5]))
		var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
		var t := Vector3(float(args[i + 1]), 0, float(args[i + 2]))
		cam.look_at_from_position(t + dir * 1500, t)
		await Common.wait_frames(self, 8)
		get_root().get_texture().get_image().save_png(args[i])
	quit()
