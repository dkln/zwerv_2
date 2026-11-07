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
## At a platform (a tile beside the track whose metadata "platform" names its kind) it stops
## with its nose at the end of the platform for `dwell_time` seconds, counted from when it
## stands there: waiting further back (behind another tram, at a red light) is no stop. At the end of the
## track it stops and goes back and forth: the driver changes ends, so the last car leads
## (the train looks the same from both ends, so nothing jumps), and it moves over to the
## track beside it, the one that goes the other way, gradually on its way back.
## Standing at a platform it opens the doors beside that platform: each leaf (`door_model`)
## is a mesh of its own that steps out of the car and slides along it, and the doors on the
## other side and beyond the platform stay shut.
## Other vehicles keep clear of all of its cars; it is not thrown off the rails by a crash.
## Lamps as usual on rails: white at the front and red at the back of the whole train, by
## day and by night, no brake lights. The first car always leads (_change_ends), so the
## headlights are on it and the red ones (`rear_lamp_positions`) on the last car.

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
## It stays on the track it started on and goes back along it, whatever way the lanes run
## there, so another vehicle on the track beside it never meets it.
@export var own_track := false
## The red lamps on the last car, seen from that car (its back is towards -Z).
@export var rear_lamp_positions := PackedVector3Array()
## Props library item of one door leaf; empty = no doors that open.
@export var door_model := ""
## Seconds a door takes to open or close.
@export var door_time := 1.4
## Seconds it stands still before the doors open.
@export var door_delay := 0.6

const NO_CELL := Vector3i(0, -1000, 0)
const STOP_MARGIN := 0.5
const END_MARGIN := 1.5
## Metres before its stopping spot at which it counts as arrived at a platform.
const PLATFORM_MARGIN := 1.5
const VOXEL := 0.125
## Voxels under the floor of a car, and of a door leaf along it (rail_vehicles.py).
const DOOR_SILL_VOXELS := 4
const DOOR_LEAF_VOXELS := 5
## How far a leaf steps out of the car (metres), and which share of opening that takes.
const DOOR_STEP_OUT := 0.125
const DOOR_STEP_SHARE := 0.25
## Metres beyond a door where the platform has to be.
const DOOR_PLATFORM_REACH := 2.0

var _cars: Array[Node3D] = []
var _car_previous: Array[Transform3D] = []
var _car_current: Array[Transform3D] = []
var _car_boxes: Array[AABB] = []     # around what is drawn on each car, seen from its origin
var _dwell_clock := 0.0
var _waiting_before := NO_CELL      # the cell beyond the platform it is stopping before
var _stop_at := 0.0                 # route distance where it stands still for that platform
var _served := NO_CELL              # the cell beyond the platform it last stood at
var _leaving_platform := false      # it changed ends at a platform: no stop at its other end
var _door_leaves: Array[Dictionary] = []   # {node, closed, slide: Vector3, outward: Vector3}
var _opening_leaves: Array[Dictionary] = [] # the leaves beside the platform, at this stop
var _door_amount := 0.0             # 0 = shut .. 1 = open


func _ready() -> void:
	lamps_always_on = true
	brake_lights = false
	super()
	var props := get_parent().get_node_or_null("Props") as GridMap
	if props == null or network.is_empty():
		return
	_add_doors(props, _body, false)
	for index in car_models.size():
		_add_car(props, car_models[index], index + 1 in reversed_cars)
	if not _cars.is_empty():
		for position in rear_lamp_positions:
			_tail_lights.append(_lamp(position, tail_light_size, _tail_material, _cars[-1]))
		_car_boxes[-1] = _mesh_bounds(_cars[-1])
	_put_whole_train_on_the_track()


## Rides the first car forward until the whole train is on the planned route.
func _put_whole_train_on_the_track() -> void:
	var length := (car_length + car_gap) * (car_models.size() + 1)
	while _distance < length and not _route_ended:
		_distance += RoadNetwork.CELL
		_plan()
	_place()
	_snap_body()
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
	_car_boxes.append(_mesh_bounds(car))
	_car_previous.append(Transform3D.IDENTITY)
	_car_current.append(Transform3D.IDENTITY)
	_add_doors(props, car, turned_round)


