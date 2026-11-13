extends "res://tests/integration/support/town_test.gd"
## Den Haag Centraal from the inside (scripts/world/station.gd and its parts): the three doors
## of the station hall on the square are ways in (west to east door 1..3), going in at the
## middle one puts you at Deur2 of the hall; the station has a departure on every track,
## trains standing, the gates before every platform (lanes in and out, shut without a card),
## OV-chipkaart machines, OV posts, the people behind the counters and people walking; a card
## bought at a machine opens a gate; who goes over the gates without checking in gets a
## conductor after them (fined when caught, who stays off the rails and goes round through
## the hall); a train that is due leaves (whistle, doors, out of the hall) and its track
## gets the next one; the travellers keep moving; out through door 3 you stand before the
## eastern door.
##   tests/run_integration_tests.sh station

const Layout = preload("res://scripts/world/station_layout.gd")
## Seconds someone on their way may stand still before they count as stuck.
const STILL_LIMIT := 20
## Seconds the travellers are watched for standing still.
const WATCH_SECONDS := 150
## Metres past the end of a gate the player is put, on the platform side.
const PAST_THE_GATE := 0.6


## The ways into Den Haag Centraal (Interiors.ways_in), door 1..3.
func _ways_in() -> Array:
	return interiors.ways_in().filter(func(way: Dictionary) -> bool: return way.kind == "centraal")


## Into the station (door 1) and the station itself, with no conductor after the player, no
## check-in left over and the chance of a fare check its own; null if it could not be entered.
func _station() -> Node3D:
	await enter("centraal")
	var station: Node3D = interiors.interior_of("centraal") if interiors.is_inside() else null
	if station == null or not station.has_method("departures"):
		return null
	if station._chaser != null:
		station._end_chase()
	station.fare_check_chance_override = -1.0
	if player.has_meta("ov_doorgang_tot"):
		player.remove_meta("ov_doorgang_tot")
	player.inventory.erase("ov_chipkaart")
	return station


## Game time on with nothing holding the game shut (a story page, a reward).
func _tick(duration: float) -> void:
	await close_screens()
	await seconds(duration)


## A lane into the platforms of `gates_node` that no one is using (else its first lane in).
func _free_lane_in(gates_node: Node) -> Node3D:
	var lanes_in: Array = (gates_node.lanes as Array).filter(func(candidate: Node3D) -> bool: return candidate.direction > 0)
	for candidate: Node3D in lanes_in:
		if candidate.occupant == null and candidate.queue.is_empty():
			return candidate
	return lanes_in[0] if not lanes_in.is_empty() else gates_node.lanes[0]


## The player from the hall side of `lane` to its platform side without checking in (as
## over the paddles), with a conductor sure to notice.
func _dodge_the_fare(station: Node3D, lane: Node3D) -> void:
	station.fare_check_chance_override = 1.0
	if player.has_meta("ov_doorgang_tot"):
		player.remove_meta("ov_doorgang_tot")
	player.teleport(station.to_global(lane.entry_point()), 0.0)
	await frames(3)
	player.teleport(station.to_global(lane.exit_point() + Vector3(0.0, 0.0, PAST_THE_GATE)), 0.0)
	await frames(3)


## The chase over and the chance of a fare check its own again.
func _call_off_the_chase(station: Node3D) -> void:
	if station._chaser != null:
		station._end_chase()
	station.fare_check_chance_override = -1.0


## A track with no train on it now (else track 7): the rails free to stand on.
func _empty_track(station: Node3D) -> int:
	var empty_track := 7
	for candidate in range(1, Layout.TRACK_COUNT + 1):
		var on_it: Dictionary = station._track_departure.get(candidate, {})
		if on_it.is_empty() or on_it.get("train") == null:
			empty_track = candidate
	return empty_track


## The width of what `label` shows now (metres).
func _text_width(label: Label3D) -> float:
	return label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size


