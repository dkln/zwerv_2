class_name Vehicle
extends Node3D
## A vehicle that drives round the road network on its own (scripts/traffic/road_network.gd,
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
## - before a zebra crossing (weg/zebrapad) when someone waits to cross there, for
##   `zebra_wait` seconds, then drives on, and for as long as someone is on it
##   (_someone_crossing: the pedestrians, scripts/world/pedestrians.gd);
## - at traffic lights (Verkeerslichten, scripts/traffic/traffic_lights.gd) until its
##   stream is green, before the zebra or the crossing, whichever comes first (the lights
##   of the whole crossing, found from its middle; a zebra right before it goes with it).
## Where its lane ends it moves over into the lane alongside, gradually over a few cells
## (a motorway losing a lane); at a dead end it turns round into the opposite lane. Where
## the map marks a cell to move over from (RoadNetwork MOVE_OVERS: an exit) it takes it as
## a turn, at straight_chance, or always where its own lane ends there.
## Emergency services (`emergency`: police, ambulance, fire service, ME): a siren
## (no sound) and blue lights on the roof (`beacon_positions`), on and off by themselves
## (`siren_duty`) or with set_siren / toggle_siren. With the siren on it drives
## EMERGENCY_SPEED_FACTOR over the limit, through red lights and past zebras, and gives way
## only to another siren. The others make way for it: on a crossing they give way to it,
## and in front of it they move over into a lane alongside if there is one, else they pull
## over to the right and crawl (`yielding`) while it passes them on the left.
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
## behind it) and gives way on a crossing to traffic from the right (_comes_from_right; not
## when it is too close to stop), else to a vehicle that will be there first. If two
## vehicles run into each other all the same (at CRASH_SPEED or faster, or one of them
## driving without looking; a scrape in a corner is not a crash), they hit each other: each
## loses health (`health`, from `max_health`) by the change of speed it takes (DAMAGE_PER_SPEED
## per m/s; the lighter one takes most). A small hit is only a bump: both brake hard
## (BUMP_SLOWDOWN), a few shards fly, and they drive on. Only a vehicle whose health runs
## out crashes and catches fire (scripts/effects/vehicle_fire.gd): it becomes
## a RigidBody3D (a "Wrak") with its
## speed and mass, so they bounce off each other and off the colliders of the town (the
## kerbs, medians and buildings of the GridMaps), hop, tip over towards where they are
## pushed, spin and slide out, hazard lights blinking; shards of paint, glass and plastic
## and a puff of dust fly out (scripts/effects/crash_burst.gd) and the view shakes; it burns
## (VehicleFire.BURN_SECONDS), blinks away ever faster (death_blink.gd) and is towed back
## onto the nearest lane, as good as new, and drives on. drive_into() sends a vehicle the wrong way down another one's route, without
## looking (the demo crash of tools/check/crash_test.gd).
## Weight and torque: `mass_kg` and `wheel_torque` differ per type, and a heavy vehicle has
## more of both. The torque over the mass gives its acceleration. In a crash the masses
## share the blow as momentum does (the light one takes most of the change of speed and
## the spin, the heavy one hardly notices), and the heavy one keeps rolling on its wheels
## with its engine still pushing for longer (ROLL_ON_*), shoving the light one ahead of it.
## Gridlock: vehicles that wait for each other in a ring (not in a queue for a light or a
## zebra) would stand there for ever, so after a while one squeezes past (SQUEEZE_TIME):
## it ignores the cells the others claim, but still keeps behind the body right ahead of it;
## only if it stands still all the same (the bodies themselves locked) does it drive
## through them, the next time.
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
const Sight = preload("res://scripts/world/sight.gd")
const CROSSING_LOOKAHEAD := 4
## Speed through a corner (m/s).
@export var corner_speed := 4.5
## Speed through two corners right after each other: turning round, an S-bend (m/s).
@export var tight_corner_speed := 2.8
## Acceleration (m/s²) of a vehicle without a `wheel_torque` (else that sets it), and
## braking (m/s²).
@export var acceleration := 2.5
@export var braking := 4.0
## How quickly the acceleration may change (m/s³): a driver eases onto the throttle and
## the brake (no jolt); easing off and braking go faster than speeding up again.
@export var throttle_rate := 3.0
@export var brake_rate := 12.0
@export_group("Rules")
## Kind of vehicle, for lanes only some kinds may use (a bus lane: "bus").
@export var vehicle_kind := "auto"
## The sound (assets/audio/geluiden/) it warns people on foot with; "" = the one of its kind
## (_horn()).
@export var horn_sound := ""
## Stops for traffic lights.
@export var obeys_lights := true
## Seconds it waits before a zebra crossing without traffic lights.
@export var zebra_wait := 1.5
## Chance (0..1) to go straight on where it could also turn (before its memory of the
## roads it has driven weighs in, see _choose_heading).
@export var straight_chance := 0.6
## How strongly it avoids roads it has driven lately (0 = not at all).
@export var variety := 4.0
@export_group("Emergency")
## A police car, ambulance, fire engine or ME van: a siren and blue lights.
@export var emergency := false
## Centres of the blue lights on the roof (metres on the vehicle, like the lamps), the
## left half flashing in turn with the right.
@export var beacon_positions := PackedVector3Array()
@export var beacon_size := Vector3(0.5, 0.15, 0.3)
## Switches the siren on and off by itself now and then (on a call, back again).
@export var siren_duty := true
## Pulls over for a siren behind it (a rail vehicle cannot).
@export var makes_way := true
@export_group("Traffic")
## Brakes for other vehicles ahead and gives way on crossings.
@export var avoids_others := true
## Mass for the crash (kg).
@export var mass_kg := 1300.0
## Torque of the engine at the driven wheels (Nm), through the gears. Its pull is this over
## `wheel_radius`, which over the mass (with a trailer) gives the acceleration, and pushes on
## in a crash. 0 = it has none: `acceleration` is what it is.
@export var wheel_torque := 0.0
## Health it starts with and is towed back with (see `health`).
@export var max_health := 100.0
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
## Front wheels (z > 0) of another size (a tractor's small ones): their own props item and
## radius, each rolling at its own rate; "" / 0 = the same as the others.
@export var front_wheel_model := ""
@export var front_wheel_radius := 0.0
## Two wheels: it leans into a corner as far as its speed and the sharpness of the corner
## ask (the angle whose tangent is the sideways acceleration over gravity), at most this.
## The lean starts before the corner (LEAN_LEAD: the bend a moment ahead), and the rider
## countersteers into it ("insturen"): to lean over to the left the front wheel first
## turns briefly to the right (`countersteer`: seconds of steering per radian a second of
## lean), then follows the corner.
@export var leans := false
@export var max_lean_degrees := 25.0
@export var countersteer := 0.12
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
const DeathBlink = preload("res://scripts/effects/death_blink.gd")
const VehicleFire = preload("res://scripts/effects/vehicle_fire.gd")
## Health lost per m/s of the change of speed a vehicle takes in a hit (a head-on crash of
## two cars at 50 km/h each takes about 14 m/s: more than all of it; a bump in a queue at
## walking pace a few points).
const DAMAGE_PER_SPEED := 8.0
## A bump (its health not run out): its speed is cut to this share, and for BUMP_COOLDOWN
## seconds it does not hit the same again (they still touch).
const BUMP_SLOWDOWN := 0.2
const BUMP_COOLDOWN := 1.2
## The worst case: a hit that drives its health this far below nought blows it up
## (VehicleFire.explode) before it burns.
const EXPLODE_HEALTH := -80.0
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
const CRASH_BOUNCE := 0.35
## Fastest a crash spins a wreck (rad/s).
const MAX_CRASH_SPIN := 9.0
## The jolt of a crash: per m/s of the closing speed it takes (its share, the lighter one
## most) it hops up (m/s) and tips over towards where it is pushed (rad/s), up to the most.
const CRASH_HOP := 0.12
const CRASH_HOP_MOST := 2.8
const CRASH_TILT := 0.14
const CRASH_TILT_MOST := 2.6
## Closing speed (m/s) of a crash with the biggest bang (shards, dust, camera shake).
const CRASH_FULL_SPEED := 20.0
## Colour words in the model names and the paint they stand for (the shards of a crash).
const PAINT_WORDS := {"wit": Color(0.92, 0.92, 0.9), "zilver": Color(0.72, 0.74, 0.76), "rood": Color(0.75, 0.12, 0.1),
		"blauw": Color(0.15, 0.3, 0.7), "zwart": Color(0.1, 0.1, 0.11), "politie": Color(0.9, 0.9, 0.9),
		"ambulance": Color(0.95, 0.85, 0.1), "brandweer": Color(0.8, 0.1, 0.08), "bus": Color(0.9, 0.85, 0.2)}
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
const RING_PATIENCE := 3.0
const RING_PATIENCE_SPREAD := 5
## Seconds it waits in a ring with a siren in it before it squeezes out of the way.
const SIREN_RING_PATIENCE := 1.5
const SQUEEZE_TIME := 6.0
## Metres a squeeze must get it on, else the next one drives through the bodies too.
const SQUEEZE_IN_VAIN := 2.0
const LOST_PATIENCE := 75.0
## Longest queue of vehicles it follows to see what they wait for.
const QUEUE_CHECK := 24
## Cells it looks along the road for a free spot when it is towed.
const TOW_SEARCH_CELLS := 12
## Speed (m/s) of a vehicle sent down another one's route (drive_into).
const RECKLESS_SPEED := 11.0
## A daredevil (`daredevil`) goes at its top speed times this, but at most this many times the
## speed limit where it is.
const DAREDEVIL_TOP_FACTOR := 1.4
const DAREDEVIL_LIMIT_FACTOR := 2.0
## Seconds in which it closes a gap between its speed and the speed it may drive.
const SPEED_SETTLE := 0.5
## Metres per second over the speed it may drive from which it brakes without easing in.
const BRAKE_SLACK := 1.5
## Seconds of driving before a lower speed limit at which it aims to be down to it: its
## speed follows the speed it may drive SPEED_SETTLE behind (braking about
## braking * SPEED_SETTLE over it), and this gives it the time to close that gap.
const LIMIT_LEAD := 1.2
## With the siren on: how much over the speed limit it may drive.
const EMERGENCY_SPEED_FACTOR := 1.8
## An idiot at the wheel (`maniac`): times the speed limit it drives; metres it sees other
## vehicles ahead (against TRAFFIC_LOOKAHEAD); how far its front axle weaves (metres) and in
## how many seconds (two waves over each other: a slow one and a quick one); the seconds
## between its shouts (from .. to).
const MANIAC_SPEED := {"dronken": 1.3, "agressief": 1.6}
const MANIAC_LOOKAHEAD := 14.0
const MANIAC_WEAVE := {"dronken": [0.55, 2.9, 0.18, 1.1], "agressief": [0.22, 1.7, 0.12, 0.6]}
const MANIAC_SHOUT_EVERY := Vector2(5.0, 11.0)
## Seconds between its horn blasts at nothing in particular (from .. to).
const MANIAC_HORN_EVERY := Vector2(3.0, 9.0)
## Seconds the siren stays on, and off, when it switches by itself (from .. to).
const SIREN_ON_SECONDS := Vector2(45.0, 100.0)
const SIREN_OFF_SECONDS := Vector2(20.0, 50.0)
## The flash of the blue lights: seconds per round (left, right) and their colour.
const BEACON_CYCLE := 0.5
const BEACON_COLOUR := Color(0.15, 0.4, 1.0)
## The blue lights by day too: unshaded in a light blue, glowing BEACON_GLOW times, the
## blocks BEACON_SCALE their size, and a stronger blue light round them.
const BEACON_LAMP_COLOUR := Color(0.35, 0.6, 1.0)
const BEACON_GLOW := 14.0
const BEACON_SCALE := Vector3(1.3, 1.5, 1.2)
const BEACON_LIGHT_ENERGY := 4.0
## Making way: how far behind a siren is heard (m), how far beside the line of the lane it
## counts (m), physics steps between looks, the speed it crawls at while pulled over (m/s),
## how far it moves over to the right and the siren to the left (m, the drawn body), and
## how fast that goes (m/s).
const SIREN_HEARD := 45.0
const SIREN_BESIDE := 3.0
const YIELD_LOOK_STEPS := 6
const YIELD_SPEED := 2.0
## Metres behind it from which a siren makes it stand still, pulled over, until it is past;
## seconds after which it drives on all the same (the siren stuck elsewhere).
const YIELD_STAND_DISTANCE := 15.0
## A siren coming towards it: how far ahead it is seen (m) and how far beside its line.
const ONCOMING_SIREN_HEARD := 30.0
const ONCOMING_BESIDE := 6.0
const YIELD_LONGEST := 20.0
const YIELD_OFFSET := 1.1
const PASS_OFFSET := 0.9
const OFFSET_RATE := 1.2
## Metres sideways per metre driven at most when it moves over (about 20 degrees of heading):
## moving over is steering, so standing still it does not move sideways.
const SIDEWAYS_PER_SPEED := 0.35
## On a crossing everyone gives way to a siren that will be there within these seconds.
const PRIORITY_CLAIM_SECONDS := 6.0
## A siren still gives way to one that reaches the crossing first within these seconds; and
## who is that close to a crossing goes on, also before traffic from the right.
const COMMITTED_SECONDS := 1.5
## How square across its way another must drive to count as coming from the right (the cosine
## of its heading against its right: 0.7 is within some 45 degrees).
const RIGHT_OF_WAY_ACROSS := 0.7
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
## How fast a two-wheeler takes up its lean (1/s), and gravity for it (m/s²); seconds ahead
## (at its speed) of the bend it leans for, and the metres over which that bend is measured.
const LEAN_RATE := 5.0
const LEAN_LEAD := 0.35
const LEAN_SPAN := 1.5
const GRAVITY := 9.81
## All corner speeds (corner_speed, tight_corner_speed of each type) times this: the types
## keep their order (a bus slower than a car), the whole town a little quicker round them.
const CORNER_SPEED_FACTOR := 1.6
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
## People on foot in its way (pedestrians and the player, the group WALKERS_GROUP): it looks
## ahead its stopping distance plus PEOPLE_LOOK_TIME seconds, brakes to stand PEOPLE_GAP
## metres before someone in its path (its width plus PEOPLE_SIDE_ROOM on each side), and
## swerves (up to DODGE_OFFSET m, not on rails) away from someone near the edge of it, slowing
## down meanwhile. It warns them with its horn (`horn_sound`, or the one of its kind: a bell
## on a bicycle, a beep on a moped, a deep horn on a bus or a lorry) when they are in its path
## less than HORN_WITHIN seconds ahead, or stand in its way after it stopped for HORN_STANDING
## seconds, or has to brake hard for them; at most every HORN_PAUSE seconds.
## Impatient: once it has stood IMPATIENT_AFTER seconds for someone in its path (honking
## meanwhile), it honks once more, the driver shouts (DriverShout) and it pushes through:
## it creeps on at IMPATIENT_SPEED (no longer stopping for them, nor at the zebra they are
## on) and knocks over whoever it drives into (the player takes the hit itself,
## player_controller.gd; a pedestrian through hit_by_vehicle, pedestrian.gd). Once its path
## has been clear IMPATIENT_CALM seconds (or after IMPATIENT_MOST seconds) it drives as usual.
const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")
const Outline = preload("res://scripts/effects/outline.gd")
const WALKERS_GROUP := "lopers"
const PEOPLE_LOOK_TIME := 2.5
const PEOPLE_GAP := 2.0
const PEOPLE_SIDE_ROOM := 0.45
## Metres between the points of its route it looks at for people (_beside_route).
const PEOPLE_ROUTE_STEP := 1.0
const DODGE_OFFSET := 0.9
const DODGE_SPEED := 3.0
const HORN_WITHIN := 2.5
const HORN_STANDING := 3.0
const HORN_PAUSE := 5.0
## Honking at the other traffic: after this many seconds held up by another vehicle, and on a
## hard brake for one (a near crash: braking this hard, at this speed or more).
const HONK_AT_VEHICLE_AFTER := 3.0
const NEAR_CRASH_BRAKING := 1.2
const NEAR_CRASH_SPEED := 4.0
## Held up longer (the same one not getting out of the way): from the HOLD_HORN_FROM-th honk
## on it holds its horn (the long horn of its kind, LONG_HORNS); moving on again
## (INSISTENCE_RESET_SPEED) starts it over.
const HOLD_HORN_FROM := 3
const INSISTENCE_RESET_SPEED := 2.5
const LONG_HORNS := {"auto_toeter": "auto_toeter_lang", "bus_toeter": "bus_toeter_lang", "brommer_toeter": "brommer_toeter_lang"}
const IMPATIENT_AFTER := 12.0
const IMPATIENT_SPEED := 2.5
const IMPATIENT_CALM := 2.0
const IMPATIENT_MOST := 10.0
## Metres from its front within which someone in its path is touched (hit_by_vehicle).
const PEOPLE_CONTACT := 0.35
## Above this mass (kg) a vehicle without a horn of its own sounds the deep one (lorries).
const HEAVY_HORN_MASS := 3500.0

