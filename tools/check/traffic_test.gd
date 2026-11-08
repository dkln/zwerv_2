extends SceneTree
## Lets all the traffic of scenes/stad.tscn (the Auto, the SUV and what the node Verkeer
## adds) drive on its own, headless and faster than real time, and prints per vehicle:
## distance, crashes and the longest it stood still; and the physics time per step, so you
## can see what the traffic costs. Standing still for over STUCK_AFTER simulated seconds
## counts as stuck (no traffic light takes that long). Standing for over STAND_REPORT
## seconds it says where and why: what it waits for (a light or a zebra, a siren it pulled
## over for, or another vehicle, and who that one waits for, round to the end of the chain).
## usage: Godot --headless --script tools/check/traffic_test.gd -- [simulated seconds]

const Common = preload("res://tools/tool_common.gd")
const TIME_SCALE := 8
const STEP := 1.0 / 60.0
const STUCK_AFTER := 90.0
const STAND_REPORT := 30.0
const CHAIN_SHOWN := 8


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
			var stood_before: float = standing[vehicle]
			standing[vehicle] = standing[vehicle] + STEP if vehicle.speed < 0.3 and not vehicle.crashed else 0.0
			if stood_before < STAND_REPORT and standing[vehicle] >= STAND_REPORT:
				print("%6.1f s  staat %d s: %s" % [elapsed, int(STAND_REPORT), _why_standing(vehicle)])
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


## Where it stands and what for, following who waits for whom.
func _why_standing(vehicle: Vehicle) -> String:
	var chain: Array[String] = []
	var seen := {}
	var current := vehicle
	while current != null and chain.size() < CHAIN_SHOWN:
		if seen.has(current):
			chain.append("KRING terug naar " + _label(current))
			break
		seen[current] = true
		var cell := Vector2i(floori(current.global_position.x / 4.0), floori(current.global_position.z / 4.0))
		var state := "%s cel %s" % [_label(current), cell]
		if current.has_priority():
			state += " SIRENE"
		if current._held_by_rule:
			state += " [licht/zebra/voorrang]"
		if current.yielding:
			state += " [opzij voor %s]" % (_label(current._yielding_to) if current._yielding_to and is_instance_valid(current._yielding_to) else "?")
		if current._squeeze_clock > 0.0:
			state += " [wringt%s]" % (" erdoor" if current._squeeze_through else "")
		chain.append(state)
		current = current._blocked_by
	return " -> wacht op ".join(chain)


func _label(vehicle: Vehicle) -> String:
	return "%s (%s)" % [vehicle.name, vehicle.model.get_file()]
