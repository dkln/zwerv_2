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


func _init() -> void:
	Common.watchdog(self, 300)
	PlayerCharacter.choose("martin")
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook", "Grassprieten"]:
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
	_check(station.boarded > 0, "mensen stappen in de trein (%d)" % station.boarded)
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
