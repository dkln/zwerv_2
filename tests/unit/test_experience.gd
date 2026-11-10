extends RefCounted
## Unit tests of PlayerController.add_xp (scripts/player/player_controller.gd): experience adds
## up, a full bar is a level up, the next level takes more.

const Player = preload("res://scripts/player/player_controller.gd")


func test_xp_adds_up(test) -> void:
	var player := Player.new()
	player.add_xp(150.0)
	player.add_xp(50.0)
	test.check(is_equal_approx(player.xp, 200.0) and player.level == 1, "200 XP, nog level 1")
	player.free()


func test_a_full_bar_is_a_level_up(test) -> void:
	var player := Player.new()
	player.add_xp(1200.0)
	test.check(player.level == 2, "level 2 (%d)" % player.level)
	test.check(is_equal_approx(player.xp, 200.0), "de rest telt door (%.0f)" % player.xp)
	test.check(player.xp_for_level > 1000.0, "het volgende level kost meer (%.0f)" % player.xp_for_level)
	player.free()


func test_nothing_for_nothing(test) -> void:
	var player := Player.new()
	player.add_xp(0.0)
	player.add_xp(-10.0)
	test.check(player.xp == 0.0 and player.level == 1, "geen of negatieve XP doet niets")
	player.free()
