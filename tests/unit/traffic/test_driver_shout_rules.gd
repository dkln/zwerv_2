extends RefCounted
## Unit tests of the rules of a shout in the street (scripts/vehicles/driver_shout_rules.gd):
## which lines fit a mood and a kind, never the same line twice, which moods are always
## shouted, the pauses, the reach and the babble.
##   tests/run_unit_tests.sh driver_shout_rules

const DriverShoutRules = preload("res://scripts/vehicles/driver_shout_rules.gd")

## The lines of each mood that has lines of its own.
const MOOD_LINES := {
	"wachten": DriverShoutRules.WAITING_LINES, "doordrukken": DriverShoutRules.PUSHING_LINES,
	"aanrijding": DriverShoutRules.HIT_LINES, "zwartrijden": DriverShoutRules.FARE_DODGER_LINES,
	"uitchecken": DriverShoutRules.CHECK_OUT_LINES, "beboeten": DriverShoutRules.FINE_LINES,
	"spoor": DriverShoutRules.OFF_THE_TRACK_LINES, "gevallen": DriverShoutRules.FALLEN_LINES,
	"dronken": DriverShoutRules.DRUNK_LINES, "agressief": DriverShoutRules.AGGRESSIVE_LINES,
	"wheelie": DriverShoutRules.WHEELIE_LINES, "waarschuwen": DriverShoutRules.WARNING_LINES,
}


func test_every_mood_has_its_own_lines(test) -> void:
	for mood: String in DriverShoutRules.MOODS:
		var lines := DriverShoutRules.lines_for("auto", mood)
		test.check(lines == MOOD_LINES[mood] and not lines.is_empty(), "%s: de eigen regels van die stemming" % mood)
		for line in lines:
			test.check(line.strip_edges() != "", "%s: geen lege regel" % mood)


func test_an_unknown_mood_warns(test) -> void:
	test.check(DriverShoutRules.lines_for("auto", "onbekend") == DriverShoutRules.WARNING_LINES, "een onbekende stemming waarschuwt")
	test.check(DriverShoutRules.lines_for("", "") == DriverShoutRules.WARNING_LINES, "ook zonder stemming en soort")


func test_kind_lines_only_when_waiting_or_warning(test) -> void:
	for kind: String in DriverShoutRules.KIND_LINES:
		var own: Array = DriverShoutRules.KIND_LINES[kind]
		var waiting := DriverShoutRules.lines_for(kind, "wachten")
		var warning := DriverShoutRules.lines_for(kind, "waarschuwen")
		test.check(waiting.size() == DriverShoutRules.WAITING_LINES.size() + own.size(), "%s wacht: de eigen regels erbij" % kind)
		test.check(warning.size() == DriverShoutRules.WARNING_LINES.size() + own.size(), "%s waarschuwt: de eigen regels erbij" % kind)
		for line: String in own:
			test.check(waiting.has(line) and warning.has(line), "%s: \"%s\" bij wachten en waarschuwen" % [kind, line])
			test.check(waiting.find(line) >= DriverShoutRules.WAITING_LINES.size(), "%s: de eigen regels achteraan" % kind)
		for mood: String in DriverShoutRules.MOODS:
			if mood in ["wachten", "waarschuwen"]:
				continue
			test.check(DriverShoutRules.lines_for(kind, mood) == DriverShoutRules.lines_for("auto", mood), "%s %s: zonder eigen regels" % [kind, mood])


func test_wheelie_lines_of_the_kind_come_with_the_wheelie(test) -> void:
	for kind: String in DriverShoutRules.WHEELIE_KIND_LINES:
		var own: Array = DriverShoutRules.WHEELIE_KIND_LINES[kind]
		var lines := DriverShoutRules.lines_for(kind, "wheelie")
		test.check(lines.size() == DriverShoutRules.WHEELIE_LINES.size() + own.size(), "%s: de eigen wheelie-regels erbij" % kind)
		for line: String in own:
			test.check(lines.has(line), "%s: \"%s\"" % [kind, line])
			test.check(not DriverShoutRules.lines_for(kind, "wachten").has(line), "%s: niet bij wachten" % kind)
	test.check(DriverShoutRules.lines_for("auto", "wheelie") == DriverShoutRules.WHEELIE_LINES, "een auto: alleen de algemene")


func test_lines_for_gives_a_list_of_its_own(test) -> void:
	var lines := DriverShoutRules.lines_for("auto", "doordrukken")
	lines.append("erbij")
	test.check(not DriverShoutRules.PUSHING_LINES.has("erbij"), "de vaste regels blijven zoals ze zijn")
	test.check(DriverShoutRules.lines_for("auto", "doordrukken").size() == DriverShoutRules.PUSHING_LINES.size(), "een volgende keer weer de vaste regels")


func test_line_at_never_gives_the_last_line_again(test) -> void:
	var lines: Array[String] = ["een", "twee", "drie"]
	test.check(DriverShoutRules.line_at(lines, 0, "") == "een" and DriverShoutRules.line_at(lines, 2, "een") == "drie", "de getrokken regel")
	test.check(DriverShoutRules.line_at(lines, 1, "twee") == "drie", "dezelfde als net: de volgende")
	test.check(DriverShoutRules.line_at(lines, 2, "drie") == "een", "de laatste als net: weer de eerste")
	var only: Array[String] = ["alleen"]
	test.check(DriverShoutRules.line_at(only, 0, "alleen") == "alleen", "één regel: dan toch die")
	for mood: String in DriverShoutRules.MOODS:
		var mood_lines := DriverShoutRules.lines_for("fiets", mood)
		for drawn_index in mood_lines.size():
			test.check(DriverShoutRules.line_at(mood_lines, drawn_index, mood_lines[drawn_index]) != mood_lines[drawn_index], "%s: nooit twee keer dezelfde" % mood)


