extends RefCounted
## Unit tests of the floor plan of an interior for the minimap (scripts/ui/widgets/interior_plan.gd):
## the area of its GridMaps, and per sample what its own colliders say: a wall, furniture, the
## floor, lower ground, nothing; only static colliders count.
##   tests/run_unit_tests.sh interior_plan

const InteriorPlan = preload("res://scripts/ui/widgets/interior_plan.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## An interior with one GridMap of cells of 2 m over `cells`, in the tree at `origin`.
func _interior(cells: Array, origin := Vector3.ZERO) -> Node3D:
	var interior := Node3D.new()
	interior.position = origin
	var library := MeshLibrary.new()
	library.create_item(0)
	var grid := GridMap.new()
	grid.name = "Vloer"
	grid.mesh_library = library
	grid.cell_size = Vector3(2.0, 2.0, 2.0)
	interior.add_child(grid)
	for cell: Vector3i in cells:
		grid.set_cell_item(cell, 0)
	tree.root.add_child(interior)
	return interior


## A box collider under `interior` from `lowest` to `highest` (its own space), on the town's layer.
static func _box(interior: Node3D, body: PhysicsBody3D, lowest: Vector3, highest: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = highest - lowest
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	body.position = (lowest + highest) * 0.5
	body.collision_layer = InteriorPlan.TOWN_LAYER
	interior.add_child(body)


static func _pixel(plan: Dictionary, column: int, row: int) -> Color:
	return (plan.texture as Texture2D).get_image().get_pixel(column, row)


static func _is(colour: Color, kind: String) -> bool:
	var wanted: Color = InteriorPlan.COLOURS[kind]
	return absf(colour.r - wanted.r) < 0.01 and absf(colour.g - wanted.g) < 0.01 and absf(colour.b - wanted.b) < 0.01


func test_no_gridmaps_no_plan(test) -> void:
	var interior := Node3D.new()
	tree.root.add_child(interior)
	test.check(InteriorPlan.build(interior).is_empty(), "zonder GridMap: geen plattegrond")
	var grid := GridMap.new()
	interior.add_child(grid)
	test.check(InteriorPlan.build(interior).is_empty(), "een lege GridMap: ook niet")
	interior.free()


func test_the_plan_covers_the_cells_of_the_gridmaps(test) -> void:
	# cells of 2 m: x 0..4, z 0..4 from the interior's origin at (10, 3, 20)
	var interior := _interior([Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1)], Vector3(10.0, 3.0, 20.0))
	var plan := InteriorPlan.build(interior)
	test.check(plan.origin == Vector2(10.0, 20.0), "de hoek van de plattegrond in de wereld (%s)" % plan.get("origin"))
	test.check(plan.extent == Vector2(4.0, 4.0), "zo groot als de cellen samen (%s)" % plan.get("extent"))
	test.check(plan.metres_per_pixel == InteriorPlan.SAMPLE_METRES, "een pixel per halve meter")
	var texture: Texture2D = plan.texture
	test.check(texture.get_width() == 8 and texture.get_height() == 8, "8 bij 8 pixels (%d x %d)" % [texture.get_width(), texture.get_height()])
	test.check(_is(_pixel(plan, 0, 0), "empty") and _is(_pixel(plan, 7, 7), "empty"), "zonder colliders: overal leeg")
	interior.free()


func test_the_colliders_colour_the_plan(test) -> void:
	# one row of two cells: x 0..4, z 0..2 (8 x 4 pixels); the floor of the interior at y = 3
	var interior := _interior([Vector3i(0, 0, 0), Vector3i(1, 0, 0)], Vector3(0.0, 3.0, 0.0))
	# a floor under x 0..3 (its top at the floor height), lower ground (a pit) under x 3..3.5
	_box(interior, StaticBody3D.new(), Vector3(0.0, -0.5, 0.0), Vector3(3.0, 0.0, 2.0))
	_box(interior, StaticBody3D.new(), Vector3(3.0, -1.5, 0.0), Vector3(3.5, -1.0, 2.0))
	# a wall over x 0..0.5 (higher than a head), a counter over x 1..1.5 (knee high)
	_box(interior, StaticBody3D.new(), Vector3(0.0, 0.0, 0.0), Vector3(0.5, 3.0, 2.0))
	_box(interior, StaticBody3D.new(), Vector3(1.0, 0.0, 0.0), Vector3(1.5, 1.0, 2.0))
	# someone standing at x 2..2.5: not part of the building
	_box(interior, CharacterBody3D.new(), Vector3(2.0, 0.0, 0.0), Vector3(2.5, 2.0, 2.0))
	var plan := InteriorPlan.build(interior)
	test.check(not plan.is_empty(), "er is een plattegrond")
	if plan.is_empty():
		interior.free()
		return
	var kinds := {}
	for kind: String in InteriorPlan.COLOURS:
		for column in 8:
			if _is(_pixel(plan, column, 1), kind):
				kinds[column] = kind
	test.check(kinds.get(0) == "wall", "een muur op hoofdhoogte: muur (%s)" % kinds.get(0))
	test.check(kinds.get(1) == "floor", "ernaast de vloer (%s)" % kinds.get(1))
	test.check(kinds.get(2) == "furniture", "iets op kniehoogte: meubel (%s)" % kinds.get(2))
	test.check(kinds.get(4) == "floor", "wie er staat telt niet mee: vloer (%s)" % kinds.get(4))
	test.check(kinds.get(6) == "lower", "grond onder de vloer: lager (%s)" % kinds.get(6))
	test.check(kinds.get(7) == "empty", "geen grond: leeg (%s)" % kinds.get(7))
	test.check(_is(_pixel(plan, 0, 0), "wall") and _is(_pixel(plan, 0, 3), "wall"), "over de hele diepte")
	interior.free()
