extends RefCounted
## Unit tests of the working traffic lights (scripts/traffic/traffic_lights.gd, the behaviour):
## on a small hand-made Props layer with one intersection, the lights go round their cycle as
## time passes, the two streams never go together, and vehicles and people get their phase.
##   tests/run_unit_tests.sh traffic_lights

const TrafficLights = preload("res://scripts/traffic/traffic_lights.gd")
const TrafficLightsRules = preload("res://scripts/traffic/traffic_lights_rules.gd")
## The hand-made Props layer of the view's tests (world_with_layers, place).
const Props = preload("res://tests/unit/traffic/test_traffic_lights_view.gd")

const NORTH_SOUTH_CAR := Vector3i(0, 0, 0)
const EAST_WEST_CAR := Vector3i(2, 0, 0)
const NORTH_SOUTH_WALKER := Vector3i(0, 0, 2)
const TRAM := Vector3i(2, 0, 2)
## The middle of the intersection (the cells are 2 m; the lights stand at 1 and 5 m).
const MIDDLE := Vector3(3.0, 1.0, 3.0)
const STEP := 0.25

var tree: SceneTree


## A world in the tree with one intersection (a car light per stream, a pedestrian light
## beside the north-south stream, a tram light on the east-west one) and the lights node.
func _crossing(with_walkers := true) -> Node3D:
	var world := Props.world_with_layers()
	Props.place(world, NORTH_SOUTH_CAR, "verkeerslichten/auto_rood")
	Props.place(world, EAST_WEST_CAR, "verkeerslichten/auto_rood", true)
	if with_walkers:
		Props.place(world, NORTH_SOUTH_WALKER, "verkeerslichten/voetganger_rood")
	Props.place(world, TRAM, "verkeerslichten/ov_stop", true)
	var lights: Node = TrafficLights.new()
	lights.name = "Verkeerslichten"
	world.add_child(lights)
	tree.root.add_child(world)
	return world


func test_the_lights_go_round_their_cycle(test) -> void:
	var world := _crossing()
	var lights: Node = world.get_node("Verkeerslichten")
	var seen_north_south := {}
	var seen_east_west := {}
	var changes := 0
	var last := -1
	for step in roundi(24.0 / STEP):
		lights._process(STEP)
		var north_south: int = lights.car_phase(MIDDLE, true)
		var east_west: int = lights.car_phase(MIDDLE, false)
		seen_north_south[north_south] = true
		seen_east_west[east_west] = true
		test.check(north_south == TrafficLightsRules.RED or east_west == TrafficLightsRules.RED, "nooit beide stromen tegelijk groen of oranje")
		if north_south != last:
			changes += 1
			last = north_south
		test.check(lights.view.prop_at(NORTH_SOUTH_CAR) == TrafficLightsRules.prop_name("auto", north_south), "het autolicht noord-zuid toont zijn fase")
		test.check(lights.view.prop_at(EAST_WEST_CAR) == TrafficLightsRules.prop_name("auto", east_west), "het autolicht oost-west toont de zijne")
		test.check(lights.view.prop_at(TRAM) == TrafficLightsRules.prop_name("ov", east_west), "het tramlicht gaat met oost-west mee")
	test.check(seen_north_south.size() == 3 and seen_east_west.size() == 3, "elke stroom krijgt groen, oranje en rood")
	test.check(changes <= 4, "één ronde per cyclus: groen, oranje, rood (%d wisselingen)" % changes)
	world.free()


func test_the_lod_copy_follows(test) -> void:
	var world := _crossing()
	var lights: Node = world.get_node("Verkeerslichten")
	var copy := world.get_node("Props_lod0") as GridMap
	for step in roundi(24.0 / STEP):
		lights._process(STEP)
		test.check(copy.mesh_library.get_item_name(copy.get_cell_item(EAST_WEST_CAR)) == lights.view.prop_at(EAST_WEST_CAR), "de LOD-kopie toont hetzelfde")
	world.free()


