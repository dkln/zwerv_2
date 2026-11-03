extends SceneTree
## Lets all the traffic of scenes/stad.tscn (the Auto, the SUV and what the node Verkeer
## adds) drive on its own, headless and faster than real time, and prints per vehicle:
## distance, crashes and the longest it stood still; and the physics time per step, so you
## can see what the traffic costs. Standing still for over STUCK_AFTER simulated seconds
## counts as stuck (no traffic light takes that long).
## usage: Godot --headless --script tools/check/traffic_test.gd -- [simulated seconds]

const Common = preload("res://tools/tool_common.gd")
const TIME_SCALE := 8
const STEP := 1.0 / 60.0
const STUCK_AFTER := 90.0


func _init() -> void:
	Common.watchdog(self, 900)
	var seconds := Common.arg_float(0, 300.0)
	var scene := Common.instantiate("res://scenes/stad.tscn")
	for node_name in ["DetailNiveau", "Rook", "Grassprieten", "Rondvlucht"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	Engine.time_scale = TIME_SCALE
	Engine.physics_ticks_per_second = 60 * TIME_SCALE
	Engine.max_physics_steps_per_frame = 4 * TIME_SCALE
	get_root().add_child(scene)
	await process_frame
	await process_frame
	var vehicles: Array[Vehicle] = Vehicle.all_vehicles.duplicate()
	print("voertuigen: ", vehicles.size())
	var distance := {}
	var crashes := {}
	var standing := {}
	var longest_stand := {}
	var was_crashed := {}
	var last_position := {}
	for vehicle in vehicles:
		if not vehicle.has_node("Carrosserie/Model"):
			print("FOUT: geen model: ", vehicle.name)
		distance[vehicle] = 0.0
		crashes[vehicle] = 0
		standing[vehicle] = 0.0
		longest_stand[vehicle] = 0.0
		was_crashed[vehicle] = false
		last_position[vehicle] = vehicle.global_position
	var elapsed := 0.0
	var physics_time := 0.0
	var samples := 0
	while elapsed < seconds:
		await physics_frame
		elapsed += STEP
		physics_time += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		samples += 1
		for vehicle in vehicles:
			if not vehicle.crashed:
				distance[vehicle] += (vehicle.global_position - last_position[vehicle]).length()
			last_position[vehicle] = vehicle.global_position
			if vehicle.crashed and not was_crashed[vehicle]:
				crashes[vehicle] += 1
				print("%6.1f s  botsing: %s op %s" % [elapsed, _label(vehicle), vehicle.global_position])
			was_crashed[vehicle] = vehicle.crashed
			standing[vehicle] = standing[vehicle] + STEP if vehicle.speed < 0.3 and not vehicle.crashed else 0.0
			longest_stand[vehicle] = maxf(longest_stand[vehicle], standing[vehicle])
	var total_crashes := 0
	var stuck := 0
	for vehicle in vehicles:
		total_crashes += crashes[vehicle]
		if longest_stand[vehicle] > STUCK_AFTER:
			stuck += 1
		print("%-34s %6.0f m  botsingen %d  langst stil %5.1f s%s" % [_label(vehicle), distance[vehicle], crashes[vehicle],
				longest_stand[vehicle], "  VAST" if longest_stand[vehicle] > STUCK_AFTER else ""])
	print("samen: %d botsingen, %d voertuigen vast, physics %.2f ms per stap" % [total_crashes, stuck, physics_time / maxf(samples, 1) * 1000.0])
	Engine.time_scale = 1.0
	quit()


func _label(vehicle: Vehicle) -> String:
	return "%s (%s)" % [vehicle.name, vehicle.model.get_file()]
