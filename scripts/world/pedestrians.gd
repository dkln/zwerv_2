class_name Pedestrians
extends Node3D
## The pedestrians of the town (the node "Voetgangers" of scenes/stad.tscn): `count`
## townspeople (Pedestrian, each a TownsfolkFigure with a look of its own) walking round
## the pavements and squares near the player, crossing the road at the zebras.
## The walk: over the cells of the ground layer (4 m) whose tile is pavement or square
## (WALK_GROUND) with no building on them, from cell to cell (_links), and over a zebra
## crossing (RoadNetwork.is_zebra) straight across the road, at right angles to its lanes,
## from the pavement on one side to the other.
## They are spread at the start within `reach` metres of the player; one that ends up
## further away comes back on a cell between `return_near` and `reach` metres from it, out of
## sight, so there are always people around the player and none walk where no one sees.
## The zebras: a pedestrian about to cross or crossing claims the zebra cells
## (claim_zebra); a vehicle stops before a zebra someone claims (Vehicle._someone_crossing)
## and, once it has waited there, drives on unless someone is on it (someone_on_zebra).
## At an intersection with pedestrian lights (Verkeerslichten, walk_light) they wait at the
## kerb for green without claiming the zebra (the traffic with green drives on) and claim it
## once they cross (a vehicle turning in then waits for them).

const PedestrianScript = preload("res://scripts/world/pedestrian.gd")
## Ground tile folders people walk on.
const WALK_GROUND := ["stoep/", "plein/"]

@export var count := 64
## Of every `mobility_every` people one rides a wheelchair and one a mobility scooter
## (Pedestrian `mobility`).
@export var mobility_every := 9
@export var reach := 110.0
@export var return_near := 50.0
@export var pedestrian_seed := 5
@export var player_path := NodePath("../Speler")
@export var ground_path := NodePath("../Grond")
@export var buildings_path := NodePath("../Gebouwen")
@export var lights_path := NodePath("../Verkeerslichten")
@export var props_path := NodePath("../Props")

## zebra cell -> {pedestrian instance id: true (on it) / false (waiting to cross)}
static var _zebra_claims := {}

var network: RoadNetwork
var _walkable := {}          # cell -> true: pavement and square cells
var _walkable_cells: Array[Vector3i] = []
var _links := {}             # cell -> Array[Vector3i] of the cells one can walk on to
var _ride := {}              # cell -> true: bicycle paths (only for mobility scooters)
var _player: Node3D
var _ground: GridMap
var _buildings: GridMap
var _lights: Node
var _random := RandomNumberGenerator.new()
var _people: Array[Pedestrian] = []
var _spread := false
var _return_clock := 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_ground = get_node_or_null(ground_path) as GridMap
	_buildings = get_node_or_null(buildings_path) as GridMap
	_lights = get_node_or_null(lights_path)
	_random.seed = pedestrian_seed
	tree_exiting.connect(func() -> void: _zebra_claims.clear())


func _physics_process(delta: float) -> void:
	if _ground == null or _ground.mesh_library == null:
		return
	if not _spread:
		if _player == null or _player.get("_placed") != false:
			_spread_people()
		return
	_return_clock -= delta
	if _return_clock <= 0.0 and _player:
		_return_clock = 1.0
		for person in _people:
			if person.global_position.distance_to(_player.global_position) > reach:
				bring_back(person)


## True if someone is waiting to cross or crossing at this zebra cell.
static func someone_at_zebra(cell: Vector3i) -> bool:
	return not (_zebra_claims.get(cell, {}) as Dictionary).is_empty()


## True if someone is on this zebra cell (or crossing over the zebra it is part of).
static func someone_on_zebra(cell: Vector3i) -> bool:
	for on: bool in (_zebra_claims.get(cell, {}) as Dictionary).values():
		if on:
			return true
	return false


## `who` waits at (on = false) or is on (on = true) these zebra cells; an empty list lets
## go of all of its claims.
static func claim_zebra(who: Object, cells: Array[Vector3i], on: bool) -> void:
	var key := who.get_instance_id()
	for cell: Vector3i in _zebra_claims.keys():
		(_zebra_claims[cell] as Dictionary).erase(key)
		if (_zebra_claims[cell] as Dictionary).is_empty():
			_zebra_claims.erase(cell)
	for cell in cells:
		if not _zebra_claims.has(cell):
			_zebra_claims[cell] = {}
		_zebra_claims[cell][key] = on


func is_walkable(cell: Vector3i) -> bool:
	return _walkable.has(cell)


func links(cell: Vector3i) -> Array:
	return _links.get(cell, [])


func is_zebra(cell: Vector3i) -> bool:
	return network != null and network.is_zebra(cell)


## The pedestrian light for crossing the zebra `cell` in direction `side`: 0 green, 1 red,
## -1 no pedestrian lights there (a plain zebra: the people on foot go first).
func walk_light(cell: Vector3i, side: Vector3i) -> int:
	if _lights == null or not _lights.has_method("pedestrian_phase"):
		return -1
	return _lights.pedestrian_phase(cell_middle(cell), side.z != 0)


## A cell to start on within `reach` of the player (any walkable cell without a player).
func start_cell() -> Vector3i:
	for attempt in 20:
		var cell: Vector3i = _walkable_cells[_random.randi() % _walkable_cells.size()]
		if _player == null or cell_middle(cell).distance_to(_player.global_position) <= reach:
			return cell
	return _walkable_cells[_random.randi() % _walkable_cells.size()]


## True if someone going about as `mobility` (Pedestrian) may go onto `cell`: pavements,
## squares and zebras for all, the bicycle paths also for a mobility scooter.
func may_use(cell: Vector3i, mobility: String) -> bool:
	return _walkable.has(cell) or is_zebra(cell) or (mobility == "scootmobiel" and _ride.has(cell))


