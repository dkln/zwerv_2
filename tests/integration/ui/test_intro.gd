extends "res://tests/integration/support/town_test.gd"
## The intro (scenes/intro.tscn) and the main menu behind it: the intro shows its context
## action (SPATIE Overslaan) and can build every character and tractor that drifts through
## space; a key breaks it off and the main menu comes up, then its 3D map (loaded in the
## background, without the town's libraries) arrives; on that map the tram drives, a column
## (tractors or the police) drives, a crash leaves a wreck, the fire starts and grows, a
## tractor that crashes hard burns, and the columns crash by themselves.
## With "volledig" the intro also plays to the end and says how long that took (about two
## minutes of the clock: it follows its music).
## A run of its own: it changes the current scene and checks what the process has loaded.
##   tests/run_integration_tests.sh intro [-- volledig]

const MENU_SCENE := "res://scenes/hoofdmenu.tscn"
## Seconds of the clock one test may take (the whole intro lasts as long as its music).
const TEST_SECONDS := 250.0
## The nodes of the menu map that hold a column of vehicles.
const COLUMNS := ["Trekkers", "Politie"]


static func world_options() -> Dictionary:
	return {"town": false, "own_process": true}


## The intro as the current scene, a moment on its way.
func _start_intro() -> Node:
	var intro: Node = load("res://scenes/intro.tscn").instantiate()
	add_to_root(intro)
	tree.current_scene = intro
	await frames(30)
	return intro


## The main menu as the current scene with its 3D map there; returns the map (null if it
## never came).
func _menu_with_map() -> Node:
	if tree.current_scene == null or tree.current_scene.name != "Hoofdmenu":
		var menu_scene: Node = load(MENU_SCENE).instantiate()
		add_to_root(menu_scene)
		tree.current_scene = menu_scene
	var menu_scene := tree.current_scene
	await wait_until(func() -> bool: return menu_scene.has_node("Menukaart"), 120.0)
	await frames(1)
	return menu_scene.get_node_or_null("Menukaart")


## A vehicle of a column that is driving in view on `map` now (`columns`: which holders), or null.
func _driving_vehicle(map: Node, columns: Array = COLUMNS) -> Node3D:
	for holder_name: String in columns:
		var holder := map.get_node_or_null(holder_name)
		if holder == null:
			continue
		for vehicle in holder.get_children():
			if vehicle.has_meta("rijdt") and (vehicle as Node3D).visible:
				return vehicle
	return null


## Waits (at most `most_seconds` of game time) for a vehicle of a column driving in view.
func _wait_for_driving_vehicle(map: Node, columns: Array, most_seconds: float) -> Node3D:
	await wait_until(func() -> bool: return _driving_vehicle(map, columns) != null, most_seconds)
	return _driving_vehicle(map, columns)


## The node of the menu that crashes vehicles (MainMenu._crash).
func _crasher() -> Node:
	var menu_scene := tree.current_scene
	if menu_scene.has_method("_crash"):
		return menu_scene
	return menu_scene.find_children("*", "", true, false).filter(
			func(node: Node) -> bool: return node.has_method("_crash")).front()


## At the start the only context action is SPATIE Overslaan (the story is not rolling yet).
func test_intro_offers_to_skip(test) -> void:
	var intro := await _start_intro()
	var prompts := intro.find_child("Toetsen", true, false)
	var actions: Array = prompts.call("actions") if prompts else []
	test.check(actions == [["SPATIE", "Overslaan"]], "contextactie %s" % [actions])


## Every character and tractor that drifts through space can be made, the characters centred.
func test_every_drifter_can_be_made(test) -> void:
	var intro := await _start_intro()
	for drifter_name: String in intro.PlayerCharacter.ORDER + intro.TRACTOR_MODELS:
		var is_character: bool = intro.PlayerCharacter.ARCHETYPES.has(drifter_name)
		var drifter: Node3D = intro._make_character(drifter_name) if is_character else intro._make_tractor(drifter_name)
		test.check(drifter != null, "zwever %s gemaakt" % drifter_name)
		if drifter == null:
			continue
		add_to_root(drifter)
		if is_character:
			intro._centre_character(drifter)
			test.check((drifter.get_child(0) as Node3D).position.y < 0.0, "personage %s in het midden" % drifter_name)
		drifter.queue_free()


## The space bar breaks the intro off: the main menu comes up, then its 3D map with the
## sun, and the menu has not loaded the town's mesh libraries for it.
func test_space_goes_to_the_main_menu_and_its_map_arrives(test) -> void:
	await _start_intro()
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	tree.root.push_input(key)
	var at_menu := await wait_until(func() -> bool: return tree.current_scene != null and tree.current_scene.name == "Hoofdmenu", 20.0)
	test.check(at_menu, "hoofdmenu na de toets")
	if not at_menu:
		return
	var map := await _menu_with_map()
	test.check(map != null, "het 3D-kaartje kwam")
	if map == null:
		return
	var sun := map.get_node_or_null("Zonneschijf") as Node3D
	test.check(sun != null, "zon op %s" % (sun.global_position if sun else Vector3.ZERO))
	for library: String in ["grond", "gebouwen", "details", "props", "grond_lod2", "grond_lod"]:
		test.check(not ResourceLoader.has_cached("res://assets/libraries/%s.res" % library), "het menu laadde de bibliotheek %s niet" % library)


