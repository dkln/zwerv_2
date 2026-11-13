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
## Going somewhere (route_to_somewhere): most of the time someone on foot is on the way to a
## place a few blocks off (a walkable cell DESTINATION_CELLS away, picked at random), along
## the shortest way over the pavements, the zebras and the stairs (an AStar3D over _links,
## _find_routes), so they walk on from block to block and cross the roads on purpose; there
## they pick the next. Now and then (Pedestrian.WANDER_CHANCE) they just wander.
## The zebras: a pedestrian about to cross or crossing claims the zebra cells
## (claim_zebra); a vehicle stops before a zebra someone claims (Vehicle._someone_crossing)
## and, once it has waited there, drives on unless someone is on it (someone_on_zebra).
## At an intersection with pedestrian lights (Verkeerslichten, walk_light) they wait at the
## kerb for green without claiming the zebra (the traffic with green drives on) and claim it
## once they cross (a vehicle turning in then waits for them).
## Den Haag Centraal (the station's ways in, Interiors.ways_in of kind STATION_KIND): near it
## people come out of its doors and go into them, most in the rush hours (the hour's
## "station" share, data/drukte.json). Within STATION_REACH metres of a door a newcomer comes
## out of a door (that share times STATION_OUT_SHARE of them, seen or not: they come from the
## station), and someone within STATION_PULL_STEPS cells' walk of a door now and then sets off
## for it (STATION_PULL_PER_SECOND times that share), walks there cell by cell (each step one
## nearer, _station_steps) and is gone through the door (into_station): freed, not kept
## resting (someone else comes instead). A way between two cells found blocked on the way
## there (a fence, a bike rack: station_way_blocked) is left out of the walk from then on.
## Stairs and footbridges (_find_stairs): the decks of footbridges (ground tiles DECK_GROUND
## above street level) are walkable, each cell at its own level; the straight flights of stairs
## of the Props layer (STAIR_PROPS, chained where the top of one is the foot of the next) link
## the pavement at their foot to the deck at their top, walked as a route of points up the
## treads (stair_route, Pedestrian); the pavement under a flight is left out.

const PedestrianScript = preload("res://scripts/world/people/pedestrian.gd")
const Crowd = preload("res://scripts/world/people/crowd.gd")
const Sight = preload("res://scripts/world/town/sight.gd")
## Ground tile folders people walk on.
const WALK_GROUND := ["stoep/", "plein/"]
## Platform tiles at street level people walk and wait on too (a tram stop, the station's):
## from them they get on a tram or a train and onto them they get off (door_open_at).
const PLATFORM_GROUND := ["tram/tram_halte_perron", "tram/tramhalte_middenperron", "spoor/perron", "spoor/perron_midden"]
## Getting on and off (door_open_at): per second that a door stands open the chance someone
## within BOARD_REACH metres gets on, and that someone gets off; only within BOARD_PLAYER_REACH
## of the player (where it can be seen).
const BOARD_PER_SECOND := 0.45
const ALIGHT_PER_SECOND := 0.4
const BOARD_REACH := 7.0
const BOARD_PLAYER_REACH := 90.0
## Who just got off does not get on again for this long (seconds; ALIGHTED_META: when).
const STAY_OFF_SECONDS := 40.0
const ALIGHTED_META := "uitgestapt_om"
## Ground tiles above street level that people walk on (footbridge decks), and the props that
## are straight flights of stairs (not the spiral ones or the fire escapes).
const DECK_GROUND := ["brug/loopbrug"]
const STAIR_PROPS := ["trappen/trap_1m", "trappen/trap_3m", "trappen/trap_metaal_3m"]