## The props library (for the wheels of wheelchairs and scooters), or null.
func props_library() -> MeshLibrary:
	var props := get_node_or_null(props_path) as GridMap
	return props.mesh_library if props else null


## The middle of a cell (metres, at the height of the ground layer it is on).
func cell_middle(cell: Vector3i) -> Vector3:
	return _ground.to_global(_ground.map_to_local(cell))


func cell_of(spot: Vector3) -> Vector3i:
	var local := _ground.local_to_map(_ground.to_local(spot))
	return Vector3i(local.x, 0, local.z)


## How many walk the town now (for the tests).
func people() -> Array[Pedestrian]:
	return _people


func _spread_people() -> void:
	_spread = true
	network = RoadNetwork.of(get_parent())
	_find_walkable()
	if _walkable_cells.is_empty():
		return
	var around := _player.global_position if _player else cell_middle(_walkable_cells[0])
	var near: Array[Vector3i] = []
	for cell in _walkable_cells:
		if cell_middle(cell).distance_to(around) <= reach:
			near.append(cell)
	if near.is_empty():
		near = _walkable_cells
	for index in count:
		var person: Pedestrian = PedestrianScript.new()
		person.name = "Voetganger%d" % (index + 1)
		person.walker_seed = _random.randi()
		person.town = self
		if index % mobility_every == mobility_every - 1:
			person.mobility = "scootmobiel"
		elif index % mobility_every == mobility_every / 2:
			person.mobility = "rolstoel"
		var cell: Vector3i = near[_random.randi() % near.size()]
		# not right on top of the player at the start
		for attempt in 8:
			if _player == null or cell_middle(cell).distance_to(_player.global_position) > 6.0:
				break
			cell = near[_random.randi() % near.size()]
		person.start_cell = cell
		add_child(person)
		_people.append(person)


## The pavement and square cells and the ways between them, the zebras included.
func _find_walkable() -> void:
	var library := _ground.mesh_library
	for cell in _ground.get_used_cells():
		if cell.y != 0:
			continue
		var item_name := library.get_item_name(_ground.get_cell_item(cell))
		if not WALK_GROUND.any(func(folder: String) -> bool: return item_name.begins_with(folder)):
			continue
		if _buildings and (_buildings.get_cell_item(Vector3i(cell.x, 0, cell.z)) != GridMap.INVALID_CELL_ITEM
				or _buildings.get_cell_item(Vector3i(cell.x, 1, cell.z)) != GridMap.INVALID_CELL_ITEM):
			continue
		_walkable[cell] = true
		_walkable_cells.append(cell)
	var sides: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	# the bicycle paths (bicycles allowed, cars not), for the mobility scooters
	for road_cell in network.ground_cells():
		var allowed := network.allowed_kinds(road_cell)
		if road_cell.y == 0 and "fiets" in allowed and not "auto" in allowed and not is_zebra(road_cell):
			_ride[Vector3i(road_cell.x, 0, road_cell.z)] = true
	for cell: Vector3i in _ride:
		var ways: Array[Vector3i] = []
		for side in sides:
			if _walkable.has(cell + side) or _ride.has(cell + side):
				ways.append(cell + side)
		_links[cell] = ways
	for cell in _walkable_cells:
		var ways: Array[Vector3i] = []
		for side in sides:
			var next := cell + side
			if _walkable.has(next) or _ride.has(next):
				ways.append(next)
			elif _crosses(next, side):
				ways.append(next)
		_links[cell] = ways
	# the zebra cells link across the road (at right angles to its lanes)
	for cell: Vector3i in _links.keys().duplicate():
		for next: Vector3i in _links[cell]:
			if is_zebra(next) and not _links.has(next):
				_link_zebra(next, next - cell)


## True if from a pavement cell a zebra in this direction leads across the road to
## pavement on the other side.
func _crosses(cell: Vector3i, side: Vector3i) -> bool:
	var steps := 0
	var spot := cell
	while is_zebra(spot) and steps < 6:
		if not _across_lanes(spot, side):
			return false
		spot += side
		steps += 1
	return steps > 0 and _walkable.has(spot)


## True if walking in direction `side` over this road cell crosses its lanes.
func _across_lanes(cell: Vector3i, side: Vector3i) -> bool:
	var lanes := network.lanes(cell)
	if lanes.is_empty():
		return true
	for heading in lanes:
		if heading.x * side.x + heading.y * side.z != 0:
			return false
	return true


func _link_zebra(cell: Vector3i, side: Vector3i) -> void:
	var spot := cell
	while is_zebra(spot):
		var ways: Array[Vector3i] = []
		for next in [spot + side, spot - side]:
			if is_zebra(next) or _walkable.has(next):
				ways.append(next)
		_links[spot] = ways
		spot += side


## Every zebra cell of the crossing `cell` lies on, going in direction `side`.
func zebra_run(cell: Vector3i, side: Vector3i) -> Array[Vector3i]:
	var run: Array[Vector3i] = []
	var spot := cell
	while is_zebra(spot) and run.size() < 8:
		run.append(spot)
		spot += side
	return run


## Puts `person` down afresh between return_near and reach from the player (a pedestrian
## that wandered off, or one run over that starts again as someone else); false if no spot.
func bring_back(person: Pedestrian) -> bool:
	if _player == null or _walkable_cells.is_empty():
		return false
	for attempt in 40:
		var cell: Vector3i = _walkable_cells[_random.randi() % _walkable_cells.size()]
		var distance := cell_middle(cell).distance_to(_player.global_position)
		if distance >= return_near and distance <= reach and person.restart_at(cell):
			return true
	return false
