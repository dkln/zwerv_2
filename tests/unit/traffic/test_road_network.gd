extends RefCounted
## Unit tests of the road network (scripts/traffic/road_network.gd): read from a small
## hand-made ground GridMap (ground, also used by the tests of the lane arrows and the
## traffic), it answers what the vehicles ask: lanes, steps, kinds, limits, who may come
## where, rails, ramps.
##   tests/run_unit_tests.sh road_network

const RoadNetworkScript = preload("res://scripts/traffic/road_network.gd")

const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)
const EAST := Vector2i(1, 0)
const WEST := Vector2i(-1, 0)
## Quarter turns that point the lane of a tile ("N" on the unturned tile) that way.
const TO_NORTH := 0
const TO_WEST := 1
const TO_SOUTH := 2
const TO_EAST := 3

## The tiles of the hand-made ground and their "traffic" metadata (as tools/voxgen/traffic.py
## writes it); "grond/gras" and "spoor/perron" have none.
const TILE_TRAFFIC := {
	"weg/rijbaan": {"lanes": ["N"], "road": "straat"},
	"weg/asfalt": {"lanes": ["N", "S", "E", "W"]},
	"weg/zebrapad": {"lanes": ["N", "S"]},
	"weg/snelweg": {"lanes": ["N"], "road": "snelweg"},
	"weg/tunnel": {"lanes": ["N"], "road": "tunnel"},
	"weg/helling": {"lanes": ["N"], "road": "straat", "rise": 1.0},
	"weg/fietspad": {"lanes": ["N"], "road": "straat", "only": ["fiets", "brommer"], "speed": 30},
	"weg/busbaan": {"lanes": ["N"], "road": "straat", "only": ["bus"]},
	"spoor/recht": {"rails": ["SN"], "only": ["tram"]},
	"spoor/bocht": {"rails": ["SE"], "only": ["tram"]},
}
const TILE_NAMES: Array[String] = ["weg/rijbaan", "weg/asfalt", "weg/zebrapad", "weg/snelweg", "weg/tunnel", "weg/helling",
	"weg/fietspad", "weg/busbaan", "spoor/recht", "spoor/bocht", "grond/gras", "spoor/perron"]

var tree: SceneTree


## A ground GridMap (not in a tree) with the tiles of `placed`: cell -> [tile name, quarter
## turns]. `choices` and `move_overs`: the metas LANE_CHOICES and MOVE_OVERS.
static func ground(placed: Dictionary, choices := {}, move_overs := {}) -> GridMap:
	var library := MeshLibrary.new()
	for item in TILE_NAMES.size():
		library.create_item(item)
		library.set_item_name(item, TILE_NAMES[item])
	library.set_meta("traffic", TILE_TRAFFIC)
	library.set_meta("platforms", {"spoor/perron": ["tram"]})
	var gridmap := GridMap.new()
	gridmap.name = "Grond"
	gridmap.cell_size = Vector3(4.0, 1.0, 4.0)
	gridmap.mesh_library = library
	for cell: Vector3i in placed:
		var turn := gridmap.get_orthogonal_index_from_basis(Basis(Vector3.UP, int(placed[cell][1]) * PI * 0.5))
		gridmap.set_cell_item(cell, TILE_NAMES.find(placed[cell][0]), turn)
	if not choices.is_empty():
		gridmap.set_meta(RoadNetwork.LANE_CHOICES, choices)
	if not move_overs.is_empty():
		gridmap.set_meta(RoadNetwork.MOVE_OVERS, move_overs)
	return gridmap


## `length` cells of `tile` in a row from `from`, each one cell on in `heading`, the lane
## pointing that way: cell -> [tile, quarter turns], to hand to ground().
static func street(from: Vector3i, heading: Vector2i, length: int, tile := "weg/rijbaan") -> Dictionary:
	var turns: int = {NORTH: TO_NORTH, WEST: TO_WEST, SOUTH: TO_SOUTH, EAST: TO_EAST}[heading]
	var placed := {}
	for index in length:
		placed[from + Vector3i(heading.x, 0, heading.y) * index] = [tile, turns]
	return placed


