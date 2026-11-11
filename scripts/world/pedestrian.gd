class_name Pedestrian
extends Node3D
## One pedestrian of the town (made by Pedestrians, scripts/world/pedestrians.gd): a
## townsperson (TownsfolkFigure, its look from `walker_seed`) walking from spot to spot over
## the pavements and squares, a cell (4 m) at a time: it goes straight on more often than it
## turns, turns back only at a dead end, and now and then stops a moment (looking round, at
## its phone). Each spot is a little off the middle of its cell, and one it cannot reach in
## a straight line without walking into something (a lamppost, a bench, a tree: the town's
## colliders) it does not choose.
## Before a zebra it stops at the kerb and claims the zebra (Pedestrians.claim_zebra:
## the traffic stops for it), waits while a vehicle comes too near too fast to stop
## (`safe_gap`), then crosses straight over, at a brisker pace.
## Others: it stops for someone (a pedestrian, the player) right ahead of it, steps aside to
## its right after SIDE_STEP_AFTER (both doing so, two who meet pass each other), and after
## BLOCKED_TIME goes another way; a rider turns round on the spot for that. Held up more
## than GHOST_AFTER seconds all told (a knot of people that cannot get out of each other's
## way), it walks on through the others for GHOST_SECONDS (not through the player).
## It stands on the ground (a ray down onto the town's colliders, a step up or down glides),
## and has a collider the size of the figure (Botsvorm, an AnimatableBody3D on the town's
## layer, as the player has), so the player cannot walk through it and wrecks bump into it.
## Some ride instead of walking (`mobility`, MobilityAid): a wheelchair ("rolstoel") or a
## mobility scooter ("scootmobiel", which may also take the bicycle paths: Pedestrians.may_use).
## A wheelchair now and then does a wheelie (Wheelie: back on its big wheels, going straight)
## and its rider shouts something cocky (DriverShout, mood "wheelie").
## They go the way they face, turning at most TURN_RATE radians a second (slower when they
## have far to turn), so the wheels roll the way they go; the casters of a wheelchair swivel
## after it, the scooter's front wheel steers into the turn. A scooter someone stands in front
## of hoots (HORN_SOUND), at most every HORN_PAUSE seconds.
## Hit by a vehicle (hit_by_vehicle, from Vehicle._watch_people: an impatient one pushing
## through, or one it stepped right in front of): it loses DAMAGE_PER_SPEED * v +
## DAMAGE_PER_SPEED_SQUARED * v^2 of its `health` (MAX_HEALTH), shards fly (CrashBurst), a
## thud and a cry of pain (pijn_<voice>_*, as the player's: a woman's voice with long hair,
## an old man's when bald or riding, else a man's) and it is thrown aside (a RigidBody3D,
## Valpartij, as the player is; what it rides tumbles with it). Lying still it gets up where
## it lies (or on the nearest spot of its last cell) and walks on. With its health gone it
## stays down DEAD_LIE seconds, then starts afresh away from the player (Pedestrians.start_again:
## someone else, healthy).
## Who it is (look, pace, what it carries, `crowd_kind`) Pedestrians chooses from the hour and
## the neighbourhood (Crowd, data/drukte.json); `become` makes it someone else on the spot. While down the traffic does not stop for it.

## Collision layer of the town and of the wrecks.
const Sight = preload("res://scripts/world/sight.gd")
const GroundShadow = preload("res://scripts/effects/ground_shadow.gd")
const Crowd = preload("res://scripts/world/crowd.gd")
const TOWN_LAYER := 1
## Metres per second walking (the slowest and the fastest), and how much faster over a zebra.
const SLOWEST := 1.05
const FASTEST := 1.55
const CROSSING_HURRY := 1.3
## Metres off the middle of a cell a spot may be.
const SPOT_SPREAD := 1.3
## Chance to go straight on where it could also turn, and to stop a moment at a spot (and
## how long).
const STRAIGHT_CHANCE := 0.55
const PAUSE_CHANCE := 0.12
const PAUSE_LONGEST := 3.5
## Someone this near ahead of it (metres) makes it stop; this long blocked, it goes another way.
const KEEP_CLEAR := 0.85
## Closer than this (metres) beside its way it stops for the player too (no brushing past).
const PLAYER_BRUSH := 0.9
const BLOCKED_TIME := 1.2
## Untangling (see the top): when it starts to step aside, how fast (m/s), and when it walks
## through the others and for how long.
const SIDE_STEP_AFTER := 0.4
const SIDE_STEP_SPEED := 0.7
const GHOST_AFTER := 4.0
const GHOST_SECONDS := 1.5
## Radius of the figure for the way to a spot, and from how high above the feet it looks
## (over the kerbs and steps).
const BODY_RADIUS := 0.22
const STEP_HEIGHT := 0.45
## Physics steps between two looks at the ground (and how fast the figure follows a step).
const GROUND_EVERY := 3
const STEP_GLIDE := 0.08
## How near (metres) the player must be for it to be drawn walking (further off it still
## walks, but the limbs are left alone).
const ANIMATE_WITHIN := 70.0
## Riding (see `mobility`): metres a second (slowest, fastest), the most it turns a second,
## its radius for the way, and how near it may come to someone ahead.
const RIDE_PACE := {"rolstoel": Vector2(0.8, 1.1), "scootmobiel": Vector2(1.5, 1.9)}
const TURN_RATE := {"rolstoel": 2.6, "scootmobiel": 1.8}
const RIDE_RADIUS := {"rolstoel": 0.34, "scootmobiel": 0.38}
const RIDE_KEEP_CLEAR := {"rolstoel": 1.0, "scootmobiel": 1.4}
const ARRIVE_WITHIN := 0.12
const RIDE_ARRIVE_WITHIN := 0.35
## How much the scooter's front wheel steers for each radian a second it turns.
const STEER_PER_TURN := 0.45
const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")
const TALKABLE_GROUP := "aanspreekbaar"
## The kinds of people in the crowd that are on duty (role): police and handhaving.
const ON_DUTY_KINDS := ["agent", "handhaver"]
const Wheelie = preload("res://scripts/vehicles/wheelie.gd")
const KnockDown = preload("res://scripts/world/knock_down.gd")
## In a wheelie a wheelchair is a daredevil (is_daredevil): this many times as fast, waiting
## for no one and nothing; what it runs into, both go down (_stunt_crash).
const CHAIR_DAREDEVIL_PACE := 2.2
## The group of the player (PlayerController.PLAYER_GROUP).
const PLAYER_GROUP := "speler"
## How far a wheelchair's front comes up in a wheelie, and the most it may turn meanwhile (rad/s).
const CHAIR_WHEELIE_DEGREES := 55.0
const CHAIR_WHEELIE_MOST_TURN := 0.6
const HORN_SOUND := "scootmobiel_toeter"
const HORN_PAUSE := 5.0
const HORN_AFTER := 0.5
const MAX_HEALTH := 40.0
const DAMAGE_PER_SPEED := 2.2
const DAMAGE_PER_SPEED_SQUARED := 0.12
## Slower than this (m/s) a vehicle only nudges it aside.
const HIT_THRESHOLD := 0.8
const KNOCK_DOWN_TIME := 2.0
const DEAD_LIE := 8.0
const BODY_MASS := 70.0
const HIT_SHARD_COLOUR := Color("#6B5844")
const BODY_HIT_SOUND := "lichaam_klap"
## From this hit strength (0..1, the impact / 20 m/s) the long cry instead of a short one.
const HARD_CRY_STRENGTH := 0.55
const SHORT_CRY_COUNT := 3

