extends SceneTree
## Lets all the traffic of scenes/stad.tscn (the Auto, the SUV and what the node Verkeer
## adds) drive on its own, headless and faster than real time, and prints per vehicle:
## distance, crashes and the longest it stood still; and the physics time per step, so you
## can see what the traffic costs. Standing still for over STUCK_AFTER simulated seconds
## counts as stuck (no traffic light takes that long). Standing for over STAND_REPORT
## seconds it says where and why: what it waits for (a light or a zebra, a siren it pulled
## over for, or another vehicle, and who that one waits for, round to the end of the chain).
## The lights: how often a vehicle that keeps to them (no siren, not reckless) drives onto
## a crossing at red (its front well over the line while the light is red), and how often one
## stands still on a zebra before a red crossing (it should wait before the zebra).
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
	# Verhaal too: its prologue holds the game (the story box pauses the tree)
	for node_name in ["DetailNiveau", "Rook", "Grassprieten", "Verhaal"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	# the whole network, all kept (not the set round the player): every road is tried
	scene.get_node("Verkeer").whole_town = true
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
	var last_cell := {}
	var through_red := 0
	var on_zebra := 0
	var on_zebra_now := {}
	for vehicle in vehicles:
		if not vehicle.has_node("Carrosserie/Model"):
			print("FOUT: geen model: ", vehicle.name)
		distance[vehicle] = 0.0
		crashes[vehicle] = 0
		standing[vehicle] = 0.0
		longest_stand[vehicle] = 0.0
		was_crashed[vehicle] = false
		last_position[vehicle] = vehicle.global_position
		last_cell[vehicle] = Vector3i.ZERO
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
			var light := _red_light_check(vehicle, last_cell[vehicle])
			if light == "door rood":
				through_red += 1
				print("%6.1f s  door rood: %s op %s" % [elapsed, _label(vehicle), vehicle.global_position.round()])
			var stands_on_zebra := light == "op zebra"
			if stands_on_zebra and not on_zebra_now.get(vehicle, false):
				on_zebra += 1
				print("%6.1f s  staat op zebra voor rood: %s op %s" % [elapsed, _label(vehicle), vehicle.global_position.round()])
			on_zebra_now[vehicle] = stands_on_zebra
			if vehicle._route_cells.size() > 0:
				last_cell[vehicle] = _front_cell(vehicle)
	var total_crashes := 0
	var stuck := 0
	for vehicle in vehicles:
		total_crashes += crashes[vehicle]
		if longest_stand[vehicle] > STUCK_AFTER:
			stuck += 1
		print("%-34s %6.0f m  botsingen %d  langst stil %5.1f s%s" % [_label(vehicle), distance[vehicle], crashes[vehicle],
				longest_stand[vehicle], "  VAST" if longest_stand[vehicle] > STUCK_AFTER else ""])
	print("samen: %d botsingen, %d voertuigen vast, physics %.2f ms per stap" % [total_crashes, stuck, physics_time / maxf(samples, 1) * 1000.0])
	print("verkeerslichten: %d keer door rood, %d keer op een zebra stil voor rood" % [through_red, on_zebra])
	Engine.time_scale = 1.0
	quit()


## "door rood" when `vehicle` (keeping to the lights) just drove from `previous` onto a
## crossing whose light is red for it, "op zebra" when it stands still on a zebra right
## before a crossing that is red for it; "" otherwise.
func _red_light_check(vehicle: Vehicle, previous: Vector3i) -> String:
	if vehicle.crashed or vehicle.reckless or vehicle.has_priority() or not vehicle.obeys_lights \
			or vehicle._lights == null or vehicle._route_cells.is_empty() or previous == Vector3i.ZERO:
		return ""
	var network := vehicle.network
	var cell := _front_cell(vehicle)
	if cell == previous:
		var middle_cell: Vector3i = vehicle._cell_under()
		if vehicle.speed < 0.3 and network.is_zebra(middle_cell):
			cell = middle_cell
			var ahead_index := vehicle._route_cells.find(cell) + 1
			if ahead_index > 0 and ahead_index < vehicle._route_cells.size():
				var next: Vector3i = vehicle._route_cells[ahead_index]
				var heading := Vector2i(next.x - cell.x, next.z - cell.z)
				if network.is_crossing(next) and vehicle._lights.car_phase(vehicle._crossing_middle(next), heading.x == 0) == 2:
					return "op zebra"
		return ""
	if not network.is_crossing(cell) or network.is_crossing(previous):
		return ""
	var heading := Vector2i(cell.x - previous.x, cell.z - previous.z)
	# just off another crossing: it drives on to clear that one (vehicle.gd, _must_stop)
	var behind := network.step(previous, -heading)
	if behind != RoadNetwork.NONE and network.is_crossing(behind):
		return ""
	if vehicle._lights.car_phase(vehicle._crossing_middle(cell), heading.x == 0) == 2:
		return "door rood"
	return ""


## The planned cell its front is on (the front of what is drawn on it), counting only
## once it is more than the overshoot a late braker may stop in over a line.
func _front_cell(vehicle: Vehicle) -> Vector3i:
	var front: float = vehicle._distance + vehicle._front_reach() - vehicle.STOP_OVERSHOOT
	var distances: Array = vehicle._route_distances
	var cells: Array = vehicle._route_cells
	for index in range(cells.size() - 1, -1, -1):
		var start: float = distances[index] if index == 0 else (distances[index - 1] + distances[index]) * 0.5
		if front >= start:
			return cells[index]
	return cells[0]


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
