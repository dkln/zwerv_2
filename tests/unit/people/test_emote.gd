extends RefCounted
## Unit tests of the moods of someone talking (scripts/world/people/emote.gd pose_of): every mood
## its own movement of the body.

const Emote = preload("res://scripts/world/people/emote.gd")


## The most a mood lifts, leans and sways the body over two seconds.
func _most(mood: String) -> Dictionary:
	var most := {"lift": 0.0, "lean": 0.0, "sway": 0.0, "turn": 0.0, "lowest": 0.0}
	for step in 400:
		var pose := Emote.pose_of(mood, step * 0.005)
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
	test.check(Emote.pose_of("onbekend", 0.4) == Emote.pose_of("neutraal", 0.4), "een onbekende stemming is neutraal")
	for mood: String in Emote.MOODS:
		var pose := Emote.pose_of(mood, 0.3)
		test.check(pose.has("lift") and pose.has("lean") and pose.has("sway") and pose.has("turn"), "%s: een hele houding" % mood)