@export var walker_seed := 1
@export var start_cell := Vector3i.ZERO
## A vehicle nearer the zebra than this (metres) plus its speed times `safe_time`, still
## moving, makes it wait at the kerb.
@export var safe_gap := 4.0
@export var safe_time := 2.2
## "" walking, "rolstoel" in a wheelchair, "scootmobiel" on a mobility scooter (MobilityAid).
@export var mobility := ""
## Its look (TownsfolkFigure); empty: the one of TownsfolkFigure.look_for(walker_seed).
var wanted_look := {}
## Its pace against the usual (Crowd.pace_of its kind).
var pace_factor := 1.0
## What it carries (a kind of CarriedItems; "" nothing), and the kind of person it is
## (data/drukte.json "mensen"; "" none in particular).
var carried := ""
var crowd_kind := ""
## Someone on duty on the street ("agent", "handhaver": their crowd_kind), talked to as staff
## (Conversations.is_official, data/gesprekken/personeel.json); "" for everyone else.
var role := ""
## On its way into Den Haag Centraal (Pedestrians._send_to_station): each step a cell nearer a
## door, at the door it is gone (Pedestrians.into_station).
var heading_to_station := false
var _entering_station := false
var _station_misses := 0            # choices in a row that got it no nearer the station
## After this many choices in a row without a way nearer the station it gives up going there.
const STATION_GIVE_UP := 6
var _carried_item: Node3D
var _carried_pose := false

var town: Pedestrians
var figure: TownsfolkFigure
var cell := Vector3i.ZERO
var _came_from := Vector3i.ZERO
var _target := Vector3.ZERO
var _next_cell := Vector3i.ZERO
var _speed := 1.3
var _pace := 1.3
var _phase := 0.0
var _walking := 0.0
var _pause := 0.0
var _blocked := 0.0
var _held_up := 0.0                 # seconds held up lately, all told (goes down while it walks)
var _ghost_left := 0.0              # seconds it still walks through the others
var _ground_countdown := 0
var _ground_y := 0.0
var _crossing: Array[Vector3i] = []   # the zebra cells it is waiting at or crossing
var _crossing_side := Vector3i.ZERO
var _on_zebra := false
var _body: AnimatableBody3D
var _random := RandomNumberGenerator.new()
var _all: Array[Pedestrian] = []
var _free_shape: SphereShape3D
var _sight_countdown := 0
var _steps_between := 1             # physics steps per step it takes (Sight: fewer out of sight)
var _saved_delta := 0.0
var aid: MobilityAid                # what it rides, if anything
var _wheelie: Wheelie               # a wheelchair's wheelie
var _drawn: Node3D                  # what glides after a step: the figure, or the aid
var _turning := 0.0                 # radians a second it turned the last step
var _horn_clock := 0.0
var _honked_while_blocked := false   # a scooter hoots once each time it is held up
## Its health (see hit_by_vehicle); at 0 it lies dead a while.
var health := MAX_HEALTH
var _ragdoll: RigidBody3D           # its thrown body while knocked down
var _waiting_become: Array = []     # become's arguments while its figure is built on a thread
var _route_points: Array[Vector3] = []   # up or down stairs (Pedestrians.stair_route): the points still to walk to
var _waiting_look := {}             # the look being built for it then
var _ragdoll_clock := 0.0
var _last_cry := 0


