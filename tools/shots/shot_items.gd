extends SceneTree
## Photographs tiles of the MeshLibraries one by one, each in its own PNG with a transparent
## background, trimmed to what is on it: from the front, slightly from above and the side, lit by a sun and a soft sky.
## For overviews (the shop fronts and their signs). Needs a window.
## usage: Godot --script tools/shots/shot_items.gd -- <list file> <output folder> [size]
##   list file: one "<library> <item name>" per line, e.g. "details tekst/naam_bakker_1" or
##   "gebouwen herenhuis_1900/herenhuis_1900_bg_bakker"; the PNG is the item name with "/"
##   as "__". A sign (a thin plate) is shot straight from the front.

const Common = preload("res://tools/tool_common.gd")
const LIBRARIES := "res://assets/libraries/%s.res"


func _init() -> void:
	Common.watchdog(self, 300)
	var list_path := Common.arg(0, "")
	var out := Common.arg(1, "/tmp/items")
	var size := int(Common.arg_float(2, 480))
	Common.render_size(self, Vector2i(size, size))
	var view := SubViewport.new()
	view.size = Vector2i(size, size)
	view.transparent_bg = true
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child.call_deferred(view)
	await process_frame
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.64, 0.7)
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	view.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.1
	view.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	view.add_child(camera)
	var instance := MeshInstance3D.new()
	view.add_child(instance)
	var libraries := {}
	var lines := FileAccess.get_file_as_string(list_path).split("\n", false)
	var done := 0
	for line in lines:
		var parts := line.strip_edges().split(" ", false, 1)
		if parts.size() < 2:
			continue
		if not libraries.has(parts[0]):
			libraries[parts[0]] = load(LIBRARIES % parts[0])
		var library: MeshLibrary = libraries[parts[0]]
		var item := library.find_item_by_name(parts[1])
		if item < 0:
			print("niet gevonden: ", line)
			continue
		instance.mesh = library.get_item_mesh(item)
		instance.transform = library.get_item_mesh_transform(item)
		var bounds := instance.transform * instance.mesh.get_aabb()
		var middle := bounds.get_center()
		var flat := bounds.size.z < 0.4 * maxf(bounds.size.x, bounds.size.y)
		# from the front (+z), a sign straight on, a building a little from above and the side
		var direction := Vector3(0.0, 0.05, 1.0) if flat else Vector3(0.45, 0.35, 1.0)
		direction = direction.normalized()
		camera.size = maxf(bounds.size.x, bounds.size.y) * (1.12 if flat else 1.35)
		camera.look_at_from_position(middle + direction * 20.0, middle, Vector3.UP)
		for frame_index in 4:
			await process_frame
		var image := view.get_texture().get_image()
		# trimmed to what is on it, with a small margin
		var used := image.get_used_rect().grow(6).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		if used.has_area():
			image = image.get_region(used)
		image.save_png("%s/%s.png" % [out, parts[1].replace("/", "__")])
		done += 1
	print("gefotografeerd: ", done)
	quit()