## How many walk at a share of 1.0 (Crowd.pedestrian_share), the fewest and the most there are.
@export var count := 64
@export var fewest := 6
@export var most := 130
@export var reach := 90.0
@export var return_near := 50.0
## Seconds someone stays (drawn between the two) before it goes once unseen and over
## `renew_beyond` metres from the player; how many come or go each second at most (more after
## a jump of the player: a warp, a load).
@export var renew_after := Vector2(45.0, 110.0)
@export var renew_beyond := 30.0
@export var changes_per_second := 3
@export var interiors_path := NodePath("../Binnenruimtes")
## How far off (cells of 4 m, as the crow flies) a place lies that someone sets off for.
const DESTINATION_CELLS := Vector2i(12, 45)
## How many places are tried (most lie too far off: they are picked from the whole town),
## and the longest way there (cells) that still counts as a walk.
const DESTINATION_ATTEMPTS := 40
const LONGEST_WAY := 140
## Den Haag Centraal: see the top.
const STATION_KIND := "centraal"
const STATION_REACH := 140.0
const STATION_OUT_SHARE := 0.75
const STATION_PULL_STEPS := 25
const STATION_PULL_PER_SECOND := 0.03
## Only who is at least this many cells from a door sets off for it (who just came out walks on first).
const STATION_PULL_FROM_STEPS := 3
## How far off a door (m) the nearest walkable cell may lie to count as its cell.
const STATION_DOOR_CELL_REACH := 6.0
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
var _routes: AStar3D                 # the route finder over _links (_find_routes)
var _route_ids := {}                 # cell -> its point in _routes
var _ride := {}              # cell -> true: bicycle paths (only for mobility scooters)
var _decks := {}             # Vector2i (x, z) -> the level of the footbridge deck there
var _stair_routes := {}      # [from cell, to cell] -> PackedVector3Array: the points up or down the stairs
var _player: Node3D
var _ground: GridMap
var _buildings: GridMap
var _lights: Node
var _random := RandomNumberGenerator.new()
var _people: Array[Pedestrian] = []        # who walks the town now (Pedestrian._all holds this same array)
var _resting: Array[Pedestrian] = []       # who is not needed now, out of the tree
var _arriving: Array[Pedestrian] = []      # new ones waiting for their figure (built on a thread)
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
var _station_doors: Array[Vector3] = []    # the station's door spots (Interiors), on the street
var _station_door_cells: Array[Vector3i] = []
var _station_steps := {}                   # walkable cell -> cells to walk to the nearest door
var _station_blocked := {}                 # [from cell, to cell] -> true: no way through there
var _station_looks_left := 5               # tries left to find the doors (Interiors sets them up)
## How many came out of the station and went into it so far (for the tests).
var came_out_of_station := 0
## How many got on and off a tram or a train so far (door_open_at; for the tests).
var boarded := 0
var alighted := 0
var went_into_station := 0


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
		for person in _resting + _arriving:
			if is_instance_valid(person):
				person.free()
		_resting.clear()
		_arriving.clear()


func _physics_process(delta: float) -> void:
	if _ground == null or _ground.mesh_library == null:
		return
	if not _spread:
		if _player == null or _player.get("_placed") != false:
			_spread_people()
		return
	_clock += delta
	_let_arrive()
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


## Every cell someone can be on gets a point in the route finder, linked as _links says.
func _find_routes() -> void:
	_routes = AStar3D.new()
	_route_ids.clear()
	for cell: Vector3i in _links:
		var id := _route_ids.size()
		_route_ids[cell] = id
		_routes.add_point(id, Vector3(cell))
	for cell: Vector3i in _links:
		for next: Vector3i in _links[cell]:
			if _route_ids.has(next):
				_routes.connect_points(int(_route_ids[cell]), int(_route_ids[next]), false)


