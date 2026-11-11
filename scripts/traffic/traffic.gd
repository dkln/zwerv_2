class_name Traffic
extends Node
## The traffic of the town (the "Verkeer" node of scenes/stad.tscn): ordinary Vehicles
## (scripts/vehicles/) under the scene root, next to the Auto and the SUV that are in the
## scene itself (those, and the trams and trains, it leaves alone). MIX says what drives,
## each with its kind of vehicle ("auto", "fiets", "brommer", "vracht", "bus", "landbouw",
## "klein"); after them come the SERVICES: police, ambulance, fire service, an ME van and
## ministers' cars (in that order and round again).
##
## A set round the player, not the whole town (`whole_town` false, the game): when the game
## starts it puts vehicles on the roads within `appear_within` metres of the player; one
## that is further than `keep_within` from the player and out of sight is taken out of the
## town (out of the tree, kept to be used again: `_parked`), and so is one that has driven
## round long enough (`renew_after`) once it is unseen and over `renew_beyond` metres away,
## and others come on a lane between `appear_from` and `appear_within` metres from the player,
## out of sight, so what drives round you keeps changing. How many: `vehicle_count` times the
## share of the hour of the day and of the neighbourhood the player is in (Crowd,
## data/drukte.json: busy in the rush hours, on the A12 and round Centraal, quiet at night
## and in the parks), at most `most_vehicles`; the services `services_count` times the hour's
## share (at least `fewest_services`). What comes: a kind of vehicle drawn by the weights of
## the hour and of the neighbourhood where it appears (lorries in the Binckhorst, bicycles in
## the centre, cars on the A12), then one of MIX of that kind the lane allows. Changes go a
## few a tick (`changes_per_tick`), all at once after a jump of the player (a warp, a load);
## inside an interior (Binnenruimtes) it all stands still. Without a camera (the tools)
## nothing counts as unseen, so nothing is taken out.
## `whole_town` true (traffic_test): as before, `vehicle_count` + `services_count` spread over
## the whole road network at the start, at random but repeatable spots at least `spacing`
## metres apart, and all of them kept.

const Crowd = preload("res://scripts/world/crowd.gd")
const Sight = preload("res://scripts/world/sight.gd")
const CAR = "res://scripts/vehicles/car.gd"
const SUV = "res://scripts/vehicles/suv.gd"
const HATCHBACK = "res://scripts/vehicles/hatchback.gd"
const TRAILER_CAR = "res://scripts/vehicles/trailer_car.gd"
const VAN = "res://scripts/vehicles/van.gd"
const TRUCK = "res://scripts/vehicles/truck.gd"
const CITY_BUS = "res://scripts/vehicles/city_bus.gd"
const POLICE_CAR = "res://scripts/vehicles/police_car.gd"
const AMBULANCE = "res://scripts/vehicles/ambulance.gd"
const FIRE_ENGINE = "res://scripts/vehicles/fire_engine.gd"
const RIOT_VAN = "res://scripts/vehicles/riot_van.gd"
const MINISTERS_CAR = "res://scripts/vehicles/ministers_car.gd"
const CYCLIST = "res://scripts/vehicles/cyclist.gd"
const FATBIKE = "res://scripts/vehicles/fatbike.gd"
const MOPED = "res://scripts/vehicles/moped.gd"
const SCOOTER = "res://scripts/vehicles/scooter.gd"
const MOTORBIKE = "res://scripts/vehicles/motorbike.gd"
const MICROCAR = "res://scripts/vehicles/microcar.gd"
const TRACTOR = "res://scripts/vehicles/tractor.gd"
## The emergency services and the ministers' cars, added after the town traffic.
const SERVICES := [POLICE_CAR, AMBULANCE, MINISTERS_CAR, FIRE_ENGINE, POLICE_CAR, RIOT_VAN, MINISTERS_CAR]
## [script, model ("" = the one of the script), kind of vehicle (data/drukte.json)]: town
## traffic, so mostly cars, with bicycles (cyclists and a fatbike, also on the cycle paths),
## mopeds and scooters (also on the cycle paths that allow them), a motorbike, a microcar and
## a tractor in between. `whole_town` takes them in this order, round again.
const MIX := [
	[HATCHBACK, "", "auto"],
	[CYCLIST, "", "fiets"],
	[CAR, "voertuigen/auto_sedan_wit", "auto"],
	[SCOOTER, "", "brommer"],
	[VAN, "", "vracht"],
	[HATCHBACK, "voertuigen/auto_hatchback_zilver", "auto"],
	[CYCLIST, "", "fiets"],
	[CITY_BUS, "", "bus"],
	[MOTORBIKE, "", "brommer"],
	[CAR, "voertuigen/auto_sedan_zilver", "auto"],
	[FATBIKE, "", "fiets"],
	[TRUCK, "", "vracht"],
	[TRACTOR, "", "landbouw"],
	[MOPED, "", "brommer"],
	[HATCHBACK, "voertuigen/auto_hatchback_groen", "auto"],
	[MICROCAR, "", "klein"],
	[TRAILER_CAR, "", "vracht"],
	[SCOOTER, "voertuigen/scooter_zwart", "brommer"],
	[CAR, "", "auto"],
	[CYCLIST, "", "fiets"],
	[SUV, "", "auto"],
	[TRACTOR, "voertuigen/trekker_rood", "landbouw"],
	[MICROCAR, "voertuigen/gehandicaptenauto_blauw", "klein"],
]

