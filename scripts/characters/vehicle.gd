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
## Other vehicles: it keeps behind a vehicle on the cells ahead of it (brakes and stops
## behind it) and gives way on a crossing to a vehicle that will be there first. If two
## vehicles touch all the same, they crash: each becomes a RigidBody3D (a "Wrak") with its
## speed and mass, so they bounce off each other and off the colliders of the town (the
## kerbs, medians and buildings of the GridMaps), spin and slide out, hazard lights
## blinking; after WRECK_TIME seconds they are towed back onto the nearest lane and
## drive on. drive_into() sends a vehicle the wrong way down another one's route, without
## looking (the demo crash, key B in the follow camera).
## Windows: the glass of the model gets dark tinted glass that mirrors the sky, more at a
## grazing angle, with a sharp sun glint and light streaks that lie on the car itself
## (voxel_glass.gdshader, streaks_on_object: world streaks would slide over its windows).
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
## How quickly the acceleration may change (m/s³): a driver eases onto the throttle and
## the brake (no jolt); easing off and braking go faster than speeding up again.
@export var throttle_rate := 3.0
@export var brake_rate := 12.0
@export_group("Rules")
## Kind of vehicle, for lanes only some kinds may use (a bus lane: "bus").
@export var vehicle_kind := "auto"
## Stops for traffic lights.
@export var obeys_lights := true
## Seconds it waits before a zebra crossing without traffic lights.
@export var zebra_wait := 1.5
## Chance (0..1) to go straight on where it could also turn (before its memory of the
## roads it has driven weighs in, see _choose_heading).
@export var straight_chance := 0.6
## How strongly it avoids roads it has driven lately (0 = not at all).
@export var variety := 4.0
@export_group("Traffic")
## Brakes for other vehicles ahead and gives way on crossings.
@export var avoids_others := true
## Mass for the crash (kg).
@export var mass_kg := 1300.0
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
@export var max_steering_degrees := 20.0
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
## Planned cells back over which it never picks the opposite heading (no U-turns at forks).
const U_TURN_CELLS := 6
## Cells it looks ahead along each way out of a fork to see how much it has driven there.
const VISIT_LOOKAHEAD := 8
## Cells it remembers; past that the memory is halved (old routes fade).
const VISIT_MEMORY := 600
## Fastest the body turns (rad/s), also when its route swings round at once.
const MAX_TURN_RATE := 3.0
## Metres ahead along its route it looks for other vehicles, and how far ahead (in
## seconds of driving) a crossing counts as claimed by a vehicle heading for it.
const TRAFFIC_LOOKAHEAD := 40.0
const CLAIM_SECONDS := 4.0
## Metres it keeps from the back of a vehicle it stops behind.
const TRAFFIC_GAP := 0.5
## Seconds a crash lasts before the wrecks are towed back onto the road.
const WRECK_TIME := 8.0
## Metres added round the bodies when testing for a crash (they touch in the next step).
const CRASH_MARGIN := 0.25
## Speed (m/s) of a vehicle sent down another one's route (drive_into).
const RECKLESS_SPEED := 11.0
## Seconds in which it closes a gap between its speed and the speed it may drive.
const SPEED_SETTLE := 0.5
## Metres per second over the speed it may drive from which it brakes without easing in.
const BRAKE_SLACK := 1.5
## Metres over which the corners of the route are rounded off.
const ROUNDING := 1.6
## Metres it plans ahead at least, beyond what it needs to brake to a stop.
const PLAN_MARGIN := 16.0
## Cells forward over which it moves over into the lane alongside, longest first.
const MOVE_OVER_CELLS := [3, 2, 1]
## Metres before the centre of a corner cell from which it keeps to its corner speed, and
## after it until it drives on.
const CORNER_REACH := 2.0

## Every vehicle in the game (for keeping clear of each other and crashing).
static var all_vehicles: Array[Vehicle] = []

## Crashed: a wreck under physics until it is towed back onto the road.
var crashed := false
## Drives without looking: no lights, no other vehicles (drive_into).
var reckless := false
var _wreck: RigidBody3D
var _wreck_clock := 0.0
var _body_size := Vector3(1.75, 1.5, 4.5)   # width, height (from the road), length

