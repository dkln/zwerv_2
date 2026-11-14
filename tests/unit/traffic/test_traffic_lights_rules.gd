extends RefCounted
## Unit tests of the logic of the traffic lights (scripts/traffic/traffic_lights_rules.gd):
## the cycle as plain sums, without props or a tree.
##   tests/run_unit_tests.sh traffic_lights_rules

const TrafficLightsRules = preload("res://scripts/traffic/traffic_lights_rules.gd")

const GREEN_TIME := 8.0
const AMBER_TIME := 2.5
const CLEARANCE_TIME := 1.5
const PEDESTRIAN_TIME := 5.0


func test_kind_of_prop(test) -> void:
	test.check(TrafficLightsRules.kind_of_prop("verkeerslichten/auto_groen") == "auto", "een autolicht")
	test.check(TrafficLightsRules.kind_of_prop("verkeerslichten/ov_stop") == "ov", "een ov-licht")
	test.check(TrafficLightsRules.kind_of_prop("verkeerslichten/voetganger_rood") == "voetganger", "een voetgangerslicht")
	test.check(TrafficLightsRules.kind_of_prop("verkeerslichten/paal_kaal") == "", "onbekende soort: geen licht")
	test.check(TrafficLightsRules.kind_of_prop("straatmeubilair/bank") == "", "een andere prop: geen licht")
	test.check(TrafficLightsRules.kind_of_prop("") == "", "niets: geen licht")


func test_prop_name_per_kind_and_phase(test) -> void:
	test.check(TrafficLightsRules.prop_name("auto", TrafficLightsRules.GREEN) == "verkeerslichten/auto_groen", "auto groen")
	test.check(TrafficLightsRules.prop_name("fiets", TrafficLightsRules.AMBER) == "verkeerslichten/fiets_oranje", "fiets oranje")
	test.check(TrafficLightsRules.prop_name("mast", TrafficLightsRules.RED) == "verkeerslichten/mast_rood", "mast rood")
	test.check(TrafficLightsRules.prop_name("ov", TrafficLightsRules.GREEN) == "verkeerslichten/ov_rijden", "ov: rijden")
	test.check(TrafficLightsRules.prop_name("ov", TrafficLightsRules.AMBER) == "verkeerslichten/ov_attentie", "ov: attentie")
	test.check(TrafficLightsRules.prop_name("ov", TrafficLightsRules.RED) == "verkeerslichten/ov_stop", "ov: stop")
	test.check(TrafficLightsRules.prop_name("voetganger", TrafficLightsRules.AMBER) == "verkeerslichten/voetganger_rood", "voetganger kent geen oranje: rood")
	for kind: String in TrafficLightsRules.STATES:
		for phase in [TrafficLightsRules.GREEN, TrafficLightsRules.AMBER, TrafficLightsRules.RED]:
			test.check(TrafficLightsRules.kind_of_prop(TrafficLightsRules.prop_name(kind, phase)) == kind, "de prop van %s is weer een %s-licht" % [kind, kind])


func test_faces_north_south(test) -> void:
	test.check(TrafficLightsRules.faces_north_south(Vector3(0, 0, 1)), "kijkt naar het zuiden: noord-zuid")
	test.check(TrafficLightsRules.faces_north_south(Vector3(0, 0, -1)), "kijkt naar het noorden: noord-zuid")
	test.check(not TrafficLightsRules.faces_north_south(Vector3(1, 0, 0)), "kijkt naar het oosten: oost-west")
	test.check(not TrafficLightsRules.faces_north_south(Vector3(-1, 0, 0)), "kijkt naar het westen: oost-west")


func test_half_cycle(test) -> void:
	test.check(TrafficLightsRules.half_cycle(GREEN_TIME, AMBER_TIME, CLEARANCE_TIME) == 12.0, "groen + oranje + ontruiming")
	test.check(TrafficLightsRules.half_cycle(0.0, 0.0, 0.0) == 0.0, "alles 0: 0")


func test_stream_time(test) -> void:
	test.check(TrafficLightsRules.stream_time(3.0, 0.0, true, 12.0) == 3.0, "noord-zuid: de tijd in de cyclus")
	test.check(TrafficLightsRules.stream_time(3.0, 0.0, false, 12.0) == 15.0, "oost-west loopt een halve cyclus achter")
	test.check(TrafficLightsRules.stream_time(15.0, 0.0, false, 12.0) == 3.0, "en heeft groen in de tweede helft")
	test.check(TrafficLightsRules.stream_time(27.0, 0.0, true, 12.0) == 3.0, "de cyclus herhaalt zich")
	test.check(TrafficLightsRules.stream_time(3.0, 5.0, true, 12.0) == 8.0, "de verschuiving van het kruispunt telt mee")
	test.check(TrafficLightsRules.stream_time(20.0, 5.0, true, 12.0) == 1.0, "ook over het eind van de cyclus heen")


