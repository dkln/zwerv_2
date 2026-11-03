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
## Windows: the glass of the model gets dark tinted glass with a broad sun glint and a
## sheen that slides over it as the vehicle moves (voxel_glass.gdshader), no mirroring.
## Lamps (glowing blocks over the lamp voxels of the model, at the `*_positions`):
## - headlights, with a spotlight on the road, once it gets dark (the Dagcyclus node);
## - tail lights, dim at night, bright as brake lights while it brakes or stands still;
## - indicators (left: x > 0, right: x < 0, as the vehicle faces +Z), blinking from
##   INDICATE_AHEAD metres before a turn at a crossing, before moving over into another
##   lane and before turning round, until it has gone round; not for bends in the road.

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
@export_group("Lamps")
## Centres (metres on the vehicle) and size of the lamp blocks; empty = no such lamps.
@export var headlight_positions := PackedVector3Array()
@export var headlight_size := Vector3(0.3, 0.12, 0.03)
@export var tail_light_positions := PackedVector3Array()
@export var tail_light_size := Vector3(0.3, 0.2, 0.03)
@export var indicator_positions := PackedVector3Array()
@export var indicator_size := Vector3(0.1, 0.1, 0.1)
## From this darkness (0 = day, 1 = night, the Dagcyclus node) the headlights are on.
@export_range(0.0, 1.0) var lights_on_from := 0.35

## Material of the wheels: draws and turns the spokes (the wheel model stays still).
const WHEEL_SHADER = preload("res://addons/vox_tiles/materials/voxel_wheel.gdshader")
## Metres before a turn, a moving over or a turning round from which it indicates.
const INDICATE_AHEAD := 30.0
## Seconds of one blink of the indicators (on and off).
const BLINK_TIME := 0.7
## Metres past the corner cell's centre before the indicator stops (it has gone round).
const INDICATE_AFTER := 2.5
## Lamp colours and brightness (emission energy); the brake light is the tail light, brighter.
const HEADLIGHT_COLOUR := Color(1.0, 0.97, 0.88)
const TAIL_COLOUR := Color(1.0, 0.08, 0.04)
const INDICATOR_COLOUR := Color(1.0, 0.5, 0.05)
const TAIL_ENERGY := 1.2
const BRAKE_ENERGY := 6.0
## Below this speed (m/s) a vehicle counts as standing still (brake lights on).
const STANDING_SPEED := 0.3
## Seconds the brake lights stay on after it last slowed down (no flicker in a corner).
const BRAKE_HOLD := 0.4
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
## The drawn body (model and wheels), placed every frame between the last two physics
## steps, so the vehicle moves smoothly at any frame rate while it drives at a fixed step.
var _body: Node3D
var _tick_previous := Transform3D.IDENTITY   # vehicle transform after the previous physics step
var _tick_current := Transform3D.IDENTITY    # and after the last one
var _roll_previous := 0.0       # wheel roll and steering after the previous physics step
var _steering_previous := 0.0
var _day_cycle: Node                 # the Dagcyclus node (how dark it is), if any
var _headlights: Array[MeshInstance3D] = []
var _tail_lights: Array[MeshInstance3D] = []
var _indicators: Array[MeshInstance3D] = []
var _beam: SpotLight3D               # the headlights' light on the road
var _tail_material: StandardMaterial3D
## Set every physics step: braking (or standing still), and the side it indicates
## (-1 left, 1 right, 0 none).
var braking_now := false
var indicating := 0
var _brake_hold := 0.0                # seconds the brake lights stay on


func _ready() -> void:
	var root := owner if owner else get_parent()
	network = RoadNetwork.of(root)
	_lights = root.get_node_or_null("Verkeerslichten") if obeys_lights else null
	_random.seed = route_seed
	var props := root.get_node_or_null("Props") as GridMap
	_body = Node3D.new()
	_body.name = "Carrosserie"
	_body.top_level = true
	add_child(_body)
	_add_model(props)
	_add_wheels(props)
	_add_lamps()
	_day_cycle = root.get_node_or_null("Dagcyclus")
	if network.is_empty():
		set_physics_process(false)
		_snap_body()
		return
	var first := network.nearest(start_cell, start_heading)
	_append(first - Vector3i(start_heading.x, 0, start_heading.y), start_heading)
	_append(first, start_heading)
	_distance = _route_distances[1]
	_plan()
	_place()
	_last_yaw = global_basis.get_euler().y
	_snap_body()


