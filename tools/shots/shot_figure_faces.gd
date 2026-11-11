extends SceneTree
## Shows the faces of a figure before and after merging (VoxelFigure.merge_faces): the same
## figure twice side by side, left a face per voxel side, right the merged rectangles; at the
## top as in the game (with the outline), below as a wireframe, each with how many faces,
## triangles and vertices it has. Needs a window.
## usage: Godot --script tools/shots/shot_figure_faces.gd -- <output.png> [martin|jos|...|stad]
##   "stad": a townsperson (TownsfolkFigure), else a player archetype (PlayerModel).

const Common = preload("res://tools/tool_common.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")
const SIZE := Vector2i(1600, 1400)
const BACKGROUND := Color("#2B3044")


func _init() -> void:
	Common.watchdog(self, 120)
	var out := Common.arg(0, "/tmp/figuur_vlakken.png")
	var who := Common.arg(1, "martin")
	RenderingServer.set_debug_generate_wireframes(true)
	Common.render_size(self, SIZE)
	var screen := VBoxContainer.new()
	screen.size = SIZE
	screen.add_theme_constant_override("separation", 0)
	get_root().add_child.call_deferred(screen)
	var counts := []
	for wireframe in [false, true]:
		var row := HBoxContainer.new()
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 0)
		screen.add_child(row)
		for merged in [false, true]:
			var parts := _parts(who, merged, not wireframe)
			var shown := _show(parts, wireframe)
			row.add_child(shown)
			if not wireframe:
				counts.append(_count(parts))
			var label := Label.new()
			var count: Dictionary = counts[int(merged)]
			label.text = "%s\n%d vlakken, %d driehoeken, %d hoekpunten" % [
				"samengevoegd" if merged else "per voxelzijde (oud)", count.faces, count.triangles, count.vertices]
			label.add_theme_font_size_override("font_size", 26)
			label.add_theme_color_override("font_color", Color("#FFE9B8"))
			label.position = Vector2(20, 14)
			shown.add_child(label)
	for frame_index in 30:
		await process_frame
	Common.save_screenshot(self, out)
	print("opgeslagen: ", out)
	for index in counts.size():
		print(("samengevoegd: " if index == 1 else "per voxelzijde: ") + str(counts[index]))
	quit()


## The parts of the figure (`who`), merged or not; `outlined`: with the outline as in the game.
func _parts(who: String, merged: bool, outlined: bool) -> Dictionary:
	var figure := PlayerModel.VoxelFigure.new()
	var rig := {}
	var voxel := PlayerModel.VOXEL
	if who == "stad":
		TownsfolkFigure._build_voxels(figure, TownsfolkFigure.look_for(1234))
		figure.centre_cell = TownsfolkFigure.CENTRE_CELL
		figure.simplify()
		rig = TownsfolkFigure.RIG
		voxel = TownsfolkFigure.VOXEL
	else:
		figure = PlayerModel.voxels_for(who)
		rig = PlayerModel.RIGS.get(who, {})
	figure.merge_faces = merged
	var materials := {}
	for kind: String in PlayerModel.CLOTH.keys() + PlayerModel.MATERIALS.keys() + ["glow"]:
		materials[kind] = PlayerModel.material_for(kind, outlined)
	return figure.to_parts(voxel, rig, materials, PlayerModel.graded)


## A view of these parts (all at the figure's origin: the limbs at rest), from the front at
## an angle; `wireframe`: only the edges of the triangles.
func _show(parts: Dictionary, wireframe: bool) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var view := SubViewport.new()
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	if wireframe:
		view.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
	container.add_child(view)
	var bounds := AABB()
	var first := true
	for part: String in parts.meshes:
		var instance := MeshInstance3D.new()
		instance.mesh = parts.meshes[part]
		view.add_child(instance)
		bounds = instance.mesh.get_aabb() if first else bounds.merge(instance.mesh.get_aabb())
		first = false
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	var world := WorldEnvironment.new()
	world.environment = environment
	view.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	view.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = bounds.size.y * 1.25
	var middle := bounds.get_center()
	var direction := Vector3(0.55, 0.3, 1.0).normalized()
	view.add_child(camera)
	camera.look_at_from_position(middle + direction * 10.0, middle, Vector3.UP)
	return container


func _count(parts: Dictionary) -> Dictionary:
	var vertices := 0
	for part: String in parts.meshes:
		var mesh: ArrayMesh = parts.meshes[part]
		for surface in mesh.get_surface_count():
			vertices += mesh.surface_get_array_len(surface)
	# vertices: four corners per face (the mesh has no index, so it stores six)
	return {"faces": vertices / 6, "triangles": vertices / 3, "vertices": vertices / 6 * 4}