## Out of sight: a vehicle off the screen by more than UNSEEN_MARGIN (a share of the screen
## size round it), or further than UNSEEN_DISTANCE from a perspective camera (used to put a
## lost one down unseen). How often it steps goes by Sight (scripts/world/sight.gd): out of
## sight every other step, far from the view every fourth (with the time of all of them),
## and then it leaves its wheels and lamps alone; it looks every SIGHT_CHECK_STEPS physics
## steps where it is.
const UNSEEN_MARGIN := 0.3
const UNSEEN_DISTANCE := 300.0
const SIGHT_CHECK_STEPS := 15
## Lost: it turned round in its own lane (no lane back beside it) this many times without
## getting onto a crossing in between, so it only drives to and fro: once out of sight (or
## after LOST_SECONDS all the same) it is put down on a free lane somewhere else.
const LANE_REVERSALS_LOST := 2
const LOST_SECONDS := 20.0
## Driving in circles (to and fro over a crossing, where the turns round are not counted):
## after PROGRESS_CHECK seconds of driving (over PROGRESS_SPEED m/s) it should be at least
## PROGRESS_LEAST metres from where it was; else it is lost, and is moved in LOST_SOON seconds.
const PROGRESS_CHECK := 12.0
const PROGRESS_SPEED := 1.0
const PROGRESS_LEAST := 8.0
const LOST_SOON := 3.0
const RELOCATE_TRIES := 40

## Every vehicle in the game (for keeping clear of each other and crashing).
static var all_vehicles: Array[Vehicle] = []
## The last crash: where, how hard (0..1) and when (seconds, Time); the camera shakes.
static var last_crash := {"at": Vector3.ZERO, "strength": 0.0, "time": -100.0}

## Out of sight of the camera (see UNSEEN_MARGIN): it takes less CPU time.
var unseen := false
var _sight_countdown := 0
var _steps_between := 1              # physics steps per step it takes (Sight)
var _people_countdown := 0           # physics steps until the next look at the people on foot
var _people_limit := INF             # speed (m/s) for the people on foot in its way
var _dodge := 0.0                    # metres it swerves right (+) or left (-) round someone
var _horn_clock := 0.0               # seconds until it may sound its horn again
var _horn_insistence := 0            # honks for the hold-up of now (longer from HOLD_HORN_FROM)
var _standing_for_people := 0.0      # seconds it has stood still for someone in its way
var _impatience := 0.0               # seconds stood for someone in its path (honks or not)
var _pushing_through := -1.0         # seconds it has been pushing through; < 0 = not
var _path_clear_for := 0.0           # seconds its path has been clear while pushing through
var _saved_delta := 0.0              # time of the step it skipped while out of sight
var _lane_reversals := 0             # turns round in its own lane since the last crossing
var _lost_clock := -1.0              # seconds it has been lost (driving to and fro); < 0 = not
var _progress_clock := 0.0           # seconds it has driven since _progress_from
var _progress_from := Vector3.ZERO

## Its health: hits take it (DAMAGE_PER_SPEED); when it runs out it crashes and burns.
var health := 100.0
var _bump_clock := 0.0               # seconds before it can be hit again after a bump
var _fire: Node3D                    # its fire while it burns as a wreck (vehicle_fire.gd)
## Crashed: a wreck under physics until it is towed back onto the road.
var crashed := false
## Drives without looking: no lights, no other vehicles (drive_into).
var reckless := false
## A daredevil: in a wheelie (TwoWheeler) it goes far faster than it should (daredevil_speed)
## and looks out for nothing: no other vehicles, no people on foot, no lights or zebras, no
## swerving; only the corners of the road it still follows. What it meets, it hits (a crash
## whatever the difference in speed): that is the whole point of a stunt.
var daredevil := false
## Now and then an idiot at the wheel (Traffic, MANIAC_CHANCE): "dronken" (drunk) or
## "agressief" (aggressive), "" for a normal driver. It drives far over the limit
## (MANIAC_SPEED), sees the others late (MANIAC_LOOKAHEAD) and gives way to nobody but a siren,
## and it weaves: it steers its front axle to and fro over its lane (MANIAC_WEAVE, the rear
## following as it does in a corner, so the body and the front wheels really steer), and
## shouts things that fit (DriverShout, its mood) and honks at nothing now and then.
var maniac := ""
var _maniac_clock := 0.0
var _maniac_shout_in := 3.0
var _maniac_horn_in := 2.0
var _weave := 0.0                    # metres the front axle is steered right (+) of its route
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
var _wheel_roll_ratios: Array[float] = []  # per wheel: wheel_radius over its own radius
var _wheel_roll := 0.0               # radians the wheels have turned
var _front_wheel_roll := 0.0         # and the front wheels of another size (front_wheel_model)
var _front_roll_previous := 0.0
var _steering := 0.0                 # current steering angle (radians)
var _front_axle := 1.2               # where the axles are (metres forwards on the body)
var _rear_axle := -1.2
var _front_axle_spot := Vector2.ZERO # where they are now in the world (x, z)
var _rear_axle_spot := Vector2.ZERO
var _front_axle_motion := Vector2.ZERO  # how far the front axle moved in the last step
var _corner_rounding := CORNER_ROUNDING_LEAST  # metres, see the constant
var _lean := 0.0                     # radians a two-wheeler leans (left > 0)
var _lean_rate := 0.0                # and how fast that changes (radians a second)
var _path_steering := 0.0            # steering angle the path asks (radians), before countersteering
## The steering head (a bicycle's fork and bars, two_wheeler.gd): turns with the steering
## about its own y (its parent leans it back as the head tube); the front wheels under it
## are turned by it, not on their own.
var _steering_pivot: Node3D
var _last_yaw := 0.0                 # its heading at the last step
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
## Siren and blue lights on (an emergency vehicle); pulled over for a siren (the others).
var siren_on := false
var yielding := false