## The cells to walk from `from` to a place a few blocks off (a walkable cell between
## DESTINATION_CELLS.x and .y cells away as the crow flies, where `mobility` may go),
## without `from` itself; empty when no such place can be reached from here.
func route_to_somewhere(from: Vector3i, mobility: String) -> Array[Vector3i]:
	var route: Array[Vector3i] = []
	if _routes == null or not _route_ids.has(from) or _walkable_cells.is_empty():
		return route
	var routes_tried := 0
	for attempt in DESTINATION_ATTEMPTS:
		var goal: Vector3i = _walkable_cells[_random.randi() % _walkable_cells.size()]
		var far := maxi(absi(goal.x - from.x), absi(goal.z - from.z))
		if far < DESTINATION_CELLS.x or far > DESTINATION_CELLS.y or not _route_ids.has(goal):
			continue
		routes_tried += 1
		if routes_tried > 3:
			break
		for point in _routes.get_point_path(int(_route_ids[from]), int(_route_ids[goal])):
			route.append(Vector3i(roundi(point.x), roundi(point.y), roundi(point.z)))
		# (a way far round, over a bridge at the other end of town, is no walk: another place)
		if route.size() > 1 and route.size() <= LONGEST_WAY:
			route.remove_at(0)
			if mobility != "" and route.any(func(cell: Vector3i) -> bool: return not may_use(cell, mobility)):
				route.clear()
				continue
			return route
		route.clear()
	return route


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
	# on a footbridge deck (not under it): that cell, at its level
	var level: int = _decks.get(Vector2i(local.x, local.z), -1)
	if level > 0 and spot.y > cell_middle(Vector3i(local.x, level, local.z)).y - 1.5:
		return Vector3i(local.x, level, local.z)
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
	_send_to_station(player_spot)
	var failures := 0
	while _people.size() + _arriving.size() < wanted and changes_left > 0 and failures < 8:
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
	var door_cell := _station_door_cell()
	_dress_for_now(person, true, cell_middle(door_cell) if door_cell != RoadNetwork.NONE else Vector3.INF)
	if door_cell != RoadNetwork.NONE and person.restart_at(door_cell):
		came_out_of_station += 1   # someone else, out of the station
		return
	if not bring_back(person):
		_rest(person)


## Starts `person` afresh as someone else, away from the player (one whose health ran out).
func start_again(person: Pedestrian) -> void:
	_dress_for_now(person, true)
	bring_back(person)


## Someone more round the player: one who rested, or a new one (up to `most`), out of sight in
## the ring round the player; false if there is no spot.
func _bring_someone() -> bool:
	var cell := _station_door_cell()
	var from_station := cell != RoadNetwork.NONE
	if not from_station:
		cell = _ring_cell()
	if cell == RoadNetwork.NONE:
		return false
	if not _resting.is_empty():
		var person: Pedestrian = _resting.pop_back()
		_dress_for_now(person, true, cell_middle(cell))
		add_child(person)
		_people.append(person)
		if not person.restart_at(cell):
			if not bring_back(person):
				_rest(person)
				return false
		elif from_station:
			came_out_of_station += 1
		return true
	if _people.size() + _resting.size() + _arriving.size() >= most:
		return false
	_add_person(cell, true)
	if from_station:
		came_out_of_station += 1
	return true


## A new pedestrian on `cell`, of the hour and the neighbourhood there. `wait_for_figure`: its
## figure is built on a thread first (TownsfolkFigure.prepare) and it comes once that is done
## (_let_arrive), so bringing someone new costs no stutter; otherwise it is built here and now
## (the town at the start, behind the loading screen).
func _add_person(cell: Vector3i, wait_for_figure := false) -> Pedestrian:
	var person: Pedestrian = PedestrianScript.new()
	_made += 1
	person.name = "Voetganger%d" % _made
	person.town = self
	_dress_for_now(person, false, cell_middle(cell))
	person.start_cell = cell
	if wait_for_figure and not person.figure_is_prepared():
		person.prepare_figure()
		_arriving.append(person)
		return person
	add_child(person)
	_people.append(person)
	return person


## The new ones whose figure is built (_add_person) come into the town.
func _let_arrive() -> void:
	if _arriving.is_empty():
		return
	for person: Pedestrian in _arriving.duplicate():
		if person.figure_is_prepared():
			_arriving.erase(person)
			add_child(person)
			_people.append(person)


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
		if not WALK_GROUND.any(func(folder: String) -> bool: return item_name.begins_with(folder)) \
				and not item_name in PLATFORM_GROUND:
			continue
		if _buildings and (_buildings.get_cell_item(Vector3i(cell.x, 0, cell.z)) != GridMap.INVALID_CELL_ITEM
				or _buildings.get_cell_item(Vector3i(cell.x, 1, cell.z)) != GridMap.INVALID_CELL_ITEM):
			continue
		_walkable[cell] = true
		_walkable_cells.append(cell)
	var flights := _find_flights()
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
	_find_stairs(flights)
	_find_routes()


