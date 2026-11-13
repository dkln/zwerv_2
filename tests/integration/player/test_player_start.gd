extends "res://tests/integration/support/town_test.gd"
## How the player starts in the town (scripts/player/player_controller.gd): put on free
## ground near Den Haag Centraal, the camera following, asleep, and waking up by themselves.
## The town as the game starts it (not woken by the tests), without the descent from the
## sky (tests/integration/camera/test_arrival.gd) and without the story (its prologue would
## pause the game), so a world of its own; the rest of the player is test_player.gd.
##   tests/run_integration_tests.sh player_start


static func world_options() -> Dictionary:
	return {"wake": false, "without": ["DetailNiveau", "Rook", "Verhaal"],
		"settings": {"Volgcamera": {"arrival": false}}}


## The start, from the first moments: on the ground where they fit, the camera on them,
## near Centraal, asleep; then awake without a key being pressed.
func test_player_starts_asleep_near_centraal_and_wakes_up(test) -> void:
	var follow: Node = scene.get_node("Volgcamera")
	await wait_until(func() -> bool: return player._placed, 4.0)
	test.check(player._placed, "op de grond gezet")
	print("start: ", player.archetype_id, " bij ", player.global_position, ", figuur ", player._figure_box.size)
	test.check(player._fits(player.global_position), "staat vrij")
	test.check(follow.is_following() and follow.target_node == player, "camera volgt de speler")
	test.check(player._sleeping, "begint slapend")
	var station: Vector2 = scene.get_meta("places")["centraal"]
	var from_station := Vector2(player.global_position.x, player.global_position.z).distance_to(station)
	test.check(from_station < 40.0, "begint bij Centraal (%.0f m)" % from_station)
	await wait_until(func() -> bool: return not player._sleeping, 10.0)
	test.check(not player._sleeping, "wordt wakker")
