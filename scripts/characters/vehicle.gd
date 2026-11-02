class_name Vehicle
extends Node3D
## A vehicle that drives round the road network on its own (scripts/world/road_network.gd,
## made from the lanes in the metadata of the ground tiles):
## the base of the car (car.gd) and of later vehicles (a bus, a van, a tram on its own
## lanes, ...). A vehicle type extends this script, sets its own speeds and model in
## _init (the scene's values still override them) and can override the hooks:
## - _may_use(cell, heading): lanes it may drive (all of them by default);
## - _choose_heading(cell, heading, options): where it goes where it could also turn;
## - _must_stop(from_cell, to_cell, distance): why it stops before a cell.
##
## No physics and no gravity: the vehicle follows the lanes kinematically, which keeps it
## exactly in its lane, and rides on the road surface (up and down the ramps of a
## tunnel, tilted with the slope). Its route is a chain of cell centres, planned a few
## cells ahead; it rides along it with the corners rounded off. It keeps to the speed
## limit of the road it is on (and brakes in time for a lower one ahead), slows down for
## corners, and stops:
## - before a zebra crossing (weg/zebrapad), for `zebra_wait` seconds, then drives on;
## - at traffic lights (Verkeerslichten, scripts/world/traffic_lights.gd) until its
##   stream is green, before the zebra or the crossing, whichever comes first.
## Where its lane ends it moves over into the lane alongside, gradually over a few cells
## (a motorway losing a lane); at a dead end it turns round into the opposite lane.
## Model: the props library item `model`, centred on the node, front along +Z, lifted by
## `model_lift`; its wheels (item `wheel_model`, at `wheel_positions`) roll with the
## distance driven, and the front ones (positions with z > 0) steer into the corners.

@export_group("Speed")
## Top speed of the vehicle itself (km/h); it never goes faster than the speed limit.
@export var top_speed_kmh := 130.0
## Speed through a corner (m/s).
@export var corner_speed := 4.5
## Speed through two corners right after each other: turning round, an S-bend (m/s).
@export var tight_corner_speed := 2.8
## Acceleration and braking (m/s²).
@export var acceleration := 2.5
@export var braking := 4.0
@export_group("Rules")
## Kind of vehicle, for lanes only some kinds may use (a bus lane: "bus").
@export var vehicle_kind := "auto"
## Stops for traffic lights.
@export var obeys_lights := true
## Seconds it waits before a zebra crossing without traffic lights.
@export var zebra_wait := 1.5
## Chance (0..1) to go straight on where it could also turn.
@export var straight_chance := 0.6
@export_group("Start")
## Start cell (on the map, x and z) and heading; if that is not a lane in that heading the
## nearest one that is is taken.
@export var start_cell := Vector2i(49, 72)
@export var start_heading := Vector2i(0, -1)
## Seed of its choices at forks (the same seed drives the same route).
@export var route_seed := 7
@export_group("Model")
## Props library item of the model.
@export var model := ""
## Height of the model's lowest part above the road (metres; a body without its wheels).
@export var model_lift := 0.0
## Metres from the centre to the front bumper, plus a margin (where it stops).
@export var half_length := 2.4
@export_group("Wheels")
## Props library item of one wheel (axle along x); "" = no separate wheels.
@export var wheel_model := ""
## Centres of the wheels on the vehicle (metres; x across, y up, z forwards). The ones
## with z > 0 steer.
@export var wheel_positions := PackedVector3Array()
## Radius the wheels roll with (metres).
@export var wheel_radius := 0.375
## Largest steering angle of the front wheels (degrees); 0 = they don't steer.
@export var max_steering_degrees := 35.0
## How quickly the steering follows the corner (1/s).
@export var steering_rate := 8.0

## Metres over which the corners of the route are rounded off.
const ROUNDING := 1.6
## Metres it plans ahead at least, beyond what it needs to brake to a stop.
const PLAN_MARGIN := 16.0
## Cells forward over which it moves over into the lane alongside, longest first.
const MOVE_OVER_CELLS := [3, 2, 1]
## Metres before the centre of a corner cell from which it keeps to its corner speed, and
## after it until it drives on.
const CORNER_REACH := 2.0

## Current speed (m/s) and velocity, for the camera.
var speed := 0.0
var velocity := Vector3.ZERO
## Speed limit of the road it is on (m/s).
var speed_limit := 0.0
var network: RoadNetwork

var _route_cells: Array[Vector3i] = []      # planned cells, the first one behind the vehicle
var _route_headings: Array[Vector2i] = []   # heading on leaving each planned cell
var _route_distances: Array[float] = []     # distance along the route of each cell centre (m)
var _distance := 0.0                         # distance of the vehicle along the route (m)
var _waited_at := {}                         # zebra cells it has already waited at (until it passes them)
var _zebra_waiting := 0.0
var _lights: Node
var _random := RandomNumberGenerator.new()
var _wheels: Array[Node3D] = []      # per wheel: the steering pivot, its child spins
var _wheel_roll := 0.0               # radians the wheels have turned
var _steering := 0.0                 # current steering angle (radians)
var _last_yaw := 0.0


