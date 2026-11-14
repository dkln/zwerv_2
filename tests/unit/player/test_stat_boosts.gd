extends RefCounted
## Unit tests of the stats over time (scripts/player/player_controller.gd): coffee gives stamina
## above the maximum for a while (boost_stat, Items "tijdelijk") and overstimulation; the
## overstimulation ebbs away by itself (calm_per_minute).

const Player = preload("res://scripts/player/player_controller.gd")
const Items = preload("res://scripts/player/items.gd")


static func _player() -> Node:
	var player := Player.new()
	player._stats = {"gezondheid": Vector2(70, 70), "uithoudingsvermogen": Vector2(20, 60),
			"honger": Vector2(80, 140), "overprikkeldheid": Vector2(50, 100)}
	return player


func test_coffee_gives_more_stamina_for_a_while(test) -> void:
	var player := _player()
	player.inventory = {"koffie": 1}
	var extra: Array = Items.item("koffie").tijdelijk.uithoudingsvermogen
	test.check(player.use_item("koffie"), "koffie gedronken")
	var stamina: Vector2 = player.stat("uithoudingsvermogen")
	test.check(stamina.y == 60.0 + float(extra[0]) and stamina.x > 60.0, "meer dan het gewone maximum (%s)" % stamina)
	test.check(player.stat("overprikkeldheid").x > 50.0, "maar ook meer overprikkeld (%s)" % player.stat("overprikkeldheid"))
	player._wear_off_boosts(float(extra[1]) - 1.0)
	test.check(player.stat("uithoudingsvermogen").y > 60.0, "na %d s nog steeds" % (int(extra[1]) - 1))
	player._wear_off_boosts(2.0)
	stamina = player.stat("uithoudingsvermogen")
	test.check(stamina == Vector2(60, 60), "uitgewerkt: terug naar het maximum (%s)" % stamina)
	player.free()


func test_a_boost_again_only_starts_the_time_over(test) -> void:
	var player := _player()
	player.boost_stat("uithoudingsvermogen", 30.0, 10.0)
	player._wear_off_boosts(8.0)
	player.boost_stat("uithoudingsvermogen", 30.0, 10.0)
	test.check(player.stat("uithoudingsvermogen").y == 90.0, "niet opgestapeld (%s)" % player.stat("uithoudingsvermogen"))
	test.check(is_equal_approx(player.boost_left("uithoudingsvermogen"), 10.0), "de tijd begint opnieuw")
	player._wear_off_boosts(5.0)
	player.change_stat("uithoudingsvermogen", -100.0)
	player._wear_off_boosts(6.0)
	test.check(player.stat("uithoudingsvermogen") == Vector2(0, 60), "leeg gerend: blijft leeg, maximum terug (%s)" % player.stat("uithoudingsvermogen"))
	player.free()


func test_overstimulation_ebbs_away(test) -> void:
	var player := _player()
	player._update_stats(60.0)
	var calm: Vector2 = player.stat("overprikkeldheid")
	test.check(is_equal_approx(calm.x, 50.0 - player.calm_per_minute), "een minuut later %.1f minder (%.1f)" % [player.calm_per_minute, calm.x])
	player._update_stats(3600.0)
	test.check(player.stat("overprikkeldheid").x == 0.0, "nooit onder nul")
	player.free()
