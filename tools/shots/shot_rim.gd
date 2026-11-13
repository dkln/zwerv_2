extends SceneTree
## The rim round the player where something hides it (PlayerModel.rim, figure_rim_mask.gdshader):
## six views side by side, the rim on in all of them. Top row, the iso view of the game: the figure
## in the open (no rim), half behind a wall, wholly behind it, and with the wall behind it (no
## rim). Bottom row, from above (the follow camera's steep_pitch): in the open (no rim: its own
## head and shoulders do not count) and half under a roof. Needs a window.
## usage: Godot --script tools/shots/shot_rim.gd -- <output.png>

const Common = preload("res://tools/tool_common.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")
const SIZE := Vector2i(1800, 1000)
const BACKGROUND := Color("#5A6070")
const ABOVE_PITCH := -88.0
## Each view: "wall" how far the wall stands sideways (metres across the view, INF: no wall),
## "behind" the wall on the far side of the figure, "above" looked at from above.
const VIEWS := [
	[{"wall": INF}, {"wall": 0.35}, {"wall": 0.0}, {"wall": 0.0, "behind": true}],
	[{"wall": INF, "above": true}, {"wall": 0.0, "above": true}],
]


func _init() -> void:
	Common.watchdog(self, 120)
	var out := Common.arg(0, "user://rand.png")
	Common.render_size(self, SIZE)
	var rows := VBoxContainer.new()
	rows.size = SIZE
	rows.add_theme_constant_override("separation", 0)
	get_root().add_child.call_deferred(rows)
	await process_frame
	for views: Array in VIEWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rows.add_child(row)
		for settings: Dictionary in views:
			_view(row, settings)
	for frame_index in 40:
		await process_frame
	Common.save_screenshot(self, out)
	print("opgeslagen: ", ProjectSettings.globalize_path(out))
	quit()


func _view(row: Control, settings: Dictionary) -> SubViewportContainer:
	var across := float(settings.wall)
	var above := bool(settings.get("above", false))
	var container := SubViewportContainer.new()
	row.add_child(container)
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var view := SubViewport.new()
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	container.add_child(view)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	var world := WorldEnvironment.new()
	world.environment = environment
	view.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	view.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	view.add_child(floor_mesh)
	var model := PlayerModel.new()
	model.archetype_id = "martin"
	model.coat = false
	model.idle = false
	model.figure_scale = 0.78
	view.add_child(model)
	model.rim = true
	var towards := Iso.direction(Iso.ROTATION.y)
	var flat := Vector3(towards.x, 0.0, towards.z).normalized()
	var side := Vector3.UP.cross(flat).normalized()
	if across != INF:
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		wall.mesh = box
		view.add_child(wall)
		if above:
			# a roof 2.5 m up over half the figure (a canopy, a tree, a bridge)
			box.size = Vector3(1.4, 0.3, 1.4)
			wall.position = side * (across * 2.0 + 0.85) + Vector3.UP * 2.5
			var roof_colour := StandardMaterial3D.new()
			roof_colour.albedo_color = Color("#7A6A5A")
			wall.material_override = roof_colour
		else:
			# a wall between the figure and the camera (or behind it), 3 m high; `across`
			# shifts it sideways
			box.size = Vector3(1.6, 3.0, 0.4)
			var wall_at := flat * (-1.0 if settings.get("behind", false) else 1.5) + side * across * 2.0 + Vector3.UP * 1.5
			wall.look_at_from_position(wall_at, wall_at + flat, Vector3.UP)
	var camera := Camera3D.new()
	camera.fov = 20.0
	view.add_child(camera)
	Iso.place(camera, Vector3(0.0, 0.8, 0.0), 4.0, Iso.ROTATION.y)
	if above:
		camera.rotation_degrees = Vector3(ABOVE_PITCH, Iso.ROTATION.y, 0.0)
		camera.global_position = Vector3(0.0, 0.8, 0.0) + camera.global_basis.z * Iso.distance(4.0)
	return container