## The station hall has three ways in on the square, door 1..3 from west to east.
func test_three_doors_from_west_to_east(test) -> void:
	var ways := _ways_in()
	for way: Dictionary in ways:
		print("  Centraal deur %d: %s" % [way.door_index, way.door.snapped(Vector3.ONE * 0.1)])
	test.check(ways.size() == 3, "drie ingangen van Centraal (%d)" % ways.size())
	if ways.size() == 3:
		test.check((ways[0].door as Vector3).x < (ways[1].door as Vector3).x and (ways[1].door as Vector3).x < (ways[2].door as Vector3).x, "deur 1..3 van west naar oost")


## At the middle door on the square [E] takes you in, and you stand at Deur2 of the hall.
func test_in_at_the_middle_door(test) -> void:
	var middle_ways := _ways_in().filter(func(way: Dictionary) -> bool: return int(way.door_index) == 2)
	test.check(not middle_ways.is_empty(), "Centraal heeft een deur 2")
	if middle_ways.is_empty():
		return
	player.teleport(middle_ways[0].door, 0.0)
	for frame_index in 4:
		await tree.physics_frame
	test.check(prompts() == [["E", "Naar binnen"]], "bij de deur: [E] Naar binnen")
	use_prompt()
	await seconds(1.4)
	var station: Node3D = interiors._interior
	test.check(interiors.is_inside() and station != null and station.has_method("departures"), "binnen in het station")
	if station == null or not station.has_method("departures"):
		return
	var door_two := station.get_node("Deur2") as Node3D
	test.check(player.global_position.distance_to(door_two.global_position) < 2.0, "binnen bij deur 2 (%.1f m)" % player.global_position.distance_to(door_two.global_position))


## What the station has once you are in: a departure on every track, trains standing, gates
## before every platform, OV posts, people behind the counters, card machines, a departure
## board with trains on it and people about.
func test_station_has_trains_gates_machines_and_people(test) -> void:
	var station := await _station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	await seconds(1.5)
	var departures: Array = station.departures()
	var tracks := {}
	for departure: Dictionary in departures:
		tracks[int(departure.track)] = true
	test.check(tracks.size() == Layout.TRACK_COUNT, "een vertrek op elk spoor (%d)" % tracks.size())
	var standing: Array = departures.filter(func(departure: Dictionary) -> bool: return departure.state == "staat")
	test.check(not standing.is_empty(), "treinen die er staan (%d)" % standing.size())
	var gates: Array = station._gates
	var lane_count := 0
	for gates_node in gates:
		lane_count += (gates_node.lanes as Array).size()
	test.check(gates.size() == Layout.platforms().size() and lane_count >= 20, "poortjes voor elk perron (%d rijen, %d poortjes)" % [gates.size(), lane_count])
	test.check(station._posts.size() >= 8, "OV-paaltjes (%d)" % station._posts.size())
	test.check(station._keepers.size() >= 10, "mensen achter de toonbanken (%d)" % station._keepers.size())
	test.check(tree.get_nodes_in_group("deuren").filter(func(node: Node) -> bool: return String(node.name).begins_with("Kaartautomaat")).size() >= 8, "OV-chipkaartautomaten")
	var board_rows: Array = station._boards[0]
	test.check(not String((board_rows[0][1] as Label3D).text).is_empty(), "het vertrekbord toont treinen (%s)" % (board_rows[0][1] as Label3D).text)
	test.check(station.station_people().size() > 5, "mensen in het station (%d)" % station.station_people().size())


## In the station the view is further out than in a snack bar and the location under the
## minimap names the station.
func test_view_zoomed_out_and_location_named(test) -> void:
	var station := await _station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	await seconds(1.5)
	var follow: Node = scene.get_node("Volgcamera")
	test.check(is_equal_approx(follow._zoom, 20.0) and follow._zoom > follow.indoor_zoom, "verder uitgezoomd in het station (%.1f m in beeld)" % follow._zoom)
	hud._update_location()
	test.check(hud._location_wijk.text == "STATION DEN HAAG CENTRAAL", "locatie bij de kaart: %s" % hud._location_wijk.text)


