class_name Traffic
extends Node
## The traffic of the town (the "Verkeer" node of scenes/stad.tscn): spreads `vehicle_count`
## vehicles over the road network when the game starts, at random but repeatable spots at
## least `spacing` metres apart, keeping off crossings and zebras. Each is an ordinary
## Vehicle (scripts/vehicles/) under the scene root, next to the Auto and the SUV that
## are in the scene itself. MIX says what drives: its entries take turns.

const CAR = "res://scripts/vehicles/car.gd"
const SUV = "res://scripts/vehicles/suv.gd"
const HATCHBACK = "res://scripts/vehicles/hatchback.gd"
const TRAILER_CAR = "res://scripts/vehicles/trailer_car.gd"
const VAN = "res://scripts/vehicles/van.gd"
const TRUCK = "res://scripts/vehicles/truck.gd"
const CITY_BUS = "res://scripts/vehicles/city_bus.gd"
## [script, model ("" = the one of the script)]: town traffic, so mostly cars.
const MIX := [
	[HATCHBACK, ""],
	[CAR, "voertuigen/auto_sedan_wit"],
	[VAN, ""],
	[HATCHBACK, "voertuigen/auto_hatchback_zilver"],
	[CITY_BUS, ""],
	[CAR, "voertuigen/auto_sedan_zilver"],
	[TRUCK, ""],
	[HATCHBACK, "voertuigen/auto_hatchback_groen"],
	[TRAILER_CAR, ""],
	[CAR, ""],
	[SUV, ""],
]

## Road cells a start spot must lead to.
const ROAD_CELLS_NEEDED := 60

## How many vehicles it adds to the ones in the scene.
@export var vehicle_count := 24
## Fewest metres between the start spots (a bus is 10.5 m long).
@export var spacing := 20.0
## Seed of the start spots and routes.
@export var traffic_seed := 11


func _ready() -> void:
	# the scene root is still setting up its children now
	_spawn.call_deferred()


func _spawn() -> void:
	var root := get_parent()
	var network := RoadNetwork.of(root)
	if network.is_empty():
		return
	var random := RandomNumberGenerator.new()
	random.seed = traffic_seed
	var cells: Array = network.cells()
	# a shuffle of our own: Array.shuffle() does not take a seed
	for cell_index in range(cells.size() - 1, 0, -1):
		var other_index := random.randi_range(0, cell_index)
		var kept: Vector3i = cells[cell_index]
		cells[cell_index] = cells[other_index]
		cells[other_index] = kept
	var taken: Array[Vector3] = []
	for vehicle in Vehicle.all_vehicles:
		taken.append(vehicle.global_position)
	var added := 0
	for cell: Vector3i in cells:
		if added >= vehicle_count:
			break
		var entry: Array = MIX[added % MIX.size()]
		var vehicle: Vehicle = load(entry[0]).new()
		if not _good_start(network, cell, vehicle.vehicle_kind, taken):
			vehicle.free()
			continue
		if entry[1] != "":
			vehicle.model = entry[1]
		var heading: Vector2i = network.lanes(cell)[0]
		vehicle.name = "Verkeer%d" % (added + 1)
		vehicle.start_cell = Vector2i(cell.x, cell.z)
		vehicle.start_heading = heading
		vehicle.route_seed = random.randi()
		root.add_child(vehicle)
		taken.append(network.centre(cell))
		added += 1


## True for a straight piece of ordinary road this kind may use, away from all the others.
func _good_start(network: RoadNetwork, cell: Vector3i, kind: String, taken: Array[Vector3]) -> bool:
	if cell.y != 0 or not network.allows(cell, kind) or network.is_crossing(cell) or network.is_zebra(cell):
		return false
	if network.kind(cell) == RoadNetwork.Kind.TUNNEL or network.lanes(cell).size() != 1:
		return false
	var heading: Vector2i = network.lanes(cell)[0]
	if network.step(cell, heading) == RoadNetwork.NONE or network.step(cell, -heading) == RoadNetwork.NONE:
		return false
	if not _leads_somewhere(network, cell):
		return false
	var centre := network.centre(cell)
	for spot in taken:
		if spot.distance_to(centre) < spacing:
			return false
	return true


## True if the lanes from this cell reach at least ROAD_CELLS_NEEDED cells: there are short
## bits of road that lead nowhere, where a vehicle would only turn round for ever.
func _leads_somewhere(network: RoadNetwork, cell: Vector3i) -> bool:
	var seen := {cell: true}
	var to_visit: Array[Vector3i] = [cell]
	while not to_visit.is_empty() and seen.size() < ROAD_CELLS_NEEDED:
		var current: Vector3i = to_visit.pop_back()
		for heading in network.lanes(current):
			var next_cell := network.step(current, heading)
			if next_cell != RoadNetwork.NONE and not seen.has(next_cell):
				seen[next_cell] = true
				to_visit.append(next_cell)
	return seen.size() >= ROAD_CELLS_NEEDED
