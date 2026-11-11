extends SceneTree
## The set of people and traffic round the player (scripts/world/pedestrians.gd,
## scripts/traffic/traffic.gd, Crowd and data/drukte.json): as many as the hour and the
## neighbourhood want; at night fewer (the rest out of the tree, kept), in the morning rush
## more again and of other kinds (commuters, business people); after a jump of the player
## (as a warp) all of them round the new spot; a vehicle taken out and put back drives on.
## Without a camera nothing counts as unseen, so the test lets it (unseen_without_camera).
## usage: tools/godot.sh --headless --script tools/check/crowd_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 300)
	PlayerCharacter.choose("martin")
	var scene := Common.instantiate(Common.CITY, true)
	for node_name in ["DetailNiveau", "Rook", "Verhaal", "Camera", "Doorkijk"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	var day: Node = scene.get_node("Dagcyclus")
	day.speed = 0.0
	day.time_of_day = 13.0
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	var traffic: Traffic = scene.get_node("Verkeer")
	walkers.unseen_without_camera = true
	traffic.unseen_without_camera = true
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	for frame_index in 300:
		await physics_frame
		if player._placed and not walkers.people().is_empty():
			break
	await physics_frame
	# midday
	var midday_people := walkers.people().size()
	var midday_traffic := traffic.vehicles().size()
	var wanted: Vector2i = traffic.wanted_counts()
	print("13:00: voetgangers %d (gewenst %d), verkeer %d + diensten (gewenst %d + %d)" % [midday_people, walkers.wanted_count(),
			traffic._town.size(), wanted.x, wanted.y])
	_check(midday_people == walkers.wanted_count(), "voetgangers zoals gewenst om 13:00")
	_check(traffic._town.size() == wanted.x and traffic._services.size() == wanted.y, "verkeer zoals gewenst om 13:00")
	_check(_all_within(walkers.people(), player.global_position, walkers.reach), "voetgangers rond de speler")
	_check(_vehicles_within(traffic, player.global_position, traffic.appear_within + 5.0), "verkeer rond de speler")
	# the night: fewer
	walkers.changes_per_second = 1000
	traffic.changes_per_tick = 1000
	day.time_of_day = 3.0
	walkers._keep_round_player()
	await _traffic_ticks(traffic, 2)
	wanted = traffic.wanted_counts()
	print("03:00: voetgangers %d (gewenst %d, %d rusten), verkeer %d (gewenst %d, %d geparkeerd)" % [walkers.people().size(),
			walkers.wanted_count(), walkers._resting.size(), traffic._town.size(), wanted.x, traffic._parked.size()])
	# who is close to the player stays (only who is out of sight and further off goes)
	var near_people := _near(walkers.people(), player.global_position, walkers.renew_beyond)
	var near_traffic := _near(traffic._town, player.global_position, traffic.renew_beyond)
	_check(walkers.people().size() <= maxi(walkers.wanted_count(), near_people) and walkers.people().size() < midday_people,
			"'s nachts minder voetgangers (%d dichtbij blijven)" % near_people)
	_check(walkers._resting.size() > 0 and walkers._resting.all(func(person: Pedestrian) -> bool: return not person.is_inside_tree()),
			"wie niet nodig is rust buiten de boom")
	_check(traffic._town.size() <= maxi(wanted.x, near_traffic) and traffic.vehicles().size() < midday_traffic,
			"'s nachts minder verkeer (%d dichtbij blijven)" % near_traffic)
	_check(traffic._parked.all(func(vehicle: Vehicle) -> bool: return not vehicle.is_inside_tree() and not Vehicle.all_vehicles.has(vehicle)),
			"geparkeerd verkeer is uit de stad")
	# the morning rush: more again, other people
	day.time_of_day = 8.0
	walkers._keep_round_player()
	await _traffic_ticks(traffic, 2)
	wanted = traffic.wanted_counts()
	var kinds := {}
	for person in walkers.people():
		kinds[person.crowd_kind] = int(kinds.get(person.crowd_kind, 0)) + 1
	print("08:00: voetgangers %d (gewenst %d), verkeer %d (gewenst %d); soorten %s" % [walkers.people().size(), walkers.wanted_count(),
			traffic._town.size(), wanted.x, str(kinds)])
	_check(walkers.people().size() == walkers.wanted_count(), "ochtendspits: weer zoveel voetgangers als gewenst")
	_check(traffic._town.size() == wanted.x, "ochtendspits: weer zoveel verkeer als gewenst")
	_check(int(kinds.get("forens", 0)) + int(kinds.get("zakenmens", 0)) + int(kinds.get("kantoormens", 0)) > 0,
			"forenzen en zakenmensen in de spits")
	var carrying := {}
	for person in walkers.people():
		if person.carried != "":
			carrying[person.carried] = int(carrying.get(person.carried, 0)) + 1
	print("08:00: dragen %s" % str(carrying))
	if ResourceLoader.exists("res://scripts/world/carried_items.gd"):
		_check(int(carrying.get("aktetas", 0)) > 0, "aktetassen in de ochtendspits")
		_check(walkers.people().filter(func(person: Pedestrian) -> bool: return person.carried != "").all(
				func(person: Pedestrian) -> bool: return person._carried_item != null and person._carried_item.is_inside_tree()),
				"wie iets draagt heeft het bij zich")
	_check(walkers.people().all(func(person: Pedestrian) -> bool: return person.figure != null and person._body != null),
			"iedereen heeft een figuur en een botsvorm")
	# a vehicle that was parked drives on
	var reused: Vehicle = null
	for vehicle in traffic._town:
		if vehicle.is_node_ready() and vehicle.name.begins_with("Verkeer"):
			reused = vehicle
	var reused_from := reused.global_position if reused else Vector3.ZERO
	for frame_index in 60 * 6:
		await physics_frame
	_check(reused != null and reused.global_position.distance_to(reused_from) > 3.0, "een teruggezet voertuig rijdt (%.1f m)"
			% (reused.global_position.distance_to(reused_from) if reused else 0.0))
	# a jump of the player: all round the new spot
	var far_cell := Vector3i.ZERO
	for cell in walkers._walkable_cells:
		if walkers.cell_middle(cell).distance_to(player.global_position) > 450.0:
			far_cell = cell
			break
	player.call("teleport", walkers.cell_middle(far_cell) + Vector3.UP * 0.3, 0.0)
	for frame_index in 120:
		await physics_frame
	walkers._keep_round_player()
	await _traffic_ticks(traffic, 2)
	print("na de sprong naar %s: voetgangers %d, verkeer %d" % [str(far_cell), walkers.people().size(), traffic.vehicles().size()])
	_check(_all_within(walkers.people(), player.global_position, walkers.reach + 2.0), "na een sprong: voetgangers rond de nieuwe plek")
	_check(_vehicles_within(traffic, player.global_position, traffic.keep_within), "na een sprong: verkeer rond de nieuwe plek")
	if _problems.is_empty():
		print("drukte: alles in orde")
	else:
		for problem in _problems:
			print("FOUT: ", problem)
	quit(0 if _problems.is_empty() else 1)


func _traffic_ticks(traffic: Traffic, ticks: int) -> void:
	for tick in ticks:
		traffic._tick_clock = 0.0
		await physics_frame
		await physics_frame


func _near(group: Array, spot: Vector3, metres: float) -> int:
	return group.filter(func(node: Node3D) -> bool: return node.global_position.distance_to(spot) <= metres).size()


func _all_within(people: Array, spot: Vector3, metres: float) -> bool:
	for person: Pedestrian in people:
		if person.global_position.distance_to(spot) > metres:
			print("  te ver: %s op %.0f m" % [person.name, person.global_position.distance_to(spot)])
			return false
	return true


func _vehicles_within(traffic: Traffic, spot: Vector3, metres: float) -> bool:
	for vehicle in traffic.vehicles():
		if vehicle.crashed:
			continue
		if vehicle.global_position.distance_to(spot) > metres:
			print("  te ver: %s op %.0f m" % [vehicle.name, vehicle.global_position.distance_to(spot)])
			return false
	return true


func _check(condition: bool, what: String) -> void:
	print(("ok   " if condition else "FOUT ") + what)
	if not condition:
		_problems.append(what)