func _ready() -> void:
	var root := owner if owner else get_parent()
	network = RoadNetwork.of(root)
	_lights = root.get_node_or_null("Verkeerslichten") if obeys_lights else null
	_random.seed = route_seed
	var props := root.get_node_or_null("Props") as GridMap
	_add_model(props)
	_add_wheels(props)
	if network.is_empty():
		set_physics_process(false)
		return
	var first := network.nearest(start_cell, start_heading)
	_append(first - Vector3i(start_heading.x, 0, start_heading.y), start_heading)
	_append(first, start_heading)
	_distance = _route_distances[1]
	_plan()
	_place()
	_last_yaw = global_basis.get_euler().y


func _physics_process(delta: float) -> void:
	_plan()
	var target := _target_speed(delta)
	if speed < target:
		speed = minf(target, speed + acceleration * delta)
	else:
		speed = maxf(target, speed - braking * 1.5 * delta)
	var before := global_position
	_distance += speed * delta
	_drop_passed_cells()
	_place()
	velocity = (global_position - before) / maxf(delta, 0.0001)
	_turn_wheels(speed * delta, delta)


# ------------------------------------------------------------------ hooks

## True if the vehicle may drive this lane: `heading` on `cell` (by default: every lane
## its kind may use, see the "only" of the tile traffic).
func _may_use(cell: Vector3i, _heading: Vector2i) -> bool:
	return network.allows(cell, vehicle_kind)


## Heading it leaves `cell` in, out of `options` (more than one), arriving in `heading`.
func _choose_heading(_cell: Vector3i, heading: Vector2i, options: Array[Vector2i]) -> Vector2i:
	if options.has(heading) and _random.randf() < straight_chance:
		return heading
	var turns := options.filter(func(option: Vector2i) -> bool: return option != heading)
	return turns[_random.randi() % turns.size()]


## Why it must stop before driving from `from_cell` into `to_cell` ("" = it may go):
## "light" for a red or amber light (amber only when it can still stop in `distance`
## metres), "zebra" for a zebra crossing without lights it has not yet waited at.
## Never inside a crossing.
func _must_stop(from_cell: Vector3i, to_cell: Vector3i, distance: float) -> String:
	if network.is_crossing(from_cell):
		return ""
	var zebra := network.is_zebra(to_cell)
	if not zebra and not network.is_crossing(to_cell):
		return ""
	var phase := -1
	if _lights and _lights.has_method("car_phase"):
		phase = _lights.car_phase(network.centre(to_cell), to_cell.x == from_cell.x)
	if phase == 2:
		return "light"
	if phase == 1:
		var braking_distance := speed * speed / (2.0 * braking)
		return "light" if distance > braking_distance - 0.5 else ""
	if phase == 0:
		return ""
	if zebra and not _waited_at.has(to_cell):
		return "zebra"
	return ""


# ------------------------------------------------------------------ route

func _append(cell: Vector3i, heading: Vector2i) -> void:
	var along := 0.0
	if not _route_cells.is_empty():
		var step := network.centre(cell) - network.centre(_route_cells[-1])
		along = _route_distances[-1] + Vector2(step.x, step.z).length()
	_route_cells.append(cell)
	_route_headings.append(heading)
	_route_distances.append(along)


## Index of the planned cell the vehicle has last passed the centre of.
func _current_index() -> int:
	var index := 0
	while index + 1 < _route_distances.size() and _route_distances[index + 1] <= _distance:
		index += 1
	return index


## Drops the cells behind the vehicle (keeping one, for the rounding of corners).
func _drop_passed_cells() -> void:
	while _route_cells.size() > 3 and _distance > _route_distances[2]:
		_waited_at.erase(_route_cells[1])
		_route_cells.pop_front()
		_route_headings.pop_front()
		_route_distances.pop_front()
	var offset := _route_distances[0]
	for index in _route_distances.size():
		_route_distances[index] -= offset
	_distance -= offset


## Plans cells until there are enough ahead to brake to a stop in time.
func _plan() -> void:
	var reach := _distance + speed * speed / (2.0 * braking) + PLAN_MARGIN
	while _route_distances[-1] < reach:
		var cell: Vector3i = _route_cells[-1]
		var heading: Vector2i = _route_headings[-1]
		var next_cell := network.step(cell, heading)
		var options: Array[Vector2i] = []
		if next_cell != RoadNetwork.NONE:
			for option in network.lanes(next_cell):
				if option != -heading and _may_use(next_cell, option) and network.step(next_cell, option) != RoadNetwork.NONE:
					options.append(option)
		if options.is_empty():
			if not _move_over(cell, heading):
				_turn_round(cell, heading)
			continue
		var next_heading: Vector2i = options[0]
		if options.size() > 1:
			next_heading = _choose_heading(next_cell, heading, options)
		_append(next_cell, next_heading)