func _ready() -> void:
	add_to_group(Vehicle.WALKERS_GROUP)   # vehicles brake, swerve and hoot for it
	add_to_group(TALKABLE_GROUP)          # the player can talk to it (PlayerController)
	_dress()
	add_child(GroundShadow.new())   # a soft patch under it, so it stands apart from the street
	_sight_countdown = get_instance_id() % Sight.LOOK_STEPS
	# no free spot on its start cell: another one near the player
	var placed := restart_at(start_cell)
	for attempt in 12:
		if placed:
			break
		start_cell = town.start_cell()
		placed = restart_at(start_cell)
	if not placed:
		# still none: the middle of the cell, and on from there as soon as it can
		global_position = town.cell_middle(start_cell)
		cell = start_cell
		_target = global_position


## Builds what is seen of it from `walker_seed`, `mobility`, `wanted_look` (empty: the look of
## TownsfolkFigure.look_for), `pace_factor` and `carried` (CarriedItems), and its collider.
func _dress() -> void:
	_random.seed = walker_seed
	if mobility != "":
		aid = MobilityAid.create(mobility, walker_seed, town.props_library(), wanted_look)
		add_child(aid)
		figure = aid.rider
		_drawn = aid
		var pace: Vector2 = RIDE_PACE[mobility]
		_pace = _random.randf_range(pace.x, pace.y) * clampf(pace_factor, 0.8, 1.2)
		if mobility == "rolstoel":
			_wheelie = Wheelie.new(deg_to_rad(CHAIR_WHEELIE_DEGREES), walker_seed)
	else:
		figure = TownsfolkFigure.create(wanted_look if not wanted_look.is_empty() else TownsfolkFigure.look_for(walker_seed))
		figure.name = "Figuur"
		add_child(figure)
		_drawn = figure
		_pace = _random.randf_range(SLOWEST, FASTEST) * pace_factor
		_carry()
	_add_collider()


## What it carries (`carried`, a kind of CarriedItems, scripts/world/carried_items.gd), if
## that script is there and it walks.
func _carry() -> void:
	_carried_item = null
	if carried == "" or figure == null:
		return
	var items := Crowd.carried_items()
	if items == null or not Crowd.has_function(items, "attach"):
		carried = ""
		return
	_carried_item = items.call("attach", figure, carried, walker_seed) as Node3D
	_carried_pose = Crowd.has_function(items, "pose")


## The look its figure (or the rider of its mobility aid) is built from: `wanted_look`, or
## else the one of its seed (as MobilityAid.create picks it for a rider).
func figure_look() -> Dictionary:
	return _look_for(walker_seed, wanted_look, mobility)


static func _look_for(look_seed: int, look_wanted: Dictionary, aid_kind: String) -> Dictionary:
	if not look_wanted.is_empty():
		return look_wanted
	return TownsfolkFigure.look_for(look_seed * 13 + 7 if aid_kind != "" else look_seed)


## True if its figure can be made without building it first (built on a thread,
## prepare_figure).
func figure_is_prepared() -> bool:
	return TownsfolkFigure.is_prepared(figure_look())


## Starts building its figure on a thread (TownsfolkFigure.prepare).
func prepare_figure() -> void:
	TownsfolkFigure.prepare(figure_look())


## Becomes someone else (Pedestrians: someone who goes and someone who comes, without a new
## node): another look, pace, way of going about and what it carries; where it stands it
## leaves to Pedestrians (restart_at, bring_back). A figure not built yet is built on a
## thread first: till then it stays who it was (out of sight, as Pedestrians renews only
## those), then it changes (_physics_process), so that costs no stutter.
func become(new_seed: int, new_look: Dictionary, new_mobility: String, new_pace_factor := 1.0, new_carried := "",
		new_kind := "") -> void:
	var look_wanted := _look_for(new_seed, new_look, new_mobility)
	if _ragdoll == null and _drawn != null and not TownsfolkFigure.is_prepared(look_wanted):
		TownsfolkFigure.prepare(look_wanted)
		_waiting_become = [new_seed, new_look, new_mobility, new_pace_factor, new_carried, new_kind]
		_waiting_look = look_wanted
		return
	_waiting_become = []
	if _ragdoll:
		_end_ragdoll()
	if _drawn:
		_drawn.free()
	if _body:
		_body.free()
	_drawn = null
	_body = null
	figure = null
	aid = null
	_wheelie = null
	_carried_item = null
	_carried_pose = false
	walker_seed = new_seed
	wanted_look = new_look
	mobility = new_mobility
	pace_factor = new_pace_factor
	carried = new_carried
	crowd_kind = new_kind
	role = new_kind if new_kind in ON_DUTY_KINDS else ""
	health = MAX_HEALTH
	_held_up = 0.0
	_ghost_left = 0.0
	_blocked = 0.0
	_walking = 0.0
	_dress()


## Starts afresh on this cell (at the start, or brought back near the player), on a spot
## where it stands free; false if the cell has none (it then stays where it was).
func restart_at(new_cell: Vector3i) -> bool:
	if _ragdoll:
		_end_ragdoll()
	if health <= 0.0:
		health = MAX_HEALTH
	var spot := Vector3.INF
	var spread := SPOT_SPREAD
	for attempt in 6:
		var candidate := _spot_in(new_cell, spread)
		# the cell's middle is at the bottom of its ground layer: look from a metre above it
		# (the ray goes from STEP_HEIGHT above that down to 1.5 m below)
		var height := _ground_height(candidate, candidate.y + 1.0)
		if not is_nan(height) and _stands_free(Vector3(candidate.x, height, candidate.z)):
			spot = Vector3(candidate.x, height, candidate.z)
			break
		spread *= 0.7
	if spot == Vector3.INF:
		return false
	_route_points.clear()
	Pedestrians.claim_zebra(self, [], false)
	_crossing.clear()
	_on_zebra = false
	heading_to_station = false
	_entering_station = false
	_station_misses = 0
	cell = new_cell
	_came_from = new_cell
	_next_cell = new_cell
	_ground_y = spot.y
	global_position = spot
	_drawn.position = Vector3.ZERO
	rotation.y = _random.randf() * TAU
	_target = global_position
	_pause = _random.randf() * 1.5
	return true


