class_name Pedestrians
extends Node3D
## The pedestrians of the town (the node "Voetgangers" of scenes/stad.tscn): `count`
## townspeople (Pedestrian, each a TownsfolkFigure with a look of its own) walking round
## the pavements and squares near the player, crossing the road at the zebras.
## The walk: over the cells of the ground layer (4 m) whose tile is pavement or square
## (WALK_GROUND) with no building on them, from cell to cell (_links), and over a zebra
## crossing (RoadNetwork.is_zebra) straight across the road, at right angles to its lanes,
## from the pavement on one side to the other.
## A set round the player, not the whole town: they are spread at the start within `reach`
## metres of the player; one that ends up further away becomes someone else (Pedestrian.become)
## on a cell between `return_near` and `reach` metres from it, out of sight, so there are
## always people around the player and none walk where no one sees. Each goes after a while
## too (`renew_after` seconds, once out of sight and over `renew_beyond` metres from the
## player) and someone else comes, so the people round you keep changing.
## How many and who (Crowd, data/drukte.json): `count` times the share of the hour of the day
## (the Dagcyclus) and of the neighbourhood the player is in (busy round Centraal and in the
## centre, quiet in the parks and the Binckhorst), at most `most`; each newcomer is a kind of
## person of that hour and of the neighbourhood where it appears (commuters and business people
## with briefcases in the rush hours, shoppers, the elderly and tourists by day, people going
## out in the evening, night owls at night), dressed as that kind, at its pace, some of them in
## a wheelchair or on a mobility scooter, carrying what that kind carries (CarriedItems). Who
## is not needed waits out of the tree (`_resting`) until more are wanted. Inside an
## interior (Binnenruimtes) it all stands still.
## The zebras: a pedestrian about to cross or crossing claims the zebra cells
## (claim_zebra); a vehicle stops before a zebra someone claims (Vehicle._someone_crossing)
## and, once it has waited there, drives on unless someone is on it (someone_on_zebra).
## At an intersection with pedestrian lights (Verkeerslichten, walk_light) they wait at the
## kerb for green without claiming the zebra (the traffic with green drives on) and claim it
## once they cross (a vehicle turning in then waits for them).

const PedestrianScript = preload("res://scripts/world/pedestrian.gd")
const Crowd = preload("res://scripts/world/crowd.gd")
const Sight = preload("res://scripts/world/sight.gd")
## Ground tile folders people walk on.
const WALK_GROUND := ["stoep/", "plein/"]

## How many walk at a share of 1.0 (Crowd.pedestrian_share), the fewest and the most there are.
@export var count := 60
@export var fewest := 6
@export var most := 84
@export var reach := 110.0
@export var return_near := 50.0
## Seconds someone stays (drawn between the two) before it goes once unseen and over
## `renew_beyond` metres from the player; how many come or go each second at most (more after
## a jump of the player: a warp, a load).
@export var renew_after := Vector2(45.0, 110.0)
@export var renew_beyond := 30.0
@export var changes_per_second := 3
@export var interiors_path := NodePath("../Binnenruimtes")
## Without a camera everything counts as seen (nothing is sent off for being old or far);
## true lets a tool test the coming and going without one.
@export var unseen_without_camera := false
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
var _people: Array[Pedestrian] = []        # who walks the town now (Pedestrian._all holds this same array)
var _resting: Array[Pedestrian] = []       # who is not needed now, out of the tree
var _leaves_at := {}                       # person -> _clock when it may go
var _ride_debt := {}                       # "kind/aid" -> share of a rider owed (Crowd.ride_share)
var _made := 0
var _clock := 0.0
var _last_player_spot := Vector3.INF
var _spread := false
var _return_clock := 0.0
var _interiors: Node
var _ring: Array[Vector3i] = []            # walkable cells in the ring round the player (_find_ring)
var _ring_around := Vector3.INF


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_ground = get_node_or_null(ground_path) as GridMap
	_buildings = get_node_or_null(buildings_path) as GridMap
	_lights = get_node_or_null(lights_path)
	_random.seed = pedestrian_seed
	_interiors = get_node_or_null(interiors_path)
	tree_exiting.connect(func() -> void: _zebra_claims.clear())


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# who rests is out of the tree: it goes with this node
		for person in _resting:
			if is_instance_valid(person):
				person.free()
		_resting.clear()


