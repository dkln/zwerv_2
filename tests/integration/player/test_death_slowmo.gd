extends "res://tests/integration/support/town_test.gd"
## Run over and killed (PlayerController._slow_motion_death): the game slows down to
## DEATH_SLOW_MOTION (the physics stepping as often in real time), the follow camera zooms in
## on the player, and after DEATH_SLOW_SECONDS the speed comes back and the death screen is up.
## (The reset before the next test brings the player back: TownWorld.back_on_feet.)
##   tests/run_integration_tests.sh death_slowmo

const PlayerControllerScript = preload("res://scripts/player/player_controller.gd")


## Killed by a vehicle: at once slow motion with the physics stepping as often in real
## time, the camera going for the close-up, and no death screen yet.
func test_run_over_the_game_slows_down_and_the_camera_closes_in(test) -> void:
	var camera: Node = scene.get_node("Volgcamera")
	var ticks_before := Engine.physics_ticks_per_second
	player._hurt(10000.0, "aangereden")
	await frames(1)
	test.check(player.is_dead(), "dood na de aanrijding")
	test.check(absf(Engine.time_scale - PlayerControllerScript.DEATH_SLOW_MOTION) < 0.01, "slow motion (%.2f)" % Engine.time_scale)
	test.check(Engine.physics_ticks_per_second > ticks_before * 5, "physics stapt even vaak in echte tijd (%d per spelseconde)" % Engine.physics_ticks_per_second)
	test.check(camera.is_dramatic(), "de camera zoomt in")
	test.check(not hud.death_screen.is_open(), "nog geen doodsscherm tijdens de slow motion")


## Through the slow motion the figure never blinks (it is seen dying whole) and the view
## ends up zoomed in on the player.
func test_dying_figure_does_not_blink_and_the_view_zooms_in(test) -> void:
	var camera: Node = scene.get_node("Volgcamera")
	var zoom_before: float = camera._zoom
	player._hurt(10000.0, "aangereden")
	await frames(1)
	var blinked := false
	for wait_index in 24:
		await unscaled_seconds(0.05)
		if not player._model.visible or player._blink_left > 0.0:
			blinked = true
	test.check(not blinked, "geen geknipper tijdens het dramatisch doodgaan")
	test.check(camera._zoom < zoom_before * 0.5, "ingezoomd op de speler (%.1f m in beeld, was %.1f)" % [camera._zoom, zoom_before])


## After the slow motion the game is back at its own speed (the physics too) and the death
## screen comes up.
func test_after_the_slow_motion_normal_speed_and_the_death_screen(test) -> void:
	var ticks_before := Engine.physics_ticks_per_second
	player._hurt(10000.0, "aangereden")
	await frames(1)
	test.check(Engine.time_scale < 1.0, "eerst slow motion")
	await unscaled_seconds(PlayerControllerScript.DEATH_SLOW_SECONDS + PlayerControllerScript.DEATH_SPEED_UP + 0.1)
	await frames(1)
	test.check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == ticks_before, "daarna weer op normale snelheid")
	test.check(hud.death_screen.is_open(), "dan het doodsscherm")
