extends RefCounted
## Unit tests of the model of a bicycle (scripts/vehicles/bicycle_parts_view.gd): the three
## parts, where they go, and that one paint and shape is built once.
##   tests/run_unit_tests.sh bicycle_parts_view

const BicyclePartsView = preload("res://scripts/vehicles/bicycle_parts_view.gd")
const BicyclePartsLayout = preload("res://scripts/vehicles/bicycle_parts_layout.gd")

const PAINT := Color("#2E6E4E")


## The box of a part in metres on the vehicle.
func _box(part: Dictionary, origin: Vector3) -> AABB:
	var box: AABB = (part.mesh as Mesh).get_aabb()
	box.position += origin + part.offset
	return box


func test_three_parts_with_a_mesh_and_a_place(test) -> void:
	var parts := BicyclePartsView.build(PAINT)
	test.check(parts.keys() == ["frame", "steer", "crank"], "frame, stuur en cranks")
	for part_name: String in parts:
		var part: Dictionary = parts[part_name]
		test.check(part.mesh is Mesh and (part.mesh as Mesh).get_surface_count() > 0, "%s: een mesh" % part_name)
		test.check(part.offset is Vector3, "%s: een plek" % part_name)


func test_the_parts_stand_where_the_layout_says(test) -> void:
	var parts := BicyclePartsView.build(PAINT)
	var frame := _box(parts.frame, Vector3.ZERO)
	var steer := _box(parts.steer, BicyclePartsLayout.steer_pivot())
	var crank := _box(parts.crank, BicyclePartsLayout.bottom_bracket())
	var rear_hub := BicyclePartsLayout.point(BicyclePartsLayout.REAR_HUB.x, BicyclePartsLayout.REAR_HUB.y)
	var front_hub := BicyclePartsLayout.point(BicyclePartsLayout.FRONT_HUB.x, BicyclePartsLayout.FRONT_HUB.y)
	test.check(frame.grow(0.07).has_point(rear_hub), "het frame reikt tot de achternaaf")
	test.check(frame.grow(0.07).has_point(BicyclePartsLayout.hip() - Vector3(0.0, 0.1, 0.0)), "het zadel onder de heupen")
	test.check(steer.grow(0.07).has_point(front_hub), "de vork reikt tot de voornaaf")
	test.check(steer.grow(0.07).has_point(BicyclePartsLayout.grip(true)) and steer.grow(0.07).has_point(BicyclePartsLayout.grip(false)), "de handvatten aan het stuur")
	test.check(steer.grow(0.07).has_point(BicyclePartsLayout.front_lamp()), "de koplamp aan het stuur")
	test.check(frame.grow(0.07).has_point(BicyclePartsLayout.rear_lamp()), "het achterlicht aan het frame")
	test.check(crank.grow(0.07).has_point(BicyclePartsLayout.pedal(0.0, true)) and crank.grow(0.07).has_point(BicyclePartsLayout.pedal(0.0, false)), "de trappers aan de cranks")
	test.check(frame.position.y > 0.0 and steer.position.y > 0.0 and crank.position.y > 0.0, "alles boven de weg")
	test.check(absf(frame.get_center().x) < 0.07 and absf(crank.get_center().x) < 0.07, "in het midden van het voertuig")


func test_a_bicycle_is_built_once(test) -> void:
	var first := BicyclePartsView.build(PAINT)
	test.check(is_same(BicyclePartsView.build(PAINT), first), "dezelfde lak en vorm: dezelfde onderdelen")
	test.check(is_same(BicyclePartsView.build(PAINT, false, false).frame.mesh, first.frame.mesh), "ook met de vorm erbij gezegd")
	test.check(not is_same(BicyclePartsView.build(Color("#B0302A")).frame.mesh, first.frame.mesh), "een andere lak: een ander frame")


func test_the_shapes_differ(test) -> void:
	var plain := BicyclePartsView.build(PAINT)
	var step_through := BicyclePartsView.build(PAINT, true)
	var fat := BicyclePartsView.build(PAINT, false, true)
	test.check(not is_same(step_through.frame.mesh, plain.frame.mesh) and not is_same(fat.frame.mesh, plain.frame.mesh), "een omafiets en een fatbike zijn eigen frames")
	var plain_frame := _box(plain.frame, Vector3.ZERO)
	var fat_frame := _box(fat.frame, Vector3.ZERO)
	test.check(fat_frame.size.z < plain_frame.size.z, "een fatbike heeft geen spatbord en bagagedrager achter (%.2f < %.2f m)" % [fat_frame.size.z, plain_frame.size.z])
	test.check(_box(fat.steer, BicyclePartsLayout.steer_pivot()).size.z < _box(plain.steer, BicyclePartsLayout.steer_pivot()).size.z, "en geen voorspatbord")
	test.check(_box(step_through.crank, Vector3.ZERO).size == _box(plain.crank, Vector3.ZERO).size, "de cranks zijn overal dezelfde")
