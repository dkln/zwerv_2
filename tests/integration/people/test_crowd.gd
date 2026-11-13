extends "res://tests/integration/support/town_test.gd"
## The set of people and traffic round the player (scripts/world/people/pedestrians.gd,
## scripts/traffic/traffic.gd, Crowd and data/drukte.json): as many as the hour and the
## neighbourhood want; at night fewer (the rest out of the tree, kept), in the morning rush
## more again and of other kinds (commuters, business people); after a jump of the player
## (as a warp) all of them round the new spot; a vehicle taken out and put back drives on.
## The town with its traffic; each test sets the hour and lets the crowd follow at once,
## without a camera (PeopleHelp.crowd_at_hour: without one nothing counts as unseen, so the
## test lets it, unseen_without_camera).
##   tests/run_integration_tests.sh crowd

const PeopleHelp = preload("res://tests/integration/support/people_help.gd")


static func world_options() -> Dictionary:
	return {"traffic": true}


## The people on foot of the town.
func _walkers() -> Pedestrians:
	return scene.get_node("Voetgangers")


## The traffic of the town.
func _traffic() -> Traffic:
	return scene.get_node("Verkeer")


## True if every one of `people` is within `metres` of `spot` (says who is not).
func _all_within(people: Array, spot: Vector3, metres: float) -> bool:
	for person: Pedestrian in people:
		if person.global_position.distance_to(spot) > metres:
			print("  te ver: %s op %.0f m" % [person.name, person.global_position.distance_to(spot)])
			return false
	return true


## True if every vehicle of the traffic that has not crashed is within `metres` of `spot`.
func _vehicles_within(spot: Vector3, metres: float) -> bool:
	for vehicle in _traffic().vehicles():
		if vehicle.crashed:
			continue
		if vehicle.global_position.distance_to(spot) > metres:
			print("  te ver: %s op %.0f m" % [vehicle.name, vehicle.global_position.distance_to(spot)])
			return false
	return true


## At 13:00 there are as many pedestrians, town vehicles and services as that hour and
## neighbourhood want, all of them round the player.
func test_midday_as_many_as_wanted_round_the_player(test) -> void:
	await PeopleHelp.crowd_at_hour(self, 13.0)
	var walkers := _walkers()
	var traffic := _traffic()
	var wanted: Vector2i = traffic.wanted_counts()
	print("13:00: voetgangers %d (gewenst %d), verkeer %d + diensten (gewenst %d + %d)" % [walkers.people().size(), walkers.wanted_count(),
			traffic._town.size(), wanted.x, wanted.y])
	test.check(walkers.people().size() == walkers.wanted_count(), "voetgangers zoals gewenst om 13:00")
	test.check(traffic._town.size() == wanted.x and traffic._services.size() == wanted.y, "verkeer zoals gewenst om 13:00")
	test.check(_all_within(walkers.people(), player.global_position, walkers.reach), "voetgangers rond de speler")
	test.check(_vehicles_within(player.global_position, traffic.appear_within + 5.0), "verkeer rond de speler")


## From midday to 03:00: fewer pedestrians and vehicles (who is close to the player stays),
## who is not needed rests out of the tree and the parked vehicles are out of the town.
func test_night_fewer_and_the_rest_kept_out_of_the_tree(test) -> void:
	await PeopleHelp.crowd_at_hour(self, 13.0)
	var walkers := _walkers()
	var traffic := _traffic()
	var midday_people := walkers.people().size()
	var midday_traffic := traffic.vehicles().size()
	await PeopleHelp.crowd_at_hour(self, 3.0)
	var wanted: Vector2i = traffic.wanted_counts()
	print("03:00: voetgangers %d (gewenst %d, %d rusten), verkeer %d (gewenst %d, %d geparkeerd)" % [walkers.people().size(),
			walkers.wanted_count(), walkers._resting.size(), traffic._town.size(), wanted.x, traffic._parked.size()])
	# who is close to the player stays (only who is out of sight and further off goes)
	var near_people := PeopleHelp.near(walkers.people(), player.global_position, walkers.renew_beyond)
	var near_traffic := PeopleHelp.near(traffic._town, player.global_position, traffic.renew_beyond)
	test.check(walkers.people().size() <= maxi(walkers.wanted_count(), near_people) and walkers.people().size() < midday_people,
			"'s nachts minder voetgangers (%d dichtbij blijven)" % near_people)
	test.check(walkers._resting.size() > 0 and walkers._resting.all(func(person: Pedestrian) -> bool: return not person.is_inside_tree()),
			"wie niet nodig is rust buiten de boom")
	test.check(traffic._town.size() <= maxi(wanted.x, near_traffic) and traffic.vehicles().size() < midday_traffic,
			"'s nachts minder verkeer (%d dichtbij blijven)" % near_traffic)
	test.check(traffic._parked.all(func(vehicle: Vehicle) -> bool: return not vehicle.is_inside_tree() and not Vehicle.all_vehicles.has(vehicle)),
			"geparkeerd verkeer is uit de stad")


