extends RefCounted
## Unit tests of the protest flag on a tractor (scripts/vehicles/protest_flag.gd): the node
## on the roof, waving with the clock while it is in view.
##   tests/run_unit_tests.sh test_protest_flag

const ProtestFlag = preload("res://scripts/vehicles/protest_flag.gd")
const ProtestFlagRules = preload("res://scripts/vehicles/protest_flag_rules.gd")
const ProtestFlagLayout = preload("res://scripts/vehicles/protest_flag_layout.gd")
const ProtestFlagView = preload("res://scripts/vehicles/protest_flag_view.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func test_it_stands_on_the_roof_with_its_picture(test) -> void:
	var flag := ProtestFlag.new()
	test.check(flag.name == "Protestvlag" and flag.position == ProtestFlag.POLE_FOOT, "de vlag heet Protestvlag en staat op de voet van de paal")
	test.check(flag.view is ProtestFlagView and flag.view.get_parent() == flag and flag.get_child_count() == 1, "met zijn beeld eronder")
	test.check(flag.view.cloth().get_child_count() == 3, "een doek van drie banen")
	flag.free()


func test_the_old_names_are_still_there(test) -> void:
	test.check(ProtestFlag.POLE_FOOT == ProtestFlagLayout.POLE_FOOT and ProtestFlag.POLE_HEIGHT == 1.15 and ProtestFlag.POLE_WIDTH == 0.05, "de paal")
	test.check(ProtestFlag.CLOTH_SIZE == Vector3(0.04, 0.5, 0.75) and ProtestFlag.BANDS == ProtestFlagView.BANDS and ProtestFlag.POLE_COLOUR == ProtestFlagView.POLE_COLOUR, "het doek en de kleuren")
	test.check(ProtestFlag.WAVE_DEGREES == 12.0 and ProtestFlag.WAVE_SPEED == 3.1, "het wapperen")


func test_it_waves_with_the_clock(test) -> void:
	var flag := ProtestFlag.new()
	tree.root.add_child(flag)
	test.check(flag._wave_offset == ProtestFlagRules.wave_offset(flag.get_instance_id()), "in de boom: zijn eigen moment")
	var before := Time.get_ticks_msec() / 1000.0 + flag._wave_offset
	flag._process(0.016)
	var after := Time.get_ticks_msec() / 1000.0 + flag._wave_offset
	var turn := flag.view.cloth().rotation.y
	var low := minf(ProtestFlagRules.cloth_turn(before), ProtestFlagRules.cloth_turn(after)) - 0.02
	var high := maxf(ProtestFlagRules.cloth_turn(before), ProtestFlagRules.cloth_turn(after)) + 0.02
	test.check(turn >= low and turn <= high, "het doek staat zoals de regels op dit moment zeggen (%.3f)" % turn)
	test.check(absf(turn) <= deg_to_rad(ProtestFlag.WAVE_DEGREES) + 0.0001, "nooit verder dan de uitslag")
	flag.free()


func test_out_of_sight_it_stands_still(test) -> void:
	var flag := ProtestFlag.new()
	tree.root.add_child(flag)
	flag.view.show_wave(1.0)
	flag.visible = false
	flag._process(0.016)
	test.check(flag.view.cloth().rotation.y == 1.0, "onzichtbaar: het doek blijft staan")
	flag.visible = true
	flag._process(0.016)
	test.check(flag.view.cloth().rotation.y != 1.0, "weer zichtbaar: het wappert weer")
	flag.free()
	var loose := ProtestFlag.new()
	loose.view.show_wave(1.0)
	loose._process(0.016)
	test.check(loose.view.cloth().rotation.y == 1.0, "niet in de boom: het doek blijft staan")
	loose.free()
