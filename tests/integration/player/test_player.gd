extends "res://tests/integration/support/town_test.gd"
## The player of the town (scripts/player/player_controller.gd): the light over the figure
## at night, walking with the keys (and staying out of what stands there), jumping, running,
## a knock-down by a vehicle that throws it as a rigid body after which it stands up again
## blinking, eating, the game menu, and the hunger running out, then the health, and at 0 the
## death screen of the HUD. How it starts (asleep near Centraal): test_player_start.gd.
##   tests/run_integration_tests.sh player


## Holds `key` for `duration` seconds, checking every physics step that the player stands free.
func _hold_key(test, key: Key, duration: float) -> void:
	press_key(key, true)
	var stuck_steps := 0
	for step_index in int(duration * Engine.physics_ticks_per_second):
		await tree.physics_frame
		if not player._fits(player.global_position):
			stuck_steps += 1
	press_key(key, false)
	await tree.physics_frame
	test.check(stuck_steps == 0, "nergens in vast tijdens %s (%d stappen)" % [OS.get_keycode_string(key), stuck_steps])


## How far the player is from `from` along the ground (metres).
func _walked_from(from: Vector3) -> float:
	return Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length()


## The light over the figure in the dark (night_glow.gd): on at night, off by day.
func test_night_light_is_on_at_night_and_off_by_day(test) -> void:
	var night_light: OmniLight3D = player.get_node("Nachtlicht")
	var day_cycle: Node = scene.get_node("Dagcyclus")
	var hour_before: float = day_cycle.time_of_day
	day_cycle.set_time(1.0)
	await frames(2)
	test.check(night_light.visible and night_light.light_energy > 0.5, "nachtlicht aan in het donker (%.2f)" % night_light.light_energy)
	day_cycle.set_time(13.0)
	await frames(2)
	test.check(not night_light.visible, "nachtlicht uit overdag")
	day_cycle.set_time(hour_before)


## The tank controls (PlayerController `controls`): D turns the player round on the spot.
func test_d_turns_on_the_spot(test) -> void:
	var start: Vector3 = player.global_position
	var heading_before: float = player.rotation.y
	await _hold_key(test, KEY_D, 0.4)
	var turned := absf(angle_difference(player.rotation.y, heading_before))
	var stepped := _walked_from(start)
	test.check(turned > deg_to_rad(30.0) and stepped < 0.05, "D draait om de as (%.0f graden, %.2f m)" % [rad_to_deg(turned), stepped])


## W walks the way the player faces; S walks backwards, and slower than W forwards.
func test_w_walks_forward_and_s_backwards_slower(test) -> void:
	var start: Vector3 = player.global_position
	await _hold_key(test, KEY_W, 1.0)
	var moved: Vector3 = player.global_position - start
	var walked := _walked_from(start)
	print("na 1 s lopen: %.2f m" % walked)
	test.check(walked > 1.0, "loopt met de toetsen (%.2f m)" % walked)
	var off_by := absf(angle_difference(player.rotation.y, atan2(moved.x, moved.z)))
	test.check(off_by < deg_to_rad(10.0), "W loopt de kant op die hij kijkt (%.0f graden ernaast)" % rad_to_deg(off_by))
	start = player.global_position
	await _hold_key(test, KEY_S, 1.0)
	moved = player.global_position - start
	var backed := _walked_from(start)
	var facing_now := Vector3(sin(player.rotation.y), 0.0, cos(player.rotation.y))
	test.check(backed > 0.3 and backed < walked * 0.8 and moved.dot(facing_now) < 0.0, "S loopt achteruit, langzamer (%.2f m)" % backed)


## Space lifts the player off the ground and they come down again where they can stand.
func test_space_jumps_and_lands_again(test) -> void:
	var ground_before: float = player.global_position.y
	press_key(KEY_SPACE, true)
	var highest := 0.0
	for step_index in 60:
		await tree.physics_frame
		highest = maxf(highest, player.global_position.y - ground_before)
	press_key(KEY_SPACE, false)
	print("sprong: %.2f m hoog" % highest)
	test.check(highest > 0.5, "springt met spatie (%.2f m)" % highest)
	test.check(not player._airborne and absf(player.global_position.y - ground_before) < 0.7, "landt weer op de grond")