var _beacons: Array[MeshInstance3D] = []
var _beacon_light: OmniLight3D
var _siren_clock := 0.0          # seconds until the siren switches by itself
var _yield_countdown := 0
var _yielding_to: Vehicle        # the siren it pulled over for, until it is past
var _yield_clock := 0.0          # seconds it has been pulled over
var _not_for: Vehicle            # the siren it gave up waiting for
var _left_free := true           # a siren: no oncoming traffic close by, so it may pass on the left
var _side_offset := 0.0          # metres the drawn vehicle stands right of its lane (left < 0)
var _brake_hold := 0.0                # seconds the brake lights stay on
var _blocked_by: Vehicle             # the vehicle it is waiting for now, if any
var _held_by_rule := false           # it is stopping for a light or a zebra
var _blocked_clock := 0.0            # seconds it has been standing for another vehicle
var _squeeze_clock := 0.0            # seconds it still ignores the others' claims (gridlock)
var _squeeze_through := false        # and their bodies too (the last squeeze got it nowhere)
var _squeeze_from := Vector3.ZERO    # where its last squeeze started
var _squeezed_in_vain := false       # it hardly moved during its last squeeze


func _ready() -> void:
	var root := owner if owner else get_parent()
	network = RoadNetwork.of(root)
	_lights = root.get_node_or_null("Verkeerslichten") if obeys_lights else null
	_random.seed = route_seed
	var props := root.get_node_or_null("Props") as GridMap
	health = max_health
	_body = Node3D.new()
	_body.name = "Carrosserie"
	_body.top_level = true
	add_child(_body)
	_add_model(props)
	_add_trailer(props)
	_add_wheels(props)
	_add_lamps()
	_add_emergency()
	_measure_length()
	Outline.apply(_body)   # the hard outline, as the characters have
	if _trailer:
		Outline.apply(_trailer)
	if wheel_torque > 0.0:
		acceleration = wheel_torque / maxf(wheel_radius, 0.01) / total_mass()
	_look_countdown = get_instance_id() % TRAFFIC_LOOK_STEPS
	_sight_countdown = get_instance_id() % SIGHT_CHECK_STEPS
	_people_countdown = get_instance_id() % TRAFFIC_LOOK_STEPS
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
	_sight_countdown -= 1
	if _sight_countdown < 0:
		_sight_countdown = SIGHT_CHECK_STEPS
		_steps_between = Sight.steps_between(get_viewport(), global_position)
		unseen = _steps_between > 1
	_watch_progress(delta)
	if _lost_clock >= 0.0:
		_lost_clock += delta
		if unseen or _lost_clock > LOST_SECONDS:
			_relocate()
			return
	if unseen:
		# every other (or fourth) step, with the time of all of them
		_saved_delta += delta
		if _saved_delta < delta * (_steps_between - 0.5):
			return
		delta = _saved_delta
	_saved_delta = 0.0
	_tick_previous = _tick_current
	var speed_before := speed
	_plan()
	_update_emergency(delta)
	_update_maniac(delta)
	var target := _target_speed(delta)
	_watch_for_gridlock(delta)
	# the acceleration that brings it to the target speed in about SPEED_SETTLE seconds,
	# reached gradually; never past the target speed
	var wanted := clampf((target - speed) / SPEED_SETTLE, -braking * 1.5, acceleration)
	# a near crash: braking hard for the vehicle ahead, it honks at it
	if wanted <= -braking * NEAR_CRASH_BRAKING and speed > NEAR_CRASH_SPEED and _blocked_by != null \
			and _horn_clock <= 0.0 and not unseen and not self is RailVehicle:
		_sound_horn("waarschuwen")
	if speed > INSISTENCE_RESET_SPEED:
		_horn_insistence = 0
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
	_bump_clock = maxf(_bump_clock - delta, 0.0)
	_check_crash()
	if not unseen:
		_turn_wheels(speed * delta, delta)
	_move_trailer()
	indicating = _indicator_side()


func _exit_tree() -> void:
	all_vehicles.erase(self)


## Back in the tree after a rest (Traffic takes vehicles out and puts them back): among the
## vehicles again (the first time _ready does that).
func _enter_tree() -> void:
	if is_node_ready() and not all_vehicles.has(self):
		all_vehicles.append(self)


## Starts afresh on the road near `cell`, heading `heading` (Traffic, putting it down round the
## player), standing still; it looks at once whether it is seen.
func put_down(cell: Vector2i, heading: Vector2i) -> void:
	_restart_at(cell, heading)
	_saved_delta = 0.0
	_sight_countdown = 0
	_blocked_by = null
	_traffic_blocker = null


## Lets go of `other` (taken out of the town by Traffic): it no longer waits or makes way for it.
func forget(other: Vehicle) -> void:
	if _blocked_by == other:
		_blocked_by = null
	if _traffic_blocker == other:
		_traffic_blocker = null
	if _yielding_to == other:
		_yielding_to = null
		yielding = false
	if _not_for == other:
		_not_for = null


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
	if unseen:
		return
	var roll := lerp_angle(_roll_previous, _wheel_roll, fraction)
	var front_roll := lerp_angle(_front_roll_previous, _front_wheel_roll, fraction)
	var steering := lerpf(_steering_previous, _steering, fraction)
	# the spokes blur once the wheel turns more than about a quarter radian a frame (they
	# would seem to stand still or run backwards); delta is this frame's time
	var turn_per_frame := speed / maxf(wheel_radius, 0.01) * delta
	var blur := smoothstep(0.25, 0.7, turn_per_frame)
	if _steering_pivot:
		_steering_pivot.rotation.y = steering
	for wheel_index in _wheels.size():
		var wheel := _wheels[wheel_index]
		var ratio := _wheel_roll_ratios[wheel_index]
		if wheel.get_parent() != _steering_pivot:
			wheel.rotation.y = steering if wheel.position.z > 0.0 and max_steering_degrees > 0.0 else 0.0
		var instance := wheel.get_child(0) as GeometryInstance3D
		# the wheel model itself never turns: voxel_wheel.gdshader turns its spokes (front
		# wheels of another size roll at their own rate)
		instance.set_instance_shader_parameter("roll", -(roll if ratio == 1.0 else front_roll))
		instance.set_instance_shader_parameter("spin_blur", blur if ratio == 1.0 else smoothstep(0.25, 0.7, turn_per_frame * ratio))
	_update_lamps()
	_animate(roll, steering, delta)


## Looks at the people on foot ahead (see WALKERS_GROUP): the speed it may go for them
## (`_people_limit`), how far it swerves round one (`_dodge`), and its horn. `seconds`: the
## time since the last look.
func _watch_people(seconds: float) -> void:
	_people_limit = INF
	_dodge = 0.0
	if crashed or _outer_box.size.x <= 0.0:
		return
	var forward := Vector2(global_basis.z.x, global_basis.z.z).normalized()
	var front := _outer_box.end.z
	var half_width := _outer_box.size.x * 0.5
	var room := half_width + PEOPLE_SIDE_ROOM
	var reach := front + PEOPLE_GAP + speed * PEOPLE_LOOK_TIME + speed * speed / (2.0 * maxf(braking, 0.5))
	var on_rails := vehicle_kind == "tram" or vehicle_kind == "trein"
	var nearest := INF          # metres from its front to the nearest one in its path
	var warn_at := INF          # metres to the nearest one it has to swerve round or stop for
	var reach_squared := (reach + 1.0) * (reach + 1.0)
	for walker in get_tree().get_nodes_in_group(WALKERS_GROUP):
		var person := walker as Node3D
		if person == null or not person.is_visible_in_tree():
			continue
		if absf(person.global_position.y - global_position.y) > 2.5:
			continue
		var offset := Vector2(person.global_position.x - global_position.x, person.global_position.z - global_position.z)
		if offset.length_squared() > reach_squared or offset.dot(forward) < front - 1.0:
			continue
		# where along its route ahead they are, and how far beside it (from the middle of its
		# lane, not from where it has swerved to: else it would lose them as it swerves,
		# swing back and run into them); the route may bend, so it looks along it, not straight on
		var place := _beside_route(Vector2(person.global_position.x, person.global_position.z), front, reach, room + 0.6)
		if place.x == INF:
			continue
		var ahead := place.x
		var lane_side := place.y
		var needed := room - absf(lane_side)   # how far over it must go to pass them clear
		if needed <= 0.0:
			continue
		if ahead < PEOPLE_CONTACT and speed > 0.5 and person.has_method("hit_by_vehicle"):
			# driven into: knocked over to the side they stand on
			var side := Vector3(global_basis.x.x, 0.0, global_basis.x.z).normalized() * (1.0 if lane_side >= 0.0 else -1.0)
			person.hit_by_vehicle(self, velocity * 0.8 + side * (speed + 1.5))
			continue
		warn_at = minf(warn_at, ahead)
		if not on_rails and needed <= DODGE_OFFSET and absf(lane_side) > 0.15:
			# near the edge of its path: round them on the other side, slowly
			var swerve := (needed + 0.15) * -signf(lane_side)
			if absf(swerve) > absf(_dodge):
				_dodge = swerve
			_people_limit = minf(_people_limit, DODGE_SPEED + ahead * 0.5)
			continue
		nearest = minf(nearest, ahead)
	# a warning when it would be on them soon, or has to brake hard for them
	var coming_soon := speed > 1.5 and (warn_at / speed < HORN_WITHIN or _people_limit < speed - 1.0)
	if _pushing_through >= 0.0:
		_push_through(seconds, nearest != INF)
		return
	if nearest == INF:
		_standing_for_people = 0.0
		_impatience = 0.0
		if coming_soon and _horn_clock <= 0.0:
			_sound_horn("waarschuwen")
		return
	# the speed follows its target about SPEED_SETTLE late, and it looks only every few steps:
	# that far before the stopping point it starts braking already
	var stop_at := _distance + nearest - PEOPLE_GAP - speed * (SPEED_SETTLE + 0.1)
	# planned with its usual braking: it can brake harder (1.5 x), which is the margin for the
	# braking building up and for the time between its looks
	_people_limit = 0.0 if stop_at - _distance < 0.3 else minf(_people_limit, _approach_speed(0.0, stop_at))
	_standing_for_people = _standing_for_people + seconds if speed < 0.3 else 0.0
	if speed < 0.3:
		_impatience += seconds
	if _impatience >= IMPATIENT_AFTER and not reckless and not has_priority():
		# waited long enough: honks, shouts and drives on
		_impatience = 0.0
		_pushing_through = 0.0
		_path_clear_for = 0.0
		_sound_horn("doordrukken")
		_push_through(0.0, true)
		return
	coming_soon = coming_soon or (speed > 1.5 and _people_limit < speed - 1.0)
	if _horn_clock <= 0.0 and (coming_soon or _standing_for_people > HORN_STANDING):
		_sound_horn("wachten" if _standing_for_people > HORN_STANDING else "waarschuwen")


