extends RefCounted
## Unit tests of how what drifts through the intro looks (scripts/ui/intro/drifter_view.gd):
## its small 3D picture, the models it makes and what it shows when told.
##   tests/run_unit_tests.sh drifter_view

const DrifterView = preload("res://scripts/ui/intro/drifter_view.gd")
const DrifterLayout = preload("res://scripts/ui/intro/drifter_layout.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _view() -> DrifterView:
	var view := DrifterView.new()
	tree.root.add_child(view)
	return view


func test_it_builds_a_small_picture_of_its_own(test) -> void:
	var view := _view()
	var picture := view.get_node("Trekkerbeeld") as SubViewport
	test.check(picture != null and picture.size == Vector2i(DrifterLayout.PICTURE, DrifterLayout.PICTURE) and picture.own_world_3d and picture.transparent_bg, "een eigen 3D-plaatje met een doorzichtige achtergrond")
	test.check(view.texture == picture.get_texture() and view.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "pixelscherp getoond")
	test.check(not view.visible and not view.is_drawing() and view.model() == null, "nog niets te zien, niets getekend")
	var cameras := picture.get_children().filter(func(child: Node) -> bool: return child is Camera3D)
	test.check(cameras.size() == 1 and (cameras[0] as Camera3D).position == DrifterLayout.CAMERA_AT, "de camera op zijn plek")
	view.free()


func test_make_tractor_and_character(test) -> void:
	test.check(DrifterView.make_tractor("bestaat_niet") == null, "een model dat er niet is: niets")
	var tractor := DrifterView.make_tractor("trekker")
	test.check(tractor != null, "een trekker")
	if tractor:
		var body := tractor.get_child(0) as Node3D
		test.check(body.position == DrifterLayout.tractor_position() and body.get_child_count() >= 2, "met zijn midden in de oorsprong, carrosserie en vlag")
		tractor.free()
	var character_id: String = PlayerCharacter.ORDER[0]
	var character := DrifterView.make_character(character_id)
	tree.root.add_child(character)
	var figure := character.get_child(0) as Node3D
	test.check(figure.get("archetype_id") == character_id and figure.scale == Vector3.ONE * DrifterLayout.CHARACTER_SCALE and figure.get("walking") == 1.0, "een personage, vergroot, spartelend")
	DrifterView.centre_character(character)
	test.check(figure.position.y < 0.0 and figure.position.is_equal_approx(DrifterLayout.character_position(figure.call("height"))), "met zijn midden in de oorsprong")
	character.free()


func test_show_a_flight(test) -> void:
	var view := _view()
	var first := Node3D.new()
	view.show_model(first, false)
	test.check(view.model() == first and first.is_inside_tree(), "het model staat in het plaatje")
	view.show_setting_off(95.0, 0.0, Vector3(0.0, PI * 0.5, 0.0))
	test.check(view.visible and view.is_drawing() and view.size == Vector2.ONE * 95.0, "onderweg: te zien, getekend, op zijn maat")
	test.check(view.modulate == DrifterView.NEAR_TINT and view.attitude().is_equal_approx(Basis.from_euler(Vector3(0.0, PI * 0.5, 0.0))), "dichtbij: helder; zo gedraaid als gezegd")
	view.show_setting_off(95.0, 1.0, Vector3.ZERO)
	test.check(view.modulate.is_equal_approx(DrifterView.FAR_TINT), "ver weg: doffer")
	view.show_flying(Vector2(40, 50), Basis(Vector3.UP, 0.25))
	view.show_flying(Vector2(60, 70), Basis(Vector3.UP, 0.25))
	test.check(view.position == Vector2(60, 70) and view.attitude().is_equal_approx(Basis(Vector3.UP, 0.5)), "hij schuift op en tuimelt verder")
	var second := Node3D.new()
	view.show_model(second, false)
	test.check(view.model() == second and first.is_queued_for_deletion(), "een nieuw model vervangt het oude")
	view.show_nothing()
	test.check(not view.visible and not view.is_drawing(), "aan de overkant: weg, niets meer getekend")
	view.free()