## The route over the stairs from `from` to `to` (cells linked by them): the points to walk
## to one after the other (the foot, the landings, the top); empty if no stairs link them.
func stair_route(from: Vector3i, to: Vector3i) -> PackedVector3Array:
	return _stair_routes.get([from, to], PackedVector3Array())


## True if `cell` is a footbridge deck (above street level).
func is_deck(cell: Vector3i) -> bool:
	return cell.y > 0 and _decks.get(Vector2i(cell.x, cell.z), -1) == cell.y


## The straight flights of stairs of the Props layer (STAIR_PROPS): each [foot, top] (world
## points on the line up its middle, at the height of its lowest and highest tread, found with
## a ray on its collider), and the pavement cells under them taken out of the walkable ones.
func _find_flights() -> Array:
	var flights := []
	var props := get_node_or_null(props_path) as GridMap
	if props == null or props.mesh_library == null:
		return flights
	var library := props.mesh_library
	for prop_cell in props.get_used_cells():
		var item := props.get_cell_item(prop_cell)
		var item_name := library.get_item_name(item)
		if not STAIR_PROPS.any(func(stair: String) -> bool: return item_name.begins_with(stair)):
			continue
		var mesh := library.get_item_mesh(item)
		if mesh == null:
			continue
		var bounds := library.get_item_mesh_transform(item) * mesh.get_aabb()
		var place := props.global_transform * Transform3D(props.get_cell_item_basis(prop_cell), props.map_to_local(prop_cell))
		# it rises towards its -z end; the treads just inside each end
		var foot := place * Vector3(0.0, 0.0, bounds.end.z - 0.15)
		var top := place * Vector3(0.0, 0.0, bounds.position.z + 0.15)
		var above := place * Vector3(0.0, bounds.end.y + 1.0, 0.0)
		foot.y = _surface_height(foot, above.y)
		top.y = _surface_height(top, above.y)
		if is_nan(foot.y) or is_nan(top.y):
			continue
		flights.append([foot, top])
		# the pavement under it: not to walk on (the stairs stand there)
		var along := Vector2(top.x - foot.x, top.z - foot.z)
		var half_width := bounds.size.x * 0.5
		for cell: Vector3i in _walkable_cells.duplicate():
			var middle := cell_middle(cell)
			var from_foot := Vector2(middle.x - foot.x, middle.z - foot.z)
			var share := from_foot.dot(along) / along.length_squared()
			var aside := absf(from_foot.cross(along.normalized()))
			if share > 0.0 and share < 1.0 and aside < half_width + 0.5:
				_walkable.erase(cell)
				_walkable_cells.erase(cell)
	return flights


## The decks of the footbridges and the routes over the stairs (see the top): the flights
## chained into ways up from the pavement to a deck, each linked both ways.
func _find_stairs(flights: Array) -> void:
	var library := _ground.mesh_library
	for cell in _ground.get_used_cells():
		if cell.y <= 0 or not DECK_GROUND.any(func(deck: String) -> bool: return library.get_item_name(_ground.get_cell_item(cell)).begins_with(deck)):
			continue
		_decks[Vector2i(cell.x, cell.z)] = cell.y
		_walkable[cell] = true
	var sides: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for column: Vector2i in _decks:
		var deck := Vector3i(column.x, _decks[column], column.y)
		var ways: Array[Vector3i] = []
		for side in sides:
			if is_deck(deck + side):
				ways.append(deck + side)
		_links[deck] = ways
	for flight: Array in flights:
		var foot: Vector3 = flight[0]
		if foot.y - cell_middle(cell_of(foot)).y > 1.0:
			continue   # a flight higher up: reached from the one below it
		var points := PackedVector3Array()
		var direction := Vector3(flight[1].x - foot.x, 0.0, flight[1].z - foot.z).normalized()
		points.append(foot - direction * 0.6)
		var current: Array = flight
		for chained in flights.size():
			points.append(current[1])
			var next_flight: Array = []
			for other: Array in flights:
				var other_foot: Vector3 = other[0]
				var top: Vector3 = current[1]
				if other != current and Vector2(other_foot.x - top.x, other_foot.z - top.z).length() < 0.8 and absf(other_foot.y - top.y) < 0.6:
					next_flight = other
			if next_flight.is_empty():
				break
			current = next_flight
		var last_top: Vector3 = current[1]
		var onwards := Vector3(last_top.x - current[0].x, 0.0, last_top.z - current[0].z).normalized()
		var beyond := last_top + onwards * 1.2
		# the pavement it is walked onto from: the first walkable cell before its foot
		var bottom := cell_of(foot - direction * 0.6)
		for back in [1.5, 2.5, 3.5]:
			if _walkable.has(bottom):
				break
			bottom = cell_of(foot - direction * back)
		var deck := _deck_at(beyond, last_top.y)
		if not _walkable.has(bottom) or deck == Vector3i(-1, -1, -1):
			continue
		points.append(beyond)
		_stair_routes[[bottom, deck]] = points
		var down := points.duplicate()
		down.reverse()
		_stair_routes[[deck, bottom]] = down
		(_links[bottom] as Array).append(deck)
		(_links[deck] as Array).append(bottom)


