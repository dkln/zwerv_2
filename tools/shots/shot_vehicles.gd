extends SceneTree
## Renders every kind of vehicle next to each other on a plain floor, without a town (with
## its wheels, lamps off, its front wheels at full lock and a trailer at an angle), from one
## side: to check the models. Needs a window.
## usage: Godot --script tools/shots/shot_vehicles.gd -- <output.png> [side: 1 front, -1 back]
##        [number in KINDS for a close-up of that one]

const Common = preload("res://tools/tool_common.gd")
const KINDS := [
	["res://scripts/characters/car.gd", ""],
	["res://scripts/characters/hatchback.gd", ""],
	["res://scripts/characters/suv.gd", ""],
	["res://scripts/characters/van.gd", ""],
	["res://scripts/characters/trailer_car.gd", ""],
	["res://scripts/characters/truck.gd", ""],
	["res://scripts/characters/city_bus.gd", ""],
]


func _init() -> void:
	Common.watchdog(self)
	var out := Common.arg(0, "/tmp/vehicles.png")
	var side := Common.arg_float(1, 1.0)
	var root := Node3D.new()
	root.name = "Voertuigshow"
	get_root().add_child(root)
	var props := GridMap.new()
	props.name = "Props"
	props.mesh_library = load("res://assets/libraries/props.res")
	root.add_child(props)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.62, 0.66, 0.56)
	floor_mesh.material_override = floor_material
	root.add_child(floor_mesh)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35 + (0.0 if side > 0.0 else 180.0), 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.75, 0.8, 0.9)
	world.environment.ambient_light_energy = 0.7
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.55, 0.65, 0.75)
	root.add_child(world)
	await process_frame
	var across := 0.0
	var vehicles: Array[Vehicle] = []
	for entry: Array in KINDS:
		var vehicle: Vehicle = load(entry[0]).new()
		root.add_child(vehicle)
		vehicle.global_position = Vector3(across, 0.0, 0.0)
		vehicle.set_process(false)
		vehicle._steering = deg_to_rad(vehicle.max_steering_degrees)
		for wheel in vehicle._wheels:
			wheel.rotation.y = vehicle._steering if wheel.position.z > 0.0 else 0.0
		vehicle._snap_body()
		if vehicle._trailer:
			# the trailer at an angle on its pivot, as in a corner
			var ball := vehicle.global_transform * vehicle.hitch_position
			vehicle._trailer.global_transform = Transform3D(Basis(Vector3.UP, 0.45), ball)
		across += 4.2
		vehicles.append(vehicle)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.fov = 32.0
	var middle := Vector3((across - 4.2) * 0.5, 0.6, 0.0)
	camera.look_at_from_position(middle + Vector3(9.0 * side, 13.0, 26.0 * side), middle)
	if Common.arg_count() > 2:
		var focus := vehicles[int(Common.arg_float(2))]
		var close_up := focus.global_transform * focus.hitch_position
		camera.look_at_from_position(close_up + Vector3(3.0, 2.5, 5.0 * side), close_up)
	Common.render_size(self, Vector2i(1800, 900))
	await Common.wait_frames(self, 10)
	Common.save_screenshot(self, out)
	print("saved ", out)
	quit()