## Pushing through (see IMPATIENT_AFTER): creeps on at IMPATIENT_SPEED whoever is in its path
## (`someone_in_path`); back to driving as usual once that has been clear IMPATIENT_CALM s,
## or after IMPATIENT_MOST s.
func _push_through(seconds: float, someone_in_path: bool) -> void:
	_pushing_through += seconds
	_path_clear_for = 0.0 if someone_in_path else _path_clear_for + seconds
	_standing_for_people = 0.0
	if _path_clear_for >= IMPATIENT_CALM or _pushing_through >= IMPATIENT_MOST:
		_pushing_through = -1.0
		_impatience = 0.0
		return
	if someone_in_path:
		_people_limit = IMPATIENT_SPEED


## True while it pushes through someone in its way (see IMPATIENT_AFTER).
func is_pushing_through() -> bool:
	return _pushing_through >= 0.0


## Where `spot` (x, z on the map) lies along its route ahead: (metres from its front to
## there, metres right (+) or left of its route there), the first route point (each
## PEOPLE_ROUTE_STEP metres, from its front to `reach` metres from its middle) it is within
## `beside` metres of; (INF, 0) if none.
func _beside_route(spot: Vector2, front: float, reach: float, beside: float) -> Vector2:
	var at := _distance + front
	var last := _distance + reach
	while at <= last:
		var point := _route_point(at)
		var next := _route_point(at + PEOPLE_ROUTE_STEP)
		var along := Vector2(next.x - point.x, next.z - point.z)
		if along.length_squared() > 0.000001:
			along = along.normalized()
			var offset := spot - Vector2(point.x, point.z)
			var ahead_of_point := offset.dot(along)
			if absf(ahead_of_point) <= PEOPLE_ROUTE_STEP * 0.5 + 0.01:
				var side := offset.dot(Vector2(-along.y, along.x))
				if absf(side) < beside:
					return Vector2(at + ahead_of_point - _distance - front, side)
		at += PEOPLE_ROUTE_STEP
	return Vector2(INF, 0.0)


## Sounds its horn (or rings its bell) where it is, held down longer the more it has to
## (LONG_HORNS); the driver may shout something too
## (DriverShout; `mood`: "wachten" standing still for someone in its way, "waarschuwen"
## driving at them, "doordrukken" pushing through).
func _sound_horn(mood := "waarschuwen") -> void:
	_horn_clock = HORN_PAUSE
	_standing_for_people = 0.0
	_horn_insistence += 1
	var horn := _horn()
	# held up long: it holds its horn down
	if _horn_insistence >= HOLD_HORN_FROM and LONG_HORNS.has(horn):
		horn = LONG_HORNS[horn]
	var sound := get_node_or_null("/root/RuimtelijkGeluid")
	if sound and sound.has_method("play_signal"):
		sound.play_signal(global_position, horn, 9.0)
	if not unseen:
		DriverShout.shout(self, vehicle_kind, maniac if maniac != "" else mood, _outer_box.end.y + 0.4)


## Its driver shouts something after running the player over (DriverShout, "aanrijding").
func shout_after_hit() -> void:
	DriverShout.shout(self, vehicle_kind, "aanrijding", _outer_box.end.y + 0.4)


## The horn of its kind (see horn_sound).
func _horn() -> String:
	if horn_sound != "":
		return horn_sound
	match vehicle_kind:
		"fiets":
			return "fiets_bel"
		"brommer":
			return "brommer_toeter"
		"tram":
			return "tram_bel"
		"trein":
			return "trein_hoorn"
		"bus":
			return "bus_toeter"
	return "bus_toeter" if mass_kg > HEAVY_HORN_MASS else "auto_toeter"


## Moves what else there is on it every drawn frame (the rider of a two-wheeler,
## two_wheeler.gd): `roll` is how far the wheels have turned (radians), `steering` the
## steering angle, both as drawn this frame.
func _animate(_roll: float, _steering_now: float, _delta: float) -> void:
	pass


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
	_flash_beacons()
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


# ------------------------------------------------------------------ emergency services

## True while it has the right of way of a siren: an emergency vehicle with the siren on.
func has_priority() -> bool:
	return emergency and siren_on and not crashed


## Switches siren and blue lights on or off (an emergency vehicle only).
func set_siren(on: bool) -> void:
	siren_on = on and emergency
	if _beacon_light:
		_beacon_light.visible = siren_on


func toggle_siren() -> void:
	set_siren(not siren_on)


## Speed limit on `cell` for it (m/s): over it with the siren on.
func _limit_of(cell: Vector3i) -> float:
	if has_priority():
		return network.speed_limit(cell) * EMERGENCY_SPEED_FACTOR
	return network.speed_limit(cell) * float(MANIAC_SPEED.get(maniac, 1.0))


## True if it drives on past `other` as if it were not there: it has the siren on, the
## other has pulled over for it and no oncoming traffic is in the way on the left.
func _passes(other: Vehicle) -> bool:
	return has_priority() and _left_free and other.yielding and not other.has_priority()


## True if a vehicle comes towards it close ahead, beside its lane on the left or in it.
func _oncoming_near() -> bool:
	var forward := Vector2(global_basis.z.x, global_basis.z.z).normalized()
	var mine := Vector2(global_position.x, global_position.z)
	for other in all_vehicles:
		if other == self or absf(other.global_position.y - global_position.y) > 2.5:
			continue
		var relative := Vector2(other.global_position.x, other.global_position.z) - mine
		var ahead := relative.dot(forward)
		if ahead < -half_length or ahead > 25.0 or absf(relative.cross(forward)) > 6.0:
			continue
		var their_forward := Vector2(other.global_basis.z.x, other.global_basis.z.z)
		if their_forward.dot(forward) < -0.5:
			if other.yielding and other._yielding_to == self and other.speed <= YIELD_SPEED + 0.1:
				continue   # pulled over for it: room to pass
			return true
	return false


## The siren and the blue lights of an emergency vehicle: the lamp blocks, a blue light on
## the surroundings, the siren sound; on or off to start with, by its own seed.
func _add_emergency() -> void:
	if not emergency:
		return
	var material := _glow(BEACON_COLOUR, BEACON_GLOW)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = BEACON_LAMP_COLOUR
	for position in beacon_positions:
		_beacons.append(_lamp(position, beacon_size * BEACON_SCALE, material))
	if not beacon_positions.is_empty():
		_beacon_light = OmniLight3D.new()
		_beacon_light.name = "Zwaailicht"
		_beacon_light.light_color = BEACON_COLOUR
		_beacon_light.omni_range = 9.0
		_beacon_light.light_energy = 0.0
		_beacon_light.shadow_enabled = false
		_beacon_light.position = beacon_positions[0] * Vector3(0.0, 1.0, 1.0) + Vector3(0.0, 0.3, 0.0)
		_beacon_light.visible = false
		_body.add_child(_beacon_light)
	_siren_clock = _random.randf_range(SIREN_OFF_SECONDS.x, SIREN_ON_SECONDS.y)
	set_siren(_random.randf() < 0.6)


## Every physics step: an emergency vehicle switches its siren by itself now and then; the
## others look behind them for a siren and make way for it; the drawn body moves over.
func _update_emergency(delta: float) -> void:
	if emergency and siren_duty and not crashed:
		_siren_clock -= delta
		if _siren_clock <= 0.0:
			toggle_siren()
			var seconds := SIREN_ON_SECONDS if siren_on else SIREN_OFF_SECONDS
			_siren_clock = _random.randf_range(seconds.x, seconds.y)
	var wanted_offset := 0.0
	if has_priority():
		yielding = false
		_yielding_to = null
		# once beside one that pulled over it goes on past it (swinging back would run into it)
		_left_free = _beside_yielder() or not _oncoming_near()
		if _left_free and _passing_someone():
			wanted_offset = -PASS_OFFSET
	elif makes_way and avoids_others and not crashed:
		_yield_countdown -= 1
		if _yield_countdown < 0:
			_yield_countdown = YIELD_LOOK_STEPS
			if yielding and _yield_clock > YIELD_LONGEST:
				_not_for = _yielding_to   # waited long enough: drives on, and not again for this one
				yielding = false
				_yielding_to = null
			elif yielding and _yielding_to and is_instance_valid(_yielding_to) and _yielding_to.has_priority() and not _is_past(_yielding_to):
				pass   # stays pulled over until the siren is past it
			else:
				# a siren behind it, or one coming towards it (that one has to pass on the left,
				# where it drives: it moves over and waits too)
				var siren := _siren_behind()
				if siren == null:
					siren = _siren_oncoming()
				if siren != null and siren == _not_for:
					siren = null
				yielding = siren != null and (yielding or not _moved_over_for_siren())
				_yielding_to = siren if yielding else null
		_yield_clock = _yield_clock + delta if yielding else 0.0
		if yielding:
			wanted_offset = YIELD_OFFSET
	else:
		yielding = false
	wanted_offset += _dodge
	# sideways only as fast as steering allows at this speed: standing still it cannot
	_side_offset = move_toward(_side_offset, wanted_offset, minf(OFFSET_RATE, speed * SIDEWAYS_PER_SPEED) * delta)