## The leaves of the four doors of a car (two on each side), in the openings of its model.
func _add_doors(props: GridMap, car: Node3D, turned_round: bool) -> void:
	if door_model == "":
		return
	var library := props.mesh_library
	var item := library.find_item_by_name(door_model)
	if item < 0:
		push_warning("rail vehicle: no item '%s' in the props library" % door_model)
		return
	var mesh := library.get_item_mesh(item)
	var mesh_transform := library.get_item_mesh_transform(item)
	var leaf_box := mesh_transform * mesh.get_aabb()
	var model := car.get_node("Model") as MeshInstance3D
	var car_width: float = (model.transform * model.mesh.get_aabb()).size.x
	var doors := Node3D.new()
	doors.name = "Deuren"
	if turned_round:
		doors.rotation.y = PI
	car.add_child(doors)
	var car_voxels := roundi(car_length / VOXEL)
	var leaf_height := model_lift + (DOOR_SILL_VOXELS * VOXEL) + leaf_box.size.y * 0.5
	for door_voxel: int in [car_voxels / 4, 3 * car_voxels / 4]:
		for slide_direction: float in [-1.0, 1.0]:
			var along := car_length * 0.5 - (door_voxel - slide_direction * DOOR_LEAF_VOXELS * 0.5) * VOXEL
			for outward: float in [-1.0, 1.0]:
				var instance := MeshInstance3D.new()
				instance.name = "Deurblad"
				instance.mesh = mesh
				_tint_windows(instance, mesh)
				var wanted := Vector3(outward * (car_width - VOXEL) * 0.5, leaf_height, along)
				var closed := Transform3D(mesh_transform.basis, mesh_transform.origin + wanted - leaf_box.get_center())
				instance.transform = closed
				doors.add_child(instance, true)
				_door_leaves.append({"node": instance, "closed": closed.origin, "centre": wanted,
					# away from the middle of its door
					"slide": Vector3(0.0, 0.0, slide_direction), "outward": Vector3(outward, 0.0, 0.0)})


## The leaves on the platform side beside a platform, at `level` of the ground layer.
func _leaves_beside_platform(level: int) -> Array[Dictionary]:
	var leaves: Array[Dictionary] = []
	for leaf in _door_leaves:
		var parent := (leaf.node as Node3D).get_parent() as Node3D
		var outside: Vector3 = parent.global_transform * (leaf.centre + leaf.outward * DOOR_PLATFORM_REACH)
		if network.is_platform_for(Vector3i(floori(outside.x / RoadNetwork.CELL), level, floori(outside.z / RoadNetwork.CELL)), vehicle_kind):
			leaves.append(leaf)
	return leaves


## Opens the doors beside the platform once it stands there, and shuts them in time to leave.
func _move_doors(delta: float) -> void:
	if _door_leaves.is_empty():
		return
	var at_platform := _stands_at_stopping_spot()
	var at_end := _route_ended and speed < STANDING_SPEED and _distance > _end_of_track() - END_MARGIN
	var open := (at_platform or at_end) and _dwell_clock > door_delay and _dwell_clock < dwell_time - door_time - door_delay
	if open and _door_amount == 0.0:
		_opening_leaves = _leaves_beside_platform(_waiting_before.y if at_platform else _route_cells[-1].y)
	var amount := move_toward(_door_amount, 1.0 if open else 0.0, delta / door_time)
	if amount == _door_amount:
		return
	_door_amount = amount
	var stepped := minf(amount / DOOR_STEP_SHARE, 1.0)
	var slid := maxf(amount - DOOR_STEP_SHARE, 0.0) / (1.0 - DOOR_STEP_SHARE)
	for leaf in _opening_leaves:
		(leaf.node as Node3D).position = leaf.closed + leaf.outward * DOOR_STEP_OUT * smoothstep(0.0, 1.0, stepped) \
			+ leaf.slide * DOOR_LEAF_VOXELS * VOXEL * smoothstep(0.0, 1.0, slid)


