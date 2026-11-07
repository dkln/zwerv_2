class_name Vehicle
extends Node3D
## A vehicle that drives round the road network on its own (scripts/world/road_network.gd,
## made from the lanes in the metadata of the ground tiles):
## the base of the car (car.gd), the bus (city_bus.gd), the van, the truck, ... (a tram
## on its own lanes could be one too). A vehicle type extends this script, sets its own speeds and model in
## _init (the scene's values still override them) and can override the hooks:
## - _may_use(cell, heading): lanes it may drive (all of them by default);
## - _may_continue(cell, arriving, leaving): ways it may go through a cell (rail_vehicle.gd);
## - _choose_heading(cell, heading, options): where it goes where it could also turn;
## - _must_stop(from_cell, to_cell, distance): why it stops before a cell.
##
## No physics and no gravity: the vehicle follows the lanes kinematically, which keeps it
## exactly in its lane, and rides on the road surface (up and down the ramps of a
## tunnel, tilted with the slope). Its route is a chain of cell centres, planned a few
## cells ahead. Like a real vehicle it turns about its rear axle: the front axle follows the
## route with the corners rounded off (the longer the wheelbase, the wider), the rear axle
## is pulled straight towards the front axle and so cuts the corner, and the body lies on
## the line between them. It keeps to the speed
## limit of the road it is on (and brakes in time for a lower one ahead), slows down for
## corners, and stops:
## - before a zebra crossing (weg/zebrapad), for `zebra_wait` seconds, then drives on;
## - at traffic lights (Verkeerslichten, scripts/world/traffic_lights.gd) until its
##   stream is green, before the zebra or the crossing, whichever comes first.
## Where its lane ends it moves over into the lane alongside, gradually over a few cells
## (a motorway losing a lane); at a dead end it turns round into the opposite lane.
## Model: the props library item `model`, centred on the node, front along +Z, lifted by
## `model_lift`; its wheels (item `wheel_model`, at `wheel_positions`) roll with the
## distance driven, and the front ones (positions with z > 0) point the way the front axle
## moves.
## Its outer size for the others and for a crash is that of everything drawn on it (body,
## wheels, tow bar, lamps; _outer_box), the same for the trailer (_trailer_box); as a wreck
## the trailer has a collider of its own that follows it.
## Trailer (`trailer_model`): a tow bar (`hitch_model`) on the back of the body and a trailer
## that pivots on its own point, the ball of the tow bar (`hitch_position`): each step its
## axle is pulled straight towards the ball (the way a real trailer follows), so it cuts
## the corners. It has its own wheels and lamps and counts as part of the vehicle for the
## others; in a crash it stays hooked on behind the wreck.
## Other vehicles: it keeps behind a vehicle on the cells ahead of it (brakes and stops
## behind it) and gives way on a crossing to a vehicle that will be there first. If two
## vehicles run into each other all the same (at CRASH_SPEED or faster, or one of them
## driving without looking; a scrape in a corner is not a crash), they crash: each becomes
## a RigidBody3D (a "Wrak") with its
## speed and mass, so they bounce off each other and off the colliders of the town (the
## kerbs, medians and buildings of the GridMaps), spin and slide out, hazard lights
## blinking; after WRECK_TIME seconds they are towed back onto the nearest lane and
## drive on. drive_into() sends a vehicle the wrong way down another one's route, without
## looking (the demo crash, key B in the follow camera).
## Weight and torque: `mass_kg` and `wheel_torque` differ per type, and a heavy vehicle has
## more of both. The torque over the mass gives its acceleration. In a crash the masses
## share the blow as momentum does (the light one takes most of the change of speed and
## the spin, the heavy one hardly notices), and the heavy one keeps rolling on its wheels
## with its engine still pushing for longer (ROLL_ON_*), shoving the light one ahead of it.
## Gridlock: vehicles that wait for each other in a ring (not in a queue for a light or a
## zebra) would stand there for ever, so after a while one squeezes past (SQUEEZE_TIME).
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
## Cells it looks ahead over a crossing for whether a heading leads on (see _leads_on).
const CROSSING_LOOKAHEAD := 4
## Speed through a corner (m/s).
@export var corner_speed := 4.5
## Speed through two corners right after each other: turning round, an S-bend (m/s).
@export var tight_corner_speed := 2.8
## Acceleration and braking (m/s²).
## Acceleration (m/s²) of a vehicle without a `wheel_torque`; else that sets it.
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
## Torque of the engine at the driven wheels (Nm), through the gears. Its pull is this over
## `wheel_radius`, which over the mass (with a trailer) gives the acceleration, and pushes on
## in a crash. 0 = it has none: `acceleration` is what it is.
@export var wheel_torque := 0.0
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
@export var max_steering_degrees := 40.0
## How quickly the steering follows the corner (1/s).
@export var steering_rate := 8.0
@export_group("Trailer")
## Props library item of the trailer, its coupling (the pivot) at the front; "" = none.
@export var trailer_model := ""
## Props library item of the tow bar on the back of the body.
@export var hitch_model := ""
## The ball of the tow bar on the vehicle (metres; x across, y up, z forwards).
@export var hitch_position := Vector3.ZERO
## Height of the lowest part of the trailer above the road (metres).
@export var trailer_lift := 0.375
## Metres from the coupling back to the axle of the trailer.
@export var trailer_axle_distance := 2.25
## Mass of the trailer (kg), added to the vehicle's in pulling away and in a crash.
@export var trailer_mass_kg := 0.0
## On the trailer, in metres: x across, y above the road, z forwards from the coupling.
@export var trailer_wheel_positions := PackedVector3Array()
@export var trailer_tail_light_positions := PackedVector3Array()
@export var trailer_tail_light_size := Vector3(0.25, 0.125, 0.03)
@export var trailer_indicator_positions := PackedVector3Array()
@export var trailer_indicator_size := Vector3(0.13, 0.13, 0.03)
@export_group("Lamps")
## Centres (metres on the vehicle) and size of the lamp blocks; empty = no such lamps.
@export var headlight_positions := PackedVector3Array()
@export var headlight_size := Vector3(0.3, 0.12, 0.03)
@export var tail_light_positions := PackedVector3Array()
@export var tail_light_size := Vector3(0.3, 0.2, 0.03)
@export var indicator_positions := PackedVector3Array()
@export var indicator_size := Vector3(0.1, 0.1, 0.1)
## Head and tail lamps burn by day too (a train, a tram).
@export var lamps_always_on := false
## The tail lights brighten while it brakes; off = they stay as they are.
@export var brake_lights := true
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
const VISIT_MEMORY := 1000
## Metres ahead along its route it looks for other vehicles, and how far ahead (in
## seconds of driving) a crossing counts as claimed by a vehicle heading for it.
const TRAFFIC_LOOKAHEAD := 40.0
const CLAIM_SECONDS := 4.0
## Metres it keeps from the back of a vehicle it stops behind.
const TRAFFIC_GAP := 0.5
## Square of the metres within which another vehicle matters at all (the look ahead along
## the route, and its claim on a crossing).
const NEAR_VEHICLES := 80.0
## Metres of height between two vehicles above which they cannot crash.
const CRASH_LEVEL_DIFFERENCE := 2.5
## Seconds a crash lasts before the wrecks are towed back onto the road.
const WRECK_TIME := 8.0
## Metres added round the bodies when testing for a crash (they touch in the next step).
const CRASH_MARGIN := 0.25
## Speed (m/s) at which they must close for touching to be a crash.
const CRASH_SPEED := 5.0
## How much of the closing speed comes back as bounce in a crash.
const CRASH_BOUNCE := 0.15
## Fastest a crash spins a wreck (rad/s).
const MAX_CRASH_SPIN := 6.0
## After a crash a wreck rolls on on its wheels (little friction, its engine pushing) for
## this many seconds, plus this per kg: a bus goes on for much longer than a small car.
const ROLL_ON_TIME := 0.6
const ROLL_ON_PER_KG := 0.00025
const ROLLING_FRICTION := 0.05
const SLIDING_FRICTION := 0.7
## Metres ahead of its nose it looks for the body of another vehicle (behind it in a lane),
## how much room it leaves it, and how much wider than itself the lane it looks along is.
const BODY_LOOKAHEAD := 12.0
const BODY_GAP := 1.0
const BODY_SIDE_ROOM := 0.2
## Seconds it waits for others in a ring before it squeezes past (and up to this much more,
## different per vehicle, so they don't all go at once), seconds that it ignores them then,
## and the seconds after which it does that anyway, ring or no ring.
const RING_PATIENCE := 5.0
const RING_PATIENCE_SPREAD := 8
const SQUEEZE_TIME := 6.0
const LOST_PATIENCE := 75.0
## Longest queue of vehicles it follows to see what they wait for.
const QUEUE_CHECK := 24
## Cells it looks along the road for a free spot when it is towed.
const TOW_SEARCH_CELLS := 12
## Speed (m/s) of a vehicle sent down another one's route (drive_into).
const RECKLESS_SPEED := 11.0
## Seconds in which it closes a gap between its speed and the speed it may drive.
const SPEED_SETTLE := 0.5
## Metres per second over the speed it may drive from which it brakes without easing in.
const BRAKE_SLACK := 1.5
## Metres before and after a point of the route over which the front axle's path is
## averaged, which rounds off the corners: the wheelbase plus CORNER_ROUNDING_EXTRA, within
## these limits.
const CORNER_ROUNDING_LEAST := 3.0
const CORNER_ROUNDING_MOST := 6.0
const CORNER_ROUNDING_EXTRA := 1.0
## Metres it plans ahead at least, beyond what it needs to brake to a stop.
const PLAN_MARGIN := 16.0
## Cells forward over which it moves over into the lane alongside, longest first.
const MOVE_OVER_CELLS := [3, 2, 1]
## Metres before the centre of a corner cell from which it keeps to its corner speed, and
## after it until it drives on.
const CORNER_REACH := 2.0
## Physics steps between looks at the other vehicles (each vehicle in its own step, so not
## all look at once; a sixth of a second at most goes by unseen).
const TRAFFIC_LOOK_STEPS := 4
## Largest angle (radians, about 80 degrees) between a trailer and its vehicle.
const MAX_TRAILER_ANGLE := 1.4
## Metres from the camera beyond which the wheels are not drawn (saves draw calls).
const WHEEL_DRAW_DISTANCE := 220.0
## Sideways and lengthways steps (metres) along a vehicle at which it claims the cell under it.
const COVER_STEP := 2.0