## How far (metres, right +) an idiot of this kind steers its front axle off its route at
## `clock` seconds, driving `speed` m/s: MANIAC_WEAVE's two waves, less at a crawl, none standing.
static func maniac_weave(kind: String, clock: float, speed: float) -> float:
	if not MANIAC_WEAVE.has(kind):
		return 0.0
	var wave: Array = MANIAC_WEAVE[kind]
	var swing := float(wave[0]) * sin(clock * TAU / float(wave[1])) + float(wave[2]) * sin(clock * TAU / float(wave[3]) + 1.3)
	return swing * clampf(speed / 6.0, 0.0, 1.0)


## An idiot at the wheel (`maniac`): the weave of its front axle (two waves over each other,
## less at a crawl, none standing still) and now and then a shout while it is in view.
func _update_maniac(delta: float) -> void:
	if maniac == "" or crashed:
		_weave = 0.0
		return
	_maniac_clock += delta
	_weave = maniac_weave(maniac, _maniac_clock, speed)
	_maniac_horn_in -= delta
	if _maniac_horn_in <= 0.0:
		_maniac_horn_in = _random.randf_range(MANIAC_HORN_EVERY.x, MANIAC_HORN_EVERY.y)
		if not unseen:
			_sound_horn(maniac)   # (its shout, if any, fits its mood)
	_maniac_shout_in -= delta
	if _maniac_shout_in <= 0.0:
		_maniac_shout_in = _random.randf_range(MANIAC_SHOUT_EVERY.x, MANIAC_SHOUT_EVERY.y)
		if not unseen:
			DriverShout.shout(self, vehicle_kind, maniac, _outer_box.end.y + 0.4)


## The nearest emergency vehicle with its siren on that comes up behind it in its lane
## (going its way, not too far beside its line), or null.
func _siren_behind() -> Vehicle:
	var forward := Vector2(global_basis.z.x, global_basis.z.z).normalized()
	var mine := Vector2(global_position.x, global_position.z)
	var nearest: Vehicle = null
	var nearest_distance := SIREN_HEARD
	for other in all_vehicles:
		if other == self or not other.has_priority() or absf(other.global_position.y - global_position.y) > 2.5:
			continue
		var theirs := Vector2(other.global_position.x, other.global_position.z)
		var relative := mine - theirs
		var their_forward := Vector2(other.global_basis.z.x, other.global_basis.z.z).normalized()
		var behind := relative.dot(their_forward)
		if behind <= 0.0 or behind > nearest_distance or their_forward.dot(forward) < 0.7:
			continue
		if absf(relative.cross(their_forward)) > SIREN_BESIDE:
			continue
		nearest = other
		nearest_distance = behind
	return nearest


## The nearest emergency vehicle with its siren on that comes towards it close ahead,
## beside its lane on the left or in it (as _oncoming_near looks for it), or null.
func _siren_oncoming() -> Vehicle:
	var forward := Vector2(global_basis.z.x, global_basis.z.z).normalized()
	var mine := Vector2(global_position.x, global_position.z)
	var nearest: Vehicle = null
	var nearest_distance := ONCOMING_SIREN_HEARD
	for other in all_vehicles:
		if other == self or not other.has_priority() or absf(other.global_position.y - global_position.y) > 2.5:
			continue
		var relative := Vector2(other.global_position.x, other.global_position.z) - mine
		var ahead := relative.dot(forward)
		if ahead <= 0.0 or ahead > nearest_distance or absf(relative.cross(forward)) > ONCOMING_BESIDE:
			continue
		var their_forward := Vector2(other.global_basis.z.x, other.global_basis.z.z).normalized()
		if their_forward.dot(forward) > -0.7:
			continue
		nearest = other
		nearest_distance = ahead
	return nearest


## True if `other` has gone by: its back is clear ahead of its front (one coming towards
## it: behind its back).
func _is_past(other: Vehicle) -> bool:
	var forward := Vector2(global_basis.z.x, global_basis.z.z).normalized()
	var relative := Vector2(other.global_position.x - global_position.x, other.global_position.z - global_position.z)
	var their_forward := Vector2(other.global_basis.z.x, other.global_basis.z.z).normalized()
	if their_forward.dot(forward) < -0.7:
		return relative.dot(forward) < -(half_length + other.half_length + 2.0) or relative.length() > SIREN_HEARD
	return relative.dot(forward) > half_length + other.half_length + 2.0 or relative.length() > SIREN_HEARD


## True if a vehicle that pulled over for it is just ahead of it (it swings out to pass).
func _passing_someone() -> bool:
	var forward := Vector2(global_basis.z.x, global_basis.z.z).normalized()
	var mine := Vector2(global_position.x, global_position.z)
	for other in all_vehicles:
		if other == self or not other.yielding:
			continue
		var relative := Vector2(other.global_position.x, other.global_position.z) - mine
		var ahead := relative.dot(forward)
		if ahead > -half_length - other.half_length and ahead < 18.0 and absf(relative.cross(forward)) < SIREN_BESIDE:
			return true
	return false


## True if one that pulled over for it is right beside it (their bodies side by side).
func _beside_yielder() -> bool:
	var forward := Vector2(global_basis.z.x, global_basis.z.z).normalized()
	var mine := Vector2(global_position.x, global_position.z)
	for other in all_vehicles:
		if other == self or not other.yielding:
			continue
		var relative := Vector2(other.global_position.x, other.global_position.z) - mine
		if absf(relative.dot(forward)) < half_length + other.half_length and absf(relative.cross(forward)) < SIREN_BESIDE:
			return true
	return false


## Makes way for a siren by moving over into a free lane alongside going the same way, the
## right one first: plans that from the next cell on. False if there is none.
func _moved_over_for_siren() -> bool:
	var index := _current_index()
	if index + 1 >= _route_cells.size():
		return false
	var cell := _route_cells[index + 1]
	var heading := _route_headings[index + 1]
	if network.is_crossing(cell):
		return false
	for side in [Vector2i(-heading.y, heading.x), Vector2i(heading.y, -heading.x)]:
		var target: Vector2i = Vector2i(cell.x, cell.z) + heading * 2 + side
		var beside := network.find(target.x, target.y, cell.y, cell, 2)
		if beside == RoadNetwork.NONE or not network.lanes(beside).has(heading) or not _may_use(beside, heading):
			continue
		# really beside it (the search round the spot can find its own lane further on)
		var sideways: Vector2i = Vector2i(beside.x - cell.x, beside.z - cell.z)
		if sideways.x * side.x + sideways.y * side.y < 1:
			continue
		if network.is_crossing(beside) or network.step(beside, heading) == RoadNetwork.NONE:
			continue
		var taken := false
		for other in all_vehicles:
			taken = taken or (other != self and other.covers(beside))
		if taken:
			continue
		_route_cells.resize(index + 2)
		_route_headings.resize(index + 2)
		_route_distances.resize(index + 2)
		_route_ended = false
		_append(beside, heading)
		return true
	return false


## The blue lights: the left and the right half in turn while the siren is on, and the
## blue light they throw round them.
func _flash_beacons() -> void:
	if _beacons.is_empty():
		return
	var phase := fmod(Time.get_ticks_msec() / 1000.0, BEACON_CYCLE) / BEACON_CYCLE
	var left_on := phase < 0.5
	# a double flash per half
	var flash := fmod(phase * 2.0, 1.0)
	var lit := flash < 0.2 or (flash > 0.35 and flash < 0.55)
	for lamp in _beacons:
		lamp.visible = siren_on and lit and ((lamp.position.x > 0.0) == left_on)
	if _beacon_light:
		_beacon_light.light_energy = BEACON_LIGHT_ENERGY if siren_on and lit else 0.0


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
	if reckless or has_priority() or network.is_crossing(from_cell):
		return ""
	var zebra := network.is_zebra(to_cell)
	var heading := Vector2i(to_cell.x - from_cell.x, to_cell.z - from_cell.z)
	# just off a crossing, between it and the next: on, to clear the crossing behind (not
	# waiting there with its back end still on it)
	var behind := network.step(from_cell, -heading)
	if behind != RoadNetwork.NONE and network.is_crossing(behind) and (network.is_crossing(to_cell) or zebra):
		return ""
	# the crossing it comes onto: this cell, or the one right behind the zebra(s) before it
	# (so it stops before the zebra for a red light, never on it)
	var crossing := _crossing_onto(to_cell, heading)
	if not zebra and crossing == RoadNetwork.NONE:
		return ""
	var phase := -1
	if crossing != RoadNetwork.NONE and _lights and _lights.has_method("car_phase"):
		# the lights of the whole crossing, looked up from its middle: on a wide crossing
		# its first cell lies too far from the lights to find them
		phase = _lights.car_phase(_crossing_middle(crossing), heading.x == 0)
	if phase == 2:
		return "light"
	if phase == 1:
		var braking_distance := speed * speed / (2.0 * braking)
		return "light" if distance > braking_distance - 0.5 else ""
	if phase == 0:
		return ""
	if zebra and not is_pushing_through() and _someone_crossing(to_cell) and (not _waited_at.has(to_cell) or Pedestrians.someone_on_zebra(to_cell)):
		return "zebra"
	return ""


## True if someone is on or about to step onto zebra `cell` (a pedestrian has claimed it,
## scripts/world/pedestrians.gd). Once it has waited there it drives on, unless someone is
## on the zebra.
func _someone_crossing(cell: Vector3i) -> bool:
	return Pedestrians.someone_at_zebra(cell)


## Metres between its front and the line it stops at (a zebra, a crossing), and how far
## over the line its front may have come braking late (a vehicle out of view moves in
## bigger steps) and still stop there, instead of driving on.
const STOP_LINE_GAP := 1.0
const STOP_OVERSHOOT := 1.0


## How far its front sticks out ahead of its middle (metres): the front of what is drawn
## on it, or half_length if that is further.
func _front_reach() -> float:
	return maxf(half_length, _outer_box.end.z)


## Zebra cells before a crossing that still count as part of it (for its lights).
const ZEBRAS_BEFORE_CROSSING := 2
## Most cells of a crossing taken for its middle (a big square of them is a few dozen).
const CROSSING_CELLS_MAX := 80
## The middle of each crossing, by every cell of it (per road network).
static var _crossing_middles := {}


## The crossing a vehicle comes onto by entering `cell` in `heading`: `cell` itself if it
## is one, the crossing right behind it if `cell` is a zebra before it (up to
## ZEBRAS_BEFORE_CROSSING zebra cells), else RoadNetwork.NONE.
func _crossing_onto(cell: Vector3i, heading: Vector2i) -> Vector3i:
	var looked_at := cell
	for _zebra_index in ZEBRAS_BEFORE_CROSSING + 1:
		if looked_at == RoadNetwork.NONE:
			return RoadNetwork.NONE
		if network.is_crossing(looked_at):
			return looked_at
		if not network.is_zebra(looked_at):
			return RoadNetwork.NONE
		looked_at = network.step(looked_at, heading)
	return RoadNetwork.NONE