## Road cells a start spot must lead to.
const ROAD_CELLS_NEEDED := 60
## Tries for a spot round the player each time one is wanted.
const SPOT_TRIES := 220
## Metres from the player a vehicle may at least appear when the game starts.
const START_CLEAR := 24.0
## Metres the player may move before the good start cells round it are looked up again.
const NEAR_REFRESH := 25.0

## How many vehicles there are at a share of 1.0 (Crowd.traffic_share), and the most.
@export var vehicle_count := 50
@export var most_vehicles := 90   # the rush hours round Centraal (1.6 x 1.1 x 50)
## How many of the SERVICES at a share of 1.0, and the fewest.
@export var services_count := 7
@export var fewest_services := 2
## Fewest metres between the start spots (a bus is 10.5 m long).
@export var spacing := 20.0
## Seed of the start spots and routes.
@export var traffic_seed := 11
## The old way: all over the whole town, all kept (see the top).
@export var whole_town := false
## The set round the player (metres, seconds): see the top.
@export var keep_within := 280.0
@export var appear_from := 110.0
@export var appear_within := 230.0
@export var renew_after := Vector2(90.0, 200.0)
@export var renew_beyond := 70.0
@export var tick_seconds := 0.5
@export var changes_per_tick := 4
## Vehicles kept out of the town to be used again at most (the rest are freed).
@export var parked_kept := 30
@export var player_path := NodePath("../Speler")
## Without a camera everything counts as seen (nothing is sent off for being old or far);
## true lets a tool test the coming and going without one.
@export var unseen_without_camera := false
@export var interiors_path := NodePath("../Binnenruimtes")

var _network: RoadNetwork
var _random := RandomNumberGenerator.new()
var _cells: Array = []
var _player: Node3D
var _interiors: Node
var _started := false
var _town: Array[Vehicle] = []          # the town traffic it put in the town, now there
var _services: Array[Vehicle] = []      # the same for the services
var _parked: Array[Vehicle] = []        # taken out, to be used again
var _entry_of := {}                     # vehicle -> index in MIX (-1: a service)
var _leaves_at := {}                    # vehicle -> _clock when it may be taken out
var _kind_of_script := {}               # script path -> its vehicle_kind
var _start_ok := {}                     # cell -> true/false: a good start apart from the others
var _clock := 0.0
var _tick_clock := 0.0
var _town_made := 0
var _services_made := 0
var _last_player_spot := Vector3.INF
var _near_cells: Array[Vector3i] = []   # good start cells round the player (_find_near_cells)
var _near_around := Vector3.INF