## A street east along z 0 from x 0 to 6 with plain asphalt at x 2, a zebra at x 3 and a
## crossing (plain asphalt) at x 5 with a street north through it; a ramp up east at x 7 to
## the road a level higher at x 8; grass beside it.
static func town() -> Dictionary:
	var placed := street(Vector3i(0, 0, 0), EAST, 7)
	placed[Vector3i(2, 0, 0)] = ["weg/asfalt", TO_NORTH]
	placed[Vector3i(3, 0, 0)] = ["weg/zebrapad", TO_WEST]
	placed[Vector3i(5, 0, 0)] = ["weg/asfalt", TO_NORTH]
	placed.merge(street(Vector3i(5, 0, 2), NORTH, 2))
	placed.merge(street(Vector3i(5, 0, -1), NORTH, 2))
	placed[Vector3i(7, 0, 0)] = ["weg/helling", TO_EAST]
	placed[Vector3i(8, 1, 0)] = ["weg/rijbaan", TO_EAST]
	placed[Vector3i(0, 0, 1)] = ["grond/gras", TO_NORTH]
	return placed


func test_empty_without_ground(test) -> void:
	var nothing := RoadNetworkScript.new(null)
	test.check(nothing.is_empty() and not nothing.has(Vector3i.ZERO), "zonder grond: een leeg netwerk")
	test.check(nothing.cells().is_empty() and nothing.lanes(Vector3i.ZERO).is_empty(), "geen cellen, geen stroken")
	test.check(nothing.tile_name(Vector3i.ZERO) == "", "geen tegelnaam")
	var gridmap := ground({Vector3i(0, 0, 0): ["grond/gras", 0]})
	var grass := RoadNetworkScript.new(gridmap)
	test.check(grass.is_empty(), "alleen gras: geen wegen")
	test.check(grass.ground_cells() == [Vector3i(0, 0, 0)] and grass.allowed_kinds(Vector3i(0, 0, 0)) == [], "het gras is een grondcel voor niemand")
	gridmap.free()


func test_lanes_follow_the_tiles_and_the_road_around(test) -> void:
	var gridmap := ground(town())
	var network := RoadNetworkScript.new(gridmap)
	test.check(not network.is_empty() and network.has(Vector3i(0, 0, 0)) and not network.has(Vector3i(0, 0, 1)), "de straat is weg, het gras niet")
	test.check(network.cells().size() == 13, "dertien wegcellen (%d)" % network.cells().size())
	test.check(network.ground_cells().size() == 14, "veertien grondcellen, met het gras (%d)" % network.ground_cells().size())
	test.check(network.lanes(Vector3i(0, 0, 0)) == ([EAST] as Array[Vector2i]), "de strook draait met de tegel mee")
	test.check(network.lanes(Vector3i(2, 0, 0)) == ([EAST] as Array[Vector2i]), "kaal asfalt gaat met de straat mee, dwars geen strook (%s)" % str(network.lanes(Vector3i(2, 0, 0))))
	test.check(network.lanes(Vector3i(3, 0, 0)) == ([EAST] as Array[Vector2i]), "de zebra ook")
	test.check(network.lanes(Vector3i(9, 0, 9)).is_empty(), "geen weg: geen stroken")
	test.check(network.is_from_context(Vector3i(2, 0, 0), EAST) and network.is_from_context(Vector3i(3, 0, 0), WEST), "die richting komt uit de omgeving")
	test.check(not network.is_from_context(Vector3i(0, 0, 0), EAST), "die van een rijbaan van de tegel zelf")
	test.check(not network.is_from_context(Vector3i(3, 0, 0), NORTH), "de zebra heeft dwars geen open as")
	test.check(network.tile_name(Vector3i(3, 0, 0)) == "weg/zebrapad" and network.tile_name(Vector3i(9, 0, 9)) == "", "de naam van de tegel")
	test.check(network.is_zebra(Vector3i(3, 0, 0)) and not network.is_zebra(Vector3i(2, 0, 0)), "de zebra is een zebra")
	gridmap.free()


func test_crossing(test) -> void:
	var gridmap := ground(town())
	var network := RoadNetworkScript.new(gridmap)
	var crossing := Vector3i(5, 0, 0)
	var headings := network.lanes(crossing)
	test.check(headings.size() == 2 and headings.has(EAST) and headings.has(NORTH), "de kruising: beide straten, elk in zijn richting (%s)" % str(headings))
	test.check(network.is_crossing(crossing), "stroken op beide assen: een kruising")
	test.check(not network.is_crossing(Vector3i(4, 0, 0)) and not network.is_crossing(Vector3i(9, 0, 9)), "een rechte straat en een lege cel niet")
	gridmap.free()


