extends "res://tests/integration/support/town_test.gd"
## Getting on and off trams and trains (Pedestrians.door_open_at, Pedestrian.board_at,
## RailVehicle._let_people_on_and_off): the platforms of the tram stops are walkable; with a
## door open beside one, someone standing on it walks to the door and is gone (boarded), and
## someone comes out of the door onto the platform and walks off (alighted).
##   tests/run_integration_tests.sh boarding

## Seconds (game time) the door stands open.
const DOOR_OPEN_SECONDS := 12


## The cells of the tram and train platforms people can walk on.
func _platform_cells() -> Array[Vector3i]:
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	var ground: GridMap = scene.get_node("Grond")
	var platforms: Array[Vector3i] = []
	for cell: Vector3i in walkers._walkable:
		var item_name := ground.mesh_library.get_item_name(ground.get_cell_item(cell))
		if item_name in Pedestrians.PLATFORM_GROUND:
			platforms.append(cell)
	return platforms


## The player near a platform, someone waiting on it and a door standing open beside it for
## DOOR_OPEN_SECONDS: how many got on and off meanwhile ({"boarded", "alighted"}; empty
## without a platform).
func _open_a_door_at_a_platform() -> Dictionary:
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	var platforms := _platform_cells()
	if platforms.is_empty() or walkers.people().is_empty():
		return {}
	var platform: Vector3i = platforms[platforms.size() / 2]
	var door := walkers.cell_middle(platform) + Vector3(1.0, 0.0, 0.0)
	await put_player(walkers.cell_middle(platform) + Vector3(0.0, 0.0, 12.0))
	var waiting: Pedestrian = walkers.people()[0]
	waiting.restart_at(platform)
	await physics_frames(10)
	var boarded_before := walkers.boarded
	var alighted_before := walkers.alighted
	for second in DOOR_OPEN_SECONDS:
		# who gets off is one of those resting out of the town: there must be one (round a
		# stop the town wants many people, so often nobody rests)
		if walkers._resting.is_empty() and walkers.people().size() > 1:
			walkers._rest(walkers.people()[-1])
		walkers.door_open_at(door, 1.0)
		for frame_index in 60:
			tree.paused = false
			await tree.physics_frame
	print("ingestapt %d, uitgestapt %d" % [walkers.boarded - boarded_before, walkers.alighted - alighted_before])
	return {"boarded": walkers.boarded - boarded_before, "alighted": walkers.alighted - alighted_before}


## The platforms of the stops are among the cells people walk on.
func test_platforms_are_walkable(test) -> void:
	var platforms := _platform_cells()
	test.check(platforms.size() > 10, "perrons zijn beloopbaar (%d cellen)" % platforms.size())


## With a door open beside the platform, someone waiting there walks to it and is gone.
func test_someone_on_the_platform_gets_on(test) -> void:
	var counted := await _open_a_door_at_a_platform()
	test.check(int(counted.get("boarded", 0)) > 0, "iemand op het perron stapt in (naar de deur, weg)")


## With a door open beside the platform, someone comes out of it onto the platform.
func test_someone_gets_off_onto_the_platform(test) -> void:
	var counted := await _open_a_door_at_a_platform()
	test.check(int(counted.get("alighted", 0)) > 0, "iemand stapt uit, het perron op")