## The deck cell under `spot` at about `height`, or (-1, -1, -1).
func _deck_at(spot: Vector3, height: float) -> Vector3i:
	var local := _ground.local_to_map(_ground.to_local(spot))
	var level: int = _decks.get(Vector2i(local.x, local.z), -1)
	if level < 0:
		return Vector3i(-1, -1, -1)
	var deck := Vector3i(local.x, level, local.z)
	return deck if absf(cell_middle(deck).y - height) < 1.5 else Vector3i(-1, -1, -1)


## The height of what can be walked on under `spot`, from `from_height` down; NAN if nothing.
func _surface_height(spot: Vector3, from_height: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(spot.x, from_height, spot.z), Vector3(spot.x, -5.0, spot.z))
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return NAN if hit.is_empty() else (hit.position as Vector3).y


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


# ------------------------------------------------------------------ Den Haag Centraal

## The station's doors and the walk to them (from Interiors, once it has them).
func _find_station() -> void:
	if not _station_doors.is_empty() or _station_looks_left <= 0 or _interiors == null or not _interiors.has_method("ways_in"):
		return
	_station_looks_left -= 1
	for way_in: Dictionary in _interiors.ways_in():
		if way_in.get("kind", "") != STATION_KIND:
			continue
		var door: Vector3 = way_in.door
		var nearest := RoadNetwork.NONE
		var nearest_distance := STATION_DOOR_CELL_REACH
		for cell in _walkable_cells:
			var distance := cell_middle(cell).distance_to(door)
			if distance < nearest_distance:
				nearest = cell
				nearest_distance = distance
		if nearest != RoadNetwork.NONE:
			_station_doors.append(door)
			_station_door_cells.append(nearest)
	_walk_to_station()


## How many cells' walk from each walkable cell to the nearest door (breadth first, over the
## links not found blocked).
func _walk_to_station() -> void:
	_station_steps.clear()
	var frontier: Array[Vector3i] = []
	for cell in _station_door_cells:
		if not _station_steps.has(cell):
			_station_steps[cell] = 0
			frontier.append(cell)
	while not frontier.is_empty():
		var next_frontier: Array[Vector3i] = []
		for cell in frontier:
			var steps: int = _station_steps[cell] + 1
			if steps > STATION_PULL_STEPS * 2:
				continue
			for way: Vector3i in links(cell):
				# walked backwards from the doors: someone goes from `way` to `cell`
				if not _station_steps.has(way) and not _station_blocked.has([way, cell]):
					_station_steps[way] = steps
					next_frontier.append(way)
		frontier = next_frontier


## The hour's share of the station's coming and going (0..1; the rush hours most).
func station_share() -> float:
	return clampf(Crowd.station_share(Crowd.hour_of(get_parent())), 0.0, 1.0)


## True if the player is near the station (within STATION_REACH metres of a door).
func _near_station(spot: Vector3) -> bool:
	for door in _station_doors:
		if door.distance_to(spot) <= STATION_REACH:
			return true
	return false


## Cells to walk from `cell` to the nearest station door (0 at a door), -1 out of reach.
func station_steps(cell: Vector3i) -> int:
	return int(_station_steps.get(cell, -1))


