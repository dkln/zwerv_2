extends RefCounted
## Unit tests of what hangs on the walls of the interiors (scripts/world/interiors/wall_mount.gd):
## the name and the emblem of both supermarket chains, the paintings and the coat of arms of
## the city hall stand just before the wall's inner surface (no face in the plane of the wall,
## which flickers), and not in the wall.

const WallMount = preload("res://scripts/world/interiors/wall_mount.gd")
const SupermarketLayout = preload("res://scripts/world/interiors/supermarket_layout.gd")
const CityHallLayout = preload("res://scripts/world/interiors/city_hall_layout.gd")
const LIBRARY := "res://assets/libraries/binnen.res"
## How far before the wall's inner surface the back of a wall tile may stand (metres).
const MOST_GAP := 0.05


## Every wall tile of the plans [library item, at, turn]: both chains, every city hall floor.
static func _wall_tiles() -> Array:
	var found := []
	for brand in ["derrek", "alfred_steyhn"]:
		for entry: Array in SupermarketLayout.plan(brand, 0, 6).wall_tiles:
			found.append(["supermarkt/" + String(entry[0]), entry[1], entry[2]])
	for plan: Dictionary in CityHallLayout.floors():
		for entry: Array in plan.wall_tiles:
			found.append(["stadhuis/" + String(entry[0]), entry[1], entry[2]])
	return found


## The back of each wall tile, put up by WallMount, is between 0 and MOST_GAP before the
## wall's inner surface.
func test_wall_tiles_stand_just_before_the_wall(test) -> void:
	var library: MeshLibrary = load(LIBRARY)
	var entries := _wall_tiles()
	test.check(entries.size() >= 6, "naam, embleem, schilderijen en wapen aan de muur (%d)" % entries.size())
	for entry: Array in entries:
		var parent := Node3D.new()
		test.tree.root.add_child(parent)
		test.check(WallMount.put(parent, library, String(entry[0]), entry[1], float(entry[2])), "tile %s bestaat" % entry[0])
		var into_room := Basis(Vector3.UP, float(entry[2])) * Vector3(0.0, 0.0, 1.0)
		var surface := (entry[1] as Vector3).dot(into_room) + WallMount.WALL_HALF_DEPTH
		for grid: GridMap in parent.get_children():
			for cell in grid.get_used_cells():
				var item := grid.get_cell_item(cell)
				var placed := Transform3D(grid.get_cell_item_basis(cell), grid.map_to_local(cell))
				var box: AABB = grid.transform * placed * library.get_item_mesh_transform(item) * library.get_item_mesh(item).get_aabb()
				# the side of the box towards the wall, along the way into the room
				var back := minf(box.position.dot(into_room), box.end.dot(into_room))
				test.check(back > surface + 0.001 and back < surface + MOST_GAP,
					"%s staat net voor de muur (achterkant %.3f m voor het oppervlak)" % [entry[0], back - surface])
		parent.free()