## The middle (metres) of the crossing that `cell` is part of: the mean of its touching
## crossing cells; found once per crossing and kept for all its cells.
func _crossing_middle(cell: Vector3i) -> Vector3:
	var key := [network.get_instance_id(), cell]
	if _crossing_middles.has(key):
		return _crossing_middles[key]
	var found := {cell: true}
	var open: Array[Vector3i] = [cell]
	var sum := Vector3.ZERO
	while not open.is_empty() and found.size() <= CROSSING_CELLS_MAX:
		var crossing_cell: Vector3i = open.pop_back()
		sum += network.centre(crossing_cell)
		for side: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := network.step(crossing_cell, side)
			if next != RoadNetwork.NONE and not found.has(next) and network.is_crossing(next):
				found[next] = true
				open.append(next)
	var counted := found.size() - open.size()
	var middle := sum / maxf(counted, 1.0)
	for crossing_cell: Vector3i in found:
		_crossing_middles[[network.get_instance_id(), crossing_cell]] = middle
	return middle


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
		if _takes_move_over(cell, heading):
			_append(network.move_over_target(cell), heading)
			continue
		var next_cell := network.step(cell, heading)
		var options: Array[Vector2i] = []
		if next_cell != RoadNetwork.NONE:
			var entered := _crossing_entry_heading()
			for option in _ways_out(next_cell):
				if option == -heading or not _may_use(next_cell, option):
					continue
				# on a crossing: the heading it drove onto it with (the turn here counts)
				var onto_crossing := (entered if entered != Vector2i.ZERO else heading) if network.is_crossing(next_cell) else Vector2i.ZERO
				if not _leads_on(next_cell, option, onto_crossing) or _only_back_after(next_cell, option, heading):
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
		if network.is_crossing(next_cell):
			_lane_reversals = 0
		_append(next_cell, next_heading)


## True if it moves over from `cell` into the lane the map marks beside it (an exit): always
## where its own lane ends there, else as it would turn off (straight_chance).
func _takes_move_over(cell: Vector3i, heading: Vector2i) -> bool:
	var target := network.move_over_target(cell)
	if target == RoadNetwork.NONE or not network.lanes(target).has(heading) or not _may_use(target, heading):
		return false
	var ahead := network.step(cell, heading)
	if ahead == RoadNetwork.NONE or not network.lanes(ahead).has(heading):
		return true
	return _random.randf() >= straight_chance


## True if leaving `cell` in `heading` leads into a cell it may use, across a crossing
## to the first cell past it, straight on or turning off the crossing: not into a square for cyclists, a tram ramp or a bus lane,
## where it would only have to turn round (on a crossing it may not). Turning off a crossing
## keeps to its rules (once at most, never back the way it came: `entered`, the heading it
## drove onto it with), else a turn it may not take there would seem to lead on, and it
## would end up going to and fro over the crossing.
func _leads_on(cell: Vector3i, heading: Vector2i, entered := Vector2i.ZERO) -> bool:
	if network.move_over_target(cell) != RoadNetwork.NONE:
		return true   # it goes on beside it (an exit lane leading off in steps)
	# the heading it drove onto this crossing with (`entered`, on a crossing it is on already),
	# else the one it drives onto the next with: the rules of a crossing hold for the turns
	# off it too (turning once at most, never back where it came from)
	var onto := entered if entered != Vector2i.ZERO else heading
	var here := network.step(cell, heading)
	for step in CROSSING_LOOKAHEAD:
		if here == RoadNetwork.NONE or not _may_use(here, heading):
			return false
		if not network.is_crossing(here):
			return true
		# a turn off the crossing leads on too (a T-junction where straight on ends), if it
		# has not turned on it already, and not back the way it came onto it
		for way in _ways_out(here):
			if way == heading or way == -heading or heading != onto or way == -onto:
				continue
			var off := network.step(here, way)
			if off != RoadNetwork.NONE and not network.is_crossing(off) and _may_use(off, way):
				return true
		here = network.step(here, heading)
	return true


## True if the cell after `cell` in `option` only leads back the way it came onto `cell`
## (arriving in `heading`): a turn into the lane of the other way, such as off a through
## road into the lane beside a junction.
func _only_back_after(cell: Vector3i, option: Vector2i, heading: Vector2i) -> bool:
	if option == heading:
		return false
	var after := network.step(cell, option)
	if after == RoadNetwork.NONE:
		return false
	var ways := _ways_out(after)
	return not ways.is_empty() and ways.all(func(way: Vector2i) -> bool: return way == -heading)


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
	# no lane back beside it: back down its own lane
	_append(cell - Vector3i(heading.x, 0, heading.y), -heading)
	_turned_round_at = _route_headings.size() - 1
	_lane_reversals += 1
	if _lane_reversals >= LANE_REVERSALS_LOST and _lost_clock < 0.0:
		_lost_clock = 0.0


# ------------------------------------------------------------------ speed

## Speed it may drive now: the speed limit (braking in time for a lower one ahead),
## slower before corners, braking for a stop.
func _target_speed(delta: float) -> float:
	var index := _current_index()
	var last := _route_cells.size() - 1
	var top_speed := top_speed_kmh / 3.6
	speed_limit = _limit_of(_cell_under())
	_blocked_by = null
	_held_by_rule = false
	var target := minf(top_speed, speed_limit)
	if reckless:
		return minf(target, RECKLESS_SPEED)
	if daredevil:
		# full throttle, only the corners still slow it (else it would leave the road)
		target = daredevil_speed()
		_people_limit = INF
		_dodge = 0.0
		return minf(target, _corner_speed_ahead(index, last))
	if yielding:
		var close := _yielding_to != null and is_instance_valid(_yielding_to) \
				and _yielding_to.global_position.distance_to(global_position) < YIELD_STAND_DISTANCE
		target = minf(target, 0.0 if close else YIELD_SPEED)
	# a lower speed limit ahead: down to it LIMIT_LEAD seconds before its cell starts
	for ahead_index in range(index + 1, last + 1):
		var cell_start := (_route_distances[ahead_index - 1] + _route_distances[ahead_index]) * 0.5
		var limit := minf(top_speed, _limit_of(_route_cells[ahead_index]))
		if limit < speed:
			target = minf(target, _approach_speed(limit, cell_start - speed * LIMIT_LEAD))
	# corners: a change of heading ahead
	target = minf(target, _corner_speed_ahead(index, last))
	if avoids_others and not (_squeeze_clock > 0.0 and _squeeze_through):
		_look_countdown -= 1
		if _look_countdown < 0:
			_look_countdown = TRAFFIC_LOOK_STEPS - 1
			# squeezing past it ignores the cells the others stand on or claim, but still
			# keeps behind the body right ahead of it (no driving through a queue)
			var claims_limit := INF if _squeeze_clock > 0.0 else _traffic_speed(index, last)
			_traffic_limit = minf(claims_limit, _body_ahead_speed(claims_limit))
			_traffic_blocker = _blocked_by
		_blocked_by = _traffic_blocker
		target = minf(target, _traffic_limit)
	# people on foot in its way
	_horn_clock = maxf(_horn_clock - delta, 0.0)
	_people_countdown -= 1
	if _people_countdown < 0:
		_people_countdown = TRAFFIC_LOOK_STEPS - 1
		_watch_people(delta * TRAFFIC_LOOK_STEPS)
	target = minf(target, _people_limit)
	# the first cell boundary it has to stop at
	for ahead_index in range(index + 1, last + 1):
		# its front STOP_LINE_GAP before the line between the cells (the start of the zebra
		# or the crossing): before the traffic light, not beside it
		var line_at := (_route_distances[ahead_index - 1] + _route_distances[ahead_index]) * 0.5 - _front_reach()
		if _distance > line_at + STOP_OVERSHOOT:
			continue           # its front is well over the line already
		# (braking a little past the stop point, even to just over the line, it still stops)
		var stop_at := line_at - STOP_LINE_GAP
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


## The highest speed now from which it still gets round the corners ahead (a change of
## heading in a cell of the route) at its corner speed.
func _corner_speed_ahead(index: int, last: int) -> float:
	var highest := INF
	for corner_index in range(maxi(index, 1), last + 1):
		if _route_headings[corner_index - 1] == _route_headings[corner_index]:
			continue
		var corner_at := _route_distances[corner_index]
		if _distance > corner_at + CORNER_REACH:   # the front axle is round it by then
			continue
		var tight := (corner_index < last and _route_headings[corner_index] != _route_headings[corner_index + 1]) \
				or (corner_index >= 2 and _route_headings[corner_index - 2] != _route_headings[corner_index - 1])
		var through_corner := (tight_corner_speed if tight else corner_speed) * CORNER_SPEED_FACTOR
		highest = minf(highest, _approach_speed(through_corner, corner_at - _corner_lead))
	return highest


## How fast a daredevil goes (m/s): DAREDEVIL_TOP_FACTOR over its top speed, at most
## DAREDEVIL_LIMIT_FACTOR times the speed limit (never under its own top speed).
func daredevil_speed() -> float:
	var top_speed := top_speed_kmh / 3.6
	return maxf(top_speed, minf(top_speed * DAREDEVIL_TOP_FACTOR, maxf(speed_limit, 1.0) * DAREDEVIL_LIMIT_FACTOR))


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


## Puts the vehicle on its route: the front axle on the rounded route (steered `_weave`
## metres off it by an idiot at the wheel), the rear axle pulled straight towards it, the body
## on the line between them, tilted with the road under the axles. delta 0 = at once (at the
## start): the rear axle on the route too.
func _place(delta := 0.0) -> void:
	var front_spot := _rounded_route_point(_distance + _front_axle)
	# moving over (pulled over for a siren, passing, swerving round someone) and the weave of
	# an idiot: steered with the front axle, the rear follows, so the body turns and the front
	# wheels steer as in a real swerve (right of the heading is (-z, x) on the map)
	var steered_off := _side_offset + _weave
	if steered_off != 0.0:
		var ahead := _rounded_route_point(_distance + _front_axle + 1.0) - front_spot
		if ahead.length_squared() > 0.0001:
			ahead = ahead.normalized()
			front_spot += Vector2(-ahead.y, ahead.x) * steered_off
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
	if leans:
		_lean_into_corner(atan2(along_body.x, along_body.y), delta)


## Tilts a two-wheeler into its corner: the lean that balances the bend it will be in
## LEAN_LEAD seconds from now at this speed (so it leans over before the corner, as a
## rider does), eased in and out (LEAN_RATE); a left turn (the heading turning towards +x,
## its left) leans it to the left.
func _lean_into_corner(yaw: float, delta: float) -> void:
	if delta > 0.0:
		var limit := deg_to_rad(max_lean_degrees)
		var bend := _bend_ahead(_distance + _front_axle + speed * LEAN_LEAD)
		var wanted := clampf(atan(speed * speed * bend / GRAVITY), -limit, limit)
		var before := _lean
		_lean = lerpf(_lean, wanted, 1.0 - exp(-LEAN_RATE * delta))
		_lean_rate = (_lean - before) / delta
	_last_yaw = yaw
	global_basis = global_basis * Basis(Vector3(0.0, 0.0, 1.0), -_lean)