## Where its lane ends: gradually over into the lane alongside, reaching it a few cells
## forward (MOVE_OVER_CELLS), over the cells between. False if there is none.
func _move_over(cell: Vector3i, heading: Vector2i) -> bool:
	for cells_forward: int in MOVE_OVER_CELLS:
		for side in [Vector2i(heading.y, -heading.x), Vector2i(-heading.y, heading.x)]:
			var target: Vector2i = Vector2i(cell.x, cell.z) + heading * cells_forward + side
			var beside := network.find(target.x, target.y, cell.y, cell, cells_forward)
			if beside == RoadNetwork.NONE or not network.lanes(beside).has(heading) or not _may_use(beside, heading):
				continue
			if network.step(beside, heading) == RoadNetwork.NONE:
				continue
			_append(beside, heading)
			return true
	return false


## At a dead end: across into the nearest opposite lane (up to four cells to the side,
## over the cells between), or straight back if there is none.
func _turn_round(cell: Vector3i, heading: Vector2i) -> void:
	for cells_across in range(1, 5):
		for side in [Vector2i(heading.y, -heading.x), Vector2i(-heading.y, heading.x)]:
			var across := network.find(cell.x + side.x * cells_across, cell.z + side.y * cells_across, cell.y, cell)
			if across == RoadNetwork.NONE or not network.lanes(across).has(-heading):
				continue
			_route_headings[-1] = side
			for between in range(1, cells_across):
				_append(Vector3i(cell.x + side.x * between, cell.y, cell.z + side.y * between), side)
			_append(across, -heading)
			return
	_append(cell - Vector3i(heading.x, 0, heading.y), -heading)


# ------------------------------------------------------------------ speed

## Speed it may drive now: the speed limit (braking in time for a lower one ahead),
## slower before corners, braking for a stop.
func _target_speed(delta: float) -> float:
	var index := _current_index()
	var last := _route_cells.size() - 1
	var top_speed := top_speed_kmh / 3.6
	speed_limit = network.speed_limit(_cell_under())
	var target := minf(top_speed, speed_limit)
	# a lower speed limit ahead: down to it where its cell starts
	for ahead_index in range(index + 1, last + 1):
		var cell_start := (_route_distances[ahead_index - 1] + _route_distances[ahead_index]) * 0.5
		var limit := minf(top_speed, network.speed_limit(_route_cells[ahead_index]))
		target = minf(target, _approach_speed(limit, cell_start))
	# corners: a change of heading in cell `corner_index`
	for corner_index in range(maxi(index, 1), last + 1):
		if _route_headings[corner_index - 1] == _route_headings[corner_index]:
			continue
		var corner_at := _route_distances[corner_index]
		if _distance > corner_at + CORNER_REACH:
			continue
		var tight := (corner_index < last and _route_headings[corner_index] != _route_headings[corner_index + 1]) \
				or (corner_index >= 2 and _route_headings[corner_index - 2] != _route_headings[corner_index - 1])
		target = minf(target, _approach_speed(tight_corner_speed if tight else corner_speed, corner_at - CORNER_REACH))
	# the first cell boundary it has to stop at
	for ahead_index in range(index + 1, last + 1):
		var stop_at := (_route_distances[ahead_index - 1] + _route_distances[ahead_index]) * 0.5 - half_length
		if _distance > stop_at + 0.5:
			continue           # already past this boundary
		var reason := _must_stop(_route_cells[ahead_index - 1], _route_cells[ahead_index], stop_at - _distance)
		if reason == "":
			continue
		target = minf(target, _approach_speed(0.0, stop_at))
		if stop_at - _distance < 0.4:
			target = 0.0
			if reason == "zebra":
				_zebra_waiting += delta
				if _zebra_waiting >= zebra_wait:
					_waited_at[_route_cells[ahead_index]] = true
					_zebra_waiting = 0.0
		break
	return target


## The planned cell the vehicle is on: the one whose centre is nearest along the route.
func _cell_under() -> Vector3i:
	var index := _current_index()
	if index + 1 < _route_cells.size():
		var halfway := (_route_distances[index] + _route_distances[index + 1]) * 0.5
		if _distance > halfway:
			return _route_cells[index + 1]
	return _route_cells[index]


## Highest speed now from which it can still brake to `wanted` (m/s) at route distance `at`.
func _approach_speed(wanted: float, at: float) -> float:
	return sqrt(wanted * wanted + 2.0 * braking * maxf(0.0, at - _distance))