## A longer walk never ends up inside something, and running (Shift) costs stamina.
func test_running_costs_stamina(test) -> void:
	await _hold_key(test, KEY_W, 4.0)
	print("na 4 s: ", player.global_position)
	var stamina_before: float = player.stat("uithoudingsvermogen").x
	press_key(KEY_SHIFT, true)
	await _hold_key(test, KEY_W, 1.5)
	press_key(KEY_SHIFT, false)
	test.check(player.stat("uithoudingsvermogen").x < stamina_before, "rennen kost uithoudingsvermogen")


## A vehicle's footprint overlapping a point in it counts as a hit.
func test_vehicle_footprint_hits_a_point_inside_it(test) -> void:
	var car: Vehicle = scene.get_node("Auto")
	var frame := Transform3D(Basis.IDENTITY, car.global_position)
	var square := Vehicle.rectangle(frame, car.global_position, 0.5, 0.5, 0.0)
	test.check(Vehicle.rectangles_overlap(square, car.footprints(0.0)[0]), "voetafdruk van de auto raakt een punt erin")


## Knocked down: the player becomes a rigid body and loses health, then stands up again
## where they fit, blinking.
func test_knocked_down_then_up_again_blinking(test) -> void:
	var health_before: float = player.stat("gezondheid").x
	player._knock_down(Vector3(9.0, 0.0, 0.0), 9.0)
	player._hurt(10.0, "aangereden")
	test.check(player._ragdoll != null, "wordt een rigid body")
	test.check(player.stat("gezondheid").x < health_before, "verliest gezondheid")
	await wait_until(func() -> bool: return player._ragdoll == null, 10.0)
	test.check(player._ragdoll == null, "staat weer op")
	test.check(player._blink_left > 0.0, "knippert na het opstaan")
	test.check(player._fits(player.global_position), "staat vrij na het opstaan")
	print("opgestaan bij ", player.global_position)


## The cry of pain: never the same short one twice in a row.
func test_cries_of_pain_alternate(test) -> void:
	var repeated := false
	for cry_index in 20:
		var previous_cry: int = player._last_cry
		player.cry_out(false, player.global_position)
		repeated = repeated or player._last_cry == previous_cry or player._last_cry < 1
	test.check(not repeated, "pijnkreten wisselen af (stem %s)" % player._voice)


## Eating bread fills the hunger.
func test_eating_bread_fills_the_hunger(test) -> void:
	player.add_item("brood", 1)
	player._stats.honger = Vector2(10.0, player.stat("honger").y)
	test.check(player.use_item("brood") and player.stat("honger").x > 10.0, "brood eten vult de honger")


## The game menu of the HUD opens over the town on each of its tabs (the game paused) and
## closes again.
func test_game_menu_opens_paused_and_closes(test) -> void:
	var game_menu: Node = scene.get_node("HUD/Spelmenu")
	for tab_name: String in ["inventaris", "quests", "kaart"]:
		game_menu.open(tab_name)
		await frames(2)
		test.check(game_menu.is_open() and tree.paused, "spelmenu open op %s" % tab_name)
		game_menu.close()
		await frames(2)
	test.check(not game_menu.is_open() and not tree.paused, "spelmenu dicht")


## The hunger runs out, then the health, then the player is dead: the slow motion with the
## close-up first, then the death screen.
func test_starving_ends_in_the_death_screen(test) -> void:
	set_for_test(player, "hunger_per_minute", 60000.0)
	set_for_test(player, "starvation_interval", 0.02)
	set_for_test(player, "starvation_damage", 25.0)
	await wait_until(func() -> bool: return player.is_dead(), 10.0)
	test.check(player.stat("honger").x <= 0.0, "honger loopt leeg")
	test.check(player.is_dead(), "dood bij 0 gezondheid")
	test.check(scene.get_node("Volgcamera").is_dramatic(), "verhongerd: dramatisch ingezoomd")
	for attempt in 50:
		if hud.death_screen.is_open():
			break
		await unscaled_seconds(0.1)
	test.check(hud.death_screen.is_open(), "doodsscherm te zien")