func test_step_find_and_the_ramp(test) -> void:
	var gridmap := ground(town())
	var network := RoadNetworkScript.new(gridmap)
	test.check(network.step(Vector3i(0, 0, 0), EAST) == Vector3i(1, 0, 0), "een stap verder")
	test.check(network.step(Vector3i(0, 0, 0), WEST) == RoadNetwork.NONE, "het eind van de weg")
	test.check(network.step(Vector3i(7, 0, 0), EAST) == Vector3i(8, 1, 0), "van de helling af een laag hoger")
	test.check(network.step(Vector3i(8, 1, 0), WEST) == Vector3i(7, 0, 0), "en terug omlaag")
	test.check(network.find(8, 0, 0) == RoadNetwork.NONE, "zonder helling vindt het de hogere laag niet")
	test.check(network.find(8, 0, 0, Vector3i(7, 0, 0)) == Vector3i(8, 1, 0), "vanaf de helling wel")
	test.check(network.find(4, 0, 0) == Vector3i(4, 0, 0), "een cel op de eigen laag")
	var ramp := Vector3i(7, 0, 0)
	test.check(is_equal_approx(network.centre(ramp).y, RoadNetwork.ROAD_SURFACE + 0.5), "halverwege de helling een halve meter hoger")
	test.check(network.centre(Vector3i(1, 0, 0)) == Vector3(6.0, RoadNetwork.ROAD_SURFACE, 2.0), "het midden van een vlakke cel")
	test.check(is_equal_approx(network.height(ramp, Vector2(32.0, 2.0)), RoadNetwork.ROAD_SURFACE + 1.0), "de top van de helling")
	test.check(network.height(Vector3i(1, 0, 0), Vector2(5.0, 1.0)) == RoadNetwork.ROAD_SURFACE, "vlak: de hoogte van de laag")
	test.check(is_equal_approx(network.slope(ramp, EAST), 0.25) and is_equal_approx(network.slope(ramp, WEST), -0.25), "de helling: 1 op 4 omhoog, terug omlaag")
	test.check(network.slope(Vector3i(1, 0, 0), EAST) == 0.0, "vlak: geen helling")
	gridmap.free()


func test_kinds_and_speed_limits(test) -> void:
	var placed := street(Vector3i(0, 0, 0), EAST, 3, "weg/snelweg")
	placed[Vector3i(3, 0, 0)] = ["weg/asfalt", TO_NORTH]
	placed.merge(street(Vector3i(0, 0, 5), EAST, 3))
	placed.merge(street(Vector3i(0, -6, 9), EAST, 2, "weg/tunnel"))
	placed.merge(street(Vector3i(0, 0, 12), EAST, 2, "weg/fietspad"))
	var gridmap := ground(placed)
	var network := RoadNetworkScript.new(gridmap)
	test.check(network.kind(Vector3i(0, 0, 0)) == RoadNetwork.Kind.MOTORWAY and network.speed_limit_kmh(Vector3i(0, 0, 0)) == 100.0, "de snelweg: 100")
	test.check(network.kind(Vector3i(3, 0, 0)) == RoadNetwork.Kind.MOTORWAY and network.speed_limit_kmh(Vector3i(3, 0, 0)) == 100.0, "asfalt zonder soort neemt die van de weg waar het in ligt")
	test.check(network.kind(Vector3i(0, 0, 5)) == RoadNetwork.Kind.STREET and network.speed_limit_kmh(Vector3i(0, 0, 5)) == 50.0, "een straat: 50")
	test.check(network.kind(Vector3i(0, -6, 9)) == RoadNetwork.Kind.TUNNEL and network.speed_limit_kmh(Vector3i(0, -6, 9)) == 80.0, "de tunnel: 80")
	test.check(network.speed_limit_kmh(Vector3i(0, 0, 12)) == 30.0, "het fietspad heeft zijn eigen limiet")
	test.check(is_equal_approx(network.speed_limit(Vector3i(0, 0, 5)), 50.0 / 3.6), "in m/s")
	test.check(network.kind(Vector3i(9, 0, 9)) == RoadNetwork.Kind.STREET and network.speed_limit_kmh(Vector3i(9, 0, 9)) == 50.0, "naast de weg: een straat, 50")
	test.check(not network.has_chosen_speed(Vector3i(0, 0, 12)), "niet gekozen in de editor")
	gridmap.free()


