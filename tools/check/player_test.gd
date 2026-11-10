extends SceneTree
## Checks the player of the town (scripts/player/player_controller.gd), headless: it is put
## on the ground near its start place, walks with the keys (and stays out of what stands
## there), the camera follows it, a knock-down by a vehicle throws it as a rigid body and it
## stands up again blinking, the hunger runs out and then the health, and at 0 the death
## screen of the HUD shows.
## usage: Godot --headless --script tools/check/player_test.gd [-- <archetype>]

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 300)
	PlayerCharacter.choose(Common.arg(0, "martin"))
	var scene := Common.instantiate(Common.CITY, false)
	# without the story (its prologue would pause the game), tested in story_test.gd
	for node_name in ["DetailNiveau", "Rook", "Grassprieten", "Verhaal"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	var follow: Node = scene.get_node("Volgcamera")
	for frame_index in 240:
		await physics_frame
		if player._placed:
			break
	# without the descent from the sky at the start (the player sleeps on through it; arrival_test.gd)
	follow._end_arrival()
	_check(player._placed, "op de grond gezet")
	print("start: ", player.archetype_id, " bij ", player.global_position, ", figuur ", player._figure_box.size)
	_check(player._fits(player.global_position), "staat vrij")
	_check(follow.is_following() and follow.target_node == player, "camera volgt de speler")
	_check(player._sleeping, "begint slapend")
	# the light over the figure in the dark (night_glow.gd): on at night, off by day
	var night_light: OmniLight3D = player.get_node("Nachtlicht")
	var day_cycle: Node = scene.get_node("Dagcyclus")
	var hour_before: float = day_cycle.time_of_day
	day_cycle.set_time(1.0)
	await process_frame
	await process_frame
	_check(night_light.visible and night_light.light_energy > 0.5, "nachtlicht aan in het donker (%.2f)" % night_light.light_energy)
	day_cycle.set_time(13.0)
	await process_frame
	await process_frame
	_check(not night_light.visible, "nachtlicht uit overdag")
	day_cycle.set_time(hour_before)
	var station: Vector2 = scene.get_meta("places")["centraal"]
	var from_station := Vector2(player.global_position.x, player.global_position.z).distance_to(station)
	_check(from_station < 40.0, "begint bij Centraal (%.0f m)" % from_station)
	for frame_index in 600:
		await physics_frame
		if not player._sleeping:
			break
	_check(not player._sleeping, "wordt wakker")

	# the tank controls (PlayerController `controls`): D turns it round on the spot, W walks
	# the way it faces, S backwards and slower
	var start := player.global_position
	var heading_before: float = player.rotation.y
	await _hold_key(KEY_D, 0.4, player)
	var turned := absf(angle_difference(player.rotation.y, heading_before))
	var stepped := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	_check(turned > deg_to_rad(30.0) and stepped < 0.05, "D draait om de as (%.0f graden, %.2f m)" % [rad_to_deg(turned), stepped])
	start = player.global_position
	await _hold_key(KEY_W, 1.0, player)
	var moved := player.global_position - start
	var walked := Vector2(moved.x, moved.z).length()
	print("na 1 s lopen: %.2f m" % walked)
	_check(walked > 1.0, "loopt met de toetsen (%.2f m)" % walked)
	var off_by := absf(angle_difference(player.rotation.y, atan2(moved.x, moved.z)))
	_check(off_by < deg_to_rad(10.0), "W loopt de kant op die hij kijkt (%.0f graden ernaast)" % rad_to_deg(off_by))
	start = player.global_position
	await _hold_key(KEY_S, 1.0, player)
	moved = player.global_position - start
	var backed := Vector2(moved.x, moved.z).length()
	var facing_now := Vector3(sin(player.rotation.y), 0.0, cos(player.rotation.y))
	_check(backed > 0.3 and backed < walked * 0.8 and moved.dot(facing_now) < 0.0, "S loopt achteruit, langzamer (%.2f m)" % backed)
	# jumping: Space lifts it off the ground and it comes down again where it can stand
	var ground_before: float = player.global_position.y
	press(KEY_SPACE, true)
	var highest := 0.0
	for step_index in 60:
		await physics_frame
		highest = maxf(highest, player.global_position.y - ground_before)
	press(KEY_SPACE, false)
	print("sprong: %.2f m hoog" % highest)
	_check(highest > 0.5, "springt met spatie (%.2f m)" % highest)
	_check(not player._airborne and absf(player.global_position.y - ground_before) < 0.7, "landt weer op de grond")
	await _hold_key(KEY_W, 4.0, player)
	print("na nog 4 s: ", player.global_position)
	var stamina_before: float = player.stat("uithoudingsvermogen").x
	press(KEY_SHIFT, true)
	await _hold_key(KEY_W, 1.5, player)
	press(KEY_SHIFT, false)
	_check(player.stat("uithoudingsvermogen").x < stamina_before, "rennen kost uithoudingsvermogen")

	# a vehicle's footprint overlapping the player's counts as a hit
	var car: Vehicle = scene.get_node("Auto")
	var frame := Transform3D(Basis.IDENTITY, car.global_position)
	var square := Vehicle.rectangle(frame, car.global_position, 0.5, 0.5, 0.0)
	_check(Vehicle.rectangles_overlap(square, car.footprints(0.0)[0]), "voetafdruk van de auto raakt een punt erin")

	# knocked down: a rigid body, hurt, then up again and blinking
	var health_before: float = player.stat("gezondheid").x
	player._knock_down(Vector3(9.0, 0.0, 0.0), 9.0)
	player._hurt(10.0, "aangereden")
	_check(player._ragdoll != null, "wordt een rigid body")
	_check(player.stat("gezondheid").x < health_before, "verliest gezondheid")
	# the cry of pain: never the same short one twice in a row
	var repeated := false
	for cry_index in 20:
		var previous_cry: int = player._last_cry
		player.cry_out(false, player.global_position)
		repeated = repeated or player._last_cry == previous_cry or player._last_cry < 1
	_check(not repeated, "pijnkreten wisselen af (stem %s)" % player._voice)
	for frame_index in 600:
		await physics_frame
		if player._ragdoll == null:
			break
	_check(player._ragdoll == null, "staat weer op")
	_check(player._blink_left > 0.0, "knippert na het opstaan")
	_check(player._fits(player.global_position), "staat vrij na het opstaan")
	print("opgestaan bij ", player.global_position)

	# eating
	player.add_item("brood", 1)
	player._stats.honger = Vector2(10.0, player.stat("honger").y)
	_check(player.use_item("brood") and player.stat("honger").x > 10.0, "brood eten vult de honger")

	# the game menu of the HUD opens over the town (paused) and closes again
	var game_menu: Node = scene.get_node("HUD/Spelmenu")
	for tab_name in ["inventaris", "quests", "kaart"]:
		game_menu.open(tab_name)
		await Common.wait_frames(self, 2)
		_check(game_menu.is_open() and paused, "spelmenu open op %s" % tab_name)
		game_menu.close()
		await Common.wait_frames(self, 2)
	_check(not game_menu.is_open() and not paused, "spelmenu dicht")

	# hunger runs out, then the health, then dead
	player.hunger_per_minute = 60000.0
	player.starvation_interval = 0.02
	player.starvation_damage = 25.0
	for frame_index in 600:
		await process_frame
		if player.is_dead():
			break
	_check(player.stat("honger").x <= 0.0, "honger loopt leeg")
	_check(player.is_dead(), "dood bij 0 gezondheid")
	var hud: Node = scene.get_node("HUD")
	# starved: first the slow motion with the close-up, then the death screen (real seconds)
	_check(scene.get_node("Volgcamera").is_dramatic(), "verhongerd: dramatisch ingezoomd")
	for attempt in 50:
		if hud._death_layer.visible:
			break
		await create_timer(0.1, true, false, true).timeout
	_check(hud._death_layer.visible, "doodsscherm te zien")
	print("speler ok" if _problems.is_empty() else "speler problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


func press(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = down
	Input.parse_input_event(event)


## Holds `key` for `seconds`, checking every step that the player stands free.
func _hold_key(key: Key, seconds: float, player: Node3D) -> void:
	press(key, true)
	var steps := int(seconds * Engine.physics_ticks_per_second)
	var stuck_steps := 0
	for step_index in steps:
		await physics_frame
		if not player._fits(player.global_position):
			stuck_steps += 1
	press(key, false)
	await physics_frame
	_check(stuck_steps == 0, "nergens in vast tijdens %s (%d stappen)" % [OS.get_keycode_string(key), stuck_steps])


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