## Overhead lines hang over the tracks, on eight slim masts whose colliders are as slim.
func test_overhead_lines_on_slim_masts(test) -> void:
	var station := await _station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	var wires := station.get_node_or_null("Bovenleiding") as MeshInstance3D
	test.check(wires != null and wires.mesh != null and wires.mesh.get_surface_count() > 0, "bovenleiding over de sporen")
	var masts := station.get_children().filter(func(node: Node) -> bool: return String(node.name).begins_with("Bovenleidingmast"))
	var slim := masts.filter(func(mast: Node) -> bool:
		if not mast is StaticBody3D:
			return false
		var shapes := mast.get_children().filter(func(child: Node) -> bool: return child is CollisionShape3D and child.shape is BoxShape3D)
		return shapes.size() == 1 and (shapes[0].shape as BoxShape3D).size.x <= 0.3 and (shapes[0].shape as BoxShape3D).size.z <= 0.3)
	test.check(masts.size() == 8 and slim.size() == 8, "slanke masten met slanke colliders (%d masten, %d slank: %s)" % [masts.size(), slim.size(), str(masts.map(func(mast: Node) -> String: return "%s %s" % [mast.name, mast.get_class()]))])


## Every text stays on its board (the departure boards 6 m wide, the platform screens
## 2.5 m), also a long one fitted in afterwards.
func test_texts_stay_on_their_boards(test) -> void:
	var station := await _station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	await seconds(1.5)
	var overflowing := []
	for rows: Array in station._boards:
		for row: Array in rows:
			for label: Label3D in row:
				var text_width := _text_width(label)
				var left := label.position.x - (text_width * 0.5 if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0)
				if left < -2.88 or left + text_width > 2.88:
					overflowing.append(label.text)
	for track: int in station._displays:
		for key: String in ["time", "destination"]:
			var label: Label3D = station._displays[track][key]
			if label.position.x + _text_width(label) > 1.13:
				overflowing.append(label.text)
	test.check(overflowing.is_empty(), "teksten binnen de borden %s" % str(overflowing))
	var room: float = station.DISPLAY_EDGE - station.DISPLAY_TEXT_LEFT
	station._fit_text(station._displays[1].time, "12:34  Rijdt niet", room)
	station._fit_text(station._displays[1].destination, "Rotterdam Centraal", room)
	for key: String in ["time", "destination"]:
		var label: Label3D = station._displays[1][key]
		test.check(label.position.x + _text_width(label) <= 1.13, "een lange tekst past op het perronscherm (%s)" % label.text)


## An announcement is typed out on screen with the cursor while the voice talks.
func test_announcement_types_out_with_the_cursor(test) -> void:
	var station := await _station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	station._announcement_pause = 0.0
	station._announcements.clear()
	station._announcing = false
	station._speak("Spoor 5: de Intercity naar Venlo, vertrekt om 12:34.")
	await seconds(2.6)
	test.check(station._subtitle_layer.visible and not station._subtitle_typewriter.is_done() and String(station._subtitle.text).contains("[bgcolor"), "omroeptekst typt uit met cursor")


## A gate stays shut without an OV-chipkaart; a card bought at a machine (7,50) opens it,
## and who went through checked in gets no conductor after them.
func test_gate_shut_without_card_and_open_with_one(test) -> void:
	var station := await _station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	var gates: Array = station._gates
	var lane := _free_lane_in(gates[3])
	await put_player_in(station, lane.entry_point())
	test.check(prompts() == [["E", "Inchecken"]], "bij een poortje: [E] Inchecken (%s)" % str(prompts()))
	use_prompt()
	await seconds(1.0)
	test.check(not lane.is_open(), "zonder OV-chipkaart blijft het poortje dicht")
	var machine: Node3D = station.get_node("Kaartautomaat")
	player.add_money(10.0)
	var money_before: float = player.money
	machine.buy_card()   # what the machine's screen does (OvMachineScreen); go_through opens it
	test.check(int(player.inventory.get("ov_chipkaart", 0)) == 1 and is_equal_approx(player.money, money_before - 7.5), "OV-chipkaart gekocht (€ 7,50)")
	await close_screens()
	print("poortje bezet door: %s" % [lane.occupant])
	lane.go_through()
	await seconds(1.0)
	test.check(lane.is_open(), "met een OV-chipkaart gaat het poortje open (gepauzeerd: %s)" % tree.paused)
	# through with a check-in: no conductor, however sure a check is
	var chases_before: int = station.chases_started
	station.fare_check_chance_override = 1.0
	await frames(3)
	player.teleport(station.to_global(lane.exit_point() + Vector3(0.0, 0.0, PAST_THE_GATE)), 0.0)
	await frames(3)
	test.check(station.chases_started == chases_before and station._chaser == null, "ingecheckt door het poortje: geen conducteur erachteraan")
	_call_off_the_chase(station)