## The station door nearest `spot` (where someone going in disappears).
func station_door_near(spot: Vector3) -> Vector3:
	var nearest := spot
	var nearest_distance := INF
	for door in _station_doors:
		if door.distance_to(spot) < nearest_distance:
			nearest = door
			nearest_distance = door.distance_to(spot)
	return nearest


## The cell of a station door for a newcomer to come out of, when it does (near the station,
## by the hour's share); NONE otherwise.
func _station_door_cell() -> Vector3i:
	_find_station()
	if _station_door_cells.is_empty() or _player == null or not _near_station(_player.global_position):
		return RoadNetwork.NONE
	if _random.randf() >= station_share() * STATION_OUT_SHARE:
		return RoadNetwork.NONE
	return _station_door_cells[_random.randi() % _station_door_cells.size()]


## Now and then someone near a door sets off into the station (see the top).
func _send_to_station(player_spot: Vector3) -> void:
	_find_station()
	if _station_steps.is_empty() or not _near_station(player_spot):
		return
	var chance := STATION_PULL_PER_SECOND * station_share()
	for person in _people:
		# not the one the player stands with (talking, perhaps), nor staff on duty
		if person.heading_to_station or person._ragdoll or person.role != "" or person.global_position.distance_to(player_spot) < 4.0:
			continue
		var steps := station_steps(person.cell)
		if steps >= STATION_PULL_FROM_STEPS and steps <= STATION_PULL_STEPS and _random.randf() < chance:
			person.heading_to_station = true


## No way through from `from` to `to` (someone heading for the station could not go there):
## the walk to the doors goes round it from now on.
func station_way_blocked(from: Vector3i, to: Vector3i) -> void:
	if _station_blocked.has([from, to]):
		return
	_station_blocked[[from, to]] = true
	_walk_to_station()


## A tram or a train stands with a door open at `door` (on the platform, just outside it:
## RailVehicle, every physics step while open, `delta` its seconds): now and then someone on
## the platform near it walks to the door and gets on (gone, as into the station), and now and
## then someone gets off (comes out of the door onto the platform and walks off).
func door_open_at(door: Vector3, delta: float) -> void:
	if _player == null or _player.global_position.distance_to(door) > BOARD_PLAYER_REACH or network == null:
		return
	if _random.randf() < BOARD_PER_SECOND * delta:
		var nearest: Pedestrian = null
		var nearest_distance := BOARD_REACH
		for person in _people:
			if person.heading_to_station or person._ragdoll or person.role != "" or person.mobility == "scootmobiel":
				continue
			if _clock - float(person.get_meta(ALIGHTED_META, -INF)) < STAY_OFF_SECONDS:
				continue   # just got off: it walks off first
			if person.global_position.distance_to(_player.global_position) < 3.0:
				continue   # not the one the player stands with (talking, perhaps)
			var distance := person.global_position.distance_to(door)
			if distance < nearest_distance:
				nearest = person
				nearest_distance = distance
		if nearest:
			nearest.board_at(door)
	if _random.randf() < ALIGHT_PER_SECOND * delta and not _resting.is_empty():
		var cell := _walkable_cell_near(door)
		if cell == RoadNetwork.NONE:
			return
		var person: Pedestrian = _resting.pop_back()
		_dress_for_now(person, true, door)
		add_child(person)
		_people.append(person)
		if person.restart_at(cell):
			person.step_out_at(door)
			person.set_meta(ALIGHTED_META, _clock)
			alighted += 1
		elif not bring_back(person):
			_rest(person)


## The walkable cell at `spot`, or the nearest one beside it; NONE if there is none.
func _walkable_cell_near(spot: Vector3) -> Vector3i:
	var here := cell_of(spot)
	if _walkable.has(here):
		return here
	for side: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if _walkable.has(here + side):
			return here + side
	return RoadNetwork.NONE


## `person` went in through a station door: gone for good (freed; someone else comes instead).
## (Getting on a tram or a train ends the same way: Pedestrian.board_at.)
func into_station(person: Pedestrian) -> void:
	person.heading_to_station = false
	if not person in _people:
		return
	if person.boarding:
		boarded += 1
	else:
		went_into_station += 1
	_people.erase(person)
	_leaves_at.erase(person)
	Pedestrians.claim_zebra(person, [], false)
	person.queue_free()
