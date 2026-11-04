class_name RailVehicle
extends Vehicle
## A vehicle of several cars that only rides on rails: the base of the RandstadRail
## (randstadrail.gd) and the NS train (ns_train.gd). Its kind ("tram", "trein") says which
## tiles it may use ("only" in their "traffic" metadata, road_network.gd), and "rails" in that
## metadata which sides of a tile its rails join, so at a junction it can only take a way
## the rails really go.
##
## The node is the first car. Every other car rides on the same route further back, its
## two bogies on the track, so the train bends through a curve car by car. A car is a
## Node3D of its own that is drawn between the last two physics steps, like the body.
## At a platform (a tile with one of `platform_names` in its name beside the track) it stops
## with its nose at the end of the platform for `dwell_time` seconds. At the end of the
## track it stops and goes back and forth: the driver changes ends, so the last car leads
## (the train looks the same from both ends, so nothing jumps), and it moves over to the
## track beside it, the one that goes the other way, gradually on its way back.
## Other vehicles keep clear of all of its cars; it is not thrown off the rails by a crash.

## Props library items of the cars behind the first one, from front to back. A car whose
## number (1 = the first of these) is in `reversed_cars` is turned round (a cab looking back).
@export var car_models: Array[String] = []
@export var reversed_cars: Array[int] = []
## Length of one car and the gap to the next (metres).
@export var car_length := 11.0
@export var car_gap := 0.5
## Distance from the end of a car to its bogie (metres).
@export var bogie_inset := 2.0
## Seconds it stands at a platform.
@export var dwell_time := 12.0
## A tile beside the track with one of these in its name is a platform of this vehicle.
@export var platform_names: Array[String] = []

const NO_CELL := Vector3i(0, -1000, 0)
const STOP_MARGIN := 0.5
const END_MARGIN := 1.5

var _cars: Array[Node3D] = []
var _car_previous: Array[Transform3D] = []
var _car_current: Array[Transform3D] = []
var _dwell_clock := 0.0
var _waiting_before := NO_CELL      # the cell beyond the platform it is stopping before
var _stop_at := 0.0                 # route distance where it stands still for that platform
var _served := NO_CELL              # the cell beyond the platform it last stood at


func _ready() -> void:
	super()
	var props := get_parent().get_node_or_null("Props") as GridMap
	if props == null or network.is_empty():
		return
	for index in car_models.size():
		_add_car(props, car_models[index], index + 1 in reversed_cars)
	_put_whole_train_on_the_track()


## Rides the first car forward until the whole train is on the planned route.
func _put_whole_train_on_the_track() -> void:
	var length := (car_length + car_gap) * (car_models.size() + 1)
	while _distance < length and not _route_ended:
		_distance += RoadNetwork.CELL
		_plan()
	_place()
	_snap_body()
	_last_yaw = global_basis.get_euler().y
	for index in _cars.size():
		_car_current[index] = _car_transform(index)
		_car_previous[index] = _car_current[index]
		_cars[index].global_transform = _car_current[index]


func _add_car(props: GridMap, item_name: String, turned_round: bool) -> void:
	var library := props.mesh_library
	var item := library.find_item_by_name(item_name)
	if item < 0:
		push_warning("rail vehicle: no item '%s' in the props library" % item_name)
		return
	var mesh := library.get_item_mesh(item)
	var mesh_transform := library.get_item_mesh_transform(item)
	var box := mesh_transform * mesh.get_aabb()
	var middle := box.get_center()
	var car := Node3D.new()
	car.name = "Wagon%d" % (_cars.size() + 1)
	car.top_level = true
	add_child(car)
	var instance := MeshInstance3D.new()
	instance.name = "Model"
	instance.mesh = mesh
	instance.transform = Transform3D(mesh_transform.basis, mesh_transform.origin - Vector3(middle.x, box.position.y - model_lift, middle.z))
	if turned_round:
		instance.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * instance.transform
	_tint_windows(instance, mesh)
	car.add_child(instance)
	_cars.append(car)
	_car_previous.append(Transform3D.IDENTITY)
	_car_current.append(Transform3D.IDENTITY)


## Where car `index` of _cars rides: between its two bogies on the route.
func _car_transform(index: int) -> Transform3D:
	var centre := _distance - (car_length + car_gap) * (index + 1)
	var reach := car_length * 0.5 - bogie_inset
	var front := _route_point(centre + reach)
	var rear := _route_point(centre - reach)
	var forward := front - rear
	if forward.length_squared() < 0.01:
		forward = global_basis.z
	return Transform3D(Basis.looking_at(-forward, Vector3.UP), (front + rear) * 0.5)


func _measure_length() -> void:
	super()
	_heading_reach = car_length * 0.5 - bogie_inset
	var train_length := (car_length + car_gap) * (car_models.size() + 1) + car_length
	_cells_kept_behind = ceili(train_length / RoadNetwork.CELL) + 2