## Every vehicle in the game (for keeping clear of each other and crashing).
static var all_vehicles: Array[Vehicle] = []

## Crashed: a wreck under physics until it is towed back onto the road.
var crashed := false
## Drives without looking: no lights, no other vehicles (drive_into).
var reckless := false
var _wreck: RigidBody3D
var _wreck_clock := 0.0
var _roll_on_clock := 0.0            # seconds the wreck still rolls on
var _traffic_limit := INF            # speed the other vehicles allow, at the last look
var _traffic_blocker: Vehicle        # who it was waiting for at the last look
var _look_countdown := 0             # physics steps until the next look at the others
var _body_size := Vector3(1.75, 1.5, 4.5)   # width, height (from the road), length
var _outer_box := AABB(Vector3(-0.875, 0.0, -2.25), Vector3(1.75, 1.5, 4.5))  # around what is drawn on it, seen from its origin

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
var _turned_round_at := 0                    # planned cell where it last turned round at a dead end
var _route_ended := false                    # nothing to plan any more: the end of its track (rail_vehicle.gd)
var _waited_at := {}                         # zebra cells it has already waited at (until it passes them)
var _zebra_waiting := 0.0
var _lights: Node
var _random := RandomNumberGenerator.new()
var _visits := {}                    # Vector3i cell -> times driven over (fades, VISIT_MEMORY)
var _wheels: Array[Node3D] = []      # per wheel: the steering pivot, its child spins
var _wheel_roll := 0.0               # radians the wheels have turned
var _steering := 0.0                 # current steering angle (radians)
var _front_axle := 1.2               # where the axles are (metres forwards on the body)
var _rear_axle := -1.2
var _front_axle_spot := Vector2.ZERO # where they are now in the world (x, z)
var _rear_axle_spot := Vector2.ZERO
var _front_axle_motion := Vector2.ZERO  # how far the front axle moved in the last step
var _corner_rounding := CORNER_ROUNDING_LEAST  # metres, see the constant
var _corner_lead := CORNER_REACH     # metres before a corner from which it keeps to its corner speed
var _cells_kept_behind := 1          # planned cells it keeps behind it (a long one: more)
## The trailer: its body (placed like _body), the point of the road under its axle, what
## is drawn on it (on the trailer, from the coupling) and its transforms after the last
## two physics steps. _trailer_collider: its collider while it hangs behind a wreck.
var _trailer: Node3D
var _trailer_axle := Vector3.ZERO
var _trailer_box := AABB()
var _trailer_collider: AnimatableBody3D
var _trailer_previous := Transform3D.IDENTITY
var _trailer_current := Transform3D.IDENTITY
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
var _blocked_by: Vehicle             # the vehicle it is waiting for now, if any
var _held_by_rule := false           # it is stopping for a light or a zebra
var _blocked_clock := 0.0            # seconds it has been standing for another vehicle
var _squeeze_clock := 0.0            # seconds it still ignores the others (gridlock)


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
	_add_trailer(props)
	_add_wheels(props)
	_add_lamps()
	_measure_length()
	if wheel_torque > 0.0:
		acceleration = wheel_torque / maxf(wheel_radius, 0.01) / total_mass()
	_look_countdown = get_instance_id() % TRAFFIC_LOOK_STEPS
	_day_cycle = root.get_node_or_null("Dagcyclus")
	all_vehicles.append(self)
	if network.is_empty():
		set_physics_process(false)
		_snap_body()
		return
	var first := network.nearest(start_cell, start_heading, vehicle_kind)
	_append(first - Vector3i(start_heading.x, 0, start_heading.y), start_heading)
	_append(first, start_heading)
	_distance = _route_distances[1]
	_plan()
	_place()
	_snap_body()