func _physics_process(delta: float) -> void:
	_tick_previous = _tick_current
	var speed_before := speed
	_plan()
	var target := _target_speed(delta)
	if speed < target:
		speed = minf(target, speed + acceleration * delta)
	else:
		speed = maxf(target, speed - braking * 1.5 * delta)
	var standing := speed < STANDING_SPEED and target < STANDING_SPEED
	_brake_hold = BRAKE_HOLD if speed < speed_before - 0.0001 else maxf(_brake_hold - delta, 0.0)
	braking_now = standing or _brake_hold > 0.0
	var before := global_position
	_distance += speed * delta
	_drop_passed_cells()
	_place()
	velocity = (global_position - before) / maxf(delta, 0.0001)
	_tick_current = global_transform
	_turn_wheels(speed * delta, delta)
	indicating = _indicator_side()


## Draws the body between the last two physics steps (the frame rate differs from the
## physics rate, so placing it at the last step would make it judder).
func _process(delta: float) -> void:
	var fraction := Engine.get_physics_interpolation_fraction()
	_body.global_transform = _tick_previous.interpolate_with(_tick_current, fraction)
	var roll := lerp_angle(_roll_previous, _wheel_roll, fraction)
	var steering := lerpf(_steering_previous, _steering, fraction)
	# the spokes blur once the wheel turns more than about a quarter radian a frame (they
	# would seem to stand still or run backwards); delta is this frame's time
	var turn_per_frame := speed / maxf(wheel_radius, 0.01) * delta
	var blur := smoothstep(0.25, 0.7, turn_per_frame)
	for wheel in _wheels:
		wheel.rotation.y = steering if wheel.position.z > 0.0 and max_steering_degrees > 0.0 else 0.0
		var instance := wheel.get_child(0) as GeometryInstance3D
		# the wheel model itself never turns: voxel_wheel.gdshader turns its spokes
		instance.set_instance_shader_parameter("roll", -roll)
		instance.set_instance_shader_parameter("spin_blur", blur)
	_update_lamps()


## Where the vehicle is drawn this frame (for a camera that follows it).
func drawn_position() -> Vector3:
	return _body.global_position if _body else global_position


## Puts the body on the vehicle without interpolation (at the start).
func _snap_body() -> void:
	_tick_previous = global_transform
	_tick_current = global_transform
	_body.global_transform = global_transform


# ------------------------------------------------------------------ lamps

## The lamp blocks (hidden until they are on) and the headlight beam.
func _add_lamps() -> void:
	for position in headlight_positions:
		_headlights.append(_lamp(position, headlight_size, _glow(HEADLIGHT_COLOUR, 3.0)))
	_tail_material = _glow(TAIL_COLOUR, TAIL_ENERGY)
	for position in tail_light_positions:
		_tail_lights.append(_lamp(position, tail_light_size, _tail_material))
	var indicator_material := _glow(INDICATOR_COLOUR, 5.0)
	for position in indicator_positions:
		_indicators.append(_lamp(position, indicator_size, indicator_material))
	if not headlight_positions.is_empty():
		_beam = SpotLight3D.new()
		_beam.name = "Koplampen"
		var front := 0.0
		for position in headlight_positions:
			front = maxf(front, position.z)
		_beam.position = Vector3(0.0, headlight_positions[0].y + 0.2, front)
		# pointing ahead and a little down (a spotlight shines along its -Z)
		_beam.basis = Basis.looking_at(Vector3(0.0, -0.25, 1.0))
		_beam.light_color = HEADLIGHT_COLOUR
		_beam.light_energy = 6.0
		_beam.spot_range = 22.0
		_beam.spot_angle = 32.0
		_beam.spot_attenuation = 0.6
		_beam.shadow_enabled = false
		_beam.visible = false
		_body.add_child(_beam)


