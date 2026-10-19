extends SceneTree
## Renders an overview grid of all tiles (.vox, recursively) in a folder with a simple
## sky, sun and SSAO, and saves a screenshot.
## usage: Godot --script tools/shot.gd -- <folder> <output.png> [columns] [spacing]
## spacing = distance between tile centres in metres (default 4.5; tiles are 4 m).

const Common = preload("res://tools/tool_common.gd")
const Builder = preload("res://addons/vox_tiles/library_builder.gd")


func _init() -> void:
	Common.watchdog(self)
	var dir := Common.arg(0, "res://assets/tiles/grond")
	var out := Common.arg(1, "/tmp/shot.png")
	var cols := int(Common.arg_float(2, 14))
	var spacing := Common.arg_float(3, 4.5)
	var files := PackedStringArray()
	Builder.list_vox(dir, files)
	files.sort()
	var root := Node3D.new()
	get_root().add_child(root)
	for i in files.size():
		var mi := MeshInstance3D.new()
		mi.mesh = load(files[i])
		mi.position = Vector3((i % cols) * spacing, 0, (i / cols) * spacing)
		root.add_child(mi)
	var rows := ceili(float(files.size()) / cols)
	root.add_child(_environment())
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	root.add_child(sun)
	# camera from the south, looking down at the centre of the grid
	var cam := Camera3D.new()
	var cx := (cols - 1) * spacing * 0.5
	var cz := (rows - 1) * spacing * 0.5
	var ext := maxf(cols, rows) * spacing
	root.add_child(cam)
	await process_frame
	cam.look_at_from_position(Vector3(cx, ext * 0.75, cz + ext * 0.65), Vector3(cx, 0, cz))
	cam.fov = 50
	get_root().size = Vector2i(1800, 1200)
	await Common.wait_frames(self, 8)
	Common.save_screenshot(self, out)
	print("saved ", out, " (", files.size(), " tiles)")
	quit()


## WorldEnvironment with a procedural sky (also as ambient light), filmic tone mapping and SSAO.
func _environment() -> WorldEnvironment:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	var env := WorldEnvironment.new()
	env.environment = e
	return env