## Current speed (m/s) and velocity, for the camera.
var speed := 0.0
## Current acceleration (m/s², negative while braking), eased (throttle_rate, brake_rate).
var acceleration_now := 0.0
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
var _visits := {}                    # Vector3i cell -> times driven over (fades, VISIT_MEMORY)
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
	all_vehicles.append(self)
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
	# the acceleration that brings it to the target speed in about SPEED_SETTLE seconds,
	# reached gradually; never past the target speed
	var wanted := clampf((target - speed) / SPEED_SETTLE, -braking * 1.5, acceleration)
	var rate := brake_rate if wanted < acceleration_now else throttle_rate
	acceleration_now = move_toward(acceleration_now, wanted, rate * delta)
	if speed > target + BRAKE_SLACK:
		# well over the speed it may drive (a light turned red, a sharp corner seen late):
		# brakes at once, as hard as needed
		acceleration_now = minf(acceleration_now, wanted)
	if target > speed:
		speed = minf(target, speed + maxf(acceleration_now, 0.0) * delta)
	else:
		speed = maxf(target, speed + minf(acceleration_now, 0.0) * delta)
	var standing := speed < STANDING_SPEED and target < STANDING_SPEED
	_brake_hold = BRAKE_HOLD if speed < speed_before - 0.0001 else maxf(_brake_hold - delta, 0.0)
	braking_now = standing or _brake_hold > 0.0
	var before := global_position
	_distance += speed * delta
	_drop_passed_cells()
	_place(delta)
	velocity = (global_position - before) / maxf(delta, 0.0001)
	_tick_current = global_transform
	_check_crash()
	_turn_wheels(speed * delta, delta)
	indicating = _indicator_side()


func _exit_tree() -> void:
	all_vehicles.erase(self)


## Draws the body between the last two physics steps (the frame rate differs from the
## physics rate, so placing it at the last step would make it judder).
func _process(delta: float) -> void:
	if crashed:
		_follow_wreck(delta)
		return
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
		# a wreck: the hazard lights (all indicators at once)
		lamp.visible = blink_on and (crashed or (indicating != 0 and on_left == (indicating < 0)))


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
## By default: straight on with `straight_chance`, else one of the turns, each weighed
## down by how much it has driven the road that way lately (`variety`), so it explores
## the town instead of driving the same loop.
func _choose_heading(cell: Vector3i, heading: Vector2i, options: Array[Vector2i]) -> Vector2i:
	var turn_count := options.size() - (1 if options.has(heading) else 0)
	var weights: Array[float] = []
	var total := 0.0
	for option in options:
		var base := 1.0
		if options.has(heading):
			base = straight_chance if option == heading else (1.0 - straight_chance) / maxf(turn_count, 1.0)
		var weight := base / (1.0 + variety * _visited_ahead(cell, option))
		weights.append(weight)
		total += weight
	var pick := _random.randf() * total
	for index in options.size():
		pick -= weights[index]
		if pick <= 0.0:
			return options[index]
	return options[-1]


## Average number of times it drove the cells along `heading` from `cell` (up to
## VISIT_LOOKAHEAD cells, straight on).
func _visited_ahead(cell: Vector3i, heading: Vector2i) -> float:
	var total := 0.0
	var here := cell
	for step in VISIT_LOOKAHEAD:
		here = network.step(here, heading)
		if here == RoadNetwork.NONE:
			break
		total += _visits.get(here, 0)
	return total / VISIT_LOOKAHEAD


## Counts a cell it drove over; halves the whole memory once it holds too many cells.
func _remember(cell: Vector3i) -> void:
	_visits[cell] = _visits.get(cell, 0) + 1
	if _visits.size() > VISIT_MEMORY:
		for key in _visits.keys():
			_visits[key] = _visits[key] / 2
			if _visits[key] == 0:
				_visits.erase(key)