## The paddles of a shut gate can be jumped: on the floor the figure does not fit between
## them, half a metre up it does.
func test_shut_gate_can_be_jumped(test) -> void:
	var station := await _station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	var shut_lanes: Array = (station._gates[2].lanes as Array).filter(func(candidate: Node3D) -> bool: return candidate.direction > 0 and not candidate.is_open())
	test.check(not shut_lanes.is_empty(), "een dicht poortje naar het perron")
	if shut_lanes.is_empty():
		return
	var over := station.to_global(Vector3(shut_lanes[-1].station_x(), 0.0, Layout.GATE_Z))
	test.check(not player._fits(over) and player._fits(over + Vector3.UP * 0.5), "over een dicht poortje springen kan (hoogte %.1f m)" % player.jump_height)


## Over a gate without checking in: a conductor comes after you, and caught you pay the
## fine of 50 euros, after which the conductor goes back.
func test_fare_dodger_is_chased_and_fined(test) -> void:
	var station := await _station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	var chases_before: int = station.chases_started
	var fines_before: int = station.fines
	await _dodge_the_fare(station, _free_lane_in(station._gates[2]))
	test.check(station.chases_started == chases_before + 1 and station._chaser != null, "zonder inchecken over het poortje: een conducteur komt erachteraan")
	player.add_money(80.0 - player.money)
	var caught := false
	for attempt in 40:
		await _tick(0.25)
		if station.fines > fines_before:
			caught = true
			break
	test.check(caught and is_equal_approx(player.money, 30.0), "ingehaald: beboet voor zwartrijden (€ %.2f over van € 80)" % player.money)
	test.check(station._chaser == null, "de conducteur gaat terug na de boete")
	_call_off_the_chase(station)


## Running from the conductor (always to the spot furthest from him): he gives up without a
## fine, and never comes down onto the rails on the way.
func test_fare_dodger_who_runs_gets_away(test) -> void:
	var station := await _station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	var gates: Array = station._gates
	var chases_before: int = station.chases_started
	var given_up_before: int = station.chases_given_up
	var fines_before: int = station.fines
	await _dodge_the_fare(station, _free_lane_in(gates[gates.size() - 1]))
	test.check(station.chases_started == chases_before + 1, "zwart erdoor: een conducteur (%d)" % (station.chases_started - chases_before))
	var hiding_places := [Vector3(-44.0, 0.0, -28.0), Vector3(44.0, 0.0, -28.0), Vector3(Layout.platform_walk_x(1), 0.0, 46.0), Vector3(Layout.platform_walk_x(12), 0.0, 46.0)]
	var escaped := false
	var chaser_lowest := 0.0
	for attempt in 40:
		await close_screens()
		var chaser: Node3D = station._chaser
		if chaser:
			chaser_lowest = minf(chaser_lowest, chaser.position.y)
			hiding_places.sort_custom(func(first: Vector3, second: Vector3) -> bool: return first.distance_to(chaser.position) > second.distance_to(chaser.position))
			player.teleport(station.to_global(hiding_places[0]), 0.0)
		await seconds(0.25)
		if station._chaser == null:
			escaped = true
			break
	test.check(escaped and chaser_lowest > -0.3, "de conducteur komt nooit op het spoor (laagst %.2f m)" % chaser_lowest)
	test.check(escaped and station.chases_given_up > given_up_before and station.fines == fines_before,
		"ontsnapt: de conducteur geeft het op (%d keer opgegeven, %d boetes)" % [station.chases_given_up - given_up_before, station.fines - fines_before])
	_call_off_the_chase(station)