func _physics_process(delta: float) -> void:
	_tick_previous = _tick_current
	var speed_before := speed
	_plan()
	var target := _target_speed(delta)
	_watch_for_gridlock(delta)
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
	_move_trailer()
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
	if _trailer:
		_trailer.global_transform = _trailer_previous.interpolate_with(_trailer_current, fraction)
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
	if _trailer:
		_move_trailer(true)
		_trailer.global_transform = _trailer_current


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
	if _trailer:
		var above_road := Vector3(0.0, hitch_position.y, 0.0)
		for position in trailer_tail_light_positions:
			_tail_lights.append(_lamp(position - above_road, trailer_tail_light_size, _tail_material, _trailer))
		for position in trailer_indicator_positions:
			_indicators.append(_lamp(position - above_road, trailer_indicator_size, indicator_material, _trailer))
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


func _lamp(centre: Vector3, size: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var lamp := MeshInstance3D.new()
	lamp.mesh = box
	lamp.material_override = material
	lamp.position = centre
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.visible = false
	(parent if parent else _body).add_child(lamp)
	return lamp


## Switches the lamps by the light of day, the braking and the indicating (every frame).
func _update_lamps() -> void:
	var night: float = _day_cycle.get("night") if _day_cycle else 0.0
	var lights_on := night >= lights_on_from
	var lamps_on := lights_on or lamps_always_on
	var braking_shows := brake_lights and braking_now
	for lamp in _headlights:
		lamp.visible = lamps_on
	if _beam:
		_beam.visible = lights_on
	for lamp in _tail_lights:
		lamp.visible = lamps_on or braking_shows
	if _tail_material:
		_tail_material.emission_energy_multiplier = BRAKE_ENERGY if braking_shows else TAIL_ENERGY
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


## True if it may leave `cell` in heading `leaving` after arriving in heading `arriving`.
func _may_continue(_cell: Vector3i, _arriving: Vector2i, _leaving: Vector2i) -> bool:
	return true


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


## Drops the cells behind the vehicle (keeping `_cells_kept_behind`, for the rounding of
## corners, the heading of a long vehicle and the road under a trailer).
func _drop_passed_cells() -> void:
	while _route_cells.size() > 2 + _cells_kept_behind and _distance > _route_distances[1 + _cells_kept_behind]:
		_waited_at.erase(_route_cells[1])
		_remember(_route_cells[1])
		_route_cells.pop_front()
		_route_headings.pop_front()
		_route_distances.pop_front()
		_turned_round_at = maxi(_turned_round_at - 1, 0)
	var offset := _route_distances[0]
	for index in _route_distances.size():
		_route_distances[index] -= offset
	_distance -= offset


## Plans cells until there are enough ahead to brake to a stop in time.
func _plan() -> void:
	var reach := _distance + speed * speed / (2.0 * braking) + PLAN_MARGIN
	while _route_distances[-1] < reach and not _route_ended:
		var cell: Vector3i = _route_cells[-1]
		var heading: Vector2i = _route_headings[-1]
		var next_cell := network.step(cell, heading)
		var options: Array[Vector2i] = []
		if next_cell != RoadNetwork.NONE:
			var entered := _crossing_entry_heading()
			for option in _ways_out(next_cell):
				if option == -heading or not _may_use(next_cell, option):
					continue
				if not _leads_on(next_cell, option):
					continue
				if not _may_continue(next_cell, heading, option):
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


## True if leaving `cell` in `heading` leads into a cell it may use, across a crossing
## to the first cell past it: not into a square for cyclists, a tram ramp or a bus lane,
## where it would only have to turn round (on a crossing it may not).
func _leads_on(cell: Vector3i, heading: Vector2i) -> bool:
	var here := network.step(cell, heading)
	for step in CROSSING_LOOKAHEAD:
		if here == RoadNetwork.NONE or not _may_use(here, heading):
			return false
		if not network.is_crossing(here):
			return true
		here = network.step(here, heading)
	return true


## The headings it may leave a cell in (RailVehicle: its rails, on a track of its own).
func _ways_out(cell: Vector3i) -> Array[Vector2i]:
	return network.lanes(cell)


## True if `heading` points back the way it drove the last few planned cells (a U-turn
## made of two turns close after each other, such as over a wide junction).
func _doubles_back(heading: Vector2i) -> bool:
	# not past a turn round at a dead end: back is the only way from there
	for index in range(maxi(_turned_round_at, _route_headings.size() - U_TURN_CELLS), _route_headings.size()):
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
			if across == RoadNetwork.NONE or not network.lanes(across).has(-heading) or not _may_use(across, -heading):
				continue
			_route_headings[-1] = side
			for between in range(1, cells_across):
				_append(Vector3i(cell.x + side.x * between, cell.y, cell.z + side.y * between), side)
			_append(across, -heading)
			_turned_round_at = _route_headings.size() - 1
			return
	_append(cell - Vector3i(heading.x, 0, heading.y), -heading)
	_turned_round_at = _route_headings.size() - 1


# ------------------------------------------------------------------ speed

## Speed it may drive now: the speed limit (braking in time for a lower one ahead),
## slower before corners, braking for a stop.
func _target_speed(delta: float) -> float:
	var index := _current_index()
	var last := _route_cells.size() - 1
	var top_speed := top_speed_kmh / 3.6
	speed_limit = network.speed_limit(_cell_under())
	_blocked_by = null
	_held_by_rule = false
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
		if _distance > corner_at + CORNER_REACH:   # the front axle is round it by then
			continue
		var tight := (corner_index < last and _route_headings[corner_index] != _route_headings[corner_index + 1]) \
				or (corner_index >= 2 and _route_headings[corner_index - 2] != _route_headings[corner_index - 1])
		target = minf(target, _approach_speed(tight_corner_speed if tight else corner_speed, corner_at - _corner_lead))
	if avoids_others and _squeeze_clock <= 0.0:
		_look_countdown -= 1
		if _look_countdown < 0:
			_look_countdown = TRAFFIC_LOOK_STEPS - 1
			_traffic_limit = minf(_traffic_speed(index, last), _body_ahead_speed())
			_traffic_blocker = _blocked_by
		_blocked_by = _traffic_blocker
		target = minf(target, _traffic_limit)
	# the first cell boundary it has to stop at
	for ahead_index in range(index + 1, last + 1):
		var stop_at := (_route_distances[ahead_index - 1] + _route_distances[ahead_index]) * 0.5 - half_length
		if _distance > stop_at + 0.5:
			continue           # already past this boundary
		var reason := _must_stop(_route_cells[ahead_index - 1], _route_cells[ahead_index], stop_at - _distance)
		if reason == "":
			continue
		target = minf(target, _approach_speed(0.0, stop_at))
		_held_by_rule = true
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


## Where the route is at distance `at` with its corners rounded off (x, z): the mean of the
## chain of cell centres over `_corner_rounding` metres either way.
func _rounded_route_point(at: float) -> Vector2:
	var window_start := at - _corner_rounding
	var window_end := at + _corner_rounding
	var weighted := Vector2.ZERO
	var first_centre := network.centre(_route_cells[0])
	weighted += Vector2(first_centre.x, first_centre.z) * maxf(_route_distances[0] - window_start, 0.0)
	for index in _route_distances.size() - 1:
		var segment_start := _route_distances[index]
		var segment_end := _route_distances[index + 1]
		if segment_end <= window_start:
			continue
		if segment_start >= window_end:
			break
		var from := network.centre(_route_cells[index])
		var to := network.centre(_route_cells[index + 1])
		var overlap_start := maxf(segment_start, window_start)
		var overlap_end := minf(segment_end, window_end)
		var overlap_middle := (overlap_start + overlap_end) * 0.5
		var fraction := (overlap_middle - segment_start) / maxf(segment_end - segment_start, 0.001)
		var middle := Vector2(lerpf(from.x, to.x, fraction), lerpf(from.z, to.z, fraction))
		weighted += middle * (overlap_end - overlap_start)
	var last_centre := network.centre(_route_cells[-1])
	weighted += Vector2(last_centre.x, last_centre.z) * maxf(window_end - _route_distances[-1], 0.0)
	return weighted / (_corner_rounding * 2.0)


## Puts the vehicle on its route: the front axle on the rounded route, the rear axle pulled
## straight towards it, the body on the line between them, tilted with the road under the
## axles. delta 0 = at once (at the start): the rear axle on the route too.
func _place(delta := 0.0) -> void:
	var front_spot := _rounded_route_point(_distance + _front_axle)
	var wheelbase := _front_axle - _rear_axle
	if delta > 0.0:
		_front_axle_motion = front_spot - _front_axle_spot
	else:
		_rear_axle_spot = _rounded_route_point(_distance + _rear_axle)
		_front_axle_motion = Vector2.ZERO
	_front_axle_spot = front_spot
	var along_body := front_spot - _rear_axle_spot
	if along_body.length_squared() < 0.000001:
		along_body = Vector2(global_basis.z.x, global_basis.z.z)
	along_body = along_body.normalized()
	_rear_axle_spot = front_spot - along_body * wheelbase
	var rise := _route_point(_distance + _front_axle).y - _route_point(_distance + _rear_axle).y
	var middle := front_spot - along_body * _front_axle
	# the height of the road right under its middle (a line between the axles would cut
	# through the top of a ramp)
	global_position = Vector3(middle.x, _route_point(_distance).y, middle.y)
	global_basis = Basis.looking_at(-Vector3(along_body.x * wheelbase, rise, along_body.y * wheelbase), Vector3.UP)


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
	_tint_windows(instance, mesh)
	_body.add_child(instance)


## The glass of a model becomes car glass.
func _tint_windows(instance: MeshInstance3D, mesh: Mesh) -> void:
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface) as ShaderMaterial
		if material and material.shader and material.shader.resource_path.ends_with("voxel_glass.gdshader"):
			# the same for every vehicle: dark tinted glass that mirrors the town and the sky
			# sliding past (more at a grazing angle), with a sharp sun glint and light
			# streaks that lie on the vehicle itself (world streaks would slide all over it)
			var windows := material.duplicate() as ShaderMaterial
			windows.set_shader_parameter("interior", 0.0)
			windows.set_shader_parameter("reflection", 0.2)
			windows.set_shader_parameter("passing_surroundings", 0.6)
			windows.set_shader_parameter("depth", 0.1)
			windows.set_shader_parameter("glint_roughness", 0.06)
			windows.set_shader_parameter("streaks", 0.12)
			windows.set_shader_parameter("streaks_on_object", 1.0)
			windows.set_shader_parameter("sheen", 0.0)
			instance.set_surface_override_material(surface, windows)


