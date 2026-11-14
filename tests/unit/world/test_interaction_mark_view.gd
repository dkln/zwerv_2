extends RefCounted
## Unit tests of the picture of the arrow (scripts/world/things/interaction_mark_view.gd).
##   tests/run_unit_tests.sh interaction_mark_view

const InteractionMarkView = preload("res://scripts/world/things/interaction_mark_view.gd")
const InteractionMarkLayout = preload("res://scripts/world/things/interaction_mark_layout.gd")


func test_create_builds_a_hidden_arrow_and_its_darker_copy(test) -> void:
	var view := InteractionMarkView.create(true)
	var arrow := view.get_node("Pijl") as MeshInstance3D
	var shadow := view.get_node("Pijl_schaduw") as MeshInstance3D
	test.check(arrow != null and shadow != null and arrow.mesh == shadow.mesh, "een pijl en zijn kopie, dezelfde vorm")
	test.check(not view.is_shown() and not shadow.visible, "eerst niet te zien")
	var material := arrow.material_override as StandardMaterial3D
	var shadow_material := shadow.material_override as StandardMaterial3D
	test.check(material.albedo_color == InteractionMarkView.MARK_COLOUR and shadow_material.albedo_color != material.albedo_color, "de pijl in de accentkleur, de kopie donkerder")
	test.check(material.no_depth_test and material.render_priority > shadow_material.render_priority, "over alles heen, de pijl over zijn kopie")
	test.check(material.billboard_mode == BaseMaterial3D.BILLBOARD_FIXED_Y, "naar de camera gekeerd")
	var inside := InteractionMarkView.create(false)
	test.check(not ((inside.get_node("Pijl") as MeshInstance3D).material_override as StandardMaterial3D).no_depth_test, "binnen: niet door muren heen")
	view.free()
	inside.free()


func test_show_at_and_show_hidden(test) -> void:
	var view := InteractionMarkView.create(true)
	view.show_at(2.9)
	test.check(view.is_shown() and is_equal_approx(view.height(), 2.9), "te zien, op zijn hoogte")
	test.check((view.get_node("Pijl_schaduw") as Node3D).position.is_equal_approx(InteractionMarkLayout.shadow_place(2.9)), "de kopie er net onder")
	view.show_hidden()
	test.check(not view.is_shown() and not (view.get_node("Pijl_schaduw") as Node3D).visible, "weer weg")
	view.free()
