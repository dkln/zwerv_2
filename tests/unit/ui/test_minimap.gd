extends RefCounted
## Unit tests of the minimap of the HUD (scripts/ui/hud/minimap.gd) in a tiny town: the
## picture built from two GridMaps, following the player, the marks, the shroud of a story
## and the floor plan of an interior.
##   tests/run_unit_tests.sh test_minimap.gd

const Minimap = preload("res://scripts/ui/hud/minimap.gd")
const MapLook = preload("res://scripts/ui/hud/map_look.gd")
const Layout = preload("res://scripts/ui/hud/minimap_layout.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## A camera that follows someone, as the Volgcamera of the town.
class Follower extends Node:
	var target_node: Node3D

	func is_following() -> bool:
		return target_node != null


## The shroud of a story: the cells with x below `open_from` are closed.
class ShroudStandIn:
	var open_from := 2

	func is_open_cell(cell_x: int, _cell_z: int) -> bool:
		return cell_x >= open_from

	func is_open(x: float, _z: float) -> bool:
		return x >= open_from * 4.0 + 10.0


class StoryStandIn extends Node:
	signal shroud_changed
	var shroud := ShroudStandIn.new()


static func _same(first: Color, second: Color) -> bool:
	return absf(first.r - second.r) < 0.01 and absf(first.g - second.g) < 0.01 and absf(first.b - second.b) < 0.01


## A little town of cells of 4 m, standing at x 10, z 20: a row of road, pavement, grass
## and road (with a bridge deck over the last and a tunnel under the first), behind it one
## cell of pavement and a building; a second building far outside.
func _town() -> Node3D:
	var library := MeshLibrary.new()
	for tile_name: String in ["weg/asfalt", "stoep/tegel", "natuur/gras", "gebouw/huis"]:
		var item := library.get_item_list().size()
		library.create_item(item)
		library.set_item_name(item, tile_name)
	var town := Node3D.new()
	var ground := GridMap.new()
	ground.name = "Grond"
	var buildings := GridMap.new()
	buildings.name = "Gebouwen"
	for grid_map: GridMap in [ground, buildings]:
		grid_map.mesh_library = library
		grid_map.cell_size = Vector3(4.0, 4.0, 4.0)
		grid_map.position = Vector3(10.0, 0.0, 20.0)
		town.add_child(grid_map)
	ground.set_cell_item(Vector3i(0, 0, 0), 0)
	ground.set_cell_item(Vector3i(0, -1, 0), 1)
	ground.set_cell_item(Vector3i(1, 0, 0), 1)
	ground.set_cell_item(Vector3i(2, 0, 0), 2)
	ground.set_cell_item(Vector3i(3, 0, 0), 0)
	ground.set_cell_item(Vector3i(3, 1, 0), 2)
	ground.set_cell_item(Vector3i(1, 0, 1), 1)
	buildings.set_cell_item(Vector3i(2, 0, 1), 3)
	buildings.set_cell_item(Vector3i(9, 0, 9), 3)
	var player := Node3D.new()
	player.name = "Speler"
	player.position = Vector3(18.0, 0.0, 24.0)
	town.add_child(player)
	tree.root.add_child(town)
	return town


## A minimap in `town`, its picture built, following the player of the town.
func _minimap(town: Node3D, story: Node = null) -> Minimap:
	var minimap := Minimap.new()
	var follower := Follower.new()
	follower.target_node = town.get_node("Speler")
	town.add_child(follower)
	minimap.follow_camera = follower
	minimap.story = story
	town.add_child(minimap)
	minimap.build(town.get_node("Grond"), town.get_node("Gebouwen"))
	return minimap


func test_builds_the_picture_of_the_town(test) -> void:
	var town := _town()
	var minimap := Minimap.new()
	town.add_child(minimap)
	test.check(minimap.name == "Kaartje" and minimap.texture() == null and not minimap.is_focus_known(), "eerst geen kaart")
	var bare := GridMap.new()
	test.check(not minimap.build(null, null) and not minimap.build(bare, null), "zonder grond niets te bouwen")
	bare.free()
	test.check(minimap.build(town.get_node("Grond"), town.get_node("Gebouwen")), "de kaart is gebouwd")
	var image := minimap.texture().get_image()
	test.check(image.get_size() == Vector2i(4, 2), "een pixel per cel (%s)" % image.get_size())
	test.check(_same(image.get_pixel(0, 0), MapLook.GROUND_COLOURS["road"]) and _same(image.get_pixel(1, 0), MapLook.GROUND_COLOURS["pavement"]), "weg en stoep")
	test.check(_same(image.get_pixel(2, 0), MapLook.GROUND_COLOURS["grass"]) and _same(image.get_pixel(3, 0), MapLook.GROUND_COLOURS["road"]), "gras, en de weg onder het brugdek")
	test.check(_same(image.get_pixel(2, 1), MapLook.GROUND_COLOURS["building"]) and _same(image.get_pixel(0, 1), MapLook.EMPTY), "een gebouw, en niets waar niets ligt")
	test.check(minimap.origin() == Vector2(10.0, 20.0) and minimap.metres_per_pixel() == 4.0, "de hoek en de schaal van de kaart (%s)" % minimap.origin())
	test.check(minimap.shroud_image() == null and not minimap.is_shrouded(Vector2(12.0, 22.0)), "zonder verhaal geen sluier")
	town.free()


func test_follows_the_player(test) -> void:
	var town := _town()
	var minimap := _minimap(town)
	test.check(minimap.follow([Vector2(28.0, 24.0)]), "de speler wordt gevolgd")
	var pixels_for_a_metre := Layout.map_rect().size.x / 160.0
	test.check(minimap.is_focus_known() and minimap.focus() == Vector3(18.0, 0.0, 24.0), "waar de speler is")
	test.check(is_equal_approx(minimap.pixels_per_metre(), pixels_for_a_metre), "160 m over de kaart")
	var map_rect := minimap.view.map_rect()
	test.check(map_rect.size.is_equal_approx(Vector2(4.0, 2.0) * 4.0 * pixels_for_a_metre), "de kaart op schaal (%s)" % map_rect.size)
	test.check(map_rect.position.is_equal_approx(Layout.centre() - Vector2(8.0, 4.0) * pixels_for_a_metre), "de speler in het midden (%s)" % map_rect.position)
	test.check(is_equal_approx(absf(minimap.view.arrow_angle()), PI), "de pijl langs +z, waar de speler heen kijkt")
	test.check(minimap.view.quest_marks().size() == 1 and (minimap.view.quest_marks()[0] as Vector2).is_equal_approx(Layout.centre() + Vector2(10.0, 0.0) * pixels_for_a_metre), "de plek van de quest tien meter naar het oosten")
	test.check(minimap.mark_position(Vector2(18.0, 24.0)).is_equal_approx(Layout.centre()), "een plek waar de speler staat: het midden")
	minimap.metres = 80.0
	test.check(is_equal_approx(minimap.pixels_per_metre(), pixels_for_a_metre * 2.0), "half zoveel meters: twee keer zo groot")
	town.free()


func test_nothing_to_follow(test) -> void:
	var town := _town()
	var minimap := Minimap.new()
	town.add_child(minimap)
	test.check(not minimap.follow([]), "zonder kaart niets te volgen")
	minimap.build(town.get_node("Grond"), town.get_node("Gebouwen"))
	test.check(not minimap.follow([]) and not minimap.is_focus_known(), "zonder speler en zonder camera ook niet")
	town.free()


func test_the_marker_on_the_minimap(test) -> void:
	var town := _town()
	var minimap := _minimap(town)
	minimap.follow([])
	minimap.show_waypoint(Vector2(18.0, 4.0))
	test.check(minimap.view.waypoint_marks().size() == 1 and (minimap.view.waypoint_marks()[0] as Vector2).is_equal_approx(minimap.mark_position(Vector2(18.0, 4.0))), "de marker op zijn plek")
	test.check((minimap.view.waypoint_marks()[0] as Vector2).y < Layout.centre().y, "naar het noorden: boven de speler")
	minimap.show_waypoint(Vector2.INF)
	test.check(minimap.view.waypoint_marks().is_empty(), "geen marker: weg")
	town.free()


func test_the_shroud_of_the_story(test) -> void:
	var town := _town()
	var story := StoryStandIn.new()
	town.add_child(story)
	var minimap := _minimap(town, story)
	var shroud := minimap.shroud_image()
	test.check(shroud != null and shroud.get_size() == Vector2i(4, 2), "een sluier zo groot als de kaart")
	test.check(shroud.get_pixel(0, 0).a == 1.0 and shroud.get_pixel(1, 1).a == 1.0 and shroud.get_pixel(2, 0).a == 0.0, "dicht waar het verhaal niet open is")
	test.check(minimap.is_shrouded(Vector2(12.0, 22.0)) and not minimap.is_shrouded(Vector2(20.0, 22.0)), "een plek onder de sluier, een erbuiten")
	minimap.follow([Vector2(12.0, 22.0), Vector2(22.0, 22.0)])
	test.check(minimap.view.is_shroud_over_map(), "de sluier ligt over de kaart")
	test.check(minimap.view.quest_marks().size() == 1, "een questplek onder de sluier staat er niet op")
	story.shroud.open_from = 0
	story.shroud_changed.emit()
	test.check(minimap.shroud_image() == null, "het verhaal opent alles: de sluier weg")
	minimap.follow([Vector2(12.0, 22.0), Vector2(22.0, 22.0)])
	test.check(not minimap.view.is_shroud_over_map() and minimap.view.quest_marks().size() == 2, "en beide plekken staan erop")
	story.shroud.open_from = 9
	minimap.refresh_shroud()
	test.check(minimap.shroud_image() != null and minimap.shroud_image().get_pixel(3, 1).a == 1.0, "opnieuw geschilderd: alles dicht")
	town.free()


func test_town_plan_and_interior(test) -> void:
	var town := _town()
	var minimap := _minimap(town)
	var texture := minimap.texture()
	test.check(not minimap.is_indoors(), "buiten")
	minimap.show_town_plan()
	test.check(minimap.texture() == texture and minimap.origin() == Vector2(10.0, 20.0), "al buiten: de kaart blijft")
	# the plan of an interior comes two physics steps later; its ways out are known at once
	var interior := Node3D.new()
	town.add_child(interior)
	var exits: Array[Vector3] = [Vector3(18.0, 0.0, 34.0)]
	minimap.show_interior_plan(interior, exits)
	minimap.follow([])
	test.check(minimap.view.exit_marks().size() == 1 and (minimap.view.exit_marks()[0] as Vector2).is_equal_approx(minimap.mark_position(Vector2(18.0, 34.0))), "de uitgang op het kaartje")
	minimap.show_map(ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGB8)), Vector2(100.0, 100.0), 0.5)
	test.check(minimap.texture() != texture and minimap.origin() == Vector2(100.0, 100.0) and minimap.metres_per_pixel() == 0.5, "een andere kaart met zijn hoek en schaal")
	minimap.show_town_plan()
	minimap.follow([])
	test.check(minimap.view.exit_marks().is_empty(), "weer buiten: geen uitgangen")
	town.free()