func _physics_process(delta: float) -> void:
	if _ground == null or _ground.mesh_library == null:
		return
	if not _spread:
		if _player == null or _player.get("_placed") != false:
			_spread_people()
		return
	_clock += delta
	_return_clock -= delta
	if _return_clock <= 0.0 and _player:
		_return_clock = 1.0
		_keep_round_player()


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


## Who walks the town now (for the tests).
func people() -> Array[Pedestrian]:
	return _people


## How many there should be now round the player (Crowd: the hour and the neighbourhood).
func wanted_count() -> int:
	var world := get_parent()
	var around := _player.global_position if _player else Vector3.ZERO
	var share := Crowd.pedestrian_share(Crowd.hour_of(world), Crowd.area_at(world, around))
	return clampi(roundi(count * share), mini(fewest, most), most)


## Who goes and who comes, once a second (see the top).
func _keep_round_player() -> void:
	if _walkable_cells.is_empty() or (_interiors and _interiors.has_method("is_inside") and _interiors.is_inside()):
		return
	var player_spot := _player.global_position
	var jumped := _last_player_spot != Vector3.INF and _last_player_spot.distance_to(player_spot) > return_near
	_last_player_spot = player_spot
	var changes_left := 1000 if jumped else changes_per_second
	var wanted := wanted_count()
	_find_ring(player_spot)
	for person: Pedestrian in _people.duplicate():
		if person._ragdoll:
			continue
		var distance := person.global_position.distance_to(player_spot)
		if distance > reach:
			# wandered off: someone else near the player (always, else the town round you empties)
			_go_or_renew(person, wanted)
		elif changes_left > 0 and _clock >= float(_leaves_at.get(person, 0.0)) and distance > renew_beyond \
				and _unseen(person.global_position):
			_go_or_renew(person, wanted)
			changes_left -= 1
	var failures := 0
	while _people.size() < wanted and changes_left > 0 and failures < 8:
		if _bring_someone():
			changes_left -= 1
		else:
			failures += 1
	while _people.size() > wanted and changes_left > 0:
		var leaving := _someone_to_send_off(player_spot)
		if leaving == null:
			break
		_rest(leaving)
		changes_left -= 1


## `person` goes (there are more than `wanted`) or becomes someone else near the player.
func _go_or_renew(person: Pedestrian, wanted: int) -> void:
	if _people.size() > wanted:
		_rest(person)
		return
	_dress_for_now(person, true)
	if not bring_back(person):
		_rest(person)


## Starts `person` afresh as someone else, away from the player (one whose health ran out).
func start_again(person: Pedestrian) -> void:
	_dress_for_now(person, true)
	bring_back(person)


## Someone more round the player: one who rested, or a new one (up to `most`), out of sight in
## the ring round the player; false if there is no spot.
func _bring_someone() -> bool:
	var cell := _ring_cell()
	if cell == RoadNetwork.NONE:
		return false
	if not _resting.is_empty():
		var person: Pedestrian = _resting.pop_back()
		_dress_for_now(person, true, cell_middle(cell))
		add_child(person)
		_people.append(person)
		if not person.restart_at(cell) and not bring_back(person):
			_rest(person)
			return false
		return true
	if _people.size() + _resting.size() >= most:
		return false
	_add_person(cell)
	return true


## A new pedestrian on `cell`, of the hour and the neighbourhood there.
func _add_person(cell: Vector3i) -> Pedestrian:
	var person: Pedestrian = PedestrianScript.new()
	_made += 1
	person.name = "Voetganger%d" % _made
	person.town = self
	_dress_for_now(person, false, cell_middle(cell))
	person.start_cell = cell
	add_child(person)
	_people.append(person)
	return person


## Out of the town until it is wanted again (out of the tree: not drawn, not stepped, no
## collider, off the zebras).
func _rest(person: Pedestrian) -> void:
	_people.erase(person)
	_leaves_at.erase(person)
	Pedestrians.claim_zebra(person, [], false)
	remove_child(person)
	_resting.append(person)


## The one to send off when there are too many: unseen, not near the player, the furthest.
func _someone_to_send_off(player_spot: Vector3) -> Pedestrian:
	var furthest: Pedestrian = null
	var furthest_distance := renew_beyond
	for person in _people:
		var distance := person.global_position.distance_to(player_spot)
		if person._ragdoll == null and distance > furthest_distance and _unseen(person.global_position):
			furthest = person
			furthest_distance = distance
	return furthest


