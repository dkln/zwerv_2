extends RefCounted
## Unit tests of what drifts through the intro (scripts/ui/intro/drifter.gd, the
## behaviour): when one sets off, how it crosses, and when the next one comes.
##   tests/run_unit_tests.sh test_drifter.gd

const Drifter = preload("res://scripts/ui/intro/drifter.gd")
const DrifterRules = preload("res://scripts/ui/intro/drifter_rules.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _drifter() -> Drifter:
	var drifter := Drifter.new()
	drifter.first_at = 20.0
	drifter.last_at = 500.0
	drifter.random().seed = 92
	tree.root.add_child(drifter)
	return drifter


func test_nothing_before_its_time(test) -> void:
	var drifter := _drifter()
	drifter.advance(19.9, 0.1)
	test.check(not drifter.is_flying() and drifter.last_drifter() == "" and not drifter.view().visible, "voor zijn tijd zweeft er niets")
	drifter.free()


func test_one_sets_off_crosses_and_the_next_follows(test) -> void:
	var drifter := _drifter()
	drifter.advance(20.0, 0.1)
	var first := drifter.last_drifter()
	test.check(drifter.is_flying() and first != "" and drifter.view().visible and drifter.view().model() != null, "op zijn tijd vertrekt er een (%s)" % first)
	var start := drifter.view().position
	drifter.advance(25.0, 0.1)
	test.check(drifter.view().position != start and absf(drifter.view().position.x - start.x) > 100.0, "hij steekt het beeld over")
	drifter.advance(20.0 + DrifterRules.SECONDS.y, 0.1)
	test.check(not drifter.is_flying() and not drifter.view().visible, "aan de overkant is hij weg")
	var landed := 20.0 + DrifterRules.SECONDS.y
	drifter.advance(landed + DrifterRules.EVERY.x - 0.1, 0.1)
	test.check(not drifter.is_flying(), "even niets")
	drifter.advance(landed + DrifterRules.EVERY.y, 0.1)
	test.check(drifter.is_flying() and drifter.last_drifter() != first, "dan de volgende, een andere (%s)" % drifter.last_drifter())
	drifter.free()


func test_none_sets_off_near_the_end(test) -> void:
	var drifter := _drifter()
	drifter.last_at = 30.0
	drifter.advance(31.0, 0.1)
	test.check(not drifter.is_flying(), "vlak voor het eind van de intro vertrekt er geen meer")
	drifter.free()
