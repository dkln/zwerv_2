extends "res://tests/integration/support/town_test.gd"
## Falling into the water (scripts/player/player_controller.gd): next to a canal the player
## finds the water there (_water_point), and once in it, splashes (WaterSplash), sinks and
## drowns ("verdronken", the HUD's death text). (The reset before the next test brings the
## player back: TownWorld.back_on_feet.)
##   tests/run_integration_tests.sh drown


## The middle of a cell of open water in the ground layer (global), Vector3.INF if the town has none.
func _open_water() -> Vector3:
	var ground: GridMap = scene.get_node("Grond")
	for cell in ground.get_used_cells():
		var item_name := ground.mesh_library.get_item_name(ground.get_cell_item(cell))
		if item_name.begins_with("water/") and not item_name.contains("kademuur"):
			return ground.to_global(ground.map_to_local(cell))
	return Vector3.INF


## The player put in the air over `over_water`, falling: returns whether they went into the water.
func _jump_in(over_water: Vector3) -> bool:
	player.global_position = over_water + Vector3.UP * 2.0
	player._takeoff_height = player.global_position.y
	player._airborne = true
	player._vertical_speed = 0.0
	for step_index in 90:
		await tree.physics_frame
		if player._drowning:
			break
	return player._drowning


## Over a cell of open water the player finds the water under them.
func test_player_finds_the_water_under_them(test) -> void:
	var over_water := _open_water()
	test.check(over_water != Vector3.INF, "water in de stad")
	if over_water == Vector3.INF:
		return
	player.global_position = over_water + Vector3.UP * 1.0
	await physics_frames(1)
	var water: Vector3 = player._water_point(over_water)
	print("water bij ", over_water, ": ", water)
	test.check(water != Vector3.INF, "water gevonden onder de speler")


## Jumped in over the water: the player comes down in it by themselves, with a splash of
## drops and bubbles.
func test_jumping_in_ends_in_the_water_with_a_splash(test) -> void:
	var over_water := _open_water()
	test.check(over_water != Vector3.INF, "water in de stad")
	if over_water == Vector3.INF:
		return
	var particles_before := scene.find_children("*", "CPUParticles3D", true, false).size()
	test.check(await _jump_in(over_water), "in het water gesprongen: erin")
	await seconds(0.6)
	test.check(scene.find_children("*", "CPUParticles3D", true, false).size() > particles_before, "plons: druppels en bellen")


## Once in the water the player sinks and dies of drowning, nothing else, and the HUD has a
## death text for it.
func test_in_the_water_the_player_drowns(test) -> void:
	var over_water := _open_water()
	test.check(over_water != Vector3.INF, "water in de stad")
	if over_water == Vector3.INF:
		return
	var causes: Array[String] = []
	var note_cause := func(cause: String) -> void: causes.append(cause)
	player.died.connect(note_cause)
	if not await _jump_in(over_water):
		player._fall_into_water(over_water)
	await seconds(0.6 + player.drown_time + 0.5)
	player.died.disconnect(note_cause)
	print("doodsoorzaak: ", causes)
	test.check(causes == ["verdronken"], "verdronken")
	test.check(hud.DEATH_CAUSES.has("verdronken"), "doodstekst voor verdrinken")