func _ready() -> void:
	# the scene root is still setting up its children now
	_spawn.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# the parked vehicles are out of the tree: they go with this node
		for vehicle in _parked:
			if is_instance_valid(vehicle):
				vehicle.free()
		_parked.clear()


## The vehicles it keeps in the town now (for the tests): the town traffic and the services.
func vehicles() -> Array[Vehicle]:
	var all: Array[Vehicle] = []
	all.append_array(_town)
	all.append_array(_services)
	return all


## How many of the town traffic and of the services there should be now round the player.
func wanted_counts() -> Vector2i:
	var world := get_parent()
	var hour := Crowd.hour_of(world)
	var around := _player.global_position if _player else Vector3.ZERO
	var town := clampi(roundi(vehicle_count * Crowd.traffic_share(hour, Crowd.area_at(world, around))), 0, most_vehicles)
	if vehicle_count <= 0:
		town = 0
	var services := clampi(roundi(services_count * Crowd.traffic_hour_share(hour)), mini(fewest_services, services_count), services_count)
	return Vector2i(town, services)


func _spawn() -> void:
	var root := get_parent()
	_network = RoadNetwork.of(root)
	if _network.is_empty():
		return
	_player = get_node_or_null(player_path) as Node3D
	_interiors = get_node_or_null(interiors_path)
	_random.seed = traffic_seed
	_cells = _network.cells()
	# a shuffle of our own: Array.shuffle() does not take a seed
	for cell_index in range(_cells.size() - 1, 0, -1):
		var other_index := _random.randi_range(0, cell_index)
		var kept: Vector3i = _cells[cell_index]
		_cells[cell_index] = _cells[other_index]
		_cells[other_index] = kept
	if whole_town or _player == null:
		_spawn_whole_town()
		return
	var wanted := wanted_counts()
	for index in wanted.x:
		_bring_town_vehicle(0.0, appear_within, false)
	for index in wanted.y:
		_bring_service(0.0, appear_within, false)
	_last_player_spot = _player.global_position
	_started = true


## The old way: `vehicle_count` + `services_count` over the whole network, MIX in its order.
func _spawn_whole_town() -> void:
	var taken: Array[Vector3] = []
	for vehicle in Vehicle.all_vehicles:
		taken.append(vehicle.global_position)
	var added := 0
	for cell: Vector3i in _cells:
		if added >= vehicle_count + services_count:
			break
		var services := added >= vehicle_count
		var entry_index := -1 if services else added % MIX.size()
		var script_path: String = SERVICES[(added - vehicle_count) % SERVICES.size()] if services else MIX[entry_index][0]
		if not _good_start(cell, _kind_of(script_path), taken):
			continue
		var vehicle := _make(entry_index, script_path, services)
		_put_in_town(vehicle, cell)
		taken.append(_network.centre(cell))
		added += 1


func _physics_process(delta: float) -> void:
	if not _started:
		return
	_clock += delta
	_tick_clock -= delta
	if _tick_clock > 0.0:
		return
	_tick_clock = tick_seconds
	if _player == null or (_interiors and _interiors.has_method("is_inside") and _interiors.is_inside()):
		return
	var player_spot := _player.global_position
	var jumped := _last_player_spot.distance_to(player_spot) > appear_from
	_last_player_spot = player_spot
	var changes_left := 1000 if jumped else changes_per_tick
	var wanted := wanted_counts()
	# out of reach or long enough round: taken out, or swapped for another out of sight
	for group in [_town, _services]:
		for vehicle: Vehicle in group.duplicate():
			if changes_left <= 0:
				break
			if not _may_take_out(vehicle):
				continue
			var distance := vehicle.global_position.distance_to(player_spot)
			var too_far := distance > keep_within
			var long_enough := _clock >= float(_leaves_at.get(vehicle, 0.0)) and distance > renew_beyond
			if (too_far or long_enough) and _unseen(vehicle.global_position):
				_take_out(vehicle)
				changes_left -= 1
	while _town.size() < wanted.x and changes_left > 0:
		if not _bring_town_vehicle(appear_from, appear_within, true):
			break
		changes_left -= 1
	while _services.size() < wanted.y and changes_left > 0:
		if not _bring_service(appear_from, appear_within, true):
			break
		changes_left -= 1
	for group_wanted: Array in [[_town, wanted.x], [_services, wanted.y]]:
		var group: Array = group_wanted[0]
		while group.size() > group_wanted[1] and changes_left > 0:
			var leaving := _furthest_unseen(group, player_spot)
			if leaving == null:
				break
			_take_out(leaving)
			changes_left -= 1