func _exit_tree() -> void:
	Pedestrians.claim_zebra(self, [], false)
	if _ragdoll:
		_ragdoll.queue_free()
		_ragdoll = null


func _physics_process(delta: float) -> void:
	if town == null:
		return
	if _ragdoll:
		_follow_ragdoll(delta)
		return
	if not _waiting_become.is_empty() and TownsfolkFigure.is_prepared(_waiting_look):
		callv("become", _waiting_become)
	# out of sight it walks in fewer, longer steps (Sight), its limbs left alone
	_sight_countdown -= 1
	if _sight_countdown < 0:
		_sight_countdown = Sight.LOOK_STEPS
		_steps_between = Sight.steps_between(get_viewport(), global_position)
	if _steps_between > 1:
		_saved_delta += delta
		if _saved_delta < delta * (_steps_between - 0.5):
			return
		delta = _saved_delta
	_saved_delta = 0.0
	if _pause > 0.0:
		_pause -= delta
		_walk_figure(delta, 0.0)
		return
	_horn_clock = maxf(_horn_clock - delta, 0.0)
	var flat_to := Vector2(_target.x - global_position.x, _target.z - global_position.z)
	if flat_to.length() < (RIDE_ARRIVE_WITHIN if aid else ARRIVE_WITHIN):
		_arrive()
		_walk_figure(delta, 0.0)
		return
	if not is_daredevil() and not _may_go():
		_walk_figure(delta, 0.0)
		return
	var towards := flat_to.normalized()
	# a rider looks the way it faces, but while it still has to turn the way it is going
	var looking := towards
	if aid:
		var facing := Vector2(sin(rotation.y), cos(rotation.y))
		if facing.dot(towards) > 0.5:
			looking = facing
	_ghost_left = maxf(_ghost_left - delta, 0.0)
	# a daredevil in a wheelie stops for no one: what is in its way, it crashes into
	if is_daredevil():
		var in_the_way := _who_is_ahead(looking)
		if in_the_way:
			_stunt_crash(in_the_way, looking)
			return
	# walking through the others (untangling) it still stops for the player
	if not is_daredevil() and ((_ghost_left <= 0.0 and _someone_ahead(looking)) or (_ghost_left > 0.0 and _player_ahead(looking))):
		_blocked += delta
		_held_up += delta
		if mobility == "scootmobiel" and _blocked > HORN_AFTER and _horn_clock <= 0.0 and not _honked_while_blocked:
			_sound_horn()
		if aid:
			_turn_on_the_spot(atan2(towards.x, towards.y), delta)
		if _blocked > SIDE_STEP_AFTER:
			_step_aside(looking, delta)
		if _held_up > GHOST_AFTER:
			_held_up = 0.0
			_ghost_left = GHOST_SECONDS
		if _blocked > BLOCKED_TIME * (2.0 if aid else 1.0):
			_blocked = 0.0
			_go_elsewhere()
		_follow_ground()
		_update_cell()
		_walk_figure(delta, 0.3 if _blocked > SIDE_STEP_AFTER else 0.0)
		return
	_blocked = 0.0
	_held_up = maxf(_held_up - delta * 0.5, 0.0)
	_honked_while_blocked = false
	_speed = _pace * (CROSSING_HURRY if _on_zebra else 1.0) * (daredevil_pace() if is_daredevil() else 1.0)
	var direction := flat_to.normalized()
	var heading := atan2(direction.x, direction.y)
	if aid:
		_ride_towards(heading, flat_to.length(), delta)
	else:
		var step := minf(_speed * delta, flat_to.length())
		global_position += Vector3(direction.x, 0.0, direction.y) * step
		# turn towards where it goes
		rotation.y = lerp_angle(rotation.y, heading, 1.0 - exp(-delta * 10.0))
	_follow_ground()
	_update_cell()
	_walk_figure(delta, 1.0)


## Rides the way it faces, turning towards `heading` (at most its TURN_RATE, slower the
## further it has to turn, so it never runs wide past its spot), `left` metres from the spot;
## the wheels roll that far, the casters swivel after it, the scooter steers into the turn.
func _ride_towards(heading: float, left: float, delta: float) -> void:
	var off := wrapf(heading - rotation.y, -PI, PI)
	var most: float = TURN_RATE[mobility] * delta
	var turn := clampf(off, -most, most)
	rotation.y += turn
	_turning = turn / maxf(delta, 0.0001)
	var speed := _speed * clampf(cos(off), 0.15, 1.0)
	var step := minf(speed * delta, left)
	global_position += Vector3(sin(rotation.y), 0.0, cos(rotation.y)) * step
	_speed = step / maxf(delta, 0.0001)
	if _steps_between > 1:
		return
	aid.roll(step)
	aid.swivel(Vector3(0.0, 0.0, _speed), _turning, delta)
	aid.steer(_turning * STEER_PER_TURN)