func _physics_process(delta: float) -> void:
	if _waiting_before != NO_CELL and speed < STANDING_SPEED:
		_dwell_clock += delta
		if _dwell_clock >= dwell_time:
			_served = _waiting_before
			_waiting_before = NO_CELL
			_dwell_clock = 0.0
	elif _route_ended and speed < STANDING_SPEED and _distance > _end_of_track() - END_MARGIN:
		_dwell_clock += delta
		if _dwell_clock >= dwell_time:
			_dwell_clock = 0.0
			_change_ends()
	super(delta)
	for index in _cars.size():
		_car_previous[index] = _car_current[index]
		_car_current[index] = _car_transform(index)


func _process(delta: float) -> void:
	super(delta)
	var fraction := Engine.get_physics_interpolation_fraction()
	for index in _cars.size():
		_cars[index].global_transform = _car_previous[index].interpolate_with(_car_current[index], fraction)


# ------------------------------------------------------------------ the rails

## A heavy train can run a little past the spot it brakes for: it stands still there all the same.
func _target_speed(delta: float) -> float:
	var target := super(delta)
	if _waiting_before != NO_CELL and _distance > _stop_at - STOP_MARGIN:
		return 0.0
	if _route_ended:
		if _distance > _end_of_track() - STOP_MARGIN:
			return 0.0
		target = minf(target, _approach_speed(0.0, _end_of_track()))
	return target


## Route distance where the first car stands with its nose at the end of the track.
func _end_of_track() -> float:
	return _route_distances[-1] - half_length


## The last car leads now: the route turned round, seen from there, and the cars in the
## same places. On the way back it plans on from the route behind it.
func _change_ends() -> void:
	var old_cells := _route_cells.duplicate()
	var old_headings := _route_headings.duplicate()
	var old_distances := _route_distances.duplicate()
	var route_length: float = old_distances[-1]
	var last_car_at := _distance - (car_length + car_gap) * _cars.size()
	_route_cells.clear()
	_route_headings.clear()
	_route_distances.clear()
	for index in range(old_cells.size() - 1, -1, -1):
		# the heading on leaving this cell is the way back to the one before it
		_append(old_cells[index], -old_headings[index - 1] if index > 0 else -old_headings[0])
	_distance = route_length - last_car_at
	_route_ended = false
	_turned_round_at = 0
	_waited_at.clear()
	_served = NO_CELL
	_waiting_before = NO_CELL
	speed = 0.0
	acceleration_now = 0.0
	_plan()
	_place()
	_snap_body()
	_last_yaw = global_basis.get_euler().y
	for index in _cars.size():
		_car_current[index] = _car_transform(index)
		_car_previous[index] = _car_current[index]
		_cars[index].global_transform = _car_current[index]


## From a tile it only leaves the way its rails go.
func _may_continue(cell: Vector3i, arriving: Vector2i, leaving: Vector2i) -> bool:
	return network.rail_connects(cell, arriving, leaving)


## At the end of the track it does not turn round: it stops there and changes ends.
func _turn_round(_cell: Vector3i, _heading: Vector2i) -> void:
	_route_ended = true


## Stops at the end of a platform as well as where any vehicle stops.
func _must_stop(from_cell: Vector3i, to_cell: Vector3i, distance: float) -> String:
	var reason := super(from_cell, to_cell, distance)
	if reason != "":
		return reason
	if to_cell == _served or not _beside_platform(from_cell, to_cell - from_cell) or _beside_platform(to_cell, to_cell - from_cell):
		return ""
	if _waiting_before != NO_CELL and _waiting_before != to_cell:
		return ""   # a platform further on, after this one
	_waiting_before = to_cell
	_stop_at = _distance + distance
	return "platform"


func _beside_platform(cell: Vector3i, direction: Vector3i) -> bool:
	var ground_heading := Vector2i(signi(direction.x), signi(direction.z))
	for side in [Vector2i(ground_heading.y, -ground_heading.x), Vector2i(-ground_heading.y, ground_heading.x)]:
		var tile := network.tile_name(Vector3i(cell.x + side.x, cell.y, cell.z + side.y))
		for platform_name in platform_names:
			if tile.contains(platform_name):
				return true
	return false


# ------------------------------------------------------------------ the others

## It stays on the rails: a blow only stops it.
func _become_wreck(_impact: Vector3, _spin := 0.0) -> void:
	speed = 0.0


## It cannot be sent off its rails (the demo crash takes another vehicle).
func drive_into(_other: Vehicle) -> void:
	pass


func covers(cell: Vector3i) -> bool:
	if super(cell):
		return true
	if absi(cell.y - roundi(global_position.y)) > 3:
		return false
	var centre := network.centre(cell)
	for frame in _car_current:
		var reach := frame.basis.z * car_length * 0.5
		if _line_covers(centre, frame.origin + reach, frame.origin - reach):
			return true
	return false


func _reach() -> float:
	return (car_length + car_gap) * (_cars.size() + 1)


func _footprints(margin: float) -> Array:
	var rectangles := super(margin)
	for frame in _car_current:
		rectangles.append(_rectangle(frame, frame.origin, _body_size.x, car_length, margin))
	return rectangles