func test_car_phase(test) -> void:
	test.check(TrafficLightsRules.car_phase(0.0, GREEN_TIME, AMBER_TIME) == TrafficLightsRules.GREEN, "begin: groen")
	test.check(TrafficLightsRules.car_phase(7.99, GREEN_TIME, AMBER_TIME) == TrafficLightsRules.GREEN, "tot het eind van het groen")
	test.check(TrafficLightsRules.car_phase(8.0, GREEN_TIME, AMBER_TIME) == TrafficLightsRules.AMBER, "dan oranje")
	test.check(TrafficLightsRules.car_phase(10.49, GREEN_TIME, AMBER_TIME) == TrafficLightsRules.AMBER, "tot het eind van het oranje")
	test.check(TrafficLightsRules.car_phase(10.5, GREEN_TIME, AMBER_TIME) == TrafficLightsRules.RED, "dan rood")
	test.check(TrafficLightsRules.car_phase(23.9, GREEN_TIME, AMBER_TIME) == TrafficLightsRules.RED, "rood tot de cyclus om is")


func test_light_phase_per_kind(test) -> void:
	for kind in ["auto", "fiets", "mast", "ov"]:
		test.check(TrafficLightsRules.light_phase(kind, 6.0, GREEN_TIME, AMBER_TIME, PEDESTRIAN_TIME) == TrafficLightsRules.GREEN, "%s: groen zolang het groen duurt" % kind)
		test.check(TrafficLightsRules.light_phase(kind, 9.0, GREEN_TIME, AMBER_TIME, PEDESTRIAN_TIME) == TrafficLightsRules.AMBER, "%s: oranje" % kind)
		test.check(TrafficLightsRules.light_phase(kind, 11.0, GREEN_TIME, AMBER_TIME, PEDESTRIAN_TIME) == TrafficLightsRules.RED, "%s: rood" % kind)
	test.check(TrafficLightsRules.light_phase("voetganger", 4.9, GREEN_TIME, AMBER_TIME, PEDESTRIAN_TIME) == TrafficLightsRules.GREEN, "voetganger: groen in het eerste deel")
	test.check(TrafficLightsRules.light_phase("voetganger", 5.0, GREEN_TIME, AMBER_TIME, PEDESTRIAN_TIME) == TrafficLightsRules.RED, "voetganger: rood zodra zijn tijd om is")
	test.check(TrafficLightsRules.light_phase("voetganger", 9.0, GREEN_TIME, AMBER_TIME, PEDESTRIAN_TIME) == TrafficLightsRules.AMBER, "voetganger: de oranje fase (die rood toont)")


func test_walk_phase(test) -> void:
	test.check(TrafficLightsRules.walk_phase(0.0, PEDESTRIAN_TIME) == TrafficLightsRules.WALK, "begin van het groen: lopen")
	test.check(TrafficLightsRules.walk_phase(4.99, PEDESTRIAN_TIME) == TrafficLightsRules.WALK, "nog net")
	test.check(TrafficLightsRules.walk_phase(5.0, PEDESTRIAN_TIME) == TrafficLightsRules.WAIT, "daarna wachten")
	test.check(TrafficLightsRules.walk_phase(20.0, PEDESTRIAN_TIME) == TrafficLightsRules.WAIT, "en de hele andere stroom lang")


func test_time_offset_is_repeatable_and_within_the_cycle(test) -> void:
	var offsets := {}
	for column in 40:
		var spot := Vector3(column * 16.0 + 2.0, 0.0, column * 7.0)
		var offset := TrafficLightsRules.time_offset(spot, 12.0)
		test.check(offset >= 0.0 and offset < 24.0, "binnen de cyclus (%.2f)" % offset)
		test.check(offset == TrafficLightsRules.time_offset(spot, 12.0), "zelfde plek: zelfde verschuiving")
		offsets[offset] = true
	test.check(offsets.size() > 20, "kruispunten schakelen niet allemaal tegelijk (%d verschillende)" % offsets.size())
	test.check(TrafficLightsRules.time_offset(Vector3(10.4, 3.0, 20.9), 12.0) == TrafficLightsRules.time_offset(Vector3(10.0, 0.0, 20.0), 12.0),
			"hele meters, de hoogte telt niet")
	test.check(TrafficLightsRules.time_offset(Vector3.ZERO, 12.0) == 0.0, "de oorsprong: 0")
	test.check(is_equal_approx(TrafficLightsRules.time_offset(Vector3(1.0, 0.0, 0.0), 12.0), (73856093 % 1000) / 1000.0 * 24.0), "de hash van de plek, als deel van de cyclus")


func test_offsets_in_step(test) -> void:
	var centres := [Vector3(0, 0, 0), Vector3(30, 0, 0), Vector3(60, 5, 0), Vector3(200, 0, 0), Vector3(200, 0, 41)]
	var offsets := [1.0, 2.0, 3.0, 4.0, 5.0]
	var in_step := TrafficLightsRules.offsets_in_step(offsets, centres, 40.0)
	test.check(in_step == [1.0, 1.0, 1.0, 4.0, 5.0], "dicht bij elkaar (ook als ketting): de verschuiving van het eerste (%s)" % str(in_step))
	test.check(offsets == [1.0, 2.0, 3.0, 4.0, 5.0], "de invoer blijft zoals hij was")
	test.check(TrafficLightsRules.offsets_in_step(offsets, centres, 0.0) == offsets, "afstand 0: niets in de pas")
	test.check(TrafficLightsRules.offsets_in_step([], [], 40.0) == [], "geen kruispunten: niets")
	test.check(TrafficLightsRules.offsets_in_step([7.0, 9.0], [Vector3(0, 0, 0), Vector3(0, 0, 40)], 40.0) == [7.0, 7.0], "precies op de afstand: in de pas")