## The route distances start again from the first cell it keeps: so does its stopping spot.
func _drop_passed_cells() -> void:
	var distance_before := _distance
	super()
	_stop_at -= distance_before - _distance


## True once it stands still at the spot it brakes for at a platform.
func _stands_at_stopping_spot() -> bool:
	return _waiting_before != NO_CELL and speed < STANDING_SPEED and _distance > _stop_at - PLATFORM_MARGIN


## Where car `index` of _cars rides: between its two bogies on the route.
func _car_transform(index: int) -> Transform3D:
	return _transform_between_bogies(_distance - (car_length + car_gap) * (index + 1))


## The first car rides on its two bogies too, not with an axle pulled behind it.
func _place(_delta := 0.0) -> void:
	global_transform = _transform_between_bogies(_distance)


## A car with its middle at route distance `centre`: both bogies on the track.
func _transform_between_bogies(centre: float) -> Transform3D:
	var reach := car_length * 0.5 - bogie_inset
	var front := _route_point(centre + reach)
	var rear := _route_point(centre - reach)
	var forward := front - rear
	if forward.length_squared() < 0.01:
		forward = global_basis.z
	return Transform3D(Basis.looking_at(-forward, Vector3.UP), (front + rear) * 0.5)


func _measure_length() -> void:
	super()
	_corner_lead = CORNER_REACH
	var train_length := (car_length + car_gap) * (car_models.size() + 1) + car_length
	_cells_kept_behind = ceili(train_length / RoadNetwork.CELL) + 2


func _physics_process(delta: float) -> void:
	if _stands_at_stopping_spot():
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
	_move_doors(delta)
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
	_leaving_platform = _stands_at_platform()
	speed = 0.0
	acceleration_now = 0.0
	_plan()
	_place()
	_snap_body()
	for index in _cars.size():
		_car_current[index] = _car_transform(index)
		_car_previous[index] = _car_current[index]
		_cars[index].global_transform = _car_current[index]


## On a track of its own it may ride the rails both ways.
func _ways_out(cell: Vector3i) -> Array[Vector2i]:
	return network.rail_headings(cell) if own_track else super(cell)


## On a track of its own it never moves over to the one beside it.
func _move_over(cell: Vector3i, heading: Vector2i) -> bool:
	return false if own_track else super(cell, heading)


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
	if _leaving_platform:
		_leaving_platform = false
		_served = to_cell
		return ""
	if _waiting_before != NO_CELL and _waiting_before != to_cell:
		return ""   # a platform further on, after this one
	_waiting_before = to_cell
	_stop_at = _distance + distance
	return "platform"


## True if the route cell under the first car lies beside a platform.
func _stands_at_platform() -> bool:
	for index in range(_route_distances.size() - 1, -1, -1):
		if _route_distances[index] <= _distance:
			var heading: Vector2i = _route_headings[index]
			return _beside_platform(_route_cells[index], Vector3i(heading.x, 0, heading.y))
	return false


func _beside_platform(cell: Vector3i, direction: Vector3i) -> bool:
	var ground_heading := Vector2i(signi(direction.x), signi(direction.z))
	for side in [Vector2i(ground_heading.y, -ground_heading.x), Vector2i(-ground_heading.y, ground_heading.x)]:
		if network.is_platform_for(Vector3i(cell.x + side.x, cell.y, cell.z + side.y), vehicle_kind):
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
	for index in _car_current.size():
		var frame := _car_current[index]
		var box := _car_boxes[index]
		if _line_covers(centre, frame * Vector3(0.0, 0.0, box.end.z), frame * Vector3(0.0, 0.0, box.position.z)):
			return true
	return false


func _reach() -> float:
	return (car_length + car_gap) * (_cars.size() + 1)


func _footprints(margin: float) -> Array:
	var rectangles := super(margin)
	for index in _car_current.size():
		rectangles.append(_box_rectangle(_car_current[index], _car_boxes[index], margin))
	return rectangles
