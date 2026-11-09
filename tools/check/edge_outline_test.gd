extends SceneTree
## The outlines (scripts/effects/edge_outline.gd/.gdshader), with a window (shaders are not
## compiled headless): a block in front of a wall, seen by a camera with the outline quad;
## the picture must have a dark line along the block's edge and stay untouched elsewhere.
## Nothing is saved: only the pixels are counted.
## usage: tools/godot.sh --script tools/check/edge_outline_test.gd

const Common = preload("res://tools/tool_common.gd")
const EdgeOutline = preload("res://scripts/effects/edge_outline.gd")
const SIZE := Vector2i(320, 240)

var _problems := []


func _init() -> void:
	Common.watchdog(self, 60)
	Common.render_size(self, SIZE)
	var world := Node3D.new()
	get_root().add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.WHITE
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(light)
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color.WHITE
	var wall := MeshInstance3D.new()
	wall.mesh = BoxMesh.new()
	(wall.mesh as BoxMesh).size = Vector3(30, 30, 1)
	wall.material_override = white
	wall.position = Vector3(0, 0, -10)
	world.add_child(wall)
	var block := MeshInstance3D.new()
	block.mesh = BoxMesh.new()
	block.material_override = white
	world.add_child(block)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 5)
	world.add_child(camera)
	camera.make_current()
	camera.add_child(EdgeOutline.new())
	for frame_index in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	var dark := 0
	var dark_in_corner := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).v < 0.9:
				dark += 1
				if x < 40 and y < 40:
					dark_in_corner += 1
	print("donkere pixels: %d (in de hoek, waar alleen de muur is: %d) van %d" % [dark, dark_in_corner, image.get_width() * image.get_height()])
	_check(dark > 50, "lijn langs de rand van het blok")
	_check(dark < image.get_width() * image.get_height() / 10, "de rest blijft licht")
	_check(dark_in_corner == 0, "geen lijnen op een vlakke muur")
	print("randjes ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
