extends RefCounted
## Unit tests of the segmented bar (scripts/ui/widgets/segment_bar.gd): its size, how a fall
## of the fill shows (the lost part held, then draining), how a jump up shows (the gained
## segments glowing) and what does not show (the first fill, a slow rise).
##   tests/run_unit_tests.sh segment_bar

const SegmentBar = preload("res://scripts/ui/widgets/segment_bar.gd")

const FULL := Color("#33CC66")
const EMPTY := Color("#202020")


## A bar of ten segments in the test colours, its fill at `start_fill` (the start, not a change).
static func _bar(start_fill: float) -> SegmentBar:
	var bar := SegmentBar.new()
	bar.segments = 10
	bar.full_colour = FULL
	bar.empty_colour = EMPTY
	bar.fill = start_fill
	return bar


func test_size_follows_segments_and_height(test) -> void:
	var bar := SegmentBar.new()
	bar.segments = 20
	var around := 2.0 * (SegmentBar.PADDING + SegmentBar.BORDER_WIDTH)
	test.check(bar.custom_minimum_size == Vector2(20 * 9.0 + 19 * 2.0 + around, 12.0 + around), "twintig blokjes van 9 px, 2 px ertussen, rand eromheen (%s)" % bar.custom_minimum_size)
	test.check(bar.size == bar.custom_minimum_size, "en zo groot is hij ook")
	bar.segments = 5
	bar.segment_height = 20
	test.check(bar.custom_minimum_size == Vector2(5 * 9.0 + 4 * 2.0 + around, 20.0 + around), "minder en hogere blokjes (%s)" % bar.custom_minimum_size)
	test.check(bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "klikken gaan erdoorheen")
	bar.free()


func test_fill_is_kept_between_zero_and_one(test) -> void:
	var bar := _bar(0.5)
	bar.fill = 1.7
	test.check(bar.fill == 1.0, "meer dan vol: vol")
	bar.fill = -0.3
	test.check(bar.fill == 0.0, "minder dan leeg: leeg")
	bar.free()


func test_the_first_fill_is_not_a_change(test) -> void:
	var bar := _bar(0.3)
	test.check(not bar.is_showing_change() and bar.lost_segments() == 0, "de eerste vulling: het begin, geen verandering")
	test.check(not bar.is_processing(), "en hij staat stil")
	test.check(bar.segment_colour(0) == FULL and bar.segment_colour(2) == FULL, "de eerste drie vol")
	test.check(bar.segment_colour(3) == EMPTY and bar.segment_colour(9) == EMPTY, "de rest leeg")
	bar.free()


func test_a_fall_holds_what_was_lost_then_drains(test) -> void:
	var bar := _bar(1.0)
	bar.fill = 0.5
	test.check(bar.is_showing_change() and bar.is_processing(), "een val: hij laat het zien")
	test.check(bar.lost_segments() == 5, "vijf blokjes verloren (%d)" % bar.lost_segments())
	test.check(bar.segment_colour(4) == FULL, "wat er nog is: vol")
	test.check(bar.segment_colour(5) == SegmentBar.LOSS_COLOUR and bar.segment_colour(9) == SegmentBar.LOSS_COLOUR, "het verlorene in de verlieskleur")
	# 0.1 s on: the blink is in its dark half, the loss still waits
	bar._process(0.1)
	test.check(bar.lost_segments() == 5, "het blijft eerst even staan")
	test.check(bar.segment_colour(5).is_equal_approx(SegmentBar.LOSS_COLOUR.darkened(0.45)), "en knippert (donker)")
	# past LOSS_HOLD: it drains at LOSS_DRAIN a second, steady
	bar._process(0.4)
	test.check(bar.lost_segments() == 3, "na de wachttijd loopt het weg (%d)" % bar.lost_segments())
	test.check(bar.segment_colour(5) == SegmentBar.LOSS_COLOUR and bar.segment_colour(8) == EMPTY, "wat weg is: leeg, de rest egaal in de verlieskleur")
	bar._process(1.0)
	test.check(bar.lost_segments() == 0 and not bar.is_showing_change(), "tot er niets meer van over is")
	test.check(not bar.is_processing() and bar.segment_colour(5) == EMPTY, "dan staat hij weer stil")
	bar.free()


func test_a_second_hit_keeps_the_first_loss(test) -> void:
	var bar := _bar(1.0)
	bar.fill = 0.8
	bar._process(0.2)
	bar.fill = 0.6
	test.check(bar.lost_segments() == 4, "twee klappen: het verlies van allebei (%d)" % bar.lost_segments())
	test.check(is_equal_approx(bar._loss_wait, SegmentBar.LOSS_HOLD), "en de wachttijd begint opnieuw")
	bar.free()


func test_a_slow_fall_blinks_its_edge(test) -> void:
	var bar := _bar(0.5)
	bar.fill = 0.49
	test.check(bar.is_showing_change() and bar.lost_segments() == 0, "minder dan een blokje: een verandering zonder verloren blokjes")
	test.check(bar.segment_colour(5) == SegmentBar.LOSS_COLOUR, "het blokje aan de rand licht op")
	bar._process(0.1)
	test.check(bar.segment_colour(5) == EMPTY, "en knippert")
	test.check(bar.segment_colour(4) == FULL and bar.segment_colour(6) == EMPTY, "de andere niet")
	bar._process(SegmentBar.CHANGE_HOLD)
	test.check(not bar.is_showing_change() and not bar.is_processing(), "na CHANGE_HOLD is het over")
	bar.free()


func test_a_jump_up_glows_and_a_slow_rise_does_not(test) -> void:
	var bar := _bar(0.2)
	bar.fill = 0.2 + SegmentBar.GAIN_JUMP * 0.5
	test.check(not bar.is_showing_change(), "langzaam vollopen: niets te zien")
	bar.fill = 0.6
	test.check(bar.is_showing_change() and bar.lost_segments() == 0, "een sprong: hij laat het zien")
	var glow := FULL.lerp(SegmentBar.GAIN_GLOW, 0.75)
	test.check(bar.segment_colour(2).is_equal_approx(glow) and bar.segment_colour(5).is_equal_approx(glow), "wat erbij kwam gloeit")
	test.check(bar.segment_colour(1) == FULL and bar.segment_colour(6) == EMPTY, "wat er al was en wat leeg is niet")
	bar._process(SegmentBar.CHANGE_HOLD * 0.5)
	test.check(bar.segment_colour(3).is_equal_approx(FULL.lerp(SegmentBar.GAIN_GLOW, 0.375)), "de gloed dooft uit")
	bar._process(SegmentBar.CHANGE_HOLD)
	test.check(not bar.is_showing_change() and bar.segment_colour(3) == FULL, "tot de gewone kleur")
	bar.free()


func test_a_jump_up_clears_a_loss(test) -> void:
	var bar := _bar(1.0)
	bar.fill = 0.4
	test.check(bar.lost_segments() == 6, "eerst een verlies")
	bar.fill = 0.7
	test.check(bar.lost_segments() == 0, "eten erna: het verlies is weg")
	test.check(bar.segment_colour(8) == EMPTY and bar.segment_colour(5) != FULL, "en de winst gloeit")
	bar.free()