## Sounds the scooter's horn where it is; its rider may grumble something (DriverShout).
func _sound_horn() -> void:
	_horn_clock = HORN_PAUSE
	_honked_while_blocked = true
	var sound := get_node_or_null("/root/RuimtelijkGeluid")
	if sound and sound.has_method("play_signal"):
		sound.play_signal(global_position, HORN_SOUND, 6.0)
	DriverShout.shout(self, mobility, "wachten", 1.9)


## The limbs and the height of the figure (smoothly over steps).
func _walk_figure(delta: float, walking: float) -> void:
	_walking = lerpf(_walking, walking, 1.0 - exp(-delta * 8.0))
	_drawn.position.y = lerpf(_drawn.position.y, 0.0, 1.0 - exp(-delta / STEP_GLIDE))
	if _steps_between > 1 or not _near_player(ANIMATE_WITHIN):
		return
	if aid:
		if walking == 0.0:
			aid.steer(0.0)
		aid.pose()
		if _wheelie:
			_do_wheelie(delta, walking > 0.0)
		return
	_phase = fmod(_phase + _speed * delta / TownsfolkFigure.STRIDE * PI * _walking, TAU)
	figure.walk(_phase, _walking)
	if _carried_pose and _carried_item:
		Crowd.carried_items().call("pose", figure, carried)


## Standing still and straight at once (both feet on the ground, the arms down), as when the
## player starts talking to it (PlayerController.talk_to): a conversation pauses the game,
## so mid-stride a leg would stay in the air. A rider (aid) keeps its pose.
func stand_neutral() -> void:
	_walking = 0.0
	_phase = 0.0
	if aid or figure == null:
		return
	figure.walk(0.0, 0.0)
	if _carried_pose and _carried_item:
		Crowd.carried_items().call("pose", figure, carried)


## A wheelchair in a wheelie: a daredevil (see CHAIR_DAREDEVIL_PACE).
func is_daredevil() -> bool:
	return _wheelie != null and _wheelie.is_up() and _ragdoll == null


func daredevil_pace() -> float:
	return CHAIR_DAREDEVIL_PACE


## Who is right ahead of it in `direction` (another one on foot or riding, or the player), or null.
func _who_is_ahead(direction: Vector2) -> Node3D:
	if _all.is_empty():
		_all = town.people()
	for other in _all:
		if other == self or other._ragdoll:
			continue
		var offset := Vector2(other.global_position.x - global_position.x, other.global_position.z - global_position.z)
		if offset.length() < _keep_clear() and offset.dot(direction) > 0.2 and absf(other.global_position.y - global_position.y) < 1.5:
			return other
	if _player_ahead(direction):
		return get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
	return null


## A daredevil's crash: it runs into `other` at full speed; another one on foot goes down
## with it (hit as by something that fast), and the chair tips over forwards, its rider
## thrown out.
func _stunt_crash(other: Node3D, direction: Vector2) -> void:
	var forward := Vector3(direction.x, 0.0, direction.y)
	var impact := _speed
	if other is Pedestrian:
		(other as Pedestrian)._hit_by_stunt(forward * impact, impact)
	DriverShout.shout(self, "rolstoel", "gevallen", 1.9)
	var contact := global_position + forward * 0.5 + Vector3.UP * 0.8
	CrashBurst.spawn(get_parent(), contact, HIT_SHARD_COLOUR, clampf(impact / 6.0, 0.3, 1.0))
	_cry_out(true, contact)
	health = maxf(health - DAMAGE_PER_SPEED * impact * 4.0, 0.0)
	_knock_down(forward * impact * 1.5 + Vector3.UP * impact * 0.6, impact * 3.0)


## Run into by a daredevil (a wheelchair in a wheelie): down, as by a slow vehicle.
func _hit_by_stunt(push: Vector3, impact: float) -> void:
	if _ragdoll or health <= 0.0:
		return
	var contact := global_position + Vector3.UP * 1.0
	health = maxf(health - DAMAGE_PER_SPEED * impact * 3.0, 0.0)
	_cry_out(true, contact)
	_knock_down(push + Vector3.UP * impact * 0.4, impact * 3.0)


## Now and then back on the big wheels (Wheelie), only riding on going (nearly) straight;
## its rider shouts something cocky as the front comes up.
func _do_wheelie(delta: float, riding: bool) -> void:
	var allowed := riding and _ragdoll == null and _speed > 0.5 and absf(_turning) < CHAIR_WHEELIE_MOST_TURN
	if _wheelie.step(delta, allowed):
		DriverShout.shout(self, "rolstoel", "wheelie", 1.9)
	aid.tilt(_wheelie.tilt_about(MobilityAid.chair_rear_contact()))


func _near_player(metres: float) -> bool:
	var player := town._player
	return player == null or player.global_position.distance_to(global_position) < metres


## Reached its spot: on to the next cell (or a pause first).
func _arrive() -> void:
	if not _route_points.is_empty():
		# on the stairs: on to the next point; at the end, in the cell it went for
		_target = _route_points.pop_front()
		if _route_points.is_empty():
			_came_from = cell
			cell = _next_cell
		return
	if _entering_station:
		_entering_station = false
		town.into_station(self)
		return
	if heading_to_station:
		_choose_next()
		return
	if not town.is_zebra(cell) and _random.randf() < PAUSE_CHANCE:
		_pause = _random.randf_range(0.6, PAUSE_LONGEST)
	_choose_next()


