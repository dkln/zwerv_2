extends RefCounted
## Unit tests of the people on the terraces (scripts/world/people/terraces.gd), on a tiny props
## map with a few terrace tables.
##   tests/run_unit_tests.sh test_terraces

const Terraces = preload("res://scripts/world/people/terraces.gd")
const TerracesLayout = preload("res://scripts/world/people/terraces_layout.gd")

var tree: SceneTree


## A world with a props map of `tables` terrace tables in a row and the Terrassen node.
func _world(tables: int) -> Node3D:
	var world := Node3D.new()
	var props := GridMap.new()
	props.name = "Props"
	props.cell_size = Vector3(4.0, 1.0, 4.0)
	var library := MeshLibrary.new()
	library.create_item(0)
	library.set_item_name(0, "terras/terras_set")
	library.create_item(1)
	library.set_item_name(1, "straat/bank")
	props.mesh_library = library
	for index in tables:
		props.set_cell_item(Vector3i(index, 0, 0), 0)
	props.set_cell_item(Vector3i(0, 0, 3), 1)
	world.add_child(props)
	var terraces: Node3D = Terraces.new()
	terraces.name = "Terrassen"
	world.add_child(terraces)
	tree.root.add_child(world)
	return world


func test_some_chairs_are_taken_and_always_the_same(test) -> void:
	var world := _world(40)
	var guests: Array = world.get_node("Terrassen").guests()
	test.check(guests.size() > 10 and guests.size() < 50, "een deel van de 80 stoelen bezet (%d)" % guests.size())
	var spots: Array[Vector3] = []
	for guest: Node3D in guests:
		spots.append(guest.global_position)
	var again := _world(40)
	var guests_again: Array = again.get_node("Terrassen").guests()
	var same := guests_again.size() == guests.size()
	for index in mini(guests.size(), guests_again.size()):
		same = same and guests_again[index].global_position.is_equal_approx(spots[index])
	test.check(same, "elke keer dezelfde stoelen")
	world.free()
	again.free()


func test_a_guest_sits_on_a_chair_facing_the_table(test) -> void:
	var world := _world(40)
	var props := world.get_node("Props") as GridMap
	var guests: Array = world.get_node("Terrassen").guests()
	var right := not guests.is_empty()
	for guest: InteriorPerson in guests:
		var table := props.to_global(props.map_to_local(props.local_to_map(props.to_local(guest.global_position))))
		var from_table := Vector2(guest.global_position.x - table.x, guest.global_position.z - table.z)
		var facing := Vector2(sin(guest.rotation.y), cos(guest.rotation.y))
		right = right and is_equal_approx(from_table.length(), TerracesLayout.CHAIR_OFFSET) and facing.dot(-from_table.normalized()) > 0.99
		right = right and guest.sitting and guest.is_talkable() and guest.name.begins_with("Terrasgast")
	test.check(right, "op CHAIR_OFFSET van de tafel, ernaar toe gekeerd, zittend en aanspreekbaar")
	world.free()


func test_without_props_nobody_sits(test) -> void:
	var terraces: Node3D = Terraces.new()
	tree.root.add_child(terraces)
	test.check(terraces.guests().is_empty(), "zonder Props-kaart: niemand")
	terraces.free()