## What is drawn on it, the axles and how far behind it it must remember the road: the
## of a long vehicle comes from around its axles, and a trailer rides on the road behind.
func _measure_length() -> void:
	var body_bounds := _mesh_bounds(_body)
	if body_bounds.size.z > 0.0:
		_outer_box = body_bounds
		_body_size = body_bounds.size
	if _trailer:
		_trailer_box = _mesh_bounds(_trailer)
	if wheel_positions.is_empty():
		_front_axle = _outer_box.end.z * 0.6
		_rear_axle = _outer_box.position.z * 0.6
	else:
		_front_axle = -INF
		_rear_axle = INF
		for wheel_position in wheel_positions:
			_front_axle = maxf(_front_axle, wheel_position.z)
			_rear_axle = minf(_rear_axle, wheel_position.z)
	_corner_rounding = clampf(_front_axle - _rear_axle + CORNER_ROUNDING_EXTRA, CORNER_ROUNDING_LEAST, CORNER_ROUNDING_MOST)
	_corner_lead = maxf(CORNER_REACH, _corner_rounding + _front_axle)
	var behind := maxf(_corner_rounding - _front_axle, -_rear_axle)
	if _trailer:
		behind = maxf(behind, -hitch_position.z + trailer_axle_distance)
	_cells_kept_behind = maxi(1, ceili(behind / RoadNetwork.CELL) + 1)


