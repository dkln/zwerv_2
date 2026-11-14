extends "res://tests/integration/support/town_test.gd"
## The meters of the HUD show it when they change (scripts/ui/widgets/segment_bar.gd), without
## moving: a hit leaves what it took in the loss colour, which then drains away; a small fall
## makes the edge blink (health, hunger, stamina, xp); a jump up lights it up,
## a slow rise does not, and after CHANGE_HOLD it is quiet again; the player's stats reach the
## bars (PlayerController._push_stats -> HUD.set_stat).
##   tests/run_integration_tests.sh segment_bar

const SegmentBar = preload("res://scripts/ui/widgets/segment_bar.gd")


## A bar of its own in the tree, filled to `fill` and quiet (the first fill is no change).
func _quiet_bar(fill: float) -> SegmentBar:
	var bar := SegmentBar.new()
	add_to_root(bar)
	bar.fill = fill
	return bar


## The first fill is no change; a small fall blinks, and after CHANGE_HOLD the bar is quiet.
func test_small_fall_blinks_then_quiet(test) -> void:
	var bar := _quiet_bar(0.8)
	test.check(not bar.is_showing_change(), "de eerste vulling is geen verandering")
	bar.fill = 0.79
	test.check(bar.is_showing_change() and bar._going_down, "een kleine daling knippert")
	await seconds(SegmentBar.CHANGE_HOLD + 0.3)
	test.check(not bar.is_showing_change(), "daarna is hij weer rustig")
	bar.free()


## A slow rise shows nothing, a jump up lights the bar up.
func test_slow_rise_is_quiet_and_a_jump_lights_up(test) -> void:
	var bar := _quiet_bar(0.79)
	bar.fill = 0.795
	test.check(not bar.is_showing_change(), "langzaam stijgen knippert niet")
	bar.fill = 0.9
	test.check(bar.is_showing_change() and not bar._going_down, "een sprong omhoog licht op")
	bar.free()


## A hit: what it took stays in the loss colour for LOSS_HOLD, then drains away to the new
## level; the bar itself does not move.
func test_hit_leaves_a_loss_that_drains_away(test) -> void:
	var bar := _quiet_bar(0.9)
	var position_before := bar.position
	bar.fill = 0.5
	test.check(bar.lost_segments() == 8, "een klap: wat eraf gaat blijft even in de verlieskleur (%d segmenten)" % bar.lost_segments())
	await seconds(SegmentBar.LOSS_HOLD + 0.2)
	var draining := bar.lost_segments()
	test.check(draining > 0 and draining < 8, "en loopt dan leeg (%d)" % draining)
	await seconds(1.0 / SegmentBar.LOSS_DRAIN)
	test.check(bar.lost_segments() == 0, "tot het nieuwe niveau")
	test.check(bar.position == position_before, "het balkje beweegt niet")
	bar.free()


## In the town: the player's health, hunger and stamina going down make their bars blink.
func test_player_stats_going_down_blink_their_bars(test) -> void:
	await seconds(SegmentBar.CHANGE_HOLD + 0.3)   # quiet after the reset
	for stat_name: String in ["gezondheid", "honger", "uithoudingsvermogen"]:
		var stat_before: Vector2 = player._stats[stat_name]
		player._stats[stat_name] = Vector2(stat_before.y * 0.9, stat_before.y)
		player._push_stats()
		var stat_bar: SegmentBar = hud.player_frame.stat_bar(stat_name)
		test.check(stat_bar.is_showing_change() and stat_bar._going_down, "%s gaat omlaag: het balkje knippert" % stat_name)
		player._stats[stat_name] = stat_before
	player._push_stats()


## In the town: the XP going down makes the XP bar blink.
func test_xp_going_down_blinks_its_bar(test) -> void:
	hud.set_xp(50.0, 100.0)
	hud.set_xp(40.0, 100.0)
	test.check(hud.player_frame.xp_bar().is_showing_change(), "xp omlaag: het balkje knippert")
	hud.set_xp(player.xp, player.xp_for_level)