## Why it must stop before driving from `from_cell` into `to_cell` ("" = it may go):
## "light" for a red or amber light (amber only when it can still stop in `distance`
## metres), "zebra" for a zebra crossing without lights it has not yet waited at.
## Never inside a crossing.
func _must_stop(from_cell: Vector3i, to_cell: Vector3i, distance: float) -> String:
	if reckless or network.is_crossing(from_cell):
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
		_remember(_route_cells[1])
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
			var entered := _crossing_entry_heading()
			for option in network.lanes(next_cell):
				if option == -heading or not _may_use(next_cell, option) or network.step(next_cell, option) == RoadNetwork.NONE:
					continue
				# on a crossing it turns once at most, and never back where it came from
				if network.is_crossing(next_cell) and entered != Vector2i.ZERO \
						and (option == -entered or (heading != entered and option != heading)):
					continue
				if _doubles_back(option):
					continue
				options.append(option)
		if options.is_empty():
			if not _move_over(cell, heading):
				_turn_round(cell, heading)
			continue
		var next_heading: Vector2i = options[0]
		if options.size() > 1:
			next_heading = _choose_heading(next_cell, heading, options)
		_append(next_cell, next_heading)


## True if `heading` points back the way it drove the last few planned cells (a U-turn
## made of two turns close after each other, such as over a wide junction).
func _doubles_back(heading: Vector2i) -> bool:
	for index in range(maxi(0, _route_headings.size() - U_TURN_CELLS), _route_headings.size()):
		if _route_headings[index] == -heading:
			return true
	return false


## Heading it drove onto the crossing it is planning through now (the last planned cells
## that are crossing cells); ZERO when the last planned cell is not on a crossing.
func _crossing_entry_heading() -> Vector2i:
	var index := _route_cells.size() - 1
	if not network.is_crossing(_route_cells[index]):
		return Vector2i.ZERO
	while index > 0 and network.is_crossing(_route_cells[index - 1]):
		index -= 1
	return _route_headings[index - 1] if index > 0 else _route_headings[index]


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
	if reckless:
		return minf(target, RECKLESS_SPEED)
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
	if avoids_others:
		target = minf(target, _traffic_speed(index, last))
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


## Puts the vehicle on its route; delta 0 = at once (at the start).
func _place(delta := 0.0) -> void:
	# rounded corners: the mean of the route a little behind and ahead; the height of
	# the road right under it (the mean would cut through the top of a ramp)
	var position_now := (_route_point(_distance - ROUNDING) + _route_point(_distance + ROUNDING)) * 0.5
	position_now.y = _route_point(_distance).y
	var forward := _route_point(_distance + 2.0) - _route_point(_distance - 2.0)
	global_position = position_now
	if Vector2(forward.x, forward.z).length() > 0.01:
		var wanted := Quaternion(Basis.looking_at(-forward, Vector3.UP))
		var now := Quaternion(global_basis.orthonormalized())
		var angle := now.angle_to(wanted)
		# turning round in a narrow street the route swings round at once: the body turns
		# at MAX_TURN_RATE at most, so it never flips
		if delta > 0.0 and angle > MAX_TURN_RATE * delta:
			wanted = now.slerp(wanted, MAX_TURN_RATE * delta / angle)
		global_basis = Basis(wanted)


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
	_body_size = Vector3(box.size.x, model_lift + box.size.y, box.size.z)
	var instance := MeshInstance3D.new()
	instance.name = "Model"
	instance.mesh = mesh
	instance.transform = Transform3D(mesh_transform.basis, mesh_transform.origin - Vector3(middle.x, box.position.y - model_lift, middle.z))
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface) as ShaderMaterial
		if material and material.shader and material.shader.resource_path.ends_with("voxel_glass.gdshader"):
			# dark tinted car glass that mirrors the sky a little (more at a grazing angle)
			# with a sharp sun glint and light streaks that lie on the car itself (world
			# streaks would slide over the windows of a moving car all the time)
			var windows := material.duplicate() as ShaderMaterial
			windows.set_shader_parameter("interior", 0.0)
			windows.set_shader_parameter("reflection", 0.08)
			windows.set_shader_parameter("depth", 0.1)
			windows.set_shader_parameter("glint_roughness", 0.06)
			windows.set_shader_parameter("streaks", 0.25)
			windows.set_shader_parameter("streaks_on_object", 1.0)
			windows.set_shader_parameter("sheen", 0.0)
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


# ------------------------------------------------------------------ other vehicles

