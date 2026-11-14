extends RefCounted
## Unit tests of the props of the traffic lights (scripts/traffic/traffic_lights_view.gd): on a
## small hand-made Props layer (world_with_lights, also used by test_traffic_lights.gd).
##   tests/run_unit_tests.sh traffic_lights_view

const TrafficLightsView = preload("res://scripts/traffic/traffic_lights_view.gd")

const PREFIX := "verkeerslichten/"
const PROP_NAMES: Array[String] = ["verkeerslichten/auto_groen", "verkeerslichten/auto_oranje", "verkeerslichten/auto_rood",
	"verkeerslichten/voetganger_groen", "verkeerslichten/voetganger_rood", "verkeerslichten/ov_rijden",
	"verkeerslichten/ov_attentie", "verkeerslichten/ov_stop", "straatmeubilair/bank"]


## A library with the props of PROP_NAMES (no meshes: only the names count).
static func light_library() -> MeshLibrary:
	var library := MeshLibrary.new()
	for item in PROP_NAMES.size():
		library.create_item(item)
		library.set_item_name(item, PROP_NAMES[item])
	return library


## A world (not in a tree) with a "Props" layer and its LOD copy "Props_lod0", both empty.
static func world_with_layers() -> Node3D:
	var world := Node3D.new()
	for layer_name in ["Props", "Props_lod0"]:
		var layer := GridMap.new()
		layer.name = layer_name
		layer.mesh_library = light_library()
		world.add_child(layer)
	return world


## Puts the prop `prop` in `cell` of every layer of `world`, facing south, or east when
## `facing_east`.
static func place(world: Node, cell: Vector3i, prop: String, facing_east := false) -> void:
	for layer: GridMap in world.get_children().filter(func(child: Node) -> bool: return child is GridMap):
		var turn := layer.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI * 0.5)) if facing_east else 0
		layer.set_cell_item(cell, PROP_NAMES.find(prop), turn)


func test_has_layer(test) -> void:
	var world := world_with_layers()
	test.check(TrafficLightsView.new(world, "Props").has_layer(), "de laag is er")
	test.check(not TrafficLightsView.new(world, "Dingen").has_layer(), "een laag die er niet is")
	(world.get_node("Props") as GridMap).mesh_library = null
	test.check(not TrafficLightsView.new(world, "Props").has_layer(), "een laag zonder bibliotheek telt niet")
	world.free()


func test_light_props_lists_the_lights_and_how_they_face(test) -> void:
	var world := world_with_layers()
	place(world, Vector3i(1, 0, 2), "verkeerslichten/auto_rood")
	place(world, Vector3i(3, 0, 2), "verkeerslichten/voetganger_groen", true)
	place(world, Vector3i(5, 0, 5), "straatmeubilair/bank")
	var view := TrafficLightsView.new(world, "Props")
	var props := view.light_props(PREFIX)
	test.check(props.size() == 2, "alleen de lichten, de bank niet (%d)" % props.size())
	var by_cell := {}
	for prop in props:
		by_cell[prop.cell] = prop
	var car: Dictionary = by_cell.get(Vector3i(1, 0, 2), {})
	var walker: Dictionary = by_cell.get(Vector3i(3, 0, 2), {})
	test.check(car.get("prop", "") == "verkeerslichten/auto_rood", "de naam van de prop")
	test.check((car.get("facing", Vector3.ZERO) as Vector3).is_equal_approx(Vector3(0, 0, 1)), "niet gedraaid: kijkt naar het zuiden")
	test.check(absf((walker.get("facing", Vector3.ZERO) as Vector3).x) > 0.9, "een kwartslag gedraaid: kijkt langs x")
	test.check((car.get("pos", Vector3.ZERO) as Vector3).is_equal_approx((world.get_node("Props") as GridMap).map_to_local(Vector3i(1, 0, 2))), "de plek in meters")
	test.check(TrafficLightsView.new(world, "Dingen").light_props(PREFIX).is_empty(), "zonder laag: geen lichten")
	world.free()


func test_has_prop_knows_the_library_after_light_props(test) -> void:
	var world := world_with_layers()
	var view := TrafficLightsView.new(world, "Props")
	test.check(not view.has_prop("verkeerslichten/auto_groen"), "nog niet gekeken: onbekend")
	view.light_props(PREFIX)
	test.check(view.has_prop("verkeerslichten/auto_groen"), "een prop van de bibliotheek")
	test.check(not view.has_prop("verkeerslichten/fiets_groen"), "een prop die er niet in zit")
	test.check(not view.has_prop("straatmeubilair/bank"), "wat geen licht is wordt niet onthouden")
	world.free()


func test_show_props_swaps_the_prop_in_every_layer(test) -> void:
	var world := world_with_layers()
	var cell := Vector3i(3, 0, 2)
	place(world, cell, "verkeerslichten/auto_rood", true)
	place(world, Vector3i(4, 0, 2), "verkeerslichten/ov_stop")
	var view := TrafficLightsView.new(world, "Props")
	view.light_props(PREFIX)
	test.check(view.prop_at(cell) == "verkeerslichten/auto_rood", "eerst rood")
	test.check(view.prop_at(Vector3i(9, 0, 9)) == "", "een lege cel: niets")
	var turn_before := (world.get_node("Props") as GridMap).get_cell_item_orientation(cell)
	view.show_props([cell, Vector3i(4, 0, 2)], ["verkeerslichten/auto_groen", "verkeerslichten/ov_rijden"])
	test.check(view.prop_at(cell) == "verkeerslichten/auto_groen" and view.prop_at(Vector3i(4, 0, 2)) == "verkeerslichten/ov_rijden", "nu groen en rijden")
	for layer in view.layers():
		test.check(layer.mesh_library.get_item_name(layer.get_cell_item(cell)) == "verkeerslichten/auto_groen", "ook in %s" % layer.name)
		test.check(layer.get_cell_item_orientation(cell) == turn_before, "gedraaid zoals het stond (%s)" % layer.name)
	world.free()


func test_layers_are_the_layer_and_its_lod_copies(test) -> void:
	var world := world_with_layers()
	var other := GridMap.new()
	other.name = "Grond"
	world.add_child(other)
	var names := TrafficLightsView.new(world, "Props").layers().map(func(layer: GridMap) -> String: return String(layer.name))
	test.check(names == ["Props", "Props_lod0"], "de laag en zijn LOD-kopie, de grond niet (%s)" % str(names))
	test.check(TrafficLightsView.new(world, "Dingen").layers().is_empty(), "een andere naam: geen lagen")
	world.free()