## The box around all meshes below `node`, seen from `node` (with its own origin in it).
static func _mesh_bounds(node: Node3D, from_root := Transform3D.IDENTITY) -> AABB:
	var bounds := AABB()
	for child in node.get_children():
		if not child is Node3D:
			continue
		var to_child: Transform3D = from_root * child.transform
		if child is MeshInstance3D and child.mesh:
			bounds = bounds.merge(to_child * child.mesh.get_aabb())
		bounds = bounds.merge(_mesh_bounds(child, to_child))
	return bounds


# ------------------------------------------------------------------ trailer

## The tow bar on the body and the trailer: a body of its own whose origin is the pivot
## (the coupling on the ball), level with the ball.
func _add_trailer(props: GridMap) -> void:
	if trailer_model == "" or props == null or props.mesh_library == null:
		return
	var library := props.mesh_library
	var item := library.find_item_by_name(trailer_model)
	if item < 0:
		push_warning("vehicle: no item '%s' in the props library" % trailer_model)
		return
	var hitch_item := library.find_item_by_name(hitch_model)
	if hitch_item >= 0:
		var hitch_mesh := library.get_item_mesh(hitch_item)
		var hitch_transform := library.get_item_mesh_transform(hitch_item)
		var hitch_box := hitch_transform * hitch_mesh.get_aabb()
		var bar := MeshInstance3D.new()
		bar.name = "Trekhaak"
		bar.mesh = hitch_mesh
		# the back end of the bar on the ball, the ball's voxel at the ball's height
		var at := hitch_position - Vector3(hitch_box.get_center().x, hitch_box.end.y - 0.0625, hitch_box.position.z + 0.0625)
		bar.transform = Transform3D(hitch_transform.basis, hitch_transform.origin + at)
		_body.add_child(bar)
	_trailer = Node3D.new()
	_trailer.name = "Aanhanger"
	_trailer.top_level = true
	add_child(_trailer)
	var mesh := library.get_item_mesh(item)
	var mesh_transform := library.get_item_mesh_transform(item)
	var box := mesh_transform * mesh.get_aabb()
	var instance := MeshInstance3D.new()
	instance.name = "Model"
	instance.mesh = mesh
	var bottom := trailer_lift - hitch_position.y
	# the coupling (the first voxels of the model) over the ball, the pivot in the middle of it
	instance.transform = Transform3D(mesh_transform.basis, mesh_transform.origin
			- Vector3(box.get_center().x, box.position.y - bottom, box.end.z - 0.125))
	_trailer.add_child(instance)


