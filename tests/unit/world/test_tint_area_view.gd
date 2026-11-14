extends RefCounted
## Unit tests of the preview box of a tint area (scripts/world/town/tint_area_view.gd): a
## see-through box of the size and colour it is told.

const TintAreaView = preload("res://scripts/world/town/tint_area_view.gd")


## The box takes the size and the tint it is given, see-through.
func test_the_box_shows_the_area(test) -> void:
	var view := TintAreaView.new()
	view.show_area(Vector3(8.0, 0.1, 12.0), Color(0.2, 0.4, 0.6))
	test.check((view.mesh as BoxMesh).size == Vector3(8.0, 0.1, 12.0), "zo groot als het gebied")
	var colour := (view.material_override as StandardMaterial3D).albedo_color
	test.check(colour.is_equal_approx(Color(0.2, 0.4, 0.6, TintAreaView.ALPHA)), "in de tint, doorzichtig (%s)" % colour)
	test.check((view.material_override as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "het materiaal is doorzichtig")
	view.free()