func test_pedestrians_get_the_first_part_of_the_green(test) -> void:
	var world := _crossing()
	var lights: Node = world.get_node("Verkeerslichten")
	var walk_seconds := 0.0
	var walked_across := 0.0
	for step in roundi(24.0 / STEP):
		lights._process(STEP)
		var along: int = lights.pedestrian_phase(MIDDLE, true)
		var across: int = lights.pedestrian_phase(MIDDLE, false)
		if along == TrafficLightsRules.WALK:
			walk_seconds += STEP
			test.check(lights.car_phase(MIDDLE, true) == TrafficLightsRules.GREEN, "lopen kan alleen tijdens het groen van de stroom ernaast")
			test.check(lights.view.prop_at(NORTH_SOUTH_WALKER) == "verkeerslichten/voetganger_groen", "het voetgangerslicht is dan groen")
		else:
			test.check(lights.view.prop_at(NORTH_SOUTH_WALKER) == "verkeerslichten/voetganger_rood", "anders rood")
		if across == TrafficLightsRules.WALK:
			walked_across += STEP
			test.check(lights.car_phase(MIDDLE, false) == TrafficLightsRules.GREEN, "dwars: met het groen van oost-west")
		test.check(along != TrafficLightsRules.WALK or across != TrafficLightsRules.WALK, "nooit beide kanten tegelijk")
	test.check(is_equal_approx(walk_seconds, lights.pedestrian_time), "%.2f s per cyclus om over te steken (%.2f)" % [lights.pedestrian_time, walk_seconds])
	test.check(is_equal_approx(walked_across, lights.pedestrian_time), "dwars evenveel (%.2f)" % walked_across)
	world.free()


func test_no_lights_nearby(test) -> void:
	var world := _crossing(false)
	var lights: Node = world.get_node("Verkeerslichten")
	test.check(lights.car_phase(Vector3(200.0, 0.0, 200.0), true) == -1, "ver van elk kruispunt: geen lichten voor auto's")
	test.check(lights.car_phase(MIDDLE, true) != -1, "op het kruispunt wel")
	test.check(lights.car_phase(MIDDLE + Vector3(20.0, 0.0, 0.0), true, 30.0) != -1, "met een grotere straal ook verderop")
	test.check(lights.pedestrian_phase(MIDDLE, true) == -1, "een kruispunt zonder voetgangerslichten: geen voor wie loopt")
	world.free()


func test_without_lights_it_stands_still(test) -> void:
	var world := Props.world_with_layers()
	var lights: Node = TrafficLights.new()
	world.add_child(lights)
	tree.root.add_child(world)
	test.check(not lights.is_processing(), "geen lichten: het doet niets")
	test.check(lights.car_phase(Vector3.ZERO, true) == -1 and lights.pedestrian_phase(Vector3.ZERO, true) == -1, "en niemand krijgt een fase")
	world.free()
	var bare := Node3D.new()
	var alone: Node = TrafficLights.new()
	bare.add_child(alone)
	tree.root.add_child(bare)
	test.check(not alone.is_processing() and alone.car_phase(Vector3.ZERO, true) == -1, "zonder Props-laag: ook niets")
	bare.free()


func test_intersections_close_together_run_in_step(test) -> void:
	var world := Props.world_with_layers()
	Props.place(world, Vector3i(0, 0, 0), "verkeerslichten/auto_rood")
	Props.place(world, Vector3i(15, 0, 0), "verkeerslichten/auto_rood")    # 30 m on: in step
	Props.place(world, Vector3i(100, 0, 0), "verkeerslichten/auto_rood")   # far off: on its own
	var lights: Node = TrafficLights.new()
	world.add_child(lights)
	tree.root.add_child(world)
	var differed_far := false
	for step in roundi(24.0 / STEP):
		lights._process(STEP)
		var first: int = lights.car_phase(Vector3(1.0, 0.0, 1.0), true)
		test.check(first == lights.car_phase(Vector3(31.0, 0.0, 1.0), true), "30 m verder: dezelfde fase")
		differed_far = differed_far or first != lights.car_phase(Vector3(201.0, 0.0, 1.0), true)
	test.check(differed_far, "het kruispunt ver weg loopt niet in de pas")
	world.free()