func test_who_may_come_where(test) -> void:
	var placed := street(Vector3i(0, 0, 0), EAST, 3)
	placed.merge(street(Vector3i(0, 0, 3), EAST, 3, "weg/fietspad"))
	placed.merge(street(Vector3i(0, 0, 6), EAST, 3, "weg/busbaan"))
	placed.merge(street(Vector3i(4, -6, 0), EAST, 3, "weg/tunnel"))
	var gridmap := ground(placed)
	var network := RoadNetworkScript.new(gridmap)
	var road := Vector3i(1, 0, 0)
	var cycle_path := Vector3i(1, 0, 3)
	var bus_lane := Vector3i(1, 0, 6)
	test.check(network.allowed_kinds(road) == RoadNetwork.ROAD_USER_KINDS, "een gewone weg: alle weggebruikers")
	test.check(network.allowed_kinds(cycle_path) == ["fiets", "brommer"], "het fietspad: fietsen en brommers")
	test.check(network.allowed_kinds(Vector3i(9, 0, 9)) == [], "geen tegel: niemand")
	test.check(network.allows(road, "auto") and network.allows(road, "bus") and network.allows(road, "fiets"), "auto, bus en fiets op de weg")
	test.check(network.allows(cycle_path, "fiets") and not network.allows(cycle_path, "auto") and not network.allows(cycle_path, "bus"), "geen auto of bus op het fietspad")
	test.check(network.allows(bus_lane, "bus") and not network.allows(bus_lane, "auto"), "de busbaan: alleen de bus")
	test.check(not network.has_chosen_kinds(road), "niet gekozen in de editor")
	test.check(network.nearest(Vector2i(1, 4), EAST) == Vector3i(1, 0, 0), "de dichtstbijzijnde strook voor een auto: de weg, niet het fietspad ernaast")
	test.check(network.nearest(Vector2i(1, 4), EAST, "fiets") == Vector3i(1, 0, 3), "voor een fiets het fietspad")
	test.check(network.nearest(Vector2i(5, 0), EAST) == Vector3i(2, 0, 0), "straatniveau gaat voor de tunnel eronder")
	test.check(network.nearest(Vector2i(1, 4), NORTH) == RoadNetwork.NONE, "geen strook die kant op")
	gridmap.free()


func test_choices_of_a_placed_tile(test) -> void:
	var chosen_cell := Vector3i(1, 0, 0)
	var other_tile := Vector3i(2, 0, 0)
	var choices := {
		chosen_cell: {"tile": "weg/rijbaan", "lanes": ["S"], "kinds": ["fiets"], "speed": 15},
		other_tile: {"tile": "weg/zebrapad", "lanes": ["S"], "kinds": [], "speed": 15},
	}
	var gridmap := ground(street(Vector3i(0, 0, 0), EAST, 4), choices)
	var network := RoadNetworkScript.new(gridmap)
	test.check(network.lanes(chosen_cell) == ([WEST] as Array[Vector2i]), "de gekozen strook (achteruit), meegedraaid met de tegel")
	test.check(network.is_chosen(chosen_cell) and network.has_chosen_kinds(chosen_cell) and network.has_chosen_speed(chosen_cell), "stroken, weggebruikers en limiet gekozen")
	test.check(network.allowed_kinds(chosen_cell) == ["fiets"] and network.speed_limit_kmh(chosen_cell) == 15.0, "en ze gelden")
	test.check(not network.is_from_context(chosen_cell, WEST), "een gekozen strook komt niet uit de omgeving")
	test.check(network.lanes(other_tile) == ([EAST] as Array[Vector2i]) and not network.is_chosen(other_tile), "een keuze voor een andere tegel telt niet")
	test.check(not network.has_chosen_kinds(other_tile) and not network.has_chosen_speed(other_tile) and network.speed_limit_kmh(other_tile) == 50.0, "ook niet zijn weggebruikers en limiet")
	gridmap.free()


func test_move_overs(test) -> void:
	var placed := street(Vector3i(0, 0, 0), EAST, 4, "weg/snelweg")
	placed.merge(street(Vector3i(0, 0, 1), EAST, 4, "weg/snelweg"))
	var move_overs := {Vector3i(0, 0, 0): Vector3i(2, 0, 1), Vector3i(1, 0, 0): Vector3i(9, 0, 9), Vector3i(7, 0, 7): Vector3i(2, 0, 1)}
	var gridmap := ground(placed, {}, move_overs)
	var network := RoadNetworkScript.new(gridmap)
	test.check(network.move_over_target(Vector3i(0, 0, 0)) == Vector3i(2, 0, 1), "vanaf deze cel kan het opschuiven")
	test.check(network.move_over_target(Vector3i(1, 0, 0)) == RoadNetwork.NONE, "naar een cel zonder weg: niet")
	test.check(network.move_over_target(Vector3i(7, 0, 7)) == RoadNetwork.NONE, "vanaf een cel zonder weg: niet")
	test.check(network.move_over_target(Vector3i(3, 0, 0)) == RoadNetwork.NONE, "niets opgegeven: niet")
	gridmap.free()