## Where next: on a zebra straight over; else straight on now and then, or another way
## (not back, unless there is no other); the first of those with a clear way there. With
## none it stays a moment and tries again.
func _choose_next() -> void:
	var ways: Array = town.links(cell).filter(func(way: Vector3i) -> bool: return town.may_use(way, mobility))
	var order: Array[Vector3i] = []
	if town.is_zebra(cell) and _crossing_side != Vector3i.ZERO and (cell + _crossing_side) in ways:
		order.append(cell + _crossing_side)
	if heading_to_station and order.is_empty():
		var steps_here := town.station_steps(cell)
		if steps_here == 0:
			# at the door: in through it
			_target = town.station_door_near(global_position)
			_next_cell = cell
			_entering_station = true
			return
		# a cell nearer the door (the way there); one it cannot get to is blocked for all, and
		# who keeps getting nowhere gives up (STATION_GIVE_UP)
		for way: Vector3i in ways:
			var steps := town.station_steps(way)
			if steps >= 0 and steps < steps_here:
				if _head_for(way):
					_station_misses = 0
					return
				town.station_way_blocked(cell, way)
		_station_misses += 1
		if _station_misses > STATION_GIVE_UP:
			heading_to_station = false
	var straight := cell + (cell - _came_from)
	if straight != cell and straight in ways and _random.randf() < STRAIGHT_CHANCE:
		order.append(straight)
	var others: Array[Vector3i] = []
	for way: Vector3i in ways:
		if way != _came_from and not way in order:
			others.append(way)
	_shuffle(others)
	order.append_array(others)
	if _came_from != cell and _came_from in ways and not _came_from in order:
		order.append(_came_from)
	order.append(cell)   # another spot in its own cell
	for next in order:
		if _head_for(next):
			return
	_target = global_position
	_pause = 0.8


func _shuffle(cells: Array[Vector3i]) -> void:
	for index in range(cells.size() - 1, 0, -1):
		var other := _random.randi_range(0, index)
		var kept := cells[index]
		cells[index] = cells[other]
		cells[other] = kept


## Sets the next spot in the cell `next`, one with a clear straight way there (nearer the
## middle if the first is not); false if there is none.
func _head_for(next: Vector3i) -> bool:
	var stairs: PackedVector3Array = town.stair_route(cell, next) if town.has_method("stair_route") else PackedVector3Array()
	if not stairs.is_empty():
		# up or down the stairs: point after point (the railings stand beside the way)
		_route_points.assign(Array(stairs))
		_route_points.append(_spot_in(next, SPOT_SPREAD * 0.4))
		_next_cell = next
		_target = _route_points.pop_front()
		return true
	var spread := SPOT_SPREAD * (0.25 if town.is_zebra(next) else 1.0)
	var side := next - cell
	for attempt in 4:
		var spot := _spot_in(next, spread, side if town.is_zebra(next) else _crossing_side)
		if _clear_way(global_position, spot):
			_next_cell = next
			_target = spot
			if town.is_zebra(next) and not _on_zebra:
				# at the kerb: claim the zebra and wait there (see _may_go); at pedestrian
				# lights only wait (the traffic with green drives on)
				_crossing_side = side
				_crossing = town.zebra_run(next, _crossing_side)
				if town.walk_light(next, _crossing_side) < 0:
					Pedestrians.claim_zebra(self, _crossing, false)
			return true
		spread *= 0.5
	return false


## A spot in a cell, up to `spread` metres off its middle (on a zebra crossed in direction
## `across`: on the line straight over it).
func _spot_in(target_cell: Vector3i, spread := SPOT_SPREAD, across := Vector3i.ZERO) -> Vector3:
	var middle := town.cell_middle(target_cell)
	var offset := Vector3(_random.randf_range(-spread, spread), 0.0, _random.randf_range(-spread, spread))
	if town.is_zebra(target_cell) and across != Vector3i.ZERO:
		# keep to the stripes: no sideways wander across the zebra
		offset = Vector3(offset.x * absf(across.x), 0.0, offset.z * absf(across.z))
	return middle + offset


## May it walk on: always, except at the kerb before a zebra while a vehicle comes too
## near too fast.
func _may_go() -> bool:
	if _on_zebra or not town.is_zebra(_next_cell):
		return true
	# at pedestrian lights: only on green
	if town.walk_light(_next_cell, _crossing_side) == 1:
		return false
	var middle := town.cell_middle(_next_cell)
	for vehicle in Vehicle.all_vehicles:
		if vehicle.crashed or vehicle.speed < 0.8:
			continue
		var gap := Vector2(vehicle.global_position.x - middle.x, vehicle.global_position.z - middle.z).length()
		if gap < safe_gap + vehicle.speed * safe_time:
			# only one that comes towards the zebra
			var towards := Vector2(middle.x - vehicle.global_position.x, middle.z - vehicle.global_position.z)
			if towards.dot(Vector2(vehicle.velocity.x, vehicle.velocity.z)) > 0.0 or gap < safe_gap:
				return false
	_on_zebra = true
	Pedestrians.claim_zebra(self, _crossing, true)
	return true


## True if someone (another pedestrian, the player) stands right ahead of it.
func _someone_ahead(direction: Vector2) -> bool:
	if _all.is_empty():
		_all = town.people()
	for other in _all:
		if other == self:
			continue
		var offset := Vector2(other.global_position.x - global_position.x, other.global_position.z - global_position.z)
		if offset.length() < _keep_clear() and offset.dot(direction) > 0.2 and absf(other.global_position.y - global_position.y) < 1.5:
			return true
	if _player_ahead(direction):
		return true
	return false