## Moves the trailer after the vehicle: its axle is pulled straight towards the ball, on
## the road at the point of the route under it. snap = straight behind the vehicle, at once.
func _move_trailer(snap := false) -> void:
	if _trailer == null:
		return
	var frame := _body.global_transform if crashed else global_transform
	var ball := frame * hitch_position
	var straight_back := -frame.basis.z
	straight_back.y = 0.0
	straight_back = straight_back.normalized()
	var towards_axle := _trailer_axle - ball
	towards_axle.y = 0.0
	if snap or towards_axle.length_squared() < 0.0001:
		towards_axle = straight_back
	towards_axle = towards_axle.normalized()
	# it never folds up against the vehicle (turning round in a narrow street)
	var angle := straight_back.signed_angle_to(towards_axle, Vector3.UP)
	if absf(angle) > MAX_TRAILER_ANGLE:
		towards_axle = straight_back.rotated(Vector3.UP, signf(angle) * MAX_TRAILER_ANGLE)
	_trailer_axle = ball + towards_axle * trailer_axle_distance
	var axle_height := ball.y
	if not crashed and not _route_cells.is_empty():
		axle_height = _route_point(_distance + hitch_position.z - trailer_axle_distance).y + hitch_position.y
	_trailer_axle.y = axle_height
	var forward := ball - _trailer_axle
	_trailer_previous = _trailer_current
	_trailer_current = Transform3D(Basis.looking_at(-forward, Vector3.UP), ball)
	if snap:
		_trailer_previous = _trailer_current


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
	# the rim and spokes of the shader are made for the car wheel (0.375 m)
	var scale_of_wheel := wheel_radius / 0.375
	material.set_shader_parameter("rim_radius", 0.24 * scale_of_wheel)
	material.set_shader_parameter("hub_radius", 0.07 * scale_of_wheel)
	material.set_shader_parameter("spoke_half_width", 0.05 * scale_of_wheel)
	var wheel_transform := Transform3D(mesh_transform.basis, mesh_transform.origin - middle)
	for wheel_position in wheel_positions:
		_add_wheel(_body, wheel_position, mesh, material, wheel_transform)
	if _trailer:
		for wheel_position in trailer_wheel_positions:
			_add_wheel(_trailer, wheel_position - Vector3(0.0, hitch_position.y, 0.0), mesh, material, wheel_transform)


func _add_wheel(parent: Node3D, at: Vector3, mesh: Mesh, material: Material, wheel_transform: Transform3D) -> void:
	var pivot := Node3D.new()
	pivot.name = "Wiel%d" % (_wheels.size() + 1)
	pivot.position = at
	var instance := MeshInstance3D.new()
	instance.name = "Band"
	instance.mesh = mesh
	instance.material_override = material
	instance.transform = wheel_transform
	instance.visibility_range_end = WHEEL_DRAW_DISTANCE
	pivot.add_child(instance)
	parent.add_child(pivot)
	_wheels.append(pivot)


## Rolls the wheels over the distance driven and steers the front ones the way the front
## axle really moves, seen from the body.
func _turn_wheels(distance_driven: float, delta: float) -> void:
	if _wheels.is_empty():
		return
	_roll_previous = _wheel_roll
	_steering_previous = _steering
	_wheel_roll = fmod(_wheel_roll + distance_driven / maxf(wheel_radius, 0.01), TAU)
	var wanted := _steering
	if distance_driven > 0.001 and _front_axle_motion.length_squared() > 0.0:
		var seen_from_body := global_basis.inverse() * Vector3(_front_axle_motion.x, 0.0, _front_axle_motion.y)
		var max_angle := deg_to_rad(max_steering_degrees)
		wanted = clampf(atan2(seen_from_body.x, seen_from_body.z), -max_angle, max_angle)
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
		var crossing := network.is_crossing(cell)
		for other in all_vehicles:
			# measured to its middle: a long one (a train) reaches further than that
			if other == self or other.global_position.distance_to(global_position) > NEAR_VEHICLES + other._reach():
				continue
			if other.covers(cell):
				blocked = true
			elif crossing and not other.crashed and other.speed > 0.5:
				var their_distance := other.distance_to(cell)
				if their_distance >= 0.0:
					var their_time := their_distance / maxf(other.speed, 1.0)
					var first := their_time < my_time - 0.2 or (absf(their_time - my_time) <= 0.2 and other.get_instance_id() < get_instance_id())
					blocked = their_time < CLAIM_SECONDS and first
			if blocked:
				_blocked_by = other
				break
		if blocked:
			var stop_at := (_route_distances[ahead_index - 1] + at) * 0.5 - half_length - TRAFFIC_GAP
			target = _approach_speed(0.0, stop_at)
			if stop_at - _distance < 0.4:
				target = 0.0
			break
	return target


## Highest speed for the body of another vehicle right ahead of its nose: the cells of
## _traffic_speed are 4 m, this keeps it behind the vehicle itself, in a lane or a corner.
func _body_ahead_speed() -> float:
	var forward := Vector2(global_basis.z.x, global_basis.z.z).normalized()
	var mine := Vector2(global_position.x, global_position.z)
	var nose := _outer_box.end.z
	var side_room := _outer_box.size.x * 0.5 + BODY_SIDE_ROOM
	var nearest_gap := INF
	for other in all_vehicles:
		if other == self or other.crashed or absf(other.global_position.y - global_position.y) > 2.5:
			continue
		var reach := nose + other._reach() + BODY_LOOKAHEAD
		if other.global_position.distance_squared_to(global_position) > reach * reach:
			continue
		for rectangle: Array[Vector2] in other._footprints(0.0):
			# seen along its own heading: how far ahead it starts and what it blocks across
			var ahead := Vector2(INF, -INF)
			var across := Vector2(INF, -INF)
			for corner in rectangle:
				var relative := corner - mine
				var along := relative.dot(forward)
				var sideways := relative.cross(forward)
				ahead = Vector2(minf(ahead.x, along), maxf(ahead.y, along))
				across = Vector2(minf(across.x, sideways), maxf(across.y, sideways))
			if across.y < -side_room or across.x > side_room or ahead.x < 0.0:
				continue         # beside it, or already next to or behind its middle
			if ahead.x - nose < nearest_gap:
				nearest_gap = ahead.x - nose
				_blocked_by = other
	if nearest_gap > BODY_LOOKAHEAD:
		return INF
	return sqrt(2.0 * braking * maxf(nearest_gap - BODY_GAP, 0.0))