func _glow(colour: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = energy
	return material


func _lamp(centre: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var lamp := MeshInstance3D.new()
	lamp.mesh = box
	lamp.material_override = material
	lamp.position = centre
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.visible = false
	_body.add_child(lamp)
	return lamp


## Switches the lamps by the light of day, the braking and the indicating (every frame).
func _update_lamps() -> void:
	var night: float = _day_cycle.get("night") if _day_cycle else 0.0
	var lights_on := night >= lights_on_from
	for lamp in _headlights:
		lamp.visible = lights_on
	if _beam:
		_beam.visible = lights_on
	for lamp in _tail_lights:
		lamp.visible = lights_on or braking_now
	if _tail_material:
		_tail_material.emission_energy_multiplier = BRAKE_ENERGY if braking_now else TAIL_ENERGY
	var blink_on := fmod(Time.get_ticks_msec() / 1000.0, BLINK_TIME) < BLINK_TIME * 0.5
	for lamp in _indicators:
		var on_left := lamp.position.x > 0.0
		lamp.visible = blink_on and indicating != 0 and on_left == (indicating < 0)


## The side the vehicle should indicate now: -1 left, 1 right, 0 none. Looks along the
## planned route up to INDICATE_AHEAD metres for the first turn at a crossing, moving
## over into the lane alongside, or turning round; keeps indicating until it is past.
func _indicator_side() -> int:
	var last := _route_cells.size() - 1
	for index in range(1, last + 1):
		var at := _route_distances[index]
		if at - _distance > INDICATE_AHEAD:
			break
		if _distance > at + INDICATE_AFTER:
			continue   # already gone round
		var heading := _route_headings[index - 1]
		var side := 0
		if _route_headings[index] != heading:
			# a change of heading: a turn at a crossing, or part of turning round
			var turning_round := false
			for later in range(index, mini(index + 3, last + 1)):
				turning_round = turning_round or _route_headings[later] == -heading
			if turning_round:
				side = -1   # turning round goes over the left (driving on the right)
			elif network.is_crossing(_route_cells[index]) or network.is_crossing(_route_cells[index - 1]):
				side = _side_of(heading, _route_headings[index])
		else:
			# the same heading but a step sideways: moving over into the lane alongside
			var step := _route_cells[index] - _route_cells[index - 1]
			side = _side_of(heading, Vector2i(step.x, step.z))
		if side != 0:
			return side
	return 0


## Side of `towards` relative to `heading` (map x and z): 1 right, -1 left, 0 ahead or behind.
static func _side_of(heading: Vector2i, towards: Vector2i) -> int:
	return signi(heading.x * towards.y - heading.y * towards.x)


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
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface) as ShaderMaterial
		if material and material.shader and material.shader.resource_path.ends_with("voxel_glass.gdshader"):
			var windows := material.duplicate() as ShaderMaterial
			windows.set_shader_parameter("interior", 0.0)
			windows.set_shader_parameter("reflection", 0.05)
			windows.set_shader_parameter("depth", 0.1)
			windows.set_shader_parameter("glint_roughness", 0.1)
			windows.set_shader_parameter("sheen", 0.4)
			instance.set_surface_override_material(surface, windows)
	_body.add_child(instance)


## The wheels: per position a pivot (steers about y) holding the wheel mesh centred on
## it. The mesh does not roll: its material (voxel_wheel.gdshader) turns the spokes.
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
	var material := ShaderMaterial.new()
	material.shader = WHEEL_SHADER
	var box := mesh.get_aabb()
	material.set_shader_parameter("centre", box.get_center())
	# the axle is the thinnest side of the wheel (in the mesh's own coordinates)
	var axle_index := box.size.min_axis_index()
	var axle := Vector3.ZERO
	axle[axle_index] = 1.0
	material.set_shader_parameter("axle", axle)
	for wheel_index in wheel_positions.size():
		var pivot := Node3D.new()
		pivot.name = "Wiel%d" % (wheel_index + 1)
		pivot.position = wheel_positions[wheel_index]
		var instance := MeshInstance3D.new()
		instance.name = "Band"
		instance.mesh = mesh
		instance.material_override = material
		instance.transform = Transform3D(mesh_transform.basis, mesh_transform.origin - middle)
		pivot.add_child(instance)
		_body.add_child(pivot)
		_wheels.append(pivot)


## Rolls the wheels over the distance driven and steers the front ones: the angle that
## makes a vehicle with this wheelbase follow the curve it is driving (its turn rate per
## metre).
func _turn_wheels(distance_driven: float, delta: float) -> void:
	if _wheels.is_empty():
		return
	_roll_previous = _wheel_roll
	_steering_previous = _steering
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
	# the wheels themselves are turned every frame in _process, between this step and the last
