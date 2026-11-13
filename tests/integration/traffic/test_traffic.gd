extends "res://tests/integration/support/town_test.gd"
## Lets all the traffic of the town (the Auto, the SUV and what the node Verkeer adds)
## drive on its own and prints per vehicle: distance, crashes and the longest it stood
## still; and the physics time per step, so you can see what the traffic costs. Standing
## still for over STUCK_AFTER simulated seconds counts as stuck (no traffic light takes that
## long). Standing for over STAND_REPORT seconds it says where and why: what it waits for
## (a light or a zebra, a siren it pulled over for, or another vehicle, and who that one
## waits for, round to the end of the chain).
## The lights: how often a vehicle that keeps to them (no siren, not reckless) drives onto
## a crossing at red (its front well over the line while the light is red), and how often one
## stands still on a zebra before a red crossing (it should wait before the zebra).
## With "speler" (and an hour) the traffic is the set round the player, as in the game (dense
## round Centraal, where the player starts, in the rush hour by default): vehicles come and go,
## each is counted while it is there; that is where junctions lock up. Without it the whole
## network is filled and all vehicles are kept, so every road is tried.
## A long simulation with arguments that set the town up, so a run of its own; it is a
## report: only the traffic being there (every vehicle with its model) is checked.
##   tests/run_integration_tests.sh test_traffic [-- <simulated seconds, default 300> [speler [<hour, default 8.5>]]]
##   ... -- 300 speler 8.5 oud    "oud" as the fourth word: without keeping the crossings clear
##                                (Vehicle.KEEP_CROSSINGS_CLEAR)

const TrafficHelp = preload("res://tests/integration/support/traffic_help.gd")
const TEST_SECONDS := 280.0
const STEP := 1.0 / 60.0
const STUCK_AFTER := 90.0
const STAND_REPORT := 30.0
const CHAIN_SHOWN := 8


## The town for the arguments: the whole network filled, or ("speler") the set round the
## player at the hour asked.
static func world_options() -> Dictionary:
	var round_player := Common.arg(2, "") == "speler"
	var settings := {"Verkeer": {"whole_town": not round_player}}
	if round_player:
		settings["Dagcyclus"] = {"time_of_day": float(Common.arg(3, "8.5"))}
	return {"own_process": true, "traffic": true, "without": ["DetailNiveau", "Rook", "Verhaal"], "settings": settings}


## What is kept of one vehicle while it drives.
class Tally:
	var distance := 0.0
	var crashes := 0
	var standing := 0.0
	var longest_stand := 0.0
	var was_crashed := false
	var last_position := Vector3.ZERO
	var last_cell := Vector3i.ZERO
	var on_zebra := false