## The player down on the rails: the conductor after them stays on the platform edge above.
func test_conductor_waits_on_the_platform_for_who_is_on_the_rails(test) -> void:
	var station := await _station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	var rail_track := _empty_track(station)
	await _dodge_the_fare(station, _free_lane_in(station._gates[Layout.platform_of_track(rail_track)]))
	test.check(station._chaser != null, "zwart erdoor bij spoor %d: een conducteur" % rail_track)
	var on_the_rails := station.to_global(Vector3(Layout.track_x(rail_track), -Layout.PLATFORM_DROP, 14.0))
	var lowest := 0.0
	var waited_at_edge := false
	for attempt in 24:
		player.teleport(on_the_rails, 0.0)
		await seconds(0.25)
		if station._chaser == null:
			break
		lowest = minf(lowest, station._chaser.position.y)
		if String(station._chase_plan).begins_with("spoor"):
			waited_at_edge = true
	test.check(waited_at_edge and lowest > -0.3, "speler op het spoor: de conducteur wacht op het perron (laagst %.2f m, plan %s)" % [lowest, station._chase_plan])
	_call_off_the_chase(station)


## The player on the next platform: the conductor goes there along the route (out through
## the gates of his platform, through the hall), never across the rails.
func test_conductor_goes_to_another_platform_through_the_hall(test) -> void:
	var station := await _station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	var from_platform := Layout.platform_of_track(_empty_track(station))
	await _dodge_the_fare(station, _free_lane_in(station._gates[from_platform]))
	test.check(station._chaser != null, "zwart erdoor: een conducteur")
	# the next platform, its edge on this side: near enough that he does not give up
	var other_platform := from_platform - 1 if from_platform > 0 else from_platform + 1
	var other_span := Layout.platform_span(Layout.platforms()[other_platform])
	var near_edge := other_span.y - 0.6 if other_platform < from_platform else other_span.x + 0.6
	var other_spot := station.to_global(Vector3(near_edge, 0.0, 6.0))
	var over_rails := 0
	var via_hall := false
	for attempt in 40:
		player.teleport(other_spot, 0.0)
		await seconds(0.25)
		if station._chaser == null:
			break
		var chaser_at: Vector3 = station._chaser.position
		if station.floor_height(chaser_at) < -0.5 and chaser_at.y > -0.3:
			over_rails += 1
		var gate_steps: Array = (station._chaser.steps as Array).filter(func(step: Dictionary) -> bool: return String(step.type) == "gate")
		if String(station._chase_plan).begins_with("route") and (gate_steps.size() >= 1 or chaser_at.z < Layout.GATE_Z):
			via_hall = true
	test.check(over_rails == 0 and via_hall, "naar een ander perron gaat de conducteur via de poortjes en de hal (%d keer boven het spoor, plan %s)" % [over_rails, station._chase_plan])
	_call_off_the_chase(station)


## A traveller who falls off the platform onto the rails climbs back up within 10 s.
func test_who_falls_onto_the_rails_climbs_back(test) -> void:
	var station := await _station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	var faller: Node3D = null
	var found := await wait_until(func() -> bool:
		for person: Node3D in station.station_people():
			if not person.is_staff() and person.position.z > 6.0 and absf(person.position.y) < 0.05 and person.follow == null:
				faller = person
				return true
		return false, 60.0)
	test.check(found, "een reiziger op een perron")
	if faller == null:
		return
	var fall_track := _empty_track(station)
	faller.position = Vector3(Layout.platform_edge_x(fall_track) - Layout.platform_side(fall_track) * 0.3, 0.0, 20.0)
	faller._falling = true
	var landed := false
	var back_up := false
	for attempt in 40:
		await seconds(0.25)
		if not is_instance_valid(faller):
			break
		landed = landed or faller.position.y < -1.0
		if landed and faller.position.y > -0.05 and not faller._falling:
			back_up = true
			break
	test.check(landed and back_up, "iemand die van het perron valt klimt binnen 10 s weer omhoog (gevallen %d, geklommen %d)" % [station.falls, station.climbs])