## True if the player stands right ahead of it.
func _player_ahead(direction: Vector2) -> bool:
	var player := town._player
	if player == null:
		return false
	var offset := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z)
	var distance := offset.length()
	if distance < 0.0001:
		return true
	var ahead := offset.dot(direction) / distance
	# right ahead, or close beside its way (it would brush past the player)
	return (distance < _keep_clear() + 0.2 and ahead > 0.2) or (distance < PLAYER_BRUSH and ahead > -0.3)


func _keep_clear() -> float:
	return RIDE_KEEP_CLEAR[mobility] if aid else KEEP_CLEAR


## Held up: a little to its right (keeping right, as on Dutch pavements), if the town and
## the others leave room there.
func _step_aside(looking: Vector2, delta: float) -> void:
	var right := Vector2(-looking.y, looking.x)
	var step := right * SIDE_STEP_SPEED * delta
	var spot := global_position + Vector3(step.x, 0.0, step.y)
	# not off the pavement (onto the road) and not into the town
	if not town.may_use(town.cell_of(spot), mobility) or not _stands_free(spot):
		return
	for other in _all:
		if other != self and Vector2(other.global_position.x - spot.x, other.global_position.z - spot.z).length() < _keep_clear() * 0.6:
			return
	# nor into the player
	var player := town._player
	if player and Vector2(player.global_position.x - spot.x, player.global_position.z - spot.z).length() < _keep_clear():
		return
	global_position = spot


## A rider held up turns towards `heading` where it stands (at its TURN_RATE).
func _turn_on_the_spot(heading: float, delta: float) -> void:
	var most: float = TURN_RATE[mobility] * delta
	var turn := clampf(wrapf(heading - rotation.y, -PI, PI), -most, most)
	rotation.y += turn
	_turning = turn / maxf(delta, 0.0001)
	if _steps_between <= 1:
		aid.swivel(Vector3.ZERO, _turning, delta)
		aid.steer(_turning * STEER_PER_TURN)


## Blocked too long: turns round to a spot back where it came from (or another one in its cell).
func _go_elsewhere() -> void:
	if _on_zebra or not _route_points.is_empty():
		return   # on a zebra or on the stairs: it waits (and walks through after a while)
	if _entering_station:
		# held up right at the door: in through it all the same
		_entering_station = false
		town.into_station(self)
		return
	Pedestrians.claim_zebra(self, [], false)
	_crossing.clear()
	var back := _came_from if _came_from != cell else cell
	_came_from = _next_cell
	if not _head_for(back) and not _head_for(cell):
		_target = global_position
		_pause = 0.8


## True if a body of BODY_RADIUS gets from `from` to `to` without walking into the town
## (a look every 0.4 m along the way, above the kerbs and at head height).
func _clear_way(from: Vector3, to: Vector3) -> bool:
	var length := Vector2(to.x - from.x, to.z - from.z).length()
	var looks := maxi(2, ceili(length / 0.4))
	for look in looks + 1:
		var spot := from.lerp(to, float(look) / float(looks))
		if not _stands_free(Vector3(spot.x, from.y, spot.z)):
			return false
	return true


## True if nothing of the town (but the ground, the other pedestrians and itself) is in
## the way of a figure with its feet at `feet`.
func _stands_free(feet: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if _free_shape == null:
		_free_shape = SphereShape3D.new()
		_free_shape.radius = RIDE_RADIUS[mobility] if mobility != "" else BODY_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _free_shape
	query.collision_mask = TOWN_LAYER
	if _body:
		query.exclude = [_body.get_rid()]
	for height in [STEP_HEIGHT + _free_shape.radius, 1.0, 1.45]:
		query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * height)
		for hit: Dictionary in space.intersect_shape(query, 4):
			var collider: Node = hit.collider
			if collider != town._ground and not collider.get_parent() is Pedestrian:
				return false
	return true


func _follow_ground() -> void:
	_ground_countdown -= 1
	if _ground_countdown > 0:
		return
	_ground_countdown = GROUND_EVERY
	var height := _ground_height(global_position, global_position.y)
	if is_nan(height):
		return
	var before := global_position.y
	global_position.y = height
	# the node steps at once, the figure glides after
	_drawn.position.y += before - height


## Height of the ground under `point` from STEP_HEIGHT above `from_height` down to 1.5 m
## below it; NAN if there is none.
func _ground_height(point: Vector3, from_height: float) -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, from_height + STEP_HEIGHT, point.z),
			Vector3(point.x, from_height - 1.5, point.z), TOWN_LAYER)
	if _body:
		query.exclude = [_body.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return NAN
	return (hit.position as Vector3).y


func _update_cell() -> void:
	if not _route_points.is_empty():
		return   # on the stairs: it is in the cell it went for once it gets there (_arrive)
	var now := town.cell_of(global_position)
	if now != cell and town.may_use(now, mobility):
		_came_from = cell
		cell = now
		if _on_zebra and not town.is_zebra(now):
			# over the road, on the pavement: the zebra is free again
			_on_zebra = false
			_crossing.clear()
			Pedestrians.claim_zebra(self, [], false)


## The collider: a box as big as the figure (standing, or with what it rides), turning with it.
func _add_collider() -> void:
	var bounds := Vehicle._mesh_bounds(_drawn, _drawn.transform)
	_body = AnimatableBody3D.new()
	_body.name = "Botsvorm"
	_body.sync_to_physics = false
	_body.collision_layer = TOWN_LAYER
	_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(bounds.size.x, 0.3), maxf(bounds.size.y, 1.0), maxf(bounds.size.z, 0.25))
	shape.shape = box
	shape.position = bounds.get_center()
	shape.name = "Doos"
	_body.add_child(shape)
	add_child(_body)