## Highest speed for the other vehicles ahead: it stops behind the first planned cell
## (within TRAFFIC_LOOKAHEAD) that another vehicle stands on, or a crossing cell that
## another vehicle will reach first (it gives way).
func _traffic_speed(index: int, last: int) -> float:
	var target := INF
	for ahead_index in range(index + 1, last + 1):
		var at := _route_distances[ahead_index]
		if at - _distance > TRAFFIC_LOOKAHEAD:
			break
		var cell := _route_cells[ahead_index]
		var my_time := (at - _distance) / maxf(speed, 1.0)
		var blocked := false
		for other in all_vehicles:
			if other == self:
				continue
			if other.covers(cell):
				blocked = true
			elif network.is_crossing(cell) and not other.crashed and other.speed > 0.5:
				var their_distance := other.distance_to(cell)
				if their_distance >= 0.0:
					var their_time := their_distance / maxf(other.speed, 1.0)
					var first := their_time < my_time - 0.2 or (absf(their_time - my_time) <= 0.2 and other.get_instance_id() < get_instance_id())
					blocked = their_time < CLAIM_SECONDS and first
			if blocked:
				break
		if blocked:
			var stop_at := (_route_distances[ahead_index - 1] + at) * 0.5 - half_length - TRAFFIC_GAP
			target = _approach_speed(0.0, stop_at)
			if stop_at - _distance < 0.4:
				target = 0.0
			break
	return target


## True if the vehicle stands on (part of) this road cell (a wreck: the cell under it).
func covers(cell: Vector3i) -> bool:
	var spot := _body.global_position if crashed else global_position
	var reach := _body_size.z * 0.5 + 0.5
	var centre := network.centre(cell)
	if absi(cell.y - roundi(spot.y)) > 3:
		return false
	var forward := (_body.global_basis if crashed else global_basis).z
	for along in [-reach, 0.0, reach]:
		var point: Vector3 = spot + forward * along
		if absf(point.x - centre.x) <= RoadNetwork.CELL * 0.5 and absf(point.z - centre.z) <= RoadNetwork.CELL * 0.5:
			return true
	return false


## Metres along its route to the centre of `cell`; -1 if it has not planned it ahead.
func distance_to(cell: Vector3i) -> float:
	for index in range(_route_cells.size()):
		if _route_cells[index] == cell and _route_distances[index] >= _distance - 1.0:
			return maxf(_route_distances[index] - _distance, 0.0)
	return -1.0


## Crashes into every vehicle whose body touches this one's (within CRASH_MARGIN).
func _check_crash() -> void:
	for other in all_vehicles:
		if other == self or other.crashed or crashed:
			continue
		if global_position.distance_to(other.global_position) > (_body_size.z + other._body_size.z) * 0.5 + 1.0:
			continue
		if _overlaps(other):
			var impact := velocity
			var their_impact := other.velocity
			_become_wreck(impact)
			other._become_wreck(their_impact)


## True if the bodies (rectangles seen from above, CRASH_MARGIN larger) overlap
## (separating axis test on the four side directions).
func _overlaps(other: Vehicle) -> bool:
	var mine := _corners(CRASH_MARGIN)
	var theirs := other._corners(CRASH_MARGIN)
	for axis in [Vector2(global_basis.x.x, global_basis.x.z), Vector2(global_basis.z.x, global_basis.z.z),
			Vector2(other.global_basis.x.x, other.global_basis.x.z), Vector2(other.global_basis.z.x, other.global_basis.z.z)]:
		var my_range := Vector2(INF, -INF)
		var their_range := Vector2(INF, -INF)
		for corner in mine:
			var along: float = corner.dot(axis)
			my_range = Vector2(minf(my_range.x, along), maxf(my_range.y, along))
		for corner in theirs:
			var along: float = corner.dot(axis)
			their_range = Vector2(minf(their_range.x, along), maxf(their_range.y, along))
		if my_range.y < their_range.x or their_range.y < my_range.x:
			return false
	return true


