extends RefCounted
## Unit tests of the picture of the player frame (scripts/ui/hud/player_frame_view.gd): what
## it builds and what it shows of what it is handed.
##   tests/run_unit_tests.sh player_frame_view

const PlayerFrameView = preload("res://scripts/ui/hud/player_frame_view.gd")
const StatLook = preload("res://scripts/ui/hud/stat_look.gd")
const Layout = preload("res://scripts/ui/hud/player_frame_layout.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _view() -> PlayerFrameView:
	var view := PlayerFrameView.new()
	tree.root.add_child(view)
	return view


func test_a_bar_per_stat_in_its_colours(test) -> void:
	var view := _view()
	for stat_name: String in StatLook.STATS:
		var stat: Dictionary = StatLook.STATS[stat_name]
		var bar := view.stat_bar(stat_name)
		test.check(view.has_stat(stat_name) and bar != null, "%s: een balk" % stat_name)
		test.check(bar.segments == int(stat.segments) and bar.segment_height == int(stat.height) and bar.full_colour == stat.colour and bar.empty_colour == stat.empty, "%s: zoals StatLook zegt" % stat_name)
		test.check(view.stat_label(stat_name) != null and view.stat_label(stat_name).text == "", "%s: het getal nog leeg" % stat_name)
	test.check(not view.has_stat("bestaat_niet") and view.stat_bar("bestaat_niet") == null and view.stat_label("bestaat_niet") == null, "een stat die er niet is: niets")
	view.free()


func test_experience_bar_as_the_slim_stats(test) -> void:
	var view := _view()
	test.check(view.xp_bar().segments == StatLook.XP_SEGMENTS and view.xp_bar().segment_height == StatLook.XP_SEGMENT_HEIGHT, "de XP-balk met zijn segmenten")
	test.check(view.xp_bar().full_colour == StatLook.XP_COLOUR and view.xp_bar().fill == 0.0, "in zijn kleur, leeg")
	test.check(view.xp_bar().custom_minimum_size.x == view.stat_bar("honger").custom_minimum_size.x, "even breed als een stat-balk")
	view.free()


func test_portrait_inside_its_frame(test) -> void:
	var view := _view()
	test.check(view.portrait != null and view.portrait.size == Layout.portrait_inner().size and view.portrait.position == Layout.portrait_inner().position, "het portret binnen zijn rand")
	view.free()


func test_shows_what_it_is_handed(test) -> void:
	var view := _view()
	view.show_stat("honger", 0.25, "20/80")
	test.check(is_equal_approx(view.stat_bar("honger").fill, 0.25) and view.stat_label("honger").text == "20/80", "een stat: de balk en het getal")
	view.show_experience(0.5, "150 / 300")
	test.check(is_equal_approx(view.xp_bar().fill, 0.5) and view.xp_label().text == "150 / 300", "de XP")
	view.show_player("Sjaan", "LEVEL 4")
	test.check(view.shown_name() == "Sjaan" and view.shown_level() == "LEVEL 4", "naam en level")
	view.free()


func test_flash_lights_the_value_up(test) -> void:
	var view := _view()
	var text := view.stat_label("gezondheid")
	test.check(text.modulate == Color.WHITE, "eerst gewoon")
	view.flash_stat("gezondheid", false)
	test.check(text.modulate == StatLook.LOST_FLASH, "eraf: roodachtig")
	view.flash_stat("gezondheid", true)
	test.check(text.modulate == StatLook.GAINED_FLASH, "erbij: licht op, de vorige flits afgebroken")
	test.check(view.stat_label("honger").modulate == Color.WHITE, "de andere stats niet")
	view.free()