# ------------------------------------------------------------------ being hit

## Hit by `vehicle` (Vehicle._watch_people), thrown along `push` (m/s): see the top.
func hit_by_vehicle(vehicle: Vehicle, push: Vector3) -> void:
	if _ragdoll or health <= 0.0:
		return
	var impact := vehicle.velocity.length()
	if impact < HIT_THRESHOLD:
		# a slow nudge: stepped out of its way
		var aside := Vector3(push.x, 0.0, push.z)
		if aside.length_squared() > 0.0001:
			global_position += aside.normalized() * 0.08
		return
	var damage := DAMAGE_PER_SPEED * impact + DAMAGE_PER_SPEED_SQUARED * impact * impact
	var strength := clampf(impact / 20.0, 0.15, 1.0)
	var contact := global_position + Vector3.UP * 1.0
	CrashBurst.spawn(get_parent(), contact, HIT_SHARD_COLOUR, strength)
	Vehicle.last_crash = {"at": contact, "strength": strength, "time": Time.get_ticks_msec() / 1000.0}
	health = maxf(health - damage, 0.0)
	_cry_out(strength >= HARD_CRY_STRENGTH or health <= 0.0, contact)
	_knock_down(push, impact)


## Its voice for the cries of pain (pijn_<voice>_*), from its look.
func voice() -> String:
	var look: Dictionary = figure.look if figure else {}
	if look.get("hair_style", "") == "lang" or look.get("skirt", false):
		return "vrouw"
	if mobility != "" or look.get("hair_style", "") == "kaal":
		return "oude_man"
	return "man"


## The thud of the hit and a cry of pain at `at`: the long one if `heavy`, else one of the
## short ones, never the same twice in a row.
func _cry_out(heavy: bool, at: Vector3) -> void:
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	if audio == null:
		return
	var cry_name := "pijn_%s_hard" % voice()
	if not heavy:
		var cry_number := _random.randi_range(1, SHORT_CRY_COUNT)
		if cry_number == _last_cry:
			cry_number = cry_number % SHORT_CRY_COUNT + 1
		_last_cry = cry_number
		cry_name = "pijn_%s_%d" % [voice(), cry_number]
	audio.play_event(at, BODY_HIT_SOUND)
	audio.play_event(at, cry_name)


## The figure (with what it rides) becomes a RigidBody3D with the box of its collider,
## thrown along with `push`; meanwhile it is off the zebra and the traffic does not stop for it.
func _knock_down(push: Vector3, impact: float) -> void:
	if _wheelie:
		_wheelie.stop()
		aid.tilt(Transform3D.IDENTITY)
	Pedestrians.claim_zebra(self, [], false)
	_crossing.clear()
	_on_zebra = false
	remove_from_group(Vehicle.WALKERS_GROUP)
	var collider := _body.get_node("Doos") as CollisionShape3D
	_ragdoll = KnockDown.throw(get_parent(), Transform3D(Basis(Vector3.UP, rotation.y), global_position),
			collider.shape, collider.position, BODY_MASS, push, impact, _random, 1.0, 2.0, TOWN_LAYER)
	_ragdoll.add_collision_exception_with(_body)
	collider.set_deferred("disabled", true)
	_drawn.position = Vector3.ZERO
	_drawn.reparent(_ragdoll, true)
	_ragdoll_clock = 0.0


## While knocked down: the node (and its shadow) stays with the body; once it lies still it
## gets up, or, dead, after DEAD_LIE s starts afresh elsewhere.
func _follow_ragdoll(delta: float) -> void:
	_ragdoll_clock += delta
	global_position = _ragdoll.global_position
	if health <= 0.0:
		if _ragdoll_clock >= DEAD_LIE:
			health = MAX_HEALTH
			_get_up()
			town.start_again(self)
		return
	var lies_still := _ragdoll.sleeping or _ragdoll.linear_velocity.length() < 0.3
	if (_ragdoll_clock >= KNOCK_DOWN_TIME and lies_still) or _ragdoll_clock >= KNOCK_DOWN_TIME * 3.0:
		_get_up()


## Back on its feet where it lies, if it may walk there and stands free; else on a spot of
## its last cell; else just where it lies. Then a moment's pause and on.
func _get_up() -> void:
	var lying_at := _ragdoll.global_position
	var heading := _ragdoll.global_basis.z
	_end_ragdoll()
	var height := _ground_height(lying_at, lying_at.y + 0.5)
	var feet := Vector3(lying_at.x, height, lying_at.z)
	var lying_cell := town.cell_of(lying_at)
	if not is_nan(height) and town.may_use(lying_cell, mobility) and _stands_free(feet):
		global_position = feet
		_ground_y = feet.y
		cell = lying_cell
		_came_from = lying_cell
		_next_cell = lying_cell
		_target = feet
		if Vector2(heading.x, heading.z).length_squared() > 0.01:
			rotation.y = atan2(heading.x, heading.z)
	elif not restart_at(cell):
		global_position = Vector3(lying_at.x, global_position.y if is_nan(height) else height, lying_at.z)
		_target = global_position
	_pause = 0.8


## The figure back from the thrown body, its collider on again, the traffic minding it again.
func _end_ragdoll() -> void:
	_drawn.reparent(self, false)
	_drawn.transform = Transform3D.IDENTITY
	_ragdoll.queue_free()
	_ragdoll = null
	(_body.get_node("Doos") as CollisionShape3D).set_deferred("disabled", false)
	add_to_group(Vehicle.WALKERS_GROUP)
