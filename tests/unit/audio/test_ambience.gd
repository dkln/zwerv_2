extends RefCounted
## Unit tests of the background sound of a place (scripts/audio/ambience.gd, the behaviour):
## which player plays where, and that the one before goes. The loops and the levels as plain
## data: tests/unit/audio/test_ambience_rules.gd.
##   tests/run_unit_tests.sh ambience

const Ambience = preload("res://scripts/audio/ambience.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _ambience() -> Ambience:
	var ambience := Ambience.new()
	tree.root.add_child(ambience)
	return ambience


func test_a_place_gets_its_player(test) -> void:
	var ambience := _ambience()
	test.check(ambience.place == "" and ambience.get_child_count() == 0, "aan het begin: nergens, geen geluid")
	ambience.set_place("straat")
	var player := ambience.get_node_or_null("Omgeving_straat") as AudioStreamPlayer
	test.check(ambience.place == "straat", "de plek is de straat")
	test.check(player != null and player.stream != null, "de straat heeft een speler met zijn lus")
	test.check(player != null and player.volume_db == Ambience.SILENT_DB, "die begint stil (en komt dan op)")
	test.check(player != null and player.stream is AudioStreamOggVorbis and (player.stream as AudioStreamOggVorbis).loop, "de lus herhaalt")
	ambience.free()


func test_the_same_place_again_changes_nothing(test) -> void:
	var ambience := _ambience()
	ambience.set_place("winkel")
	var player := ambience.get_node_or_null("Omgeving_winkel")
	ambience.set_place("winkel")
	test.check(ambience.get_child_count() == 1 and ambience.get_node_or_null("Omgeving_winkel") == player, "dezelfde plek nog eens: dezelfde speler")
	test.check(not player.is_queued_for_deletion(), "en die blijft")
	ambience.free()


func test_another_place_takes_over(test) -> void:
	var ambience := _ambience()
	ambience.set_place("straat")
	var street := ambience.get_node_or_null("Omgeving_straat")
	ambience.set_place("station")
	test.check(ambience.get_node_or_null("Omgeving_station") != null, "het station heeft nu een speler")
	test.check(is_instance_valid(street) and not street.is_queued_for_deletion(), "de straat klinkt nog even door (hij zakt weg)")
	ambience.set_place("winkel")
	test.check(street.is_queued_for_deletion(), "wat al wegzakte gaat meteen weg als er weer een plek komt")
	test.check(ambience.get_node_or_null("Omgeving_winkel") != null and ambience.place == "winkel", "de winkel heeft nu een speler")
	ambience.free()


func test_nowhere_and_unknown_places_are_silent(test) -> void:
	var ambience := _ambience()
	ambience.set_place("straat")
	ambience.set_place("")
	test.check(ambience.place == "" and ambience.get_child_count() == 1, "nergens: geen nieuwe speler, de straat zakt weg")
	ambience.set_place("maan")
	test.check(ambience.place == "maan" and ambience.get_node_or_null("Omgeving_maan") == null, "een onbekende plek: geen speler")
	ambience.free()