## Standing still for other vehicles: if they wait for each other in a ring, one squeezes
## past after a while (a queue for a light or a zebra just waits).
func _watch_for_gridlock(delta: float) -> void:
	_squeeze_clock = maxf(_squeeze_clock - delta, 0.0)
	if _blocked_by == null or speed > STANDING_SPEED:
		_blocked_clock = 0.0
		return
	_blocked_clock += delta
	var patience := RING_PATIENCE + get_instance_id() % RING_PATIENCE_SPREAD
	if _blocked_clock > LOST_PATIENCE or (_blocked_clock > patience and _waits_in_a_ring()):
		_squeeze_clock = SQUEEZE_TIME
		_blocked_clock = 0.0


## True if following who waits for whom comes back round to someone it has seen already.
func _waits_in_a_ring() -> bool:
	var seen := {}
	var vehicle := self as Vehicle
	for step_index in QUEUE_CHECK:
		if vehicle == null or vehicle._held_by_rule or vehicle.crashed:
			return false
		if seen.has(vehicle):
			return true
		seen[vehicle] = true
		vehicle = vehicle._blocked_by
	return false


## True if the vehicle stands on (part of) this road cell (a wreck: the cell under it).
func covers(cell: Vector3i) -> bool:
	var spot := _body.global_position if crashed else global_position
	if absi(cell.y - roundi(spot.y)) > 3:
		return false
	var centre := network.centre(cell)
	var forward := (_body.global_basis if crashed else global_basis).z
	if _line_covers(centre, spot + forward * (_outer_box.end.z + 0.5), spot + forward * (_outer_box.position.z - 0.5)):
		return true
	if _trailer:
		return _line_covers(centre, _trailer_current * Vector3(0.0, 0.0, _trailer_box.end.z),
				_trailer_current * Vector3(0.0, 0.0, _trailer_box.position.z))
	return false


## True if the line between these two points crosses the road cell with this centre.
func _line_covers(centre: Vector3, from: Vector3, to: Vector3) -> bool:
	var steps := ceili(from.distance_to(to) / COVER_STEP)
	for step_index in steps + 1:
		var point := from.lerp(to, float(step_index) / maxf(steps, 1))
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
		if global_position.distance_to(other.global_position) > _reach() + other._reach() + 1.0:
			continue
		# one on a viaduct or in a tunnel, the other above or under it: their bodies never touch
		if absf(other.global_position.y - global_position.y) > CRASH_LEVEL_DIFFERENCE:
			continue
		if (reckless or other.reckless or (velocity - other.velocity).length() >= CRASH_SPEED) and _overlaps(other):
			_crash_with(other)


## The blow: both become a wreck with the speed and spin the masses give them. The change
## of speed along the line between them is shared as momentum does, so the lighter one takes
## most of it; the blow lands off-centre, which spins the lighter one most too.
func _crash_with(other: Vehicle) -> void:
	var line := other.global_position - global_position
	line.y = 0.0
	line = line.normalized() if line.length_squared() > 0.0001 else global_basis.z
	var closing := maxf((velocity - other.velocity).dot(line), 0.0)
	var my_mass := total_mass()
	var their_mass := other.total_mass()
	var blow := line * (1.0 + CRASH_BOUNCE) * closing * my_mass * their_mass / (my_mass + their_mass)
	var contact := (global_position + other.global_position) * 0.5
	var my_speed := velocity - blow / my_mass
	var their_speed := other.velocity + blow / their_mass
	var my_spin := _spin_from(blow * -1.0, contact)
	var their_spin := other._spin_from(blow, contact)
	_become_wreck(my_speed, my_spin)
	other._become_wreck(their_speed, their_spin)


## Turning speed (rad/s) a blow at this point gives this vehicle: the moment of the blow
## over the inertia of its mass about its middle.
func _spin_from(blow: Vector3, contact: Vector3) -> float:
	var arm := contact - global_position
	var inertia := total_mass() * (_body_size.x * _body_size.x + _body_size.z * _body_size.z) / 12.0
	var moment := arm.z * blow.x - arm.x * blow.z
	return clampf(moment / maxf(inertia, 1.0), -MAX_CRASH_SPIN, MAX_CRASH_SPIN)


## Its mass with what it pulls.
func total_mass() -> float:
	return mass_kg + (trailer_mass_kg if _trailer else 0.0)


## Metres from its middle to the far end of the vehicle (with its trailer).
func _reach() -> float:
	if _trailer:
		return -hitch_position.z - _trailer_box.position.z
	return maxf(_outer_box.end.z, -_outer_box.position.z)


## True if the bodies or trailers (rectangles seen from above, CRASH_MARGIN larger) overlap.
func _overlaps(other: Vehicle) -> bool:
	for mine in _footprints(CRASH_MARGIN):
		for theirs in other._footprints(CRASH_MARGIN):
			if _rectangles_overlap(mine, theirs):
				return true
	return false


## Separating axis test of two rectangles (four corners each, see _rectangle): the two
## side directions of each.
static func _rectangles_overlap(first: Array[Vector2], second: Array[Vector2]) -> bool:
	for axis: Vector2 in [first[0] - first[1], first[0] - first[2], second[0] - second[1], second[0] - second[2]]:
		var first_range := Vector2(INF, -INF)
		var second_range := Vector2(INF, -INF)
		for corner in first:
			var along := corner.dot(axis)
			first_range = Vector2(minf(first_range.x, along), maxf(first_range.y, along))
		for corner in second:
			var along := corner.dot(axis)
			second_range = Vector2(minf(second_range.x, along), maxf(second_range.y, along))
		if first_range.y < second_range.x or second_range.y < first_range.x:
			return false
	return true