# ------------------------------------------------------------------ coming and going

## One more of the town traffic on a lane `from`..`to` metres from the player (`unseen_only`:
## out of sight): a kind of vehicle of the hour and the neighbourhood there, one of MIX of
## that kind; false if there is no spot.
func _bring_town_vehicle(from: float, to: float, unseen_only: bool) -> bool:
	var world := get_parent()
	var hour := Crowd.hour_of(world)
	var weights_by_area := {}
	var taken := _taken_spots()
	var everything := 0.0
	for try_index in SPOT_TRIES:
		var cell := _ring_cell(from, to, unseen_only)
		if cell == RoadNetwork.NONE:
			continue
		var area := Crowd.area_at(world, _network.centre(cell))
		if not weights_by_area.has(area):
			weights_by_area[area] = _entry_weights(hour, area)
		var weights: Array = weights_by_area[area]
		everything = 0.0
		var allowed := 0.0
		var usable: Array[float] = []
		for entry_index in MIX.size():
			var weight: float = weights[entry_index]
			everything += weight
			var fits := weight > 0.0 and _network.allows(cell, _kind_of(MIX[entry_index][0])) and _apart(cell, taken)
			usable.append(weight if fits else 0.0)
			allowed += usable[-1]
		# a lane only some kinds may use (a cycle path) is taken as often as those kinds come
		if allowed <= 0.0 or _random.randf() * everything > allowed:
			continue
		var roll := _random.randf() * allowed
		var chosen := 0
		for entry_index in usable.size():
			roll -= usable[entry_index]
			if roll < 0.0:
				chosen = entry_index
				break
			if usable[entry_index] > 0.0:
				chosen = entry_index
		var vehicle := _parked_like(chosen)
		if vehicle == null:
			if _town.size() + _parked_count(false) >= most_vehicles:
				return false
			vehicle = _make(chosen, MIX[chosen][0], false)
		_put_in_town(vehicle, cell)
		return true
	return false


## One more of the services (the next of SERVICES), as _bring_town_vehicle.
func _bring_service(from: float, to: float, unseen_only: bool) -> bool:
	var script_path: String = SERVICES[_services_made % SERVICES.size()]
	var kind := _kind_of(script_path)
	var taken := _taken_spots()
	for try_index in SPOT_TRIES:
		var cell := _ring_cell(from, to, unseen_only)
		if cell == RoadNetwork.NONE or not _network.allows(cell, kind) or not _apart(cell, taken):
			continue
		var vehicle := _parked_service(script_path)
		if vehicle == null:
			vehicle = _make(-1, script_path, true)
		_put_in_town(vehicle, cell)
		return true
	return false


## A new vehicle of MIX entry `entry_index` (-1: the service `script_path`), not in the tree yet.
func _make(entry_index: int, script_path: String, service: bool) -> Vehicle:
	var vehicle: Vehicle = load(script_path).new()
	if entry_index >= 0 and MIX[entry_index][1] != "":
		vehicle.model = MIX[entry_index][1]
	if service:
		_services_made += 1
		vehicle.name = "Dienst%d" % _services_made
	else:
		_town_made += 1
		vehicle.name = "Verkeer%d" % _town_made
	vehicle.route_seed = _random.randi()
	_entry_of[vehicle] = entry_index
	return vehicle


