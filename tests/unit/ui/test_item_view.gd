extends RefCounted
## Unit tests of the item view (scripts/ui/widgets/item_view.gd) on its own: an item turning
## round: its model, its framing.
##   tests/run_unit_tests.sh item_view

const ItemView = preload("res://scripts/ui/widgets/item_view.gd")
const ItemModels = preload("res://scripts/world/things/item_models.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func test_item_view_shows_the_model_of_an_item(test) -> void:
	var view := ItemView.new()
	tree.root.add_child(view)
	view.size = Vector2(200, 200)
	test.check(view.mesh() == null, "eerst geen item")
	view.show_item("kroket")
	var kroket := ItemModels.mesh_for("kroket")
	test.check(view.mesh() == kroket and kroket != null, "het model van de kroket")
	var box := kroket.get_aabb()
	test.check(view._model.position.is_equal_approx(-box.get_center()), "het draait om zijn midden")
	test.check(is_equal_approx(view._camera.size, box.size.length() * ItemView.ROOM), "het hele model in beeld met ruimte eromheen (%s)" % view._camera.size)
	test.check(view._camera.position.is_equal_approx(Vector3(0.0, 0.0, box.size.length() * 4.0)), "de camera ervoor")
	view.show_item("bestaat_niet")
	test.check(view.mesh() != null and not ItemModels.has_model("bestaat_niet"), "een item zonder model: het zakje")
	view.free()


func test_item_view_keeps_the_item_in_a_narrow_picture(test) -> void:
	var view := ItemView.new()
	tree.root.add_child(view)
	view.size = Vector2(100, 200)
	view.show_item("kroket")
	var diagonal := ItemModels.mesh_for("kroket").get_aabb().size.length()
	test.check(is_equal_approx(view._camera.size, diagonal * ItemView.ROOM / 0.5), "half zo breed als hoog: twee keer zoveel in beeld")
	view.size = Vector2(400, 200)
	test.check(is_equal_approx(view._camera.size, diagonal * ItemView.ROOM), "breder dan hoog: de gewone maat")
	view.free()


func test_item_view_turns_and_bobs_while_seen(test) -> void:
	var view := ItemView.new()
	tree.root.add_child(view)
	view.size = Vector2(200, 200)
	view.show_item("kroket")
	view._process(0.5)
	var pivot := view._pivot
	test.check(is_equal_approx(pivot.rotation.y, 0.5 * ItemView.TURN_SPEED), "het draait rond (%s)" % pivot.rotation.y)
	test.check(is_equal_approx(pivot.rotation.x, deg_to_rad(ItemView.TILT_DEGREES)), "een beetje naar je toe gekanteld")
	test.check(pivot.position.y > 0.0, "en deint")
	view.show_item("kroket")
	view._process(0.1)
	test.check(is_equal_approx(pivot.rotation.y, 0.1 * ItemView.TURN_SPEED), "een nieuw item begint van voren")
	view.visible = false
	view._process(5.0)
	test.check(is_equal_approx(pivot.rotation.y, 0.1 * ItemView.TURN_SPEED), "verborgen: het staat stil")
	test.check(view.process_mode == Node.PROCESS_MODE_ALWAYS, "het draait door als het spel stilstaat")
	view.free()
