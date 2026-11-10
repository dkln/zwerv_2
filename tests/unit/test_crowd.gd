extends RefCounted
## Unit tests of Crowd (scripts/world/crowd.gd) and its table data/drukte.json: the file reads,
## the rush hours are busier than the night, the neighbourhoods differ (Centraal busy, the
## parks quiet for cars, the A12 without walkers but full of cars, lorries in the Binckhorst),
## the kinds of people change with the hour, and each kind gets a look of its own.

const Crowd = preload("res://scripts/world/crowd.gd")


func test_the_table_reads(test) -> void:
	Crowd.reload()
	var table := Crowd.data()
	test.check(not table.is_empty(), "data/drukte.json leest")
	test.check((table.get("uren", []) as Array).size() >= 4, "uren in de tabel")
	test.check(not (table.get("gebieden", {}) as Dictionary).is_empty(), "gebieden in de tabel")
	var hours: Array = table.get("uren", [])
	for index in range(1, hours.size()):
		test.check(float(hours[index].uur) > float(hours[index - 1].uur), "uren op volgorde (%s)" % hours[index].uur)
	for kind: String in Crowd.person_kinds():
		test.check(Crowd.pace_of(kind) > 0.5 and Crowd.pace_of(kind) < 1.5, "tempo van %s" % kind)


func test_busy_by_day_quiet_at_night(test) -> void:
	test.check(Crowd.pedestrian_share(8.0, "Den Haag") > Crowd.pedestrian_share(3.0, "Den Haag") * 3.0,
			"ochtendspits veel drukker dan de nacht (voetgangers)")
	test.check(Crowd.traffic_share(17.0, "Den Haag") > Crowd.traffic_share(2.0, "Den Haag") * 3.0,
			"avondspits veel drukker dan de nacht (verkeer)")
	# round midnight it blends from the last moment of the day into the first
	var late := Crowd.pedestrian_share(23.5, "Den Haag")
	test.check(late > 0.0 and late < Crowd.pedestrian_share(22.0, "Den Haag") + 0.01, "na middernacht loopt het door")


func test_the_areas_differ(test) -> void:
	test.check(Crowd.pedestrian_share(12.0, "Centraal Station") > Crowd.pedestrian_share(12.0, "Bezuidenhout"), "Centraal drukker dan de woonwijk")
	test.check(Crowd.traffic_share(12.0, "Malieveld") < Crowd.traffic_share(12.0, "Centrum"), "weinig auto's in het park")
	test.check(Crowd.traffic_share(12.0, "A12") > Crowd.traffic_share(12.0, "Centrum"), "druk op de A12")
	test.check(Crowd.pedestrian_share(12.0, "A12") < 0.5, "weinig voetgangers op de A12")
	test.check(Crowd.vehicle_weight("vracht", 11.0, "Binckhorst") > Crowd.vehicle_weight("vracht", 11.0, "Centrum") * 3.0,
			"vrachtverkeer in de Binckhorst")
	test.check(Crowd.vehicle_weight("fiets", 12.0, "Centrum") > Crowd.vehicle_weight("fiets", 12.0, "A12") * 5.0,
			"fietsers in het centrum, niet op de A12")


func test_who_is_out_changes_with_the_hour(test) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 3
	var morning := {}
	var night := {}
	for index in 400:
		var morning_kind := Crowd.person_kind(8.0, "Centraal Station", random)
		morning[morning_kind] = int(morning.get(morning_kind, 0)) + 1
		var night_kind := Crowd.person_kind(2.0, "Centrum", random)
		night[night_kind] = int(night.get(night_kind, 0)) + 1
	test.check(int(morning.get("forens", 0)) + int(morning.get("zakenmens", 0)) > 150, "ochtendspits bij Centraal: forenzen en zakenmensen (%s)" % str(morning))
	test.check(int(morning.get("nachtbraker", 0)) == 0, "geen nachtbrakers in de ochtendspits")
	test.check(int(night.get("nachtbraker", 0)) + int(night.get("uitgaanspubliek", 0)) > 300, "'s nachts nachtbrakers en uitgaanders (%s)" % str(night))


func test_each_kind_dresses_as_itself(test) -> void:
	var elders_grey := 0
	for look_seed in 40:
		var look := Crowd.look_for("oudere", look_seed)
		var hair: Color = look.hair
		if hair.is_equal_approx(Color("#8A8680")) or hair.is_equal_approx(Color("#D8D4CC")):
			elders_grey += 1
		test.check(look.has("coat") and look.has("trim") and look.has("shoes"), "een volledige look")
	test.check(elders_grey == 40, "ouderen grijs (%d van 40)" % elders_grey)
	var workers_vest := 0
	for look_seed in 40:
		if (Crowd.look_for("werkman", look_seed).coat as Color).is_equal_approx(Color("#E0A030")):
			workers_vest += 1
	test.check(workers_vest > 10, "werklui vaak in geel (%d van 40)" % workers_vest)
	test.check(Crowd.ride_share("oudere", "rolstoel") > Crowd.ride_share("forens", "rolstoel"), "ouderen vaker in een rolstoel")
	test.check(Crowd.look_for("bestaat_niet", 5) == TownsfolkFigure.look_for(5), "een onbekende soort: de gewone look")


func test_the_area_of_a_spot(test) -> void:
	var world := Node.new()
	world.set_meta("wijken", [["Centraal Station", 72, 61, 94, 77], ["Den Haag", 0, 0, 215, 175]])
	test.check(Crowd.area_at(world, Vector3(80 * 4.0, 0.0, 70 * 4.0)) == "Centraal Station", "plek in Centraal")
	test.check(Crowd.area_at(world, Vector3(10.0, 0.0, 10.0)) == "Den Haag", "plek daarbuiten")
	test.check(Crowd.hour_of(world) == Crowd.DEFAULT_HOUR, "zonder Dagcyclus het standaarduur")
	world.free()
