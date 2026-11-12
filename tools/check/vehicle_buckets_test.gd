extends SceneTree
## The clustered lookup of the vehicles (Vehicle.near, buckets of Vehicle.BUCKET_SIZE metres,
## filled once per physics frame): with the town full of traffic, for many spots and radii it
## must give every vehicle the old way (going through all of them) finds within the radius plus
## its own reach, never fewer (a few more is fine), and far fewer than all of them. Also
## Traffic._apart (room for a new vehicle) must agree with going through all vehicles.
## usage: tools/godot.sh --headless --script tools/check/vehicle_buckets_test.gd

const Common = preload("res://tools/tool_common.gd")
const SPOTS := 400
const RADII := [0.0, 4.0, 12.0, 32.0, 80.0]

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 200)
	var scene := Common.instantiate(Common.CITY)
	for node_name in ["DetailNiveau", "Rook", "Verhaal"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	var traffic: Traffic = scene.get_node("Verkeer")
	traffic.whole_town = true
	traffic.vehicle_count = 160
	get_root().add_child(scene)
	for frame_index in 90:
		paused = false
		await physics_frame
	var vehicles: Array[Vehicle] = Vehicle.all_vehicles.filter(func(vehicle: Vehicle) -> bool: return is_instance_valid(vehicle) and vehicle.is_inside_tree())
	print("voertuigen in de stad: %d" % vehicles.size())
	_check(vehicles.size() > 100, "de stad zit vol verkeer (%d)" % vehicles.size())
	var random := RandomNumberGenerator.new()
	random.seed = 3
	var missed := 0
	var looked := 0
	var found_total := 0
	for spot_index in SPOTS:
		# spots on and round the vehicles, and anywhere in the town
		var spot: Vector3
		if spot_index % 2 == 0:
			spot = vehicles[random.randi() % vehicles.size()].global_position + Vector3(random.randf_range(-20.0, 20.0), 0.0, random.randf_range(-20.0, 20.0))
		else:
			spot = Vector3(random.randf_range(0.0, 900.0), 0.0, random.randf_range(0.0, 700.0))
		for radius: float in RADII:
			var near := Vehicle.near(spot, radius)
			found_total += near.size()
			looked += 1
			for vehicle in vehicles:
				if vehicle.global_position.distance_to(spot) <= radius + vehicle._reach() and not vehicle in near:
					missed += 1
	_check(missed == 0, "Vehicle.near mist er nooit een (%d gemist)" % missed)
	var average := float(found_total) / maxf(looked, 1)
	print("gemiddeld %.1f van de %d voertuigen bekeken per vraag" % [average, vehicles.size()])
	_check(average < vehicles.size() * 0.5, "en bekijkt er veel minder dan allemaal (%.1f van %d)" % [average, vehicles.size()])
	# room for a new one: the same as going through all of them
	var network := RoadNetwork.of(scene)
	var cells := network.cells()
	var disagree := 0
	for try_index in 300:
		var cell: Vector3i = cells[random.randi() % cells.size()]
		var centre := network.centre(cell)
		var free_the_old_way := vehicles.all(func(vehicle: Vehicle) -> bool: return vehicle.global_position.distance_to(centre) >= traffic.spacing)
		var empty: Array[Vector3] = []
		if traffic._apart(cell, empty) != free_the_old_way:
			disagree += 1
	_check(disagree == 0, "ruimte voor een nieuwe: als vroeger (%d anders)" % disagree)
	print("clustering ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit(0 if _problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