func test_which_moods_are_always_shouted(test) -> void:
	for mood: String in DriverShoutRules.MOODS:
		var by_chance := mood in ["wachten", "waarschuwen", "dronken", "agressief"]
		test.check(DriverShoutRules.is_always(mood) == (not by_chance), "%s: %s" % [mood, "op kans" if by_chance else "altijd"])
	for mood: String in DriverShoutRules.ALWAYS_MOODS:
		test.check(DriverShoutRules.MOODS.has(mood), "%s is een stemming" % mood)
	test.check(not DriverShoutRules.is_always("onbekend"), "een onbekende stemming: op kans")


func test_the_chance_of_a_shout(test) -> void:
	test.check(DriverShoutRules.chance_of("wachten") == DriverShoutRules.SHOUT_CHANCE, "wachten: de kans van wachten")
	for mood: String in ["waarschuwen", "dronken", "agressief", "onbekend"]:
		test.check(DriverShoutRules.chance_of(mood) == DriverShoutRules.WARNING_CHANCE, "%s: de kans van waarschuwen" % mood)
	test.check(DriverShoutRules.SHOUT_CHANCE > DriverShoutRules.WARNING_CHANCE and DriverShoutRules.SHOUT_CHANCE < 1.0, "niet bij elke toeter")


func test_may_speak_after_both_pauses(test) -> void:
	test.check(DriverShoutRules.may_speak(10.0, 0.0, 0.0), "niemand riep nog")
	test.check(not DriverShoutRules.may_speak(10.0, 10.5, 0.0), "iemand riep net")
	test.check(not DriverShoutRules.may_speak(10.0, 0.0, 12.0), "hij riep zelf net")
	test.check(DriverShoutRules.may_speak(10.0, 10.0, 10.0), "precies op het eind van de pauzes mag het weer")
	test.check(DriverShoutRules.SPEAKER_PAUSE > DriverShoutRules.ANY_PAUSE, "de eigen pauze duurt langer dan die van iedereen")


func test_the_roof_and_the_reach(test) -> void:
	test.check(DriverShoutRules.roof_of(Vector3(1.0, 2.0, 3.0), 1.9) == Vector3(1.0, 3.9, 3.0), "het dak recht boven de spreker")
	var focus := Vector3(10.0, 0.0, -5.0)
	test.check(DriverShoutRules.within_reach(focus, focus), "op het punt waar de camera naar kijkt")
	test.check(DriverShoutRules.within_reach(focus, focus + Vector3(DriverShoutRules.SHOUT_DISTANCE, 0.0, 0.0)), "precies op de grens nog wel")
	test.check(not DriverShoutRules.within_reach(focus, focus + Vector3(DriverShoutRules.SHOUT_DISTANCE + 0.1, 0.0, 0.0)), "net erbuiten niet")
	test.check(not DriverShoutRules.within_reach(focus, focus + Vector3(40.0, 0.0, 40.0)), "schuin te ver")
	test.check(DriverShoutRules.within_reach(focus, focus + Vector3(0.0, 500.0, 0.0)), "de hoogte telt niet mee")


func test_a_camera_looking_down_has_a_point_on_the_ground(test) -> void:
	test.check(DriverShoutRules.looks_at_ground(Vector3(0.0, -0.7, -0.7)), "schuin omlaag")
	test.check(DriverShoutRules.looks_at_ground(Vector3.DOWN), "recht omlaag")
	test.check(not DriverShoutRules.looks_at_ground(Vector3.FORWARD), "vlak vooruit niet")
	test.check(not DriverShoutRules.looks_at_ground(Vector3(0.0, DriverShoutRules.LEVEL_FORWARD, -1.0)), "op de grens niet")
	test.check(not DriverShoutRules.looks_at_ground(Vector3.UP), "omhoog niet")


func test_the_babble_of_a_mood_and_a_line(test) -> void:
	for mood: String in DriverShoutRules.MOODS:
		test.check(DriverShoutRules.BABBLE_MOOD.has(mood), "%s heeft een brabbelstemming" % mood)
		test.check(DriverShoutRules.babble_mood_for(mood) == DriverShoutRules.BABBLE_MOOD[mood], "%s: die stemming" % mood)
	test.check(DriverShoutRules.babble_mood_for("wheelie") == "opgewonden" and DriverShoutRules.babble_mood_for("gevallen") == "verdrietig", "opgewonden op één wiel, verdrietig gevallen")
	test.check(DriverShoutRules.babble_mood_for("onbekend") == "neutraal", "onbekend: neutraal")
	test.check(DriverShoutRules.babble_mood_of("Wil je dood ofzo?", "boos") == "vraag", "een vraag gaat omhoog")
	test.check(DriverShoutRules.babble_mood_of("Wil je dood ofzo?  ", "boos") == "vraag", "ook met spaties erachter")
	test.check(DriverShoutRules.babble_mood_of("Kijk uit!", "boos") == "boos", "anders de stemming zelf")
	test.check(DriverShoutRules.babble_mood_of("Waar? Daar!", "opgewonden") == "opgewonden", "een vraagteken middenin telt niet")


func test_a_vehicle_keeps_its_voice(test) -> void:
	var voices := ["man", "oude_man", "vrouw"]
	test.check(DriverShoutRules.voice_at(0, voices) == "man" and DriverShoutRules.voice_at(4, voices) == "oude_man", "de stem bij het nummer")
	test.check(DriverShoutRules.voice_at(302, voices) == DriverShoutRules.voice_at(302, voices), "steeds dezelfde")
	var heard := {}
	for instance_id in 30:
		heard[DriverShoutRules.voice_at(instance_id, voices)] = true
	test.check(heard.size() == voices.size(), "alle stemmen komen voor")
