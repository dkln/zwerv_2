extends SceneTree
## Den Haag Centraal from the inside (scripts/world/station.gd and its parts): the three doors
## of the station hall on the square are ways in (west to east door 1..3), going in at the
## middle one puts you at Deur2 of the hall; the station has a departure on every track,
## trains standing, the gates before every platform (lanes in and out, shut without a card),
## OV-chipkaart machines, OV posts, the people behind the counters and people walking; a card
## bought at a machine opens a gate; a train that is due leaves (whistle, doors, out of the
## hall) and its track gets the next one; out through door 3 you stand before the eastern door.
## usage: tools/godot.sh --headless --script tools/check/station_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const Layout = preload("res://scripts/world/station_layout.gd")

var _problems: Array[String] = []
## Seconds someone on their way may stand still before they count as stuck.
const STILL_LIMIT := 20
var _chaser_lowest := 0.0


func _init() -> void:
	Common.watchdog(self, 560)
	PlayerCharacter.choose("martin")
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	var hud: Node = scene.get_node("HUD")
	var follow: Node = scene.get_node("Volgcamera")
	follow._end_arrival()
	for frame_index in 600:
		await physics_frame
		if player._placed and not player._sleeping:
			break
	player._wake_up()
	for attempt in 40:
		if not player._sleeping:
			break
		await create_timer(0.1, true).timeout
	for frame_index in 120:
		await process_frame
		if hud._story_box.is_showing():
			hud._story_box._pages = hud._story_box._pages.slice(-1)
			hud._story_box._page_index = 0
			hud._story_box._next_page()
	var interiors: Node = scene.get_node("Binnenruimtes")
	var ways: Array = interiors.ways_in().filter(func(way: Dictionary) -> bool: return way.kind == "centraal")
	for way: Dictionary in ways:
		print("  Centraal deur %d: %s" % [way.door_index, way.door.snapped(Vector3.ONE * 0.1)])
	_check(ways.size() == 3, "drie ingangen van Centraal (%d)" % ways.size())
	if ways.size() < 2:
		_finish()
		return
	_check((ways[0].door as Vector3).x < (ways[1].door as Vector3).x and (ways[1].door as Vector3).x < (ways[2].door as Vector3).x, "deur 1..3 van west naar oost")
	var middle: Dictionary = ways.filter(func(way: Dictionary) -> bool: return int(way.door_index) == 2)[0]
	player.teleport(middle.door, 0.0)
	for frame_index in 4:
		await physics_frame
	_check(hud._action_prompts.actions() == [["E", "Naar binnen"]], "bij de deur: [E] Naar binnen")
	player._talk_partner.go_through()
	await create_timer(1.4, true).timeout
	var station: Node3D = interiors._interior
	_check(interiors.is_inside() and station != null and station.has_method("departures"), "binnen in het station")
	if station == null or not station.has_method("departures"):
		_finish()
		return
	var door_two := station.get_node("Deur2") as Node3D
	_check(player.global_position.distance_to(door_two.global_position) < 2.0, "binnen bij deur 2 (%.1f m)" % player.global_position.distance_to(door_two.global_position))
	await create_timer(1.5, true).timeout
	var departures: Array = station.departures()
	var tracks := {}
	for departure: Dictionary in departures:
		tracks[int(departure.track)] = true
	_check(tracks.size() == Layout.TRACK_COUNT, "een vertrek op elk spoor (%d)" % tracks.size())
	var standing: Array = departures.filter(func(departure: Dictionary) -> bool: return departure.state == "staat")
	_check(not standing.is_empty(), "treinen die er staan (%d)" % standing.size())
	var gates: Array = station._gates
	var lane_count := 0
	for gates_node in gates:
		lane_count += (gates_node.lanes as Array).size()
	_check(gates.size() == Layout.platforms().size() and lane_count >= 20, "poortjes voor elk perron (%d rijen, %d poortjes)" % [gates.size(), lane_count])
	_check(station._posts.size() >= 8, "OV-paaltjes (%d)" % station._posts.size())
	_check(station._keepers.size() >= 10, "mensen achter de toonbanken (%d)" % station._keepers.size())
	_check(station.get_tree().get_nodes_in_group("deuren").filter(func(node: Node) -> bool: return String(node.name).begins_with("Kaartautomaat")).size() >= 8, "OV-chipkaartautomaten")
	var board_rows: Array = station._boards[0]
	_check(not String((board_rows[0][1] as Label3D).text).is_empty(), "het vertrekbord toont treinen (%s)" % (board_rows[0][1] as Label3D).text)
	_check(station.station_people().size() > 5, "mensen in het station (%d)" % station.station_people().size())
	# further out than in a snack bar, the location under the minimap, the overhead lines
	_check(is_equal_approx(follow._zoom, 20.0) and follow._zoom > follow.indoor_zoom, "verder uitgezoomd in het station (%.1f m in beeld)" % follow._zoom)
	hud._update_location()
	_check(hud._location_wijk.text == "STATION DEN HAAG CENTRAAL", "locatie bij de kaart: %s" % hud._location_wijk.text)
	var wires := station.get_node_or_null("Bovenleiding") as MeshInstance3D
	_check(wires != null and wires.mesh != null and wires.mesh.get_surface_count() > 0, "bovenleiding over de sporen")
	var masts := station.get_children().filter(func(node: Node) -> bool: return String(node.name).begins_with("Bovenleidingmast"))
	var slim := masts.filter(func(mast: Node) -> bool:
		if not mast is StaticBody3D:
			return false
		var shapes := mast.get_children().filter(func(child: Node) -> bool: return child is CollisionShape3D and child.shape is BoxShape3D)
		return shapes.size() == 1 and (shapes[0].shape as BoxShape3D).size.x <= 0.3 and (shapes[0].shape as BoxShape3D).size.z <= 0.3)
	_check(masts.size() == 8 and slim.size() == 8, "slanke masten met slanke colliders (%d masten, %d slank: %s)" % [masts.size(), slim.size(), str(masts.map(func(mast: Node) -> String: return "%s %s" % [mast.name, mast.get_class()]))])
	# every text stays on its board (Vertrekbord 6 m wide, Perronscherm 2.5 m)
	var overflowing := []
	for rows: Array in station._boards:
		for row: Array in rows:
			for label: Label3D in row:
				var text_width := label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size
				var left := label.position.x - (text_width * 0.5 if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0)
				if left < -2.88 or left + text_width > 2.88:
					overflowing.append(label.text)
	for track: int in station._displays:
		for key: String in ["time", "destination"]:
			var label: Label3D = station._displays[track][key]
			var text_width := label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size
			if label.position.x + text_width > 1.13:
				overflowing.append(label.text)
	_check(overflowing.is_empty(), "teksten binnen de borden %s" % str(overflowing))
	station._fit_text(station._displays[1].time, "12:34  Rijdt niet", station.DISPLAY_EDGE - station.DISPLAY_TEXT_LEFT)
	station._fit_text(station._displays[1].destination, "Rotterdam Centraal", station.DISPLAY_EDGE - station.DISPLAY_TEXT_LEFT)
	# an announcement types out with the cursor while the voice talks
	station._announcement_pause = 0.0
	station._announcements.clear()
	station._announcing = false
	station._speak("Spoor 5: de Intercity naar Venlo, vertrekt om 12:34.")
	await create_timer(2.6, true).timeout
	_check(station._subtitle_layer.visible and not station._subtitle_typewriter.is_done() and String(station._subtitle.text).contains("[bgcolor"), "omroeptekst typt uit met cursor")
	# a gate without a card stays shut, with one it opens (a lane no one is using)
	_awake(hud)
	var lane: Node3D = gates[1].lanes[0]
	for candidate: Node3D in gates[3].lanes + gates[1].lanes:
		if candidate.direction > 0 and candidate.occupant == null and candidate.queue.is_empty():
			lane = candidate
	player.inventory.erase("ov_chipkaart")
	player.teleport(station.to_global(lane.entry_point()), 0.0)
	for frame_index in 4:
		await physics_frame
	_check(hud._action_prompts.actions() == [["E", "Inchecken"]], "bij een poortje: [E] Inchecken (%s)" % str(hud._action_prompts.actions()))
	player._talk_partner.go_through()
	await create_timer(1.0, true).timeout
	_check(not lane.is_open(), "zonder OV-chipkaart blijft het poortje dicht")
	var machine: Node3D = station.get_node("Kaartautomaat")
	player.add_money(10.0)
	var money_before: float = player.money
	machine.go_through()
	_check(int(player.inventory.get("ov_chipkaart", 0)) == 1 and is_equal_approx(player.money, money_before - 7.5), "OV-chipkaart gekocht (€ 7,50)")
	_awake(hud)
	print("poortje bezet door: %s" % [lane.occupant])
	lane.go_through()
	await create_timer(1.0, true).timeout
	_check(lane.is_open(), "met een OV-chipkaart gaat het poortje open (gepauzeerd: %s)" % paused)
	# fare dodging: through with a check-in is fine, over the gates without one a conductor may come after you
	station.fare_check_chance_override = 1.0
	for frame_index in 3:
		await process_frame
	player.teleport(station.to_global(lane.exit_point() + Vector3(0.0, 0.0, 0.6)), 0.0)
	for frame_index in 3:
		await process_frame
	_check(station.chases_started == 0 and station._chaser == null, "ingecheckt door het poortje: geen conducteur erachteraan")
	# the paddles can be jumped: at the top of a jump (0.9 m) the figure clears them
	var shut_lane: Node3D = null
	for candidate: Node3D in gates[2].lanes:
		if candidate.direction > 0 and not candidate.is_open():
			shut_lane = candidate
	if shut_lane:
		var over := station.to_global(Vector3(shut_lane.station_x(), 0.0, Layout.GATE_Z))
		_check(not player._fits(over) and player._fits(over + Vector3.UP * 0.5), "over een dicht poortje springen kan (hoogte %.1f m)" % player.jump_height)
	var dodge_lane: Node3D = shut_lane if shut_lane else lane
	var hall_side := station.to_global(dodge_lane.entry_point())
	var platform_side := station.to_global(dodge_lane.exit_point() + Vector3(0.0, 0.0, 0.6))
	player.remove_meta("ov_doorgang_tot")
	player.teleport(hall_side, 0.0)
	for frame_index in 3:
		await process_frame
	player.teleport(platform_side, 0.0)
	for frame_index in 3:
		await process_frame
	_check(station.chases_started == 1 and station._chaser != null, "zonder inchecken over het poortje: een conducteur komt erachteraan")
	player.add_money(80.0 - player.money)
	var caught := false
	for attempt in 40:
		_awake(hud)
		await create_timer(0.25, true).timeout
		if station.fines > 0:
			caught = true
			break
	_check(caught and is_equal_approx(player.money, 30.0), "ingehaald: beboet voor zwartrijden (€ %.2f over van € 80)" % player.money)
	_check(station._chaser == null, "de conducteur gaat terug na de boete")
	# again (at gates far from the first conductor), and this time get away: far off, the conductor gives up
	var far_lane: Node3D = gates[gates.size() - 1].lanes[0]
	for candidate: Node3D in gates[gates.size() - 1].lanes:
		if candidate.direction > 0:
			far_lane = candidate
	var fines_before: int = station.fines
	player.teleport(station.to_global(far_lane.entry_point()), 0.0)
	for frame_index in 3:
		await process_frame
	player.teleport(station.to_global(far_lane.exit_point() + Vector3(0.0, 0.0, 0.6)), 0.0)
	for frame_index in 3:
		await process_frame
	_check(station.chases_started == 2, "weer zwart erdoor: weer een conducteur (%d)" % station.chases_started)
	var hiding_places := [Vector3(-44.0, 0.0, -28.0), Vector3(44.0, 0.0, -28.0), Vector3(Layout.platform_walk_x(1), 0.0, 46.0), Vector3(Layout.platform_walk_x(12), 0.0, 46.0)]
	var escaped := false
	for attempt in 40:
		# always the spot furthest from him (running away)
		_awake(hud)
		var chaser: Node3D = station._chaser
		if chaser:
			_chaser_lowest = minf(_chaser_lowest, chaser.position.y)
			hiding_places.sort_custom(func(first: Vector3, second: Vector3) -> bool: return first.distance_to(chaser.position) > second.distance_to(chaser.position))
			player.teleport(station.to_global(hiding_places[0]), 0.0)
		await create_timer(0.25, true).timeout
		if station._chaser == null:
			escaped = true
			break
	_check(escaped and _chaser_lowest > -0.3, "de conducteur komt nooit op het spoor (laagst %.2f m)" % _chaser_lowest)
	_check(escaped and station.chases_given_up >= 1 and station.fines == fines_before, "ontsnapt: de conducteur geeft het op (%d keer opgegeven, %d boetes)" % [station.chases_given_up, station.fines])
	# the player down on the rails: the conductor stays on the platform edge above them
	var rail_track := 7
	for candidate in range(1, Layout.TRACK_COUNT + 1):
		var on_it: Dictionary = station._track_departure.get(candidate, {})
		if on_it.is_empty() or on_it.get("train") == null:
			rail_track = candidate
	var rail_platform := Layout.platform_of_track(rail_track)
	var rail_lanes: Array = gates[rail_platform].lanes.filter(func(candidate: Node3D) -> bool: return candidate.direction > 0)
	var rail_lane: Node3D = rail_lanes[0]
	player.teleport(station.to_global(rail_lane.entry_point()), 0.0)
	for frame_index in 3:
		await process_frame
	player.teleport(station.to_global(rail_lane.exit_point() + Vector3(0.0, 0.0, 0.6)), 0.0)
	for frame_index in 3:
		await process_frame
	var rail_chaser: Node3D = station._chaser
	_check(rail_chaser != null, "zwart erdoor bij spoor %d: een conducteur" % rail_track)
	var on_the_rails := station.to_global(Vector3(Layout.track_x(rail_track), -Layout.PLATFORM_DROP, 14.0))
	var lowest := 0.0
	var waited_at_edge := false
	for attempt in 24:
		player.teleport(on_the_rails, 0.0)
		await create_timer(0.25, true).timeout
		if station._chaser == null:
			break
		lowest = minf(lowest, station._chaser.position.y)
		if String(station._chase_plan).begins_with("spoor"):
			waited_at_edge = true
	_check(waited_at_edge and lowest > -0.3, "speler op het spoor: de conducteur wacht op het perron (laagst %.2f m, plan %s)" % [lowest, station._chase_plan])
	# chasing to another platform: along the route (the hall, the gates), never over the rails
	# (the next platform, its edge on this side: near enough that he does not give up)
	var other_platform := rail_platform - 1 if rail_platform > 0 else rail_platform + 1
	var other_span := Layout.platform_span(Layout.platforms()[other_platform])
	var near_edge := other_span.y - 0.6 if other_platform < rail_platform else other_span.x + 0.6
	var other_spot := station.to_global(Vector3(near_edge, 0.0, 6.0))
	var over_rails := 0
	var via_hall := false
	for attempt in 40:
		player.teleport(other_spot, 0.0)
		await create_timer(0.25, true).timeout
		if station._chaser == null:
			break
		var chaser_at: Vector3 = station._chaser.position
		if station.floor_height(chaser_at) < -0.5 and chaser_at.y > -0.3:
			over_rails += 1
		# his way: out through the gates of his platform, through the hall, in at the others
		var gate_steps: Array = (station._chaser.steps as Array).filter(func(step: Dictionary) -> bool: return String(step.type) == "gate")
		if String(station._chase_plan).begins_with("route") and (gate_steps.size() >= 1 or chaser_at.z < Layout.GATE_Z):
			via_hall = true
	_check(over_rails == 0 and via_hall, "naar een ander perron gaat de conducteur via de poortjes en de hal (%d keer boven het spoor, plan %s)" % [over_rails, station._chase_plan])
	if station._chaser != null:
		station._end_chase()
	station.fare_check_chance_override = -1.0
	# someone who falls onto the rails by accident gets back up
	var faller: Node3D = null
	for person: Node3D in station.station_people():
		if not person.is_staff() and person.position.z > 6.0 and absf(person.position.y) < 0.05 and person.follow == null:
			faller = person
			break
	if faller:
		var fall_track := rail_track
		var edge_x := Layout.platform_edge_x(fall_track)
		faller.position = Vector3(edge_x - Layout.platform_side(fall_track) * 0.3, 0.0, 20.0)
		faller._falling = true
		var landed := false
		var back_up := false
		for attempt in 40:
			await create_timer(0.25, true).timeout
			if not is_instance_valid(faller):
				break
			landed = landed or faller.position.y < -1.0
			if landed and faller.position.y > -0.05 and not faller._falling:
				back_up = true
				break
		_check(landed and back_up, "iemand die van het perron valt klimt binnen 10 s weer omhoog (geval %d, geklommen %d)" % [station.falls, station.climbs])
	# a train that is due leaves, and its track gets the next one
	var leaving: Dictionary = standing[0]
	var track := int(leaving.track)
	station._minutes = float(leaving.time) + float(leaving.delay) - 20.0 / 60.0
	for attempt in 24:
		_awake(hud)
		await create_timer(0.5, true).timeout
	_check(leaving.closing, "de deuren van de trein op spoor %d gaan dicht" % track)
	var gone := false
	for attempt in 80:
		_awake(hud)
		await create_timer(0.5, true).timeout
		if leaving.state == "vertrokken":
			gone = true
			break
	if not gone and leaving.train:
		print("  trein: neus z %.1f, snelheid %.2f, deuren dicht %s, toestand %s" % [leaving.train.nose_z, leaving.train.speed, leaving.train.doors_shut(), leaving.train.state])
	_check(gone, "de trein op spoor %d is vertrokken (%s)" % [track, leaving.state])
	await create_timer(0.5, true).timeout
	var next: Dictionary = station._track_departure.get(track, {})
	_check(not next.is_empty() and int(next.id) != int(leaving.id), "spoor %d heeft weer een volgende trein" % track)
	# ...which comes in soon (a train every few minutes per track), stops, opens its doors
	if not next.is_empty():
		var wait_minutes: float = station._departs_at(next) - float(next.dwell) - station._minutes
		_check(wait_minutes <= station.GAP_MINUTES.y + 1.0 + float(next.delay), "de volgende trein op spoor %d komt binnen %.1f min" % [track, wait_minutes])
		next.cancelled = false
		station._minutes += maxf(wait_minutes, 0.0) + 0.01
		var arrived := false
		for attempt in 60:
			_awake(hud)
			await create_timer(0.5, true).timeout
			if next.state == "staat" and next.train and next.train.doors_open():
				arrived = true
				break
		_check(arrived, "er komt weer een trein aan op spoor %d (uit %s), deuren open (%s)" % [track, next.get("origin", "?"), next.state])
	var through := 0
	for person: Node in station.station_people():
		if person.position.z > Layout.GATE_Z:
			through += 1
	print("mensen voorbij de poortjes: %d van %d" % [through, station.station_people().size()])
	# nobody stuck: who should be walking moves
	var before := {}
	for person: Node3D in station.station_people():
		before[person] = person.position
	for attempt in 30:
		_awake(hud)
		await create_timer(0.5, true).timeout
	var stuck := []
	for person: Node3D in station.station_people():
		if not before.has(person) or person.follow != null:
			continue
		var step: Dictionary = person.current_step()
		var walking := not step.is_empty() and String(step.type) in ["walk", "board"]
		if walking and person.position.distance_to(before[person]) < 0.3:
			stuck.append("%s %s bij %s (%s)" % [person.role, step.type, person.position.snapped(Vector3.ONE * 0.1), person._gate_phase])
	var at_gates := {}
	for person: Node3D in station.station_people():
		var step: Dictionary = person.current_step()
		if not step.is_empty() and String(step.type) == "gate":
			at_gates[person._gate_phase] = int(at_gates.get(person._gate_phase, 0)) + 1
	print("bij de poortjes: %s" % str(at_gates))
	_check(int(at_gates.get("naar", 0)) + int(at_gates.get("wachten", 0)) < 25, "geen lange rijen voor de poortjes")
	for line in stuck.slice(0, 8):
		print("  vast: ", line)
	print("ingestapt %d, naar buiten %d" % [station.boarded, station.went_out])
	_check(stuck.size() <= 2, "niemand loopt vast (%d)" % stuck.size())
	# a few minutes: no one who should be walking stands still for more than STILL_LIMIT s
	var still_since := {}
	var last_spot := {}
	var last_height := {}
	var height_jumps := []
	var worst := []
	for second in 150:
		_awake(hud)
		for tick in 10:
			await create_timer(0.1, true).timeout
			for person: Node3D in station.station_people():
				var kind := String(person.current_step().get("type", ""))
				if last_height.has(person) and absf(person.position.y - float(last_height[person])) > 0.6 \
						and not person._falling and not kind in ["climb", "board", "leave", "climbed"]:
					height_jumps.append("%s %s %.2f -> %.2f" % [person.role, kind, last_height[person], person.position.y])
				last_height[person] = person.position.y
		for person: Node3D in station.station_people():
			if person.follow != null:
				continue
			var step: Dictionary = person.current_step()
			var kind := String(step.get("type", ""))
			var deliberate := kind in ["", "wait", "wait_train", "stand", "tap"]
			var moved: bool = not last_spot.has(person) or (last_spot[person] as Vector3).distance_to(person.position) > 0.2
			last_spot[person] = person.position
			if moved or deliberate:
				still_since[person] = second
				continue
			var still := second - int(still_since.get(person, second))
			if still > STILL_LIMIT and not worst.any(func(entry: Array) -> bool: return entry[0] == person):
				worst.append([person, "%s %s/%s bij %s, %d s stil" % [person.role, kind, person._gate_phase, person.position.snapped(Vector3.ONE * 0.1), still]])
	for entry in worst.slice(0, 10):
		print("  stil: ", entry[1])
	_check(worst.is_empty(), "in %d s staat niemand langer dan %d s onbedoeld stil (%d)" % [150, STILL_LIMIT, worst.size()])
	_check(height_jumps.is_empty(), "niemand gaat in een stap meer dan 0,6 m omhoog of omlaag %s" % str(height_jumps.slice(0, 4)))
	var on_the_rails_still: Array = station.station_people().filter(func(person: Node3D) -> bool: return person.position.y < -0.5 and String(person.current_step().get("type", "")) != "board")
	_check(on_the_rails_still.size() <= 1, "niemand blijft op het spoor (%d)" % on_the_rails_still.size())
	print("gevallen %d, geklommen %d, losgemaakt %d" % [station.falls, station.climbs, station.unstuck])
	_check(station.boarded > 0, "mensen stappen in de trein (%d)" % station.boarded)
	# the crowd comes and goes: in at the doors and off the trains, out at the doors and into trains
	print("binnen door de deuren %d, uit de trein %d" % [station.came_in_at_doors, station.came_by_train])
	_check(station.came_in_at_doors > 0, "nieuwe mensen lopen binnen door de deuren (%d)" % station.came_in_at_doors)
	_check(station.came_by_train > 0, "mensen komen met de trein aan (%d)" % station.came_by_train)
	_check(station.went_out > 0, "mensen verlaten het station door de deuren (%d)" % station.went_out)
	_check(station._travellers() <= station._traveller_cap() + station.ALIGHTING_AT_FULL, "niet te druk (%d reizigers, maximum %d)" % [station._travellers(), station._traveller_cap()])
	# out through door 3
	_awake(hud)
	var exit_three: Node3D = interiors._exits["centraal"][2]
	player.teleport(exit_three.global_position, 0.0)
	for frame_index in 4:
		await physics_frame
	_check(hud._action_prompts.actions() == [["E", "Naar buiten"]], "bij deur 3 binnen: [E] Naar buiten")
	player._talk_partner.go_through()
	await create_timer(1.4, true).timeout
	var east: Dictionary = ways.filter(func(way: Dictionary) -> bool: return int(way.door_index) == 3)[0]
	_check(not interiors.is_inside() and player.global_position.distance_to(east.door) < 2.5, "weer buiten bij de oostelijke deur (%.1f m)" % player.global_position.distance_to(east.door))
	_finish()


## A story page or a mission notice pauses the game: away with it.
func _awake(hud: Node) -> void:
	if hud._story_box.is_showing():
		print("  (verhaalvenster weggeklikt: %s)" % str(hud._story_box._pages.slice(0, 1)).left(80))
		hud._story_box._pages = hud._story_box._pages.slice(-1)
		hud._story_box._page_index = 0
		hud._story_box._next_page()
	if paused:
		print("  (spel stond op pauze)")
		paused = false


func _finish() -> void:
	print("station ok" if _problems.is_empty() else "problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FOUT  ") + what)
	if not ok:
		_problems.append(what)