## From the night to 08:00: as many as wanted again, commuters and business people among
## them, briefcases carried (and who carries something has it with them), everyone with a
## figure and a collider.
func test_morning_rush_more_again_and_other_people(test) -> void:
	await PeopleHelp.crowd_at_hour(self, 3.0)
	await PeopleHelp.crowd_at_hour(self, 8.0)
	var walkers := _walkers()
	var traffic := _traffic()
	var wanted: Vector2i = traffic.wanted_counts()
	var kinds := {}
	var carrying := {}
	for person in walkers.people():
		kinds[person.crowd_kind] = int(kinds.get(person.crowd_kind, 0)) + 1
		if person.carried != "":
			carrying[person.carried] = int(carrying.get(person.carried, 0)) + 1
	print("08:00: voetgangers %d (gewenst %d), verkeer %d (gewenst %d); soorten %s" % [walkers.people().size(), walkers.wanted_count(),
			traffic._town.size(), wanted.x, str(kinds)])
	print("08:00: dragen %s" % str(carrying))
	test.check(walkers.people().size() == walkers.wanted_count(), "ochtendspits: weer zoveel voetgangers als gewenst")
	test.check(traffic._town.size() == wanted.x, "ochtendspits: weer zoveel verkeer als gewenst")
	test.check(int(kinds.get("forens", 0)) + int(kinds.get("zakenmens", 0)) + int(kinds.get("kantoormens", 0)) > 0,
			"forenzen en zakenmensen in de spits")
	if ResourceLoader.exists("res://scripts/world/people/carried_items.gd"):
		test.check(int(carrying.get("aktetas", 0)) > 0, "aktetassen in de ochtendspits")
		test.check(walkers.people().filter(func(person: Pedestrian) -> bool: return person.carried != "").all(
				func(person: Pedestrian) -> bool: return person._carried_item != null and person._carried_item.is_inside_tree()),
				"wie iets draagt heeft het bij zich")
	test.check(walkers.people().all(func(person: Pedestrian) -> bool: return person.figure != null and person._body != null),
			"iedereen heeft een figuur en een botsvorm")


## A vehicle that was parked for the night and put back in the morning drives on.
func test_vehicle_put_back_drives_on(test) -> void:
	await PeopleHelp.crowd_at_hour(self, 3.0)
	await PeopleHelp.crowd_at_hour(self, 8.0)
	var reused: Vehicle = null
	for vehicle in _traffic()._town:
		if vehicle.is_node_ready() and vehicle.name.begins_with("Verkeer"):
			reused = vehicle
	var reused_from := reused.global_position if reused else Vector3.ZERO
	await physics_frames(60 * 6)
	test.check(reused != null and reused.global_position.distance_to(reused_from) > 3.0, "een teruggezet voertuig rijdt (%.1f m)"
			% (reused.global_position.distance_to(reused_from) if reused else 0.0))


## After a jump of the player (as a warp) far across the town, the people and the traffic
## are all round the new spot.
func test_after_a_jump_everyone_round_the_new_spot(test) -> void:
	await PeopleHelp.crowd_at_hour(self, 8.0)
	var walkers := _walkers()
	var traffic := _traffic()
	var far_cell := Vector3i.ZERO
	for cell in walkers._walkable_cells:
		if walkers.cell_middle(cell).distance_to(player.global_position) > 450.0:
			far_cell = cell
			break
	player.call("teleport", walkers.cell_middle(far_cell) + Vector3.UP * 0.3, 0.0)
	await physics_frames(120)
	walkers._keep_round_player()
	await PeopleHelp.traffic_ticks(self, 2)
	print("na de sprong naar %s: voetgangers %d, verkeer %d" % [str(far_cell), walkers.people().size(), traffic.vehicles().size()])
	test.check(_all_within(walkers.people(), player.global_position, walkers.reach + 2.0), "na een sprong: voetgangers rond de nieuwe plek")
	test.check(_vehicles_within(player.global_position, traffic.keep_within), "na een sprong: verkeer rond de nieuwe plek")