func test_rails_and_platforms(test) -> void:
	var placed := {
		Vector3i(0, 0, 0): ["spoor/recht", TO_NORTH],
		Vector3i(0, 0, -1): ["spoor/bocht", TO_NORTH],
		Vector3i(1, 0, 0): ["spoor/perron", TO_NORTH],
		Vector3i(3, 0, 0): ["weg/rijbaan", TO_NORTH],
	}
	var gridmap := ground(placed)
	var network := RoadNetworkScript.new(gridmap)
	var straight := Vector3i(0, 0, 0)
	var bend := Vector3i(0, 0, -1)
	test.check(network.rail_cells().size() == 2 and network.rail_cells().has(straight) and network.rail_cells().has(bend), "de twee spoortegels")
	test.check(not network.has(straight), "spoor is geen wegcel")
	test.check(network.rails(straight) == [[SOUTH, NORTH]] and network.rails(Vector3i(3, 0, 0)) == [], "de rails van een cel (%s)" % str(network.rails(straight)))
	test.check(network.rail_headings(straight) == ([SOUTH, NORTH] as Array[Vector2i]), "recht spoor: naar zuid en noord")
	test.check(network.rail_headings(bend) == ([SOUTH, EAST] as Array[Vector2i]), "de bocht: naar zuid en oost")
	test.check(network.rail_headings(Vector3i(3, 0, 0)).is_empty(), "een weg heeft geen rails")
	test.check(network.rail_connects(straight, NORTH, NORTH) and not network.rail_connects(straight, NORTH, EAST), "recht spoor gaat rechtdoor")
	test.check(network.rail_connects(bend, NORTH, EAST) and not network.rail_connects(bend, NORTH, NORTH), "de bocht buigt af")
	test.check(network.rail_connects(Vector3i(3, 0, 0), NORTH, WEST), "een tegel zonder rails houdt niemand tegen")
	test.check(network.allows(straight, "tram") and not network.allows(straight, "auto"), "alleen de tram op het spoor")
	test.check(network.is_platform_for(Vector3i(1, 0, 0), "tram"), "het perron is een halte voor de tram")
	test.check(not network.is_platform_for(Vector3i(1, 0, 0), "trein") and not network.is_platform_for(straight, "tram"), "niet voor de trein, en het spoor is geen perron")
	test.check(not network.is_platform_for(Vector3i(9, 0, 9), "tram"), "een lege cel is geen perron")
	gridmap.free()


func test_heading_of_side(test) -> void:
	var gridmap := ground({Vector3i(0, 0, 0): ["weg/rijbaan", TO_NORTH], Vector3i(1, 0, 0): ["weg/rijbaan", TO_EAST]})
	var network := RoadNetworkScript.new(gridmap)
	test.check(network.heading_of_side(Vector3i(0, 0, 0), "N") == NORTH and network.heading_of_side(Vector3i(0, 0, 0), "E") == EAST, "niet gedraaid: N is noord")
	test.check(network.heading_of_side(Vector3i(1, 0, 0), "N") == EAST and network.heading_of_side(Vector3i(1, 0, 0), "E") == SOUTH, "gedraaid: de kanten draaien mee")
	gridmap.free()


func test_of_gives_one_network_per_scene(test) -> void:
	var root := Node3D.new()
	root.add_child(ground(street(Vector3i(0, 0, 0), EAST, 3)))
	tree.root.add_child(root)
	var network := RoadNetwork.of(root)
	test.check(network.cells().size() == 3, "het netwerk van de Grond van de scène")
	test.check(RoadNetwork.of(root) == network, "de tweede keer hetzelfde netwerk")
	var bare := Node3D.new()
	tree.root.add_child(bare)
	test.check(RoadNetwork.of(bare).is_empty(), "een scène zonder Grond: een leeg netwerk")
	var known := RoadNetwork._networks.size()
	root.free()
	bare.free()
	test.check(RoadNetwork._networks.size() == known - 2, "weg met de scène: het netwerk wordt vergeten")
