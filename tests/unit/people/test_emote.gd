extends RefCounted
## Unit tests of the node that moves the body of someone talking (scripts/world/people/emote.gd):
## it starts on a person, changes mood, moves the figure and puts it back.
##   tests/run_unit_tests.sh test_emote

const Emote = preload("res://scripts/world/people/emote.gd")
const EmoteRules = preload("res://scripts/world/people/emote_rules.gd")


func _person_with_figure() -> Node3D:
	var person := Node3D.new()
	var figure := Node3D.new()
	figure.name = "Figuur"
	figure.position = Vector3(0.0, 0.5, 0.0)
	person.add_child(figure)
	return person


func test_start_puts_one_mood_on_a_person(test) -> void:
	var person := _person_with_figure()
	var figure := person.get_node("Figuur") as Node3D
	Emote.start(person, figure, "blij")
	var emote := person.get_node_or_null(Emote.NODE_NAME)
	test.check(emote != null and emote.mood == "blij" and emote.figure == figure, "een Emotie-node met de stemming")
	test.check(emote.process_mode == Node.PROCESS_MODE_ALWAYS, "gaat door als het spel stilstaat")
	emote._clock = 1.0
	Emote.start(person, figure, "blij")
	test.check(emote._clock == 1.0 and person.get_child_count() == 2, "dezelfde stemming: er verandert niets")
	Emote.start(person, figure, "boos")
	test.check(emote.mood == "boos" and emote._clock == 0.0, "een andere stemming begint opnieuw")
	Emote.start(null, figure, "boos")
	Emote.start(person, null, "verdrietig")
	test.check(emote.mood == "boos", "zonder persoon of figuur gebeurt er niets")
	person.free()


func test_the_figure_moves_with_the_mood(test) -> void:
	var person := _person_with_figure()
	var figure := person.get_node("Figuur") as Node3D
	Emote.start(person, figure, "blij")
	var emote := person.get_node(Emote.NODE_NAME)
	var highest := 0.5
	for step in 40:
		emote._process(0.02)
		highest = maxf(highest, figure.position.y)
	test.check(highest > 0.55, "blij: het figuur springt (%.2f)" % highest)
	test.check(emote._weight == 1.0, "de stemming is er helemaal")
	person.free()


func test_stop_puts_the_figure_back(test) -> void:
	var person := _person_with_figure()
	var figure := person.get_node("Figuur") as Node3D
	var before := figure.transform
	Emote.start(person, figure, "verdrietig")
	var emote := person.get_node(Emote.NODE_NAME)
	for step in 10:
		emote._process(0.05)
	test.check(not figure.transform.is_equal_approx(before), "verdrietig: het figuur staat anders")
	Emote.stop(person)
	test.check(figure.transform.is_equal_approx(before), "gestopt: zoals het stond")
	test.check(emote.is_queued_for_deletion(), "de Emotie-node gaat weg")
	Emote.stop(null)
	Emote.stop(Node.new())
	person.free()


func test_the_pose_is_that_of_the_rules(test) -> void:
	test.check(Emote.pose_of("boos", 0.3) == EmoteRules.pose_of("boos", 0.3), "pose_of geeft door wat de logica zegt")
	test.check(Emote.MOODS == EmoteRules.MOODS, "dezelfde stemmingen")