## How sharply the rounded route bends at route distance `at` (radians per metre, a left
## bend positive), measured over LEAN_SPAN metres either side.
func _bend_ahead(at: float) -> float:
	var behind := _rounded_route_point(at - LEAN_SPAN)
	var here := _rounded_route_point(at)
	var ahead := _rounded_route_point(at + LEAN_SPAN)
	var first := here - behind
	var second := ahead - here
	if first.length_squared() < 0.0001 or second.length_squared() < 0.0001:
		return 0.0
	var turn := wrapf(atan2(second.x, second.y) - atan2(first.x, first.y), -PI, PI)
	return turn / ((first.length() + second.length()) * 0.5)


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
	var wheel := _wheel_kind(props.mesh_library, wheel_model, wheel_radius)
	if wheel.is_empty():
		return
	var front := wheel
	var front_radius := wheel_radius
	if front_wheel_model != "":
		front_radius = front_wheel_radius if front_wheel_radius > 0.0 else wheel_radius
		var other := _wheel_kind(props.mesh_library, front_wheel_model, front_radius)
		if not other.is_empty():
			front = other
		else:
			front_radius = wheel_radius
	for wheel_position in wheel_positions:
		var kind: Dictionary = front if wheel_position.z > 0.0 else wheel
		_add_wheel(_body, wheel_position, kind["mesh"], kind["material"], kind["transform"],
				wheel_radius / maxf(front_radius if wheel_position.z > 0.0 else wheel_radius, 0.01))
	if _trailer:
		for wheel_position in trailer_wheel_positions:
			_add_wheel(_trailer, wheel_position - Vector3(0.0, hitch_position.y, 0.0), wheel["mesh"], wheel["material"], wheel["transform"])


## The mesh, wheel material and transform of one size of wheel (props item `item_name`,
## rolling with `radius`); empty if the library lacks it.
func _wheel_kind(library: MeshLibrary, item_name: String, radius: float) -> Dictionary:
	var item := library.find_item_by_name(item_name)
	if item < 0:
		push_warning("vehicle: no item '%s' in the props library" % item_name)
		return {}
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
	var scale_of_wheel := radius / 0.375
	material.set_shader_parameter("rim_radius", 0.24 * scale_of_wheel)
	material.set_shader_parameter("hub_radius", 0.07 * scale_of_wheel)
	material.set_shader_parameter("spoke_half_width", 0.05 * scale_of_wheel)
	return {"mesh": mesh, "material": material, "transform": Transform3D(mesh_transform.basis, mesh_transform.origin - middle)}


func _add_wheel(parent: Node3D, at: Vector3, mesh: Mesh, material: Material, wheel_transform: Transform3D, roll_ratio := 1.0) -> void:
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
	_wheel_roll_ratios.append(roll_ratio)


## Rolls the wheels over the distance driven and steers the front ones the way the front
## axle really moves, seen from the body.
func _turn_wheels(distance_driven: float, delta: float) -> void:
	if _wheels.is_empty():
		return
	_roll_previous = _wheel_roll
	_front_roll_previous = _front_wheel_roll
	_steering_previous = _steering
	_wheel_roll = fmod(_wheel_roll + distance_driven / maxf(wheel_radius, 0.01), TAU)
	if front_wheel_radius > 0.0:
		_front_wheel_roll = fmod(_front_wheel_roll + distance_driven / front_wheel_radius, TAU)
	var wanted := _path_steering
	var max_angle := deg_to_rad(max_steering_degrees)
	if distance_driven > 0.001 and _front_axle_motion.length_squared() > 0.0:
		var seen_from_body := global_basis.inverse() * Vector3(_front_axle_motion.x, 0.0, _front_axle_motion.y)
		wanted = clampf(atan2(seen_from_body.x, seen_from_body.z), -max_angle, max_angle)
	_path_steering = lerpf(_path_steering, wanted, 1.0 - exp(-steering_rate * delta))
	_steering = _path_steering
	if leans:
		# countersteering: leaning over to the left takes a turn of the bars to the right
		_steering = clampf(_path_steering - countersteer * _lean_rate, -max_angle, max_angle)
	# the wheels themselves are turned every frame in _process, between this step and the last


# ------------------------------------------------------------------ other vehicles

## Highest speed for the other vehicles ahead: it stops behind the first planned cell
## (within TRAFFIC_LOOKAHEAD) that another vehicle stands on, or a crossing cell that
## another vehicle will reach first (it gives way).
func _traffic_speed(index: int, last: int) -> float:
	var target := INF
	var lookahead := MANIAC_LOOKAHEAD if maniac != "" else TRAFFIC_LOOKAHEAD
	for ahead_index in range(index + 1, last + 1):
		var at := _route_distances[ahead_index]
		if at - _distance > lookahead:
			break
		var cell := _route_cells[ahead_index]
		var my_time := (at - _distance) / maxf(speed, 1.0)
		var blocked := false
		var crossing := network.is_crossing(cell)
		for other in all_vehicles:
			# measured to its middle: a long one (a train) reaches further than that
			if other == self or other.global_position.distance_to(global_position) > NEAR_VEHICLES + other._reach():
				continue
			if _passes(other):
				continue
			if other.covers(cell):
				blocked = true
			elif crossing and not other.crashed and other.speed > 0.5 and (maniac == "" or other.has_priority()):
				var their_distance := other.distance_to(cell)
				if their_distance >= 0.0:
					var their_time := their_distance / maxf(other.speed, 1.0)
					var first := their_time < my_time - 0.2 or (absf(their_time - my_time) <= 0.2 and other.get_instance_id() < get_instance_id())
					if other.has_priority() and not has_priority():
						# a siren: always give way, but not to one that comes up behind it (that
						# one waits for it to get out of the way: it drives on, clearing the road)
						blocked = their_time < PRIORITY_CLAIM_SECONDS and not _clears_way_for(other, at - _distance, their_distance)
					elif has_priority() and not other.has_priority() and other.makes_way:
						# it gives way to nobody else, but to one that can no longer stop
						blocked = their_time < COMMITTED_SECONDS and first
					elif _comes_from_right(other):
						# traffic from the right goes first, unless it is too late to stop
						blocked = their_time < CLAIM_SECONDS and not (my_time < COMMITTED_SECONDS and not first)
					elif other._comes_from_right(self):
						# it is the one from the right: on, unless the other can no longer stop
						blocked = their_time < COMMITTED_SECONDS and first
					else:
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


## True if `other` comes from its right towards the crossing (it drives across its way from
## right to left, on its right-hand side): traffic from the right goes first.
func _comes_from_right(other: Vehicle) -> bool:
	return comes_from_right(Vector2(global_position.x, global_position.z), Vector2(global_basis.z.x, global_basis.z.z),
		Vector2(other.global_position.x, other.global_position.z), Vector2(other.global_basis.z.x, other.global_basis.z.z))


## The rule of _comes_from_right on the map (x, z): one at `my_spot` heading `my_forward`,
## the other at `their_spot` heading `their_forward`.
static func comes_from_right(my_spot: Vector2, my_forward: Vector2, their_spot: Vector2, their_forward: Vector2) -> bool:
	var forward := my_forward.normalized()
	var right := Vector2(-forward.y, forward.x)   # forward x up: +z ahead, -x to the right
	return (their_spot - my_spot).dot(right) > 0.0 and their_forward.normalized().dot(right) < -RIGHT_OF_WAY_ACROSS


## True if the siren `other` comes up behind it on the way to the same cell (it is nearer
## to it, the siren going its way) or waits for it: then it does not give way to it there
## but drives on, out of its way, instead of both waiting for each other.
func _clears_way_for(other: Vehicle, my_distance: float, their_distance: float) -> bool:
	if other._blocked_by == self:
		return true
	var forward := Vector2(global_basis.z.x, global_basis.z.z).normalized()
	var their_forward := Vector2(other.global_basis.z.x, other.global_basis.z.z).normalized()
	return their_distance > my_distance and their_forward.dot(forward) > 0.7


## Highest speed for the body of another vehicle right ahead of its nose: the cells of
## _traffic_speed are 4 m, this keeps it behind the vehicle itself, in a lane or a corner.
func _body_ahead_speed(claims_limit := INF) -> float:
	var forward := Vector2(global_basis.z.x, global_basis.z.z).normalized()
	var mine := Vector2(global_position.x, global_position.z)
	var nose := _outer_box.end.z
	var side_room := _outer_box.size.x * 0.5 + BODY_SIDE_ROOM
	var nearest_gap := INF
	var nearest_body: Vehicle = null
	for other in all_vehicles:
		if other == self or other.crashed or absf(other.global_position.y - global_position.y) > 2.5 or _passes(other):
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
				nearest_body = other
	if nearest_gap > BODY_LOOKAHEAD:
		return INF   # nothing close enough to hold it: who it waits for stays as it was
	var limit := sqrt(2.0 * braking * maxf(nearest_gap - BODY_GAP, 0.0))
	if limit < claims_limit:
		_blocked_by = nearest_body   # this body holds it back more than the cells do
	return limit


## Driving but getting nowhere (to and fro between two cells, round in a loop): it counts as
## lost, and is moved soon (a rail vehicle changes ends at the end of its track: not that).
func _watch_progress(delta: float) -> void:
	if crashed or self is RailVehicle or _lost_clock >= 0.0:
		_progress_clock = 0.0
		_progress_from = global_position
		return
	if absf(speed) > PROGRESS_SPEED:
		_progress_clock += delta
	if _progress_clock < PROGRESS_CHECK:
		return
	if global_position.distance_to(_progress_from) < PROGRESS_LEAST:
		_lost_clock = LOST_SECONDS - LOST_SOON
	_progress_clock = 0.0
	_progress_from = global_position