## A train that is due shuts its doors and leaves; its track gets the next one, which comes
## in within a few minutes, stops and opens its doors.
func test_due_train_leaves_and_the_next_comes_in(test) -> void:
	var station := await _station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	await seconds(1.5)
	var standing: Array = station.departures().filter(func(departure: Dictionary) -> bool: return departure.state == "staat")
	test.check(not standing.is_empty(), "treinen die er staan (%d)" % standing.size())
	if standing.is_empty():
		return
	var leaving: Dictionary = standing[0]
	var track := int(leaving.track)
	station._minutes = float(leaving.time) + float(leaving.delay) - 20.0 / 60.0
	for attempt in 24:
		await _tick(0.5)
	test.check(leaving.closing, "de deuren van de trein op spoor %d gaan dicht" % track)
	var gone := false
	for attempt in 80:
		await _tick(0.5)
		if leaving.state == "vertrokken":
			gone = true
			break
	if not gone and leaving.train:
		print("  trein: neus z %.1f, snelheid %.2f, deuren dicht %s, toestand %s" % [leaving.train.nose_z, leaving.train.speed, leaving.train.doors_shut(), leaving.train.state])
	test.check(gone, "de trein op spoor %d is vertrokken (%s)" % [track, leaving.state])
	await seconds(0.5)
	var next: Dictionary = station._track_departure.get(track, {})
	test.check(not next.is_empty() and int(next.id) != int(leaving.id), "spoor %d heeft weer een volgende trein" % track)
	if next.is_empty():
		return
	var wait_minutes: float = station._departs_at(next) - float(next.dwell) - station._minutes
	test.check(wait_minutes <= station.GAP_MINUTES.y + 1.0 + float(next.delay), "de volgende trein op spoor %d komt binnen %.1f min" % [track, wait_minutes])
	next.cancelled = false
	station._minutes += maxf(wait_minutes, 0.0) + 0.01
	var arrived := false
	for attempt in 60:
		await _tick(0.5)
		if next.state == "staat" and next.train and next.train.doors_open():
			arrived = true
			break
	test.check(arrived, "er komt weer een trein aan op spoor %d (uit %s), deuren open (%s)" % [track, next.get("origin", "?"), next.state])


## Over 15 s nobody who should be walking stays on one spot, and there are no long queues
## before the gates.
func test_nobody_gets_stuck_or_queues_long_at_the_gates(test) -> void:
	var station := await _station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	await seconds(5.0)
	var through := 0
	for person: Node in station.station_people():
		if person.position.z > Layout.GATE_Z:
			through += 1
	print("mensen voorbij de poortjes: %d van %d" % [through, station.station_people().size()])
	var before := {}
	for person: Node3D in station.station_people():
		before[person] = person.position
	for attempt in 30:
		await _tick(0.5)
	var stuck := []
	var at_gates := {}
	for person: Node3D in station.station_people():
		var step: Dictionary = person.current_step()
		if not step.is_empty() and String(step.type) == "gate":
			at_gates[person._gate_phase] = int(at_gates.get(person._gate_phase, 0)) + 1
		if not before.has(person) or person.follow != null:
			continue
		var walking := not step.is_empty() and String(step.type) in ["walk", "board"]
		if walking and person.position.distance_to(before[person]) < 0.3:
			stuck.append("%s %s bij %s (%s)" % [person.role, step.type, person.position.snapped(Vector3.ONE * 0.1), person._gate_phase])
	print("bij de poortjes: %s" % str(at_gates))
	test.check(int(at_gates.get("naar", 0)) + int(at_gates.get("wachten", 0)) < 25, "geen lange rijen voor de poortjes")
	for line: String in stuck.slice(0, 8):
		print("  vast: ", line)
	test.check(stuck.size() <= 2, "niemand loopt vast (%d)" % stuck.size())


