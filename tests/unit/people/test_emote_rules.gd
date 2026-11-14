extends RefCounted
## Unit tests of the moods of someone talking, worked out (scripts/world/people/emote_rules.gd):
## every mood its own movement of the body, how a mood takes over, the transform it gives.
##   tests/run_unit_tests.sh emote_rules

const EmoteRules = preload("res://scripts/world/people/emote_rules.gd")


## The most a mood lifts, leans and sways the body over two seconds.
func _most(mood: String) -> Dictionary:
	var most := {"lift": 0.0, "lean": 0.0, "sway": 0.0, "turn": 0.0, "lowest": 0.0}
	for step in 400:
		var pose := EmoteRules.pose_of(mood, step * 0.005)
		for part: String in ["lift", "lean", "sway", "turn"]:
			most[part] = maxf(float(most[part]), absf(float(pose[part])))
		most.lowest = minf(float(most.lowest), float(pose.lift))
	return most


## Every mood moves the body its own way: anger shakes without hopping, joy hops, excitement
## hops higher, sadness leans far forward and sags, neutral only nods.
func test_every_mood_moves_its_own_way(test) -> void:
	var angry := _most("boos")
	var happy := _most("blij")
	var excited := _most("opgewonden")
	var sad := _most("verdrietig")
	var neutral := _most("neutraal")
	test.check(float(angry.sway) > 0.05 and float(angry.turn) > 0.05 and float(angry.lift) == 0.0, "boos: schudden, niet springen")
	test.check(float(happy.lift) > 0.1 and float(happy.sway) == 0.0, "blij: op en neer")
	test.check(float(excited.lift) > float(happy.lift) and float(excited.sway) > 0.0, "opgewonden: hoger, en wiegend")
	test.check(float(sad.lean) > float(angry.lean) and float(sad.lowest) < 0.0, "verdrietig: voorover en ingezakt")
	test.check(float(neutral.lean) > 0.0 and float(neutral.lift) == 0.0 and float(neutral.sway) == 0.0, "neutraal: alleen knikken")


## An unknown mood counts as neutral, and every pose has all its parts.
func test_an_unknown_mood_is_neutral(test) -> void:
	test.check(EmoteRules.pose_of("onbekend", 0.4) == EmoteRules.pose_of("neutraal", 0.4), "een onbekende stemming is neutraal")
	test.check(EmoteRules.MOODS.has(EmoteRules.DEFAULT_MOOD), "de gewone stemming bestaat")
	for mood: String in EmoteRules.MOODS:
		var pose := EmoteRules.pose_of(mood, 0.3)
		test.check(pose.has("lift") and pose.has("lean") and pose.has("sway") and pose.has("turn"), "%s: een hele houding" % mood)


func test_a_mood_takes_over_in_a_third_of_a_second(test) -> void:
	test.check(is_equal_approx(EmoteRules.weight_after(0.0, 0.1), 0.3), "na een tiende seconde: 0,3")
	test.check(EmoteRules.weight_after(0.9, 0.1) == 1.0, "niet voorbij 1")
	test.check(EmoteRules.weight_after(0.4, 0.0) == 0.4, "zonder tijd verandert er niets")


func test_the_transform_of_the_figure(test) -> void:
	var rest := Transform3D(Basis(Vector3.UP, 0.5), Vector3(1.0, 2.0, 3.0))
	var still := {"lift": 0.0, "lean": 0.0, "sway": 0.0, "turn": 0.0}
	test.check(EmoteRules.figure_transform(rest, still, 1.0).is_equal_approx(rest), "geen beweging: zoals het stond")
	var hop := {"lift": 0.2, "lean": 0.0, "sway": 0.0, "turn": 0.0}
	test.check(EmoteRules.figure_transform(rest, hop, 0.5).origin.is_equal_approx(Vector3(1.0, 2.1, 3.0)), "de sprong naar het gewicht")
	test.check(EmoteRules.figure_transform(rest, hop, 0.0).is_equal_approx(rest), "gewicht nul: nog niets te zien")
	var lean := {"lift": 0.0, "lean": 0.3, "sway": 0.0, "turn": 0.0}
	var leant := EmoteRules.figure_transform(Transform3D.IDENTITY, lean, 1.0)
	test.check(leant.basis.is_equal_approx(Basis(Vector3.RIGHT, 0.3)), "voorover om de x-as")
	var turn := {"lift": 0.0, "lean": 0.0, "sway": 0.0, "turn": 0.2}
	test.check(EmoteRules.figure_transform(Transform3D.IDENTITY, turn, 0.0).basis.is_equal_approx(Basis(Vector3.UP, 0.2)),
		"de draai telt meteen heel")
