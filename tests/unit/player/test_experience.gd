extends RefCounted
## Unit tests of PlayerController.add_xp (scripts/player/player_controller.gd): experience adds
## up, a full bar is a level up, the next level takes more.

const Player = preload("res://scripts/player/player_controller.gd")


## Experience adds up without a level up while the bar is not full.
func test_xp_adds_up(test) -> void:
	var player := Player.new()
	player.add_xp(150.0)
	player.add_xp(50.0)   # under the 500 of the first level
	test.check(is_equal_approx(player.xp, 200.0) and player.level == 1, "200 XP, nog level 1")
	player.free()


## A full bar is a level up, the rest counts on, and the next level takes more.
func test_a_full_bar_is_a_level_up(test) -> void:
	var player := Player.new()
	test.check(is_equal_approx(player.xp_for_level, 500.0), "level 2 kost 500 XP (%.0f)" % player.xp_for_level)
	player.add_xp(600.0)
	test.check(player.level == 2, "level 2 (%d)" % player.level)
	test.check(is_equal_approx(player.xp, 100.0), "de rest telt door (%.0f)" % player.xp)
	test.check(is_equal_approx(player.xp_for_level, 750.0), "het volgende level kost meer (%.0f)" % player.xp_for_level)
	player.add_xp(750.0)
	test.check(player.level == 3 and is_equal_approx(player.xp_for_level, 1150.0), "en het level daarna nog meer (%.0f)" % player.xp_for_level)
	player.free()


## Zero or negative XP changes nothing.
func test_nothing_for_nothing(test) -> void:
	var player := Player.new()
	player.add_xp(0.0)
	player.add_xp(-10.0)
	test.check(player.xp == 0.0 and player.level == 1, "geen of negatieve XP doet niets")
	player.free()


## A stat chosen on the level-up screen: its maximum goes up (LEVEL_UP_RAISE); health fills up
## by as much, overstimulation (how much you can take) stays where it was.
func test_raise_stat(test) -> void:
	var player := Player.new()
	player._stats = {"gezondheid": Vector2(50.0, 70.0), "uithoudingsvermogen": Vector2(60.0, 60.0),
			"honger": Vector2(80.0, 140.0), "overprikkeldheid": Vector2(20.0, 100.0)}
	player.raise_stat("gezondheid")
	var health_raise: float = Player.LEVEL_UP_RAISE["gezondheid"]
	test.check(player.stat("gezondheid") == Vector2(50.0 + health_raise, 70.0 + health_raise), "gezondheid: maximum en waarde omhoog (%s)" % player.stat("gezondheid"))
	player.raise_stat("overprikkeldheid")
	var calm_raise: float = Player.LEVEL_UP_RAISE["overprikkeldheid"]
	test.check(player.stat("overprikkeldheid") == Vector2(20.0, 100.0 + calm_raise), "overprikkeldheid: alleen het maximum omhoog (%s)" % player.stat("overprikkeldheid"))
	player.raise_stat("bestaat_niet")
	test.check(player._stats.size() == 4, "een onbekende stat doet niets")
	player.free()