## A few minutes of the station: no one who should be walking stands still longer than
## STILL_LIMIT s or jumps more than 0.6 m in height in one step, no one stays on the rails;
## people get into trains, come in at the doors and off the trains, go out at the doors,
## and it never gets fuller than the station holds.
func test_travellers_keep_coming_going_and_moving(test) -> void:
	var station := await _station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	var still_since := {}
	var last_spot := {}
	var last_height := {}
	var height_jumps := []
	var worst := []
	for second in WATCH_SECONDS:
		await close_screens()
		for tick in 10:
			await seconds(0.1)
			for person: Node3D in station.station_people():
				var kind := String(person.current_step().get("type", ""))
				if last_height.has(person) and absf(person.position.y - float(last_height[person])) > 0.6 \
						and not person._falling and not kind in ["climb", "board", "leave", "climbed"]:
					height_jumps.append("%s %s %.2f -> %.2f" % [person.role, kind, last_height[person], person.position.y])
				last_height[person] = person.position.y
		for person: Node3D in station.station_people():
			if person.follow != null:
				continue
			var kind := String(person.current_step().get("type", ""))
			var deliberate := kind in ["", "wait", "wait_train", "stand", "tap"]
			var moved: bool = not last_spot.has(person) or (last_spot[person] as Vector3).distance_to(person.position) > 0.2
			last_spot[person] = person.position
			if moved or deliberate:
				still_since[person] = second
				continue
			var still := second - int(still_since.get(person, second))
			if still > STILL_LIMIT and not worst.any(func(entry: Array) -> bool: return entry[0] == person):
				worst.append([person, "%s %s/%s bij %s, %d s stil" % [person.role, kind, person._gate_phase, person.position.snapped(Vector3.ONE * 0.1), still]])
	for entry: Array in worst.slice(0, 10):
		print("  stil: ", entry[1])
	test.check(worst.is_empty(), "in %d s staat niemand langer dan %d s onbedoeld stil (%d)" % [WATCH_SECONDS, STILL_LIMIT, worst.size()])
	test.check(height_jumps.is_empty(), "niemand gaat in een stap meer dan 0,6 m omhoog of omlaag %s" % str(height_jumps.slice(0, 4)))
	var on_the_rails_still: Array = station.station_people().filter(func(person: Node3D) -> bool: return person.position.y < -0.5 and String(person.current_step().get("type", "")) != "board")
	test.check(on_the_rails_still.size() <= 1, "niemand blijft op het spoor (%d)" % on_the_rails_still.size())
	print("gevallen %d, geklommen %d, losgemaakt %d" % [station.falls, station.climbs, station.unstuck])
	print("ingestapt %d, naar buiten %d, binnen door de deuren %d, uit de trein %d" % [station.boarded, station.went_out, station.came_in_at_doors, station.came_by_train])
	test.check(station.boarded > 0, "mensen stappen in de trein (%d)" % station.boarded)
	test.check(station.came_in_at_doors > 0, "nieuwe mensen lopen binnen door de deuren (%d)" % station.came_in_at_doors)
	test.check(station.came_by_train > 0, "mensen komen met de trein aan (%d)" % station.came_by_train)
	test.check(station.went_out > 0, "mensen verlaten het station door de deuren (%d)" % station.went_out)
	test.check(station._travellers() <= station._traveller_cap() + station.ALIGHTING_AT_FULL, "niet te druk (%d reizigers, maximum %d)" % [station._travellers(), station._traveller_cap()])


## At door 3 inside [E] takes you out, and you stand before the eastern door on the square.
func test_out_through_door_three(test) -> void:
	var station := await _station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	var exit_three: Node3D = interiors._exits["centraal"][2]
	player.teleport(exit_three.global_position, 0.0)
	for frame_index in 4:
		await tree.physics_frame
	test.check(prompts() == [["E", "Naar buiten"]], "bij deur 3 binnen: [E] Naar buiten")
	use_prompt()
	await seconds(1.4)
	var east: Dictionary = _ways_in().filter(func(way: Dictionary) -> bool: return int(way.door_index) == 3)[0]
	test.check(not interiors.is_inside() and player.global_position.distance_to(east.door) < 2.5, "weer buiten bij de oostelijke deur (%.1f m)" % player.global_position.distance_to(east.door))