## The traffic drives for the simulated seconds asked; reports crashes, vehicles standing
## long (and why), driving through red and standing on a zebra before red as they happen,
## and per vehicle and in total at the end.
func test_report_how_the_traffic_drives(test) -> void:
	var simulated_seconds := float(argument(0, "300"))
	var round_player := argument(1) == "speler"
	var keep_clear_before := Vehicle.KEEP_CROSSINGS_CLEAR
	if argument(3) == "oud":
		Vehicle.KEEP_CROSSINGS_CLEAR = false
	await frames(2)
	var vehicles := TrafficHelp.vehicles_in_town()
	print("voertuigen: ", vehicles.size())
	test.check(not vehicles.is_empty(), "er rijdt verkeer (%d voertuigen)" % vehicles.size())
	var tallies := {}       # Vehicle -> Tally
	var without_model := 0
	var through_red := 0
	var on_zebra := 0
	var elapsed := 0.0
	var physics_time := 0.0
	var samples := 0
	while elapsed < simulated_seconds:
		await tree.physics_frame
		elapsed += STEP
		physics_time += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		samples += 1
		# every vehicle there now is counted (round the player the set changes)
		for vehicle in Vehicle.all_vehicles:
			if is_instance_valid(vehicle) and not tallies.has(vehicle):
				if not vehicles.has(vehicle):
					vehicles.append(vehicle)
				if not vehicle.has_node("Carrosserie/Model"):
					without_model += 1
					print("FOUT: geen model: ", vehicle.name)
				var fresh := Tally.new()
				fresh.last_position = vehicle.global_position
				tallies[vehicle] = fresh
		for vehicle in vehicles:
			if not is_instance_valid(vehicle) or not vehicle.is_inside_tree():
				continue
			var tally: Tally = tallies[vehicle]
			if not vehicle.crashed:
				tally.distance += (vehicle.global_position - tally.last_position).length()
			tally.last_position = vehicle.global_position
			if vehicle.crashed and not tally.was_crashed:
				tally.crashes += 1
				print("%6.1f s  botsing: %s op %s" % [elapsed, TrafficHelp.label(vehicle), vehicle.global_position])
			tally.was_crashed = vehicle.crashed
			var stood_before := tally.standing
			tally.standing = tally.standing + STEP if vehicle.speed < 0.3 and not vehicle.crashed else 0.0
			if stood_before < STAND_REPORT and tally.standing >= STAND_REPORT:
				print("%6.1f s  staat %d s: %s" % [elapsed, int(STAND_REPORT), _why_standing(vehicle)])
			tally.longest_stand = maxf(tally.longest_stand, tally.standing)
			var light := _red_light_check(vehicle, tally.last_cell)
			if light == "door rood":
				through_red += 1
				print("%6.1f s  door rood: %s op %s" % [elapsed, TrafficHelp.label(vehicle), vehicle.global_position.round()])
			var stands_on_zebra := light == "op zebra"
			if stands_on_zebra and not tally.on_zebra:
				on_zebra += 1
				print("%6.1f s  staat op zebra voor rood: %s op %s" % [elapsed, TrafficHelp.label(vehicle), vehicle.global_position.round()])
			tally.on_zebra = stands_on_zebra
			if vehicle._route_cells.size() > 0:
				tally.last_cell = _front_cell(vehicle)
	var total_crashes := 0
	var stuck := 0
	var barged := 0
	for vehicle in vehicles:
		if not is_instance_valid(vehicle):
			continue
		var tally: Tally = tallies[vehicle]
		total_crashes += tally.crashes
		barged += vehicle.barged
		if tally.longest_stand > STUCK_AFTER:
			stuck += 1
		print("%-34s %6.0f m  botsingen %d  langst stil %5.1f s%s" % [TrafficHelp.label(vehicle), tally.distance, tally.crashes,
				tally.longest_stand, "  VAST" if tally.longest_stand > STUCK_AFTER else ""])
	print("samen: %d botsingen, %d voertuigen vast, %d keer er langs gebeukt, physics %.2f ms per stap" % [total_crashes, stuck, barged, physics_time / maxf(samples, 1) * 1000.0])
	print("verkeerslichten: %d keer door rood, %d keer op een zebra stil voor rood" % [through_red, on_zebra])
	test.check(without_model == 0, "elk voertuig heeft zijn model (%d zonder)" % without_model)
	Vehicle.KEEP_CROSSINGS_CLEAR = keep_clear_before


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


## Where `vehicle` stands and what for, following who waits for whom (to the end of the
## chain, or round to where it closes).
func _why_standing(vehicle: Vehicle) -> String:
	var chain: Array[String] = []
	var seen := {}
	var current := vehicle
	while current != null and chain.size() < CHAIN_SHOWN:
		if seen.has(current):
			chain.append("KRING terug naar " + TrafficHelp.label(current))
			break
		seen[current] = true
		var cell := Vector2i(floori(current.global_position.x / 4.0), floori(current.global_position.z / 4.0))
		var state := "%s cel %s" % [TrafficHelp.label(current), cell]
		if current.has_priority():
			state += " SIRENE"
		if current._held_by_rule:
			state += " [licht/zebra/voorrang]"
		if current.yielding:
			state += " [opzij voor %s]" % (TrafficHelp.label(current._yielding_to) if current._yielding_to and is_instance_valid(current._yielding_to) else "?")
		if current._squeeze_clock > 0.0:
			state += " [wringt%s]" % (" erdoor" if current._squeeze_through else "")
		chain.append(state)
		current = current._blocked_by
	return " -> wacht op ".join(chain)
