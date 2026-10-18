extends SceneTree
## Rendert een overzicht van tiles uit een map en slaat een screenshot op.
## gebruik: Godot --script tools/shot.gd -- <map> <uitvoer.png> [kolommen] [afstand]
func _init():
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "res://assets/tiles/grond"
	var out: String = args[1] if args.size() > 1 else "/tmp/shot.png"
	var cols: int = int(args[2]) if args.size() > 2 else 14
	var spacing: float = float(args[3]) if args.size() > 3 else 4.5
	var B = load("res://addons/vox_tiles/library_builder.gd")
	var files := PackedStringArray()
	B.list_vox(dir, files)
	files.sort()
	var root := Node3D.new()
	get_root().add_child(root)
	var i := 0
	for f in files:
		var mi := MeshInstance3D.new()
		mi.mesh = load(f)
		mi.position = Vector3((i % cols) * spacing, 0, (i / cols) * spacing)
		root.add_child(mi)
		i += 1
	var rows := ceili(float(i) / cols)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	root.add_child(sun)
	var cam := Camera3D.new()
	var cx := (cols - 1) * spacing * 0.5
	var cz := (rows - 1) * spacing * 0.5
	var ext := maxf(cols, rows) * spacing
	root.add_child(cam)
	await process_frame
	cam.look_at_from_position(Vector3(cx, ext * 0.75, cz + ext * 0.65), Vector3(cx, 0, cz))
	cam.fov = 50
	get_root().size = Vector2i(1800, 1200)
	for k in 8:
		await process_frame
	get_root().get_texture().get_image().save_png(out)
	print("saved ", out, " (", i, " tiles)")
	quit()