# ------------------------------------------------------------------ placement

## Point on the chain of cell centres at route distance `at`, on the road surface.
func _route_point(at: float) -> Vector3:
	var index := 0
	while index + 2 < _route_distances.size() and _route_distances[index + 1] <= at:
		index += 1
	var span := maxf(_route_distances[index + 1] - _route_distances[index], 0.001)
	var fraction := clampf((at - _route_distances[index]) / span, 0.0, 1.0)
	var from := network.centre(_route_cells[index])
	var to := network.centre(_route_cells[index + 1])
	var spot := Vector2(lerpf(from.x, to.x, fraction), lerpf(from.z, to.z, fraction))
	var nearer := _route_cells[index] if fraction < 0.5 else _route_cells[index + 1]
	# the road cell right under the spot (a long stretch, moving over, crosses others)
	var under := network.find(floori(spot.x / RoadNetwork.CELL), floori(spot.y / RoadNetwork.CELL), nearer.y, nearer)
	if under == RoadNetwork.NONE:
		under = nearer
	return Vector3(spot.x, network.height(under, spot), spot.y)


func _place() -> void:
	# rounded corners: the mean of the route a little behind and ahead; the height of
	# the road right under it (the mean would cut through the top of a ramp)
	var position_now := (_route_point(_distance - ROUNDING) + _route_point(_distance + ROUNDING)) * 0.5
	position_now.y = _route_point(_distance).y
	var forward := _route_point(_distance + 2.0) - _route_point(_distance - 2.0)
	global_position = position_now
	if Vector2(forward.x, forward.z).length() > 0.01:
		global_basis = Basis.looking_at(-forward, Vector3.UP)


func _add_model(props: GridMap) -> void:
	if model == "" or props == null or props.mesh_library == null:
		return
	var library := props.mesh_library
	var item := library.find_item_by_name(model)
	if item < 0:
		push_warning("vehicle: no item '%s' in the props library" % model)
		return
	var mesh := library.get_item_mesh(item)
	var mesh_transform := library.get_item_mesh_transform(item)
	var box := mesh_transform * mesh.get_aabb()
	var middle := box.get_center()
	var instance := MeshInstance3D.new()
	instance.name = "Model"
	instance.mesh = mesh
	instance.transform = Transform3D(mesh_transform.basis, mesh_transform.origin - Vector3(middle.x, box.position.y - model_lift, middle.z))
	add_child(instance)


## The wheels: per position a pivot (steers about y) with a spinning node (rolls about
## x) holding the wheel mesh centred on it.
func _add_wheels(props: GridMap) -> void:
	if wheel_model == "" or props == null or props.mesh_library == null:
		return
	var library := props.mesh_library
	var item := library.find_item_by_name(wheel_model)
	if item < 0:
		push_warning("vehicle: no item '%s' in the props library" % wheel_model)
		return
	var mesh := library.get_item_mesh(item)
	var mesh_transform := library.get_item_mesh_transform(item)
	var middle := (mesh_transform * mesh.get_aabb()).get_center()
	for wheel_index in wheel_positions.size():
		var pivot := Node3D.new()
		pivot.name = "Wiel%d" % (wheel_index + 1)
		pivot.position = wheel_positions[wheel_index]
		var spin := Node3D.new()
		spin.name = "Draai"
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.transform = Transform3D(mesh_transform.basis, mesh_transform.origin - middle)
		spin.add_child(instance)
		pivot.add_child(spin)
		add_child(pivot)
		_wheels.append(pivot)


## Rolls the wheels over the distance driven and steers the front ones: the angle that
## makes a vehicle with this wheelbase follow the curve it is driving (its turn rate per
## metre).
func _turn_wheels(distance_driven: float, delta: float) -> void:
	if _wheels.is_empty():
		return
	_wheel_roll = fmod(_wheel_roll + distance_driven / maxf(wheel_radius, 0.01), TAU)
	var yaw := global_basis.get_euler().y
	var yaw_change := wrapf(yaw - _last_yaw, -PI, PI)
	_last_yaw = yaw
	var wanted := _steering
	if distance_driven > 0.001:
		var front := -INF
		var back := INF
		for wheel_position in wheel_positions:
			front = maxf(front, wheel_position.z)
			back = minf(back, wheel_position.z)
		var max_angle := deg_to_rad(max_steering_degrees)
		wanted = clampf(atan((front - back) * yaw_change / distance_driven), -max_angle, max_angle)
	_steering = lerpf(_steering, wanted, 1.0 - exp(-steering_rate * delta))
	for wheel in _wheels:
		wheel.rotation.y = _steering if wheel.position.z > 0.0 and max_steering_degrees > 0.0 else 0.0
		(wheel.get_child(0) as Node3D).rotation.x = _wheel_roll