## The four corners of the body seen from above (x, z), `margin` metres larger.
func _corners(margin: float) -> Array[Vector2]:
	var across := Vector2(global_basis.x.x, global_basis.x.z) * (_body_size.x * 0.5 + margin)
	var along := Vector2(global_basis.z.x, global_basis.z.z) * (_body_size.z * 0.5 + margin)
	var middle := Vector2(global_position.x, global_position.z)
	return [middle + across + along, middle + across - along, middle - across + along, middle - across - along]


## Hands the body to the physics engine: a RigidBody3D with a box the size of the body,
## its mass and its speed, that hits the other wreck and the colliders of the town.
func _become_wreck(impact: Vector3) -> void:
	crashed = true
	reckless = false
	speed = 0.0
	braking_now = false
	indicating = 0
	set_physics_process(false)
	_wreck = RigidBody3D.new()
	_wreck.name = "Wrak"
	_wreck.mass = mass_kg
	_wreck.continuous_cd = true
	var material := PhysicsMaterial.new()
	material.friction = 0.7
	material.bounce = 0.15
	_wreck.physics_material_override = material
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_body_size.x, _body_size.y - 0.05, _body_size.z)
	shape.shape = box
	shape.position = Vector3(0.0, _body_size.y * 0.5 + 0.03, 0.0)
	_wreck.add_child(shape)
	# lower centre of mass (engine and floor), so it slides and spins more than it rolls
	_wreck.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	_wreck.center_of_mass = Vector3(0.0, _body_size.y * 0.3, 0.0)
	get_parent().add_child(_wreck)
	_wreck.global_transform = global_transform
	_wreck.linear_velocity = impact
	_wreck_clock = 0.0


## While crashed: the body sits on the wreck; after WRECK_TIME it is towed back.
func _follow_wreck(delta: float) -> void:
	_body.global_transform = _wreck.global_transform
	_update_lamps()
	_wreck_clock += delta
	if _wreck_clock >= WRECK_TIME:
		_tow()


## Puts the vehicle back on the nearest lane (facing the way its wreck faces) and lets it
## drive on.
func _tow() -> void:
	var spot := _wreck.global_position
	var facing := _wreck.global_basis.z   # the front of a body is along its +Z
	var heading := Vector2i(signi(roundi(facing.x)), 0) if absf(facing.x) > absf(facing.z) else Vector2i(0, signi(roundi(facing.z)))
	if heading == Vector2i.ZERO:
		heading = Vector2i(0, 1)
	_wreck.queue_free()
	_wreck = null
	crashed = false
	_route_cells.clear()
	_route_headings.clear()
	_route_distances.clear()
	_waited_at.clear()
	var first := network.nearest(Vector2i(floori(spot.x / RoadNetwork.CELL), floori(spot.z / RoadNetwork.CELL)), heading)
	_append(first - Vector3i(heading.x, 0, heading.y), heading)
	_append(first, heading)
	_distance = _route_distances[1]
	speed = 0.0
	acceleration_now = 0.0
	_plan()
	_place()
	_last_yaw = global_basis.get_euler().y
	_snap_body()
	set_physics_process(true)


## Sends this vehicle the wrong way down the route `other` has planned, from beyond its
## far end, without looking (no lights, no other vehicles): a head-on crash unless the
## other gets out of the way. The demo crash.
func drive_into(other: Vehicle) -> void:
	if crashed or other.crashed:
		return
	other._plan_ahead(55.0)
	var start := other._current_index() + 2
	var last := other._route_cells.size() - 1
	if last <= start:
		return
	_route_cells.clear()
	_route_headings.clear()
	_route_distances.clear()
	_waited_at.clear()
	var away := -other._route_headings[last]
	_append(other._route_cells[last] - Vector3i(away.x, 0, away.y), away)
	for index in range(last, start - 1, -1):
		_append(other._route_cells[index], -other._route_headings[index - 1])
	_distance = _route_distances[1]
	speed = RECKLESS_SPEED
	acceleration_now = 0.0
	reckless = true
	_place()
	_last_yaw = global_basis.get_euler().y
	_snap_body()


## Plans at least `metres` ahead.
func _plan_ahead(metres: float) -> void:
	var keep := speed
	speed = sqrt(maxf(0.0, 2.0 * braking * (metres - PLAN_MARGIN)))
	_plan()
	speed = keep