## Into the town on `cell` (a new one starts there, a parked one is put down there).
func _put_in_town(vehicle: Vehicle, cell: Vector3i) -> void:
	var heading: Vector2i = _network.lanes(cell)[0]
	var service := int(_entry_of.get(vehicle, -1)) < 0
	_parked.erase(vehicle)
	if vehicle.is_node_ready():
		get_parent().add_child(vehicle)
		vehicle.put_down(Vector2i(cell.x, cell.z), heading)
	else:
		vehicle.start_cell = Vector2i(cell.x, cell.z)
		vehicle.start_heading = heading
		get_parent().add_child(vehicle)
	(_services if service else _town).append(vehicle)
	_leaves_at[vehicle] = _clock + _random.randf_range(renew_after.x, renew_after.y)


## Out of the town (out of the tree: not drawn, not driving, no sound), kept to be used
## again; the others let go of it first.
func _take_out(vehicle: Vehicle) -> void:
	_town.erase(vehicle)
	_services.erase(vehicle)
	_leaves_at.erase(vehicle)
	for other in Vehicle.all_vehicles:
		if other != vehicle:
			other.forget(vehicle)
	vehicle.get_parent().remove_child(vehicle)
	_parked.append(vehicle)
	while _parked.size() > parked_kept:
		var oldest: Vehicle = _parked.pop_front()
		_entry_of.erase(oldest)
		oldest.free()


## Not now: a wreck (until it is towed back), or one that is not in the town.
func _may_take_out(vehicle: Vehicle) -> bool:
	return vehicle.is_inside_tree() and not vehicle.crashed


func _furthest_unseen(group: Array, player_spot: Vector3) -> Vehicle:
	var furthest: Vehicle = null
	var furthest_distance := renew_beyond
	for vehicle: Vehicle in group:
		var distance := vehicle.global_position.distance_to(player_spot)
		if _may_take_out(vehicle) and distance > furthest_distance and _unseen(vehicle.global_position):
			furthest = vehicle
			furthest_distance = distance
	return furthest


## A parked one of MIX entry `entry_index` (the same script, the same model), or null.
func _parked_like(entry_index: int) -> Vehicle:
	for vehicle in _parked:
		var parked_entry := int(_entry_of.get(vehicle, -1))
		if parked_entry >= 0 and MIX[parked_entry][0] == MIX[entry_index][0] and MIX[parked_entry][1] == MIX[entry_index][1]:
			return vehicle
	return null


func _parked_service(script_path: String) -> Vehicle:
	for vehicle in _parked:
		if int(_entry_of.get(vehicle, 0)) < 0 and (vehicle.get_script() as Script).resource_path == script_path:
			_services_made += 1   # the next service next time
			return vehicle
	return null


func _parked_count(services: bool) -> int:
	return _parked.filter(func(vehicle: Vehicle) -> bool: return (int(_entry_of.get(vehicle, -1)) < 0) == services).size()


# ------------------------------------------------------------------ spots

## The weight of each MIX entry at `hour` in `area`: the weight of its kind (Crowd) shared by
## the entries of that kind.
func _entry_weights(hour: float, area: String) -> Array[float]:
	var of_kind := {}
	for entry: Array in MIX:
		of_kind[entry[2]] = int(of_kind.get(entry[2], 0)) + 1
	var weights: Array[float] = []
	for entry: Array in MIX:
		weights.append(Crowd.vehicle_weight(entry[2], hour, area) / float(of_kind[entry[2]]))
	return weights