## On the menu map the tram comes by within 12 s.
func test_tram_drives_on_the_menu_map(test) -> void:
	var map := await _menu_with_map()
	var tram := map.get_node_or_null("Tramlijn1/Tram") as Node3D if map else null
	test.check(tram != null, "een tram op het kaartje")
	if tram == null:
		return
	var tram_seen := await wait_until(func() -> bool: return tram.visible, 12.0)
	test.check(tram_seen, "tram rijdt (bij %s)" % tram.global_position)


## A column (tractors or the police) drives by within half a minute, and a vehicle of it
## that is made to crash hard becomes a wreck.
func test_column_drives_and_a_crash_leaves_a_wreck(test) -> void:
	var map := await _menu_with_map()
	test.check(map != null, "het 3D-kaartje kwam")
	if map == null:
		return
	var driving := await _wait_for_driving_vehicle(map, COLUMNS, 30.0)
	test.check(driving != null, "colonne rijdt: %s" % (driving.name if driving else &"geen"))
	if driving == null:
		return
	_crasher().call("_crash", driving, 25.0)   # hard: it blows up and burns
	var wreck := driving.get_parent() as RigidBody3D
	for frame_index in 90:
		await tree.physics_frame
	test.check(wreck != null and is_instance_valid(wreck), "wrak op %s" % (wreck.global_position if wreck and is_instance_valid(wreck) else Vector3.ZERO))


## The fire on the map starts after a while and then grows: its flames come from a wider box.
func test_fire_starts_and_grows(test) -> void:
	var map := await _menu_with_map()
	test.check(map != null, "het 3D-kaartje kwam")
	if map == null:
		return
	await wait_until(func() -> bool:
		var burning := map.get_node_or_null("Brand/Vlammen") as GPUParticles3D
		return burning != null and burning.visible, 80.0)
	var flames := map.get_node_or_null("Brand/Vlammen") as GPUParticles3D
	test.check(flames != null, "een brand op het kaartje")
	if flames == null:
		return
	var fire := map.get_node_or_null("Brand") as Node3D
	test.check(flames.visible, "brand op %s" % fire.global_position)
	var box_at_start := (flames.process_material as ParticleProcessMaterial).emission_box_extents
	await seconds(20.0)
	var box_later := (flames.process_material as ParticleProcessMaterial).emission_box_extents
	test.check(box_later.x > box_at_start.x, "brand groeit (%s -> %s)" % [box_at_start, box_later])


## A tractor that crashes hard enough (not hard enough to explode) goes up in flames.
func test_tractor_that_crashes_hard_burns(test) -> void:
	var map := await _menu_with_map()
	test.check(map != null, "het 3D-kaartje kwam")
	if map == null:
		return
	var tractor := await _wait_for_driving_vehicle(map, ["Trekkers"], 80.0)
	test.check(tractor != null, "een trekker gezien")
	if tractor == null:
		return
	_crasher().call("_crash", tractor, 15.0)   # hard enough for a fire (vehicle_fire.gd), not to explode
	test.check(tractor.get_parent().get_node_or_null("Brand") != null, "trekker in de fik")


## Left alone the columns crash by themselves (the police meeting the tractors on their
## lane) within four minutes of menu time: a wreck appears.
func test_columns_crash_by_themselves(test) -> void:
	var map := await _menu_with_map()
	test.check(map != null, "het 3D-kaartje kwam")
	if map == null:
		return
	var there_before := map.get_children()
	var wreck_name := [""]
	var frames_waited := [0]
	await wait_until(func() -> bool:
		frames_waited[0] += 1
		for node in map.get_children():
			if node.name.begins_with("Wrak") and not there_before.has(node):
				wreck_name[0] = node.name
		return wreck_name[0] != "", 240.0)
	print("  wrak %s na %d frames" % [wreck_name[0], frames_waited[0]])
	test.check(wreck_name[0] != "", "vanzelf gebotst (%s)" % wreck_name[0])


## Only with the argument "volledig": the intro left alone plays to its end and goes on to
## the main menu by itself; says how long it took.
func test_whole_intro_plays_to_the_end(test) -> void:
	if argument(0) != "volledig":
		test.check(true, "overgeslagen (alleen met -- volledig)")
		return
	var intro: Node = load("res://scenes/intro.tscn").instantiate()
	add_to_root(intro)
	tree.current_scene = intro
	var began := Time.get_ticks_msec()
	while tree.current_scene == intro and Time.get_ticks_msec() - began < 200000:
		await tree.process_frame
	test.check(tree.current_scene != intro, "de hele intro duurt %.1f s" % ((Time.get_ticks_msec() - began) / 1000.0))