## Standing still for other vehicles: if they wait for each other in a ring, one squeezes
## past after a while (a queue for a light or a zebra just waits).
func _watch_for_gridlock(delta: float) -> void:
	if _squeeze_clock > 0.0 and _squeeze_clock <= delta:
		_squeezed_in_vain = global_position.distance_to(_squeeze_from) < SQUEEZE_IN_VAIN
	_squeeze_clock = maxf(_squeeze_clock - delta, 0.0)
	if _squeeze_clock <= 0.0:
		_squeeze_through = false
	elif _squeeze_through and global_position.distance_to(_squeeze_from) > SQUEEZE_IN_VAIN * 3.0:
		_squeezed_in_vain = false
	if _blocked_by == null or speed > STANDING_SPEED:
		_blocked_clock = 0.0
		return
	_blocked_clock += delta
	# held up by another vehicle: it honks at it (again every HORN_PAUSE, ever longer)
	if _blocked_clock > HONK_AT_VEHICLE_AFTER and _horn_clock <= 0.0 and not unseen and not self is RailVehicle:
		_sound_horn("wachten")
	var patience := RING_PATIENCE + get_instance_id() % RING_PATIENCE_SPREAD
	# a ring with a siren in it: not the siren (it may not wait), the other gets out of the way
	if _blocked_clock > SIREN_RING_PATIENCE and not has_priority() and _waits_in_a_ring_with_siren():
		patience = SIREN_RING_PATIENCE
	if _blocked_clock > LOST_PATIENCE or (_blocked_clock > patience and _waits_in_a_ring()):
		# first it only ignores the claims; if the bodies themselves are locked (that
		# squeeze got it nowhere, or it waited far too long) it drives through them
		_squeeze_through = _squeezed_in_vain or _squeeze_clock > 0.0 or _blocked_clock > LOST_PATIENCE \
				or _head_on_with(_blocked_by)
		_squeezed_in_vain = false
		_squeeze_from = global_position
		_squeeze_clock = SQUEEZE_TIME
		_blocked_clock = 0.0


## True if `other` faces it and waits for it too: their bodies hold each other, so ignoring
## the claimed cells alone would get neither of them on.
func _head_on_with(other: Vehicle) -> bool:
	if other == null or other._blocked_by != self:
		return false
	var forward := Vector2(global_basis.z.x, global_basis.z.z).normalized()
	var their_forward := Vector2(other.global_basis.z.x, other.global_basis.z.z).normalized()
	return their_forward.dot(forward) < -0.5


## True if it waits for a siren that, round the ring, waits for it.
func _waits_in_a_ring_with_siren() -> bool:
	var seen := {}
	var vehicle := _blocked_by
	var siren_seen := false
	for step_index in QUEUE_CHECK:
		if vehicle == null or vehicle.crashed:
			return false
		if vehicle == self:
			return siren_seen
		if seen.has(vehicle):
			return false
		seen[vehicle] = true
		siren_seen = siren_seen or vehicle.has_priority()
		vehicle = vehicle._blocked_by
	return false


## True if following who waits for whom comes back round to someone it has seen already.
func _waits_in_a_ring() -> bool:
	var seen := {}
	var vehicle := self as Vehicle
	for step_index in QUEUE_CHECK:
		# one that waits only for a light or a zebra: a queue, no ring (one that waits for
		# a vehicle as well is in the ring all the same: the light turning green won't free it)
		if vehicle == null or (vehicle._held_by_rule and vehicle._blocked_by == null) or vehicle.crashed:
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
		if other == self or other.crashed or crashed or _bump_clock > 0.0 or other._bump_clock > 0.0:
			continue
		if global_position.distance_to(other.global_position) > _reach() + other._reach() + 1.0:
			continue
		# one on a viaduct or in a tunnel, the other above or under it: their bodies never touch
		if absf(other.global_position.y - global_position.y) > CRASH_LEVEL_DIFFERENCE:
			continue
		if _passes(other) or other._passes(self):
			continue   # a siren going by one that pulled over for it
		var careless := reckless or other.reckless or daredevil or other.daredevil
		if (careless or (velocity - other.velocity).length() >= CRASH_SPEED) and _overlaps(other):
			_crash_with(other)


## The blow: the change of speed along the line between them is shared as momentum does,
## so the lighter one takes most of it, and costs each its health by what it takes. One
## whose health runs out becomes a burning wreck with the speed and spin the masses give it
## (the blow lands off-centre, which spins the lighter one most too); the other is bumped.
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
	# the light one takes most of the jolt, and of the damage
	var my_jolt := closing * their_mass / (my_mass + their_mass)
	var their_jolt := closing * my_mass / (my_mass + their_mass)
	if _take_hit(my_jolt):
		_become_wreck(my_speed, my_spin, -line, my_jolt)
		_catch_fire()
	if other._take_hit(their_jolt):
		other._become_wreck(their_speed, their_spin, line, their_jolt)
		other._catch_fire()
	var strength := clampf(closing / CRASH_FULL_SPEED, 0.15, 1.0)
	if _explodes() or other._explodes():
		strength = 1.0   # the biggest bang and shake
	var paint := _paint() if my_mass < their_mass else other._paint()
	CrashBurst.spawn(get_parent(), contact + Vector3.UP * 0.8, paint, strength)
	last_crash = {"at": contact, "strength": strength, "time": Time.get_ticks_msec() / 1000.0}


## Takes a hit that changes its speed by `jolt` m/s: loses health by it; true if its health
## ran out (it crashes), else it is only bumped: it brakes hard and drives on.
func _take_hit(jolt: float) -> bool:
	health -= jolt * DAMAGE_PER_SPEED
	reckless = false
	daredevil = false
	if health <= 0.0:
		return true
	speed *= BUMP_SLOWDOWN
	_bump_clock = BUMP_COOLDOWN
	return false


## Its wreck catches fire (no fire without a wreck: a rail vehicle only stops); in the worst
## case (EXPLODE_HEALTH) it blows up first.
func _catch_fire() -> void:
	if _wreck == null or _fire != null:
		return
	if health <= EXPLODE_HEALTH:
		VehicleFire.explode(_wreck, _body_size.y * 0.5, get_parent())
	_fire = VehicleFire.ignite(_wreck, _body_size.y * 0.8)


## True if it blew up in the hit just now.
func _explodes() -> bool:
	return crashed and _fire != null and health <= EXPLODE_HEALTH


## The paint of its body, from the colour word in its model name (grey if none).
func _paint() -> Color:
	for word: String in PAINT_WORDS:
		if model.contains(word):
			return PAINT_WORDS[word]
	return Color(0.55, 0.57, 0.6)


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


## What it takes up seen from above (rectangles of four corners x, z), for others than
## vehicles: the player (scripts/player/player_controller.gd) tests being hit with it.
func footprints(margin := 0.0) -> Array:
	return _footprints(margin)


## The four corners (x, z) of a rectangle round `middle`, turned like `frame` (see _rectangle).
static func rectangle(frame: Transform3D, middle: Vector3, width: float, length: float, margin: float) -> Array[Vector2]:
	return _rectangle(frame, middle, width, length, margin)


## True if two rectangles of four corners (footprints, rectangle) overlap.
static func rectangles_overlap(first: Array, second: Array) -> bool:
	var first_corners: Array[Vector2] = []
	first_corners.assign(first)
	var second_corners: Array[Vector2] = []
	second_corners.assign(second)
	return _rectangles_overlap(first_corners, second_corners)


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
func _become_wreck(impact: Vector3, spin := 0.0, pushed := Vector3.ZERO, jolt := 0.0) -> void:
	crashed = true
	reckless = false
	daredevil = false
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
	# a hop, and tipping over towards where it is pushed (its top goes that way)
	_wreck.linear_velocity = impact + Vector3.UP * minf(jolt * CRASH_HOP, CRASH_HOP_MOST)
	_wreck.angular_velocity = Vector3.UP * spin + Vector3.UP.cross(pushed) * minf(jolt * CRASH_TILT, CRASH_TILT_MOST)
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


## While crashed: the body sits on the wreck; once it has burnt out (or after WRECK_TIME
## without a fire) it is towed back, blinking ever faster in its last seconds
## (death_blink.gd).
func _follow_wreck(delta: float) -> void:
	_body.global_transform = _wreck.global_transform
	_roll_on(delta)
	if _trailer:
		_move_trailer()
		_trailer.global_transform = _trailer_current
		_trailer_collider.global_transform = _trailer_current
	_update_lamps()
	_wreck_clock += delta
	var lasts := VehicleFire.BURN_SECONDS if _fire else WRECK_TIME
	# about to be towed: it blinks, ever faster, as in old games
	var shown := DeathBlink.shown(lasts - _wreck_clock)
	_body.visible = shown
	if _trailer:
		_trailer.visible = shown
	if _wreck_clock >= lasts:
		_body.visible = true
		if _trailer:
			_trailer.visible = true
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
	if _fire:
		_fire.call("leave_smoke", get_parent())   # the last smoke drifts off where it burnt
		_fire = null
	_wreck.queue_free()
	_wreck = null
	health = max_health
	if _trailer_collider:
		_trailer_collider.queue_free()
		_trailer_collider = null
	crashed = false
	_restart_at(Vector2i(floori(spot.x / RoadNetwork.CELL), floori(spot.z / RoadNetwork.CELL)), heading)
	set_physics_process(true)


## Starts again, standing, on the first free lane from the road cell nearest `near`.
func _restart_at(near: Vector2i, heading: Vector2i) -> void:
	_route_cells.clear()
	_route_headings.clear()
	_route_distances.clear()
	_route_ended = false
	_turned_round_at = 0
	_waited_at.clear()
	_lane_reversals = 0
	_lost_clock = -1.0
	var first := _free_lane(network.nearest(near, heading, vehicle_kind), heading)
	_append(first - Vector3i(heading.x, 0, heading.y), heading)
	_append(first, heading)
	_distance = _route_distances[1]
	speed = 0.0
	acceleration_now = 0.0
	_plan()
	_place()
	_snap_body()


## Lost (driving to and fro): puts it down on a straight piece of road it may use, out of
## sight if it can find one, else anywhere.
func _relocate() -> void:
	var cells: Array = network.cells()
	var chosen := RoadNetwork.NONE
	for try_index in RELOCATE_TRIES:
		var cell: Vector3i = cells[_random.randi() % cells.size()]
		if network.is_crossing(cell) or network.lanes(cell).size() != 1 or not _may_use(cell, network.lanes(cell)[0]):
			continue
		var heading: Vector2i = network.lanes(cell)[0]
		if network.step(cell, heading) == RoadNetwork.NONE or network.step(cell, -heading) == RoadNetwork.NONE:
			continue
		chosen = cell
		if _out_of_sight(network.centre(cell)):
			break
	if chosen == RoadNetwork.NONE:
		_lost_clock = 0.0   # try again later
		return
	_restart_at(Vector2i(chosen.x, chosen.z), network.lanes(chosen)[0])


## True if `spot` lies well off the screen of the current camera (or very far from it).
func _out_of_sight(spot: Vector3) -> bool:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport else null
	if camera == null:
		return false
	if camera.is_position_behind(spot):
		return true
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE and camera.global_position.distance_to(spot) > UNSEEN_DISTANCE:
		return true
	var screen := viewport.get_visible_rect()
	var on_screen := camera.unproject_position(spot)
	return not screen.grow_individual(screen.size.x * UNSEEN_MARGIN, screen.size.y * UNSEEN_MARGIN,
			screen.size.x * UNSEEN_MARGIN, screen.size.y * UNSEEN_MARGIN).has_point(on_screen)


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