## A random road cell between `from` and `to` metres from the player that is a good start
## (straight, ordinary road, leading somewhere), unseen if `unseen_only`; NONE if this try
## found none. It picks from the good cells near the player (_near_cells).
func _ring_cell(from: float, to: float, unseen_only: bool) -> Vector3i:
	if _near_around.distance_to(_player.global_position) > NEAR_REFRESH:
		_find_near_cells()
	if _near_cells.is_empty():
		return RoadNetwork.NONE
	var cell: Vector3i = _near_cells[_random.randi() % _near_cells.size()]
	var middle := _network.centre(cell)
	var distance := Vector2(middle.x - _player.global_position.x, middle.z - _player.global_position.z).length()
	if distance < maxf(from, START_CLEAR) or distance > to:
		return RoadNetwork.NONE
	if unseen_only and not _unseen(middle):
		return RoadNetwork.NONE
	return cell


## The good start cells (_road_fit) within appear_within metres of the player (plus
## NEAR_REFRESH, so they last while it moves that far).
func _find_near_cells() -> void:
	_near_cells.clear()
	_near_around = _player.global_position
	var within := appear_within + NEAR_REFRESH
	for cell: Vector3i in _cells:
		var middle := Vector2(cell.x + 0.5, cell.z + 0.5) * RoadNetwork.CELL
		if middle.distance_to(Vector2(_near_around.x, _near_around.z)) > within:
			continue
		if not _start_ok.has(cell):
			_start_ok[cell] = _road_fit(cell)
		if _start_ok[cell]:
			_near_cells.append(cell)


func _taken_spots() -> Array[Vector3]:
	var taken: Array[Vector3] = []
	for vehicle in Vehicle.all_vehicles:
		taken.append(vehicle.global_position)
	return taken


func _apart(cell: Vector3i, taken: Array[Vector3]) -> bool:
	var centre := _network.centre(cell)
	for spot in taken:
		if spot.distance_to(centre) < spacing:
			return false
	return true


## The vehicle_kind of a vehicle script (made once to ask it).
func _kind_of(script_path: String) -> String:
	if not _kind_of_script.has(script_path):
		var sample: Vehicle = load(script_path).new()
		_kind_of_script[script_path] = sample.vehicle_kind
		sample.free()
	return _kind_of_script[script_path]


## True for a straight piece of ordinary road this kind may use, away from all the others.
func _good_start(cell: Vector3i, kind: String, taken: Array[Vector3]) -> bool:
	if not _network.allows(cell, kind):
		return false
	if not _start_ok.has(cell):
		_start_ok[cell] = _road_fit(cell)
	return _start_ok[cell] and _apart(cell, taken)


## A straight piece of ordinary road on the ground, no crossing, zebra or tunnel, with road
## before and after it, that leads somewhere.
func _road_fit(cell: Vector3i) -> bool:
	if cell.y != 0 or _network.is_crossing(cell) or _network.is_zebra(cell):
		return false
	if _network.kind(cell) == RoadNetwork.Kind.TUNNEL or _network.lanes(cell).size() != 1:
		return false
	var heading: Vector2i = _network.lanes(cell)[0]
	if _network.step(cell, heading) == RoadNetwork.NONE or _network.step(cell, -heading) == RoadNetwork.NONE:
		return false
	return _leads_somewhere(cell)


## True if the lanes from this cell reach at least ROAD_CELLS_NEEDED cells: there are short
## bits of road that lead nowhere, where a vehicle would only turn round for ever.
func _leads_somewhere(cell: Vector3i) -> bool:
	var seen := {cell: true}
	var to_visit: Array[Vector3i] = [cell]
	while not to_visit.is_empty() and seen.size() < ROAD_CELLS_NEEDED:
		var current: Vector3i = to_visit.pop_back()
		for heading in _network.lanes(current):
			var next_cell := _network.step(current, heading)
			if next_cell != RoadNetwork.NONE and not seen.has(next_cell):
				seen[next_cell] = true
				to_visit.append(next_cell)
	return seen.size() >= ROAD_CELLS_NEEDED


## True if `spot` is out of sight of the camera (Sight: off the screen); false without a camera.
func _unseen(spot: Vector3) -> bool:
	var viewport := get_viewport()
	if viewport == null or viewport.get_camera_3d() == null:
		return unseen_without_camera
	return Sight.steps_between(viewport, spot) > 1