## Who `person` is (now, or once it comes): a kind of person of this hour and of the
## neighbourhood of `spot` (Crowd), its look, pace, aid and what it carries. `rebuild`: it is
## built already and becomes someone else (Pedestrian.become).
func _dress_for_now(person: Pedestrian, rebuild: bool, spot := Vector3.INF) -> void:
	var world := get_parent()
	if spot == Vector3.INF:
		spot = _player.global_position if _player else person.global_position
	var kind := Crowd.person_kind(Crowd.hour_of(world), Crowd.area_at(world, spot), _random)
	var look_seed := _random.randi()
	var look := Crowd.look_for(kind, look_seed) if kind != "" else {}
	var aid := _aid_for(kind)
	var item := Crowd.carried_for(kind, _random) if aid == "" else ""
	var pace := Crowd.pace_of(kind)
	_leaves_at[person] = _clock + _random.randf_range(renew_after.x, renew_after.y)
	if rebuild:
		person.become(look_seed, look, aid, pace, item, kind)
	else:
		person.walker_seed = look_seed
		person.wanted_look = look
		person.mobility = aid
		person.pace_factor = pace
		person.carried = item
		person.crowd_kind = kind


## Whether the next person of `kind` rides: each kind owes its share of riders (Crowd.ride_share)
## and pays a rider out once it owes a whole one, so the shares come out even, not by luck.
func _aid_for(kind: String) -> String:
	for aid: String in ["rolstoel", "scootmobiel"]:
		var debt_key := kind + "/" + aid
		var debt := float(_ride_debt.get(debt_key, 0.0)) + Crowd.ride_share(kind, aid)
		if debt >= 1.0:
			_ride_debt[debt_key] = debt - 1.0
			return aid
		_ride_debt[debt_key] = debt
	return ""


## The walkable cells between `return_near` and `reach` metres from `spot` (the player), for
## _ring_cell (once a tick: the player hardly moves in a second).
func _find_ring(spot: Vector3) -> void:
	_ring.clear()
	_ring_around = spot
	for cell in _walkable_cells:
		var distance := cell_middle(cell).distance_to(spot)
		if distance >= return_near and distance <= reach:
			_ring.append(cell)


## A walkable cell between `return_near` and `reach` metres from the player, unseen (or, after
## many tries, any in that ring); NONE without one.
func _ring_cell() -> Vector3i:
	if _player == null or _walkable_cells.is_empty():
		return RoadNetwork.NONE
	if _ring.is_empty() or _ring_around.distance_to(_player.global_position) > 10.0:
		_find_ring(_player.global_position)
	if _ring.is_empty():
		return RoadNetwork.NONE
	var any_cell: Vector3i = _ring[_random.randi() % _ring.size()]
	for attempt in 30:
		var cell: Vector3i = _ring[_random.randi() % _ring.size()]
		if _unseen(cell_middle(cell)):
			return cell
	return any_cell


## True if `spot` is out of sight of the camera (Sight: off the screen); false without a camera
## (the tools: then no one is sent off for being old, only for being far).
func _unseen(spot: Vector3) -> bool:
	var viewport := get_viewport()
	if viewport == null or viewport.get_camera_3d() == null:
		return unseen_without_camera
	return Sight.steps_between(viewport, spot) > 1




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
	for index in wanted_count():
		var cell: Vector3i = near[_random.randi() % near.size()]
		# not right on top of the player at the start
		for attempt in 8:
			if _player == null or cell_middle(cell).distance_to(_player.global_position) > 6.0:
				break
			cell = near[_random.randi() % near.size()]
		_add_person(cell)
	_last_player_spot = _player.global_position if _player else Vector3.INF


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


## Puts `person` down afresh between return_near and reach from the player, out of sight when
## it can (a pedestrian that wandered off, or one run over that starts again as someone
## else); false if no spot.
func bring_back(person: Pedestrian) -> bool:
	if _player == null or _walkable_cells.is_empty():
		return false
	for attempt in 6:
		var cell := _ring_cell()
		if cell == RoadNetwork.NONE:
			return false
		if person.restart_at(cell):
			return true
	return false