## What it takes up on the road seen from above: its body, and its trailer if it has one.
func _footprints(margin: float) -> Array:
	var rectangles := [_box_rectangle(global_transform, _outer_box, margin)]
	if _trailer:
		rectangles.append(_box_rectangle(_trailer_current, _trailer_box, margin))
	return rectangles


## The rectangle of a box of a body that stands at `frame`.
static func _box_rectangle(frame: Transform3D, box: AABB, margin: float) -> Array[Vector2]:
	return _rectangle(frame, frame * box.get_center(), box.size.x, box.size.z, margin)


## The four corners (x, z) of a rectangle around `middle`, turned like `frame`.
static func _rectangle(frame: Transform3D, middle: Vector3, width: float, length: float, margin: float) -> Array[Vector2]:
	var across := Vector2(frame.basis.x.x, frame.basis.x.z) * (width * 0.5 + margin)
	var along := Vector2(frame.basis.z.x, frame.basis.z.z) * (length * 0.5 + margin)
	var centre := Vector2(middle.x, middle.z)
	return [centre + across + along, centre + across - along, centre - across + along, centre - across - along]


## Hands the body to the physics engine: a RigidBody3D with a box the outer size of the
## body, its mass and its speed, that hits the other wreck and the colliders of the town.
## A trailer gets a collider of its own: it is dragged along behind the wreck (_move_trailer)
## and pushes other wrecks out of the way.
func _become_wreck(impact: Vector3, spin := 0.0) -> void:
	crashed = true
	reckless = false
	speed = 0.0
	braking_now = false
	indicating = 0
	set_physics_process(false)
	_wreck = RigidBody3D.new()
	_wreck.name = "Wrak"
	_wreck.mass = total_mass()
	_wreck.continuous_cd = true
	var material := PhysicsMaterial.new()
	material.friction = ROLLING_FRICTION
	material.bounce = 0.15
	_wreck.physics_material_override = material
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_outer_box.size.x, _outer_box.size.y - 0.05, _outer_box.size.z)
	shape.shape = box
	shape.position = _outer_box.get_center() + Vector3(0.0, 0.03, 0.0)
	_wreck.add_child(shape)
	# lower centre of mass (engine and floor), so it slides and spins more than it rolls
	_wreck.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	_wreck.center_of_mass = Vector3(0.0, _body_size.y * 0.3, 0.0)
	get_parent().add_child(_wreck)
	_wreck.global_transform = global_transform
	_wreck.linear_velocity = impact
	_wreck.angular_velocity = Vector3.UP * spin
	if _trailer:
		_add_trailer_collider()
	_wreck_clock = 0.0
	_roll_on_clock = ROLL_ON_TIME + ROLL_ON_PER_KG * total_mass()


func _add_trailer_collider() -> void:
	_trailer_collider = AnimatableBody3D.new()
	_trailer_collider.name = "WrakAanhanger"
	_trailer_collider.sync_to_physics = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _trailer_box.size
	shape.shape = box
	shape.position = _trailer_box.get_center()
	_trailer_collider.add_child(shape)
	get_parent().add_child(_trailer_collider)
	_trailer_collider.global_transform = _trailer_current
	_wreck.add_collision_exception_with(_trailer_collider)


## While crashed: the body sits on the wreck; after WRECK_TIME it is towed back.
func _follow_wreck(delta: float) -> void:
	_body.global_transform = _wreck.global_transform
	_roll_on(delta)
	if _trailer:
		_move_trailer()
		_trailer.global_transform = _trailer_current
		_trailer_collider.global_transform = _trailer_current
	_update_lamps()
	_wreck_clock += delta
	if _wreck_clock >= WRECK_TIME:
		_tow()


## Just after the crash it is still on its wheels with its engine pushing; then it stops
## rolling and slides to a halt. The pull is the same as when it pulls away.
func _roll_on(delta: float) -> void:
	if _roll_on_clock <= 0.0:
		return
	_roll_on_clock -= delta
	if _roll_on_clock > 0.0:
		_wreck.constant_force = _wreck.global_basis.z * wheel_torque / maxf(wheel_radius, 0.01)
	else:
		_wreck.constant_force = Vector3.ZERO
		_wreck.physics_material_override.friction = SLIDING_FRICTION


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
	if _trailer_collider:
		_trailer_collider.queue_free()
		_trailer_collider = null
	crashed = false
	_route_cells.clear()
	_route_headings.clear()
	_route_distances.clear()
	_turned_round_at = 0
	_waited_at.clear()
	var first := _free_lane(network.nearest(Vector2i(floori(spot.x / RoadNetwork.CELL), floori(spot.z / RoadNetwork.CELL)), heading, vehicle_kind), heading)
	_append(first - Vector3i(heading.x, 0, heading.y), heading)
	_append(first, heading)
	_distance = _route_distances[1]
	speed = 0.0
	acceleration_now = 0.0
	_plan()
	_place()
	_snap_body()
	set_physics_process(true)


## The first cell along the road from `cell` that no other vehicle stands on or next to.
func _free_lane(cell: Vector3i, heading: Vector2i) -> Vector3i:
	var candidate := cell
	for step_index in TOW_SEARCH_CELLS:
		var free := true
		for other in all_vehicles:
			if other != self and not other.crashed and (other.covers(candidate) \
					or other.global_position.distance_to(network.centre(candidate)) < _body_size.z + other._reach()):
				free = false
				break
		if free:
			return candidate
		var next_cell := network.step(candidate, heading)
		if next_cell == RoadNetwork.NONE or not network.lanes(next_cell).has(heading) or not _may_use(next_cell, heading):
			break
		candidate = next_cell
	return candidate


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
	_turned_round_at = 0
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
	_snap_body()


## Plans at least `metres` ahead.
func _plan_ahead(metres: float) -> void:
	var keep := speed
	speed = sqrt(maxf(0.0, 2.0 * braking * (metres - PLAN_MARGIN)))
	_plan()
	speed = keep
