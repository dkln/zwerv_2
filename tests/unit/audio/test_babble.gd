extends RefCounted
## Unit tests of the babble (scripts/audio/babble.gd, the behaviour): the random draws of a
## sound and a pitch, what was played last, and the players in the UI and in the world. Which
## variant a draw gives and the names as plain sums: tests/unit/audio/test_babble_rules.gd.
##   tests/run_unit_tests.sh babble

const Babble = preload("res://scripts/audio/babble.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## The name is brabbel_<voice>_<mood>_<n>, n one of the variants.
func test_name_has_voice_mood_and_variant(test) -> void:
	var name := Babble.sound_name("vrouw", "boos")
	test.check(name.begins_with("brabbel_vrouw_boos_"), "begint met brabbel_vrouw_boos_ (%s)" % name)
	var variant := int(name.get_slice("_", 3))
	test.check(variant >= 1 and variant <= Babble.VARIANTS, "variant tussen 1 en %d (%d)" % [Babble.VARIANTS, variant])


## The same voice and mood never give one of the last RECENT variants again.
func test_no_variant_again_soon(test) -> void:
	var recent: Array[String] = []
	for attempt in 80:
		var next := Babble.sound_name("man", "blij")
		test.check(not next in recent, "%s niet binnen %d keer opnieuw" % [next, Babble.RECENT])
		recent.append(next)
		if recent.size() > Babble.RECENT:
			recent.pop_front()


## An unknown voice or mood falls back to "man" and "neutraal".
func test_unknown_voice_and_mood_fall_back(test) -> void:
	test.check(Babble.sound_name("robot", "verveeld").begins_with("brabbel_man_neutraal_"), "onbekend wordt man, neutraal")


## Every word a random sound: the same word (or line) does not always sound the same, and in
## a while every variant comes by.
func test_every_word_a_random_sound(test) -> void:
	var line := "Heb je misschien wat kleingeld voor me?"
	var first: Array[String] = []
	var second: Array[String] = []
	for index in 9:
		first.append(Babble.sound_name("man", "neutraal", Babble.word_at(line, index)))
		second.append(Babble.sound_name("man", "neutraal", Babble.word_at(line, index)))
	test.check(first != second, "dezelfde regel klinkt elke keer anders")
	var heard := {}
	for attempt in 400:
		heard[Babble.sound_name("vrouw", "vraag", "kroket")] = true
	test.check(heard.size() == Babble.VARIANTS, "alle %d varianten komen langs (%d)" % [Babble.VARIANTS, heard.size()])
	test.check(Babble.word_at(line, 0) == "Heb" and Babble.word_at(line, 2) == "misschien", "het zoveelste geluid is het zoveelste woord")
	test.check(Babble.word_at(line, 50) == "me?", "na het laatste woord: dat woord nog eens")
	test.check(Babble.word_at("", 0) == "", "zonder woorden: geen woord")


## Every word at its own random pitch, within PITCH_SPREAD of 1.
func test_every_word_a_random_pitch(test) -> void:
	var pitches := {}
	for play_index in 30:
		var pitch := Babble.played_pitch("kroket")
		pitches[snappedf(pitch, 0.0001)] = true
		test.check(absf(pitch - 1.0) <= Babble.PITCH_SPREAD + 0.0001, "binnen de spreiding (%.3f)" % pitch)
	test.check(pitches.size() > 10, "steeds een andere toonhoogte (%d)" % pitches.size())


## A recorder standing in for RuimtelijkGeluid: what it was asked to play.
class FakeSpatialAudio:
	extends Node
	var played: Array = []

	func play_signal(at: Vector3, sound_name: String, unit := 8.0) -> void:
		played.append([at, sound_name, unit])


## In the UI: a player on the owner, at UI_DB, at its own pitch, going on while paused.
func test_play_near_puts_a_player_on_the_owner(test) -> void:
	var owner := Node.new()
	tree.root.add_child(owner)
	var player := Babble.play_near(owner, "vrouw", "blij", "kroket")
	test.check(player != null and player.get_parent() == owner, "de speler hangt aan wie hem vroeg")
	test.check(player != null and player.stream != null and player.volume_db == Babble.UI_DB, "met zijn geluid, op het niveau van de UI")
	test.check(player != null and absf(player.pitch_scale - 1.0) <= Babble.PITCH_SPREAD + 0.0001, "op een eigen toonhoogte binnen de spreiding")
	test.check(player != null and player.process_mode == Node.PROCESS_MODE_ALWAYS, "hij klinkt door terwijl het spel stilstaat")
	test.check(Babble.play_near(null, "vrouw", "blij") == null, "zonder eigenaar: geen speler")
	owner.free()


## In the world: handed to RuimtelijkGeluid as a signal at that place.
func test_play_at_hands_the_shout_to_the_spatial_sound(test) -> void:
	var real := tree.root.get_node_or_null("RuimtelijkGeluid")
	if real != null:
		real.name = "RuimtelijkGeluidEcht"
	var fake := FakeSpatialAudio.new()
	fake.name = "RuimtelijkGeluid"
	tree.root.add_child(fake)
	Babble.play_at(tree, Vector3(3.0, 0.0, 4.0), "man", "boos", "Kijk uit!")
	test.check(fake.played.size() == 1, "één geluid gevraagd")
	if fake.played.size() == 1:
		test.check(fake.played[0][0] == Vector3(3.0, 0.0, 4.0), "op die plek")
		test.check(String(fake.played[0][1]).begins_with("brabbel_man_boos_"), "in die stem en stemming (%s)" % fake.played[0][1])
		test.check(fake.played[0][2] == 7.0, "tot 7 m op volle sterkte")
	Babble.play_at(null, Vector3.ZERO, "man", "boos")
	test.check(fake.played.size() == 1, "zonder boom gebeurt er niets")
	fake.free()
	if real != null:
		real.name = "RuimtelijkGeluid"
