extends "res://tests/integration/support/town_test.gd"
## People coming out of Den Haag Centraal and going into it (scripts/world/pedestrians.gd,
## the "station" share of data/drukte.json): in the morning rush, with the player near a
## station door, newcomers come out of the doors, people near it set off for a door and are
## gone through it; far off the station none of that.
##   tests/run_integration_tests.sh station_flow
##   STATION_TRACE=1 tests/run_integration_tests.sh station_flow   follows one of them, a line a second

## The hour of the morning rush the town is put at.
const RUSH_HOUR := 7.6
## Physics steps (60 a second) to watch the station's doors.
const WATCH_STEPS := 2400
## Cells' walk from a station door where the player stands to watch.
const WATCH_FROM_STEPS := 6


## The people on foot of the town (Pedestrians) in the morning rush: the clock at RUSH_HOUR
## and standing still, no camera (so anyone may come and go wherever they are), the
## station's doors known. For this test only.
func _walkers_in_the_rush() -> Pedestrians:
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	var day: Node = scene.get_node("Dagcyclus")
	camera_off()
	set_for_test(day, "speed", 0.0)
	set_for_test(day, "time_of_day", RUSH_HOUR)
	set_for_test(walkers, "unseen_without_camera", true)
	await wait_until(func() -> bool: return not walkers.people().is_empty(), 5.0)
	walkers._find_station()
	return walkers


## A street cell WATCH_FROM_STEPS cells' walk from a station door (else the cell of door 1).
func _cell_near_a_door(walkers: Pedestrians) -> Vector3i:
	for cell: Vector3i in walkers._station_steps:
		if walkers.station_steps(cell) == WATCH_FROM_STEPS:
			return cell
	return walkers._station_door_cells[0]


## Those on their way into the station now.
func _heading_to_station(walkers: Pedestrians) -> Array:
	return walkers.people().filter(func(person: Pedestrian) -> bool: return person.heading_to_station)


## In the morning rush, seen from a little way off a station door: people come out of the
## station, people near it set off for a door, and they are gone through it.
func test_in_the_rush_people_come_out_and_go_in(test) -> void:
	var walkers := await _walkers_in_the_rush()
	print("stationsdeuren: %d, stappen tot een deur bekend voor %d cellen, aandeel in de spits %.2f" % [
		walkers._station_doors.size(), walkers._station_steps.size(), walkers.station_share()])
	test.check(not walkers._station_doors.is_empty(), "de deuren van Centraal gevonden")
	if walkers._station_doors.is_empty():
		return
	var door: Vector3 = walkers._station_doors[0]
	player.teleport(walkers.cell_middle(_cell_near_a_door(walkers)) + Vector3.UP * 0.3, 0.0)
	for frame_index in 120:
		await tree.physics_frame
	walkers.came_out_of_station = 0
	walkers.went_into_station = 0
	var most_heading := 0
	var trace := OS.get_environment("STATION_TRACE") != ""
	for step in WATCH_STEPS:
		await tree.physics_frame
		if step % 60 != 0:
			continue
		var heading := _heading_to_station(walkers)
		most_heading = maxi(most_heading, heading.size())
		if step % 600 == 0:
			var total_steps := 0
			for person: Pedestrian in heading:
				total_steps += walkers.station_steps(person.cell)
			print("  %d s: %d op weg, gemiddeld %.1f cellen van een deur" % [step / 60, heading.size(), float(total_steps) / maxi(heading.size(), 1)])
		if trace and not heading.is_empty():
			var person: Pedestrian = heading[0]
			print("    %s cel %s stappen %d op %s doel %s volgende %s pauze %.1f geblokt %.1f binnen %s" % [person.name, person.cell,
				walkers.station_steps(person.cell), person.global_position.snapped(Vector3.ONE * 0.1), person._target.snapped(Vector3.ONE * 0.1),
				person._next_cell, person._pause, person._blocked, person._entering_station])
	print("in %d s bij de deur (%.0f m van de speler): %d naar buiten, %d naar binnen, tot %d tegelijk op weg naar binnen, %d voetgangers" % [
		WATCH_STEPS / 60, door.distance_to(player.global_position), walkers.came_out_of_station, walkers.went_into_station,
		most_heading, walkers.people().size()])
	test.check(walkers.came_out_of_station > 0, "in de spits komen er mensen uit het station")
	test.check(most_heading > 0, "in de spits gaan er mensen op weg naar het station")
	test.check(walkers.went_into_station > 0, "en ze verdwijnen door de deur")


## With the player far from the station nobody comes out of it, rush hour or not.
func test_far_from_the_station_nobody_comes_out(test) -> void:
	var walkers := await _walkers_in_the_rush()
	test.check(not walkers._station_doors.is_empty(), "de deuren van Centraal gevonden")
	if walkers._station_doors.is_empty():
		return
	var door: Vector3 = walkers._station_doors[0]
	var far_cell := RoadNetwork.NONE
	for cell: Vector3i in walkers._walkable_cells:
		if walkers.cell_middle(cell).distance_to(door) > walkers.STATION_REACH + 200.0:
			far_cell = cell
			break
	test.check(far_cell != RoadNetwork.NONE, "een plek ver van het station")
	if far_cell == RoadNetwork.NONE:
		return
	player.teleport(walkers.cell_middle(far_cell) + Vector3.UP * 0.3, 0.0)
	for frame_index in 180:
		await tree.physics_frame
	walkers.came_out_of_station = 0
	for step in 600:
		await tree.physics_frame
	test.check(walkers.came_out_of_station == 0, "ver van het station komt er niemand uit (%d)" % walkers.came_out_of_station)
