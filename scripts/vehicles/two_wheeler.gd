class_name TwoWheeler
extends Vehicle
## A two-wheeler with its rider: the base of the bicycles (cyclist.gd, fatbike.gd) and the
## motor two-wheelers (moped.gd, scooter.gd, motorbike.gd). It leans into its corners and
## countersteers into them (Vehicle `leans`, `countersteer`).
## The rider is a townsperson (TownsfolkFigure, the size of the player figures), its look
## from the vehicle's route_seed (`rider_kind`: a bare head or a cap on a bicycle, an open
## or a full-face helmet on a moped or a motorbike; `rider_look` overrides parts of it):
## the hips on the seat (`rider_hip`), the hands on the grips (`rider_grips`), the body
## leaning forward as far as the arms need to reach them, the feet on the footrests
## (`rider_feet`).
## A bicycle (`bicycle`) is built in code (BicycleParts): its steering (fork, bars, front
## wheel and front lamp) turns about the leaning head tube, and the rider pedals: the
## cranks turn with the rear wheel (PEDAL_GEAR wheel turns per turn of the cranks, not
## while it brakes or rolls to a stop), its feet on the pedals and its knees bending
## (TownsfolkFigure.aim_leg), its hands following the bars as they steer.
## The rider and the bicycle count for its size (Vehicle._measure_length: everything drawn
## on the body), so for the others, for a crash and for its wreck's collider.
## Some do a wheelie now and then (`wheelie_degrees`, Wheelie): going straight at speed the
## front comes up on the rear wheel for a few seconds and the rider shouts something cocky
## (DriverShout, mood "wheelie", `wheelie_kind` for its own lines).
## Crashing hard (_become_wreck) it goes down: the wreck tips over onto its side (a higher centre
## of mass and a roll towards where it was pushed, TOPPLE_SPIN) and slides on without its
## engine, and the rider comes off: thrown as a tumbling body of their own (KnockDown) along
## the way they were going. A bicycle never burns (_catch_fire). Towed back, the rider is in
## the saddle again.

const Wheelie = preload("res://scripts/vehicles/wheelie.gd")
const KnockDown = preload("res://scripts/world/knock_down.gd")

## Going down: the roll (rad/s) round its length that tips the wreck over, the height of its
## centre of mass (share of its height), and the rider thrown off: their mass (kg), the share
## of the speed they fly on with, the extra tumble (rad/s).
const TOPPLE_SPIN := 5.5
const TOPPLE_CENTRE := 0.6
const RIDER_MASS := 75.0
const RIDER_FLIES_ON := 0.85
const RIDER_TUMBLE := 3.0
## Seconds after the crash at which the wreck's box shrinks to the vehicle without its rider.
const FIT_WRECK_AFTER := 0.8

## Wheel turns per turn of the cranks (a Dutch bicycle's gear).
const PEDAL_GEAR := 2.4
## Pedalling under this acceleration (m/s²) stops: it brakes or rolls out.
const COAST_BELOW := -0.25
## Furthest the rider's body leans forward to reach the grips (radians).
const MOST_LEAN := 0.9
## A wheelie only from this speed (m/s), and only while leaning less than this (radians).
const WHEELIE_FROM_SPEED := 4.0
const WHEELIE_MOST_LEAN := 0.1

@export_group("Rider")
## "": no rider; "fiets": bare head or a cap; "helm": an open helmet; "helm_dicht": a full-face one.
@export var rider_kind := "fiets"
## Parts of the rider's look set by hand (TownsfolkFigure.look_for keys: "coat", "trim", ...).
@export var rider_look := {}
## Where the rider's hips are, and its left foot and left hand (+x; the right ones are
## mirrored), in metres on the vehicle. A bicycle takes them from BicycleParts.
@export var rider_hip := Vector3(0.0, 0.9, -0.4)
@export var rider_foot := Vector3(0.22, 0.25, -0.19)
@export var rider_grip := Vector3(0.28, 1.15, 0.22)
@export_group("Wheelie")
## How far the front comes up in a wheelie (degrees); 0: never.
@export var wheelie_degrees := 0.0
## Its own wheelie lines (DriverShout KIND_LINES): "fatbike", "brommer", "motor".
@export var wheelie_kind := ""
@export_group("Bicycle")
## Built in code (BicycleParts) instead of the props item `model`.
@export var bicycle := false
## The frame colours one of which it gets (from route_seed), and how many in 100 have a
## low step-through frame.
@export var bicycle_paints: Array[Color] = [Color("#1E1F24")]
@export var step_through_share := 0
@export var fat_tyres := false

var _rider: TownsfolkFigure
var _thrown_rider: RigidBody3D       # the rider's body, thrown off in a crash
var _rider_seat := Transform3D()     # the rider on the body, to put them back after the tow
var _crank: Node3D
var _steer_head: Node3D           # the head tube: leans the steering back
var _grips_on_steering := {}      # side ("left", "right") -> grip in the steering pivot's space
var _rider_lean := 0.0
var _crank_angle := 0.0
var _last_roll := 0.0
var _wheelie: Wheelie
var _rear_contact := Vector3.ZERO   # where the rear wheel touches the road, on the body


## A point of a two-wheeler tile of tools/voxgen/tiles/two_wheelers.py in metres on the
## vehicle: `along` from its front backwards and `up` in its voxels (0.0625 m; the row
## up = 2 on the road + 0.125 m), `across` voxels from its middle (+ = left);
## `middle_along`: half the tile's length (the middle between its hubs).
static func tile_point(along: float, up: float, across: float, middle_along: float) -> Vector3:
	return Vector3(across * 0.0625, 0.125 + (up - 2.0) * 0.0625, (middle_along - along) * 0.0625)


func _add_model(props: GridMap) -> void:
	if bicycle:
		_add_bicycle()
	else:
		super(props)
	_add_rider()
	if wheelie_degrees > 0.0 and _rider:
		_wheelie = Wheelie.new(deg_to_rad(wheelie_degrees), route_seed)
		var rear := Vector3(0.0, wheel_radius, INF)
		for wheel_position in wheel_positions:
			if wheel_position.z < rear.z:
				rear = wheel_position
		_rear_contact = Vector3(0.0, rear.y - wheel_radius, rear.z)


func _add_bicycle() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = route_seed
	var paint: Color = bicycle_paints[random.randi() % bicycle_paints.size()]
	var step_through := random.randi() % 100 < step_through_share
	var parts := BicycleParts.build(paint, step_through, fat_tyres)
	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	frame.mesh = parts.frame.mesh
	frame.position = parts.frame.offset
	_body.add_child(frame)
	# the head tube, leaning back (its y along BicycleParts.steer_axis), and the steering in it
	_steer_head = Node3D.new()
	_steer_head.name = "Balhoofd"
	var axis := BicycleParts.steer_axis()
	var across := Vector3.RIGHT
	_steer_head.transform = Transform3D(Basis(across, axis, across.cross(axis)), BicycleParts.steer_pivot())
	_body.add_child(_steer_head)
	_steering_pivot = Node3D.new()
	_steering_pivot.name = "Stuur"
	_steer_head.add_child(_steering_pivot)
	var steer := MeshInstance3D.new()
	steer.name = "Vork"
	steer.mesh = parts.steer.mesh
	_body.add_child(steer)
	steer.position = BicycleParts.steer_pivot() + parts.steer.offset
	steer.reparent(_steering_pivot, true)
	_crank = Node3D.new()
	_crank.name = "Trapas"
	_crank.position = BicycleParts.bottom_bracket()
	_body.add_child(_crank)
	var crank := MeshInstance3D.new()
	crank.name = "Trappers"
	crank.mesh = parts.crank.mesh
	crank.position = parts.crank.offset
	_crank.add_child(crank)
	rider_hip = BicycleParts.hip()
	rider_grip = BicycleParts.grip(true)
	for side: String in ["left", "right"]:
		var grip := BicycleParts.grip(side == "left")
		_grips_on_steering[side] = _steering_pivot.global_transform.affine_inverse() * (_body.global_transform * grip)


## The front wheel goes into the steering (it turns with the fork).
func _add_wheels(props: GridMap) -> void:
	super(props)
	if _steering_pivot == null:
		return
	for wheel in _wheels:
		if wheel.position.z > 0.0:
			wheel.reparent(_steering_pivot, true)


## The front lamp sits on the fork, so it (and its beam) turns with it.
func _add_lamps() -> void:
	super()
	if _steering_pivot == null:
		return
	for lamp in _headlights:
		if lamp.position.z > 0.0:
			lamp.reparent(_steering_pivot, true)
	if _beam:
		_beam.reparent(_steering_pivot, true)


## The look of its rider (empty without one): one of its route_seed and rider_kind, with
## rider_look over it. Traffic builds it on a thread before it comes (TownsfolkFigure.prepare).
func rider_figure_look() -> Dictionary:
	if rider_kind == "":
		return {}
	var look := TownsfolkFigure.look_for(route_seed * 7 + 3, rider_kind)
	look.merge(rider_look, true)
	return look


func _add_rider() -> void:
	if rider_kind == "":
		return
	_rider = TownsfolkFigure.create(rider_figure_look())
	_rider.name = "Berijder"
	_body.add_child(_rider)
	_rider.position = rider_hip - _rider.hip_middle()
	_rider_lean = _lean_to_reach()
	_rider.lean_body(_rider_lean)
	_pose_rider(0.0)


## Which side of the vehicle a limb of the rider is on: "left" for +x.
func _vehicle_side(limb: String) -> String:
	return "left" if _rider.rest_joint(limb).x > 0.0 else "right"


func _grip(side: String) -> Vector3:
	if _grips_on_steering.has(side):
		var on_body := _body.global_transform.affine_inverse() * (_steering_pivot.global_transform * (_grips_on_steering[side] as Vector3))
		return on_body
	return Vector3(rider_grip.x if side == "left" else -rider_grip.x, rider_grip.y, rider_grip.z)


## How far forward the body leans so the arms reach the grips (the lean at which the
## distance from shoulder to grip comes closest to the arm's length).
func _lean_to_reach() -> float:
	var best := 0.0
	var best_miss := INF
	var lean := 0.0
	while lean <= MOST_LEAN:
		var miss := 0.0
		for limb: String in ["arm_left", "arm_right"]:
			var hand := _grip(_vehicle_side(limb)) - _rider.position
			miss += absf(_rider.shoulder_at(limb.get_slice("_", 1), lean).distance_to(hand) - TownsfolkFigure.arm_length())
		if miss < best_miss:
			best_miss = miss
			best = lean
		lean += 0.02
	return best


## Feet on the pedals (cranks at `crank_angle`) or the footrests, hands on the grips.
func _pose_rider(crank_angle: float) -> void:
	for side: String in ["left", "right"]:
		var thigh := "thigh_" + side
		var on_vehicle := _vehicle_side(thigh)
		var foot: Vector3
		if bicycle:
			foot = BicycleParts.pedal(crank_angle, on_vehicle == "right")
		else:
			foot = Vector3(rider_foot.x if on_vehicle == "left" else -rider_foot.x, rider_foot.y, rider_foot.z)
		_rider.aim_leg(side, foot - _rider.position)
		var arm := "arm_" + side
		_rider.aim_arm(side, _grip(_vehicle_side(arm)) - _rider.position, _rider_lean)


func _animate(roll: float, _steering_now: float, delta: float) -> void:
	if _rider == null or crashed:
		return
	if _wheelie:
		_do_wheelie(delta)
	if not bicycle:
		return
	var turned := wrapf(roll - _last_roll, -PI, PI)
	_last_roll = roll
	if acceleration_now > COAST_BELOW and speed > 0.2:
		_crank_angle = fmod(_crank_angle + absf(turned) / PEDAL_GEAR, TAU)
	if _crank:
		_crank.rotation.x = _crank_angle
	_pose_rider(_crank_angle)


## Now and then the front up (Wheelie): only going straight at speed, not braking; while it
## is up the rider is a daredevil (Vehicle.daredevil: far too fast, no braking or swerving for
## anyone, so it may well crash hard); the
## body (drawn between the physics steps by Vehicle._process) is turned about the rear
## wheel's contact point, so the rider and the wheels go up with it.
func _do_wheelie(delta: float) -> void:
	var allowed := not crashed and speed > WHEELIE_FROM_SPEED and not braking_now \
			and acceleration_now > -0.2 and absf(_lean) < WHEELIE_MOST_LEAN
	if _wheelie.step(delta, allowed):
		DriverShout.shout(self, wheelie_kind, "wheelie", _outer_box.end.y + 0.6)
	# with the front up it is a daredevil: flat out, looking out for nothing (Vehicle.daredevil)
	daredevil = _wheelie.is_up() and not crashed
	if _wheelie.angle > 0.0:
		_body.global_transform = _body.global_transform * _wheelie.tilt_about(_rear_contact)


# ------------------------------------------------------------------ going down

func _become_wreck(impact: Vector3, spin := 0.0, pushed := Vector3.ZERO, jolt := 0.0) -> void:
	var speed_before := velocity
	super(impact, spin, pushed, jolt)
	if _wreck == null:
		return
	# over onto its side, towards where it was pushed (or either way), sliding without its engine
	# (the centre of mass high while it tips; _fit_wreck_to_vehicle sets the vehicle's own after
	# FIT_WRECK_AFTER)
	_wreck.center_of_mass = Vector3(0.0, _body_size.y * TOPPLE_CENTRE, 0.0)
	var along := global_basis.z.normalized()
	var side := signf(pushed.dot(global_basis.x))
	if side == 0.0:
		side = 1.0 if route_seed % 2 == 0 else -1.0
	_wreck.angular_velocity += along * side * TOPPLE_SPIN
	_roll_on_clock = 0.0
	_wreck.physics_material_override.friction = SLIDING_FRICTION
	_throw_rider(speed_before, maxf(jolt, speed_before.length()))
	# once it is going over, the wreck the size of the vehicle alone (with its own centre of mass)
	get_tree().create_timer(FIT_WRECK_AFTER, false).timeout.connect(_fit_wreck_to_vehicle)


## Without its rider the wreck is only as big as the vehicle (its meshes): the box the wreck
## got was measured with the rider on it.
func _fit_wreck_to_vehicle() -> void:
	if _wreck == null or not is_instance_valid(_wreck):
		return
	var shape_node: CollisionShape3D = null
	for child in _wreck.get_children():
		if child is CollisionShape3D:
			shape_node = child
			break
	if shape_node == null:
		return
	var bounds := Vehicle._mesh_bounds(_body)
	if bounds.size.y < 0.2:
		return
	(shape_node.shape as BoxShape3D).size = Vector3(maxf(bounds.size.x, 0.2), maxf(bounds.size.y - 0.05, 0.2), maxf(bounds.size.z, 0.5))
	shape_node.position = bounds.get_center() + Vector3(0.0, 0.03, 0.0)
	_wreck.center_of_mass = Vector3(0.0, bounds.get_center().y, 0.0)


## The rider off the vehicle, flying on the way they went (and up and tumbling by the blow).
func _throw_rider(speed_before: Vector3, impact: float) -> void:
	if _rider == null or _thrown_rider != null:
		return
	_rider_seat = _rider.transform
	# limp: straight arms and legs (no longer on the grips and the pedals), then the body as
	# big as the figure is now (its meshes), so it lands and lies the size it looks
	_rider.walk(0.0, 0.0)
	_rider.lean_body(0.0)
	var bounds := Vehicle._mesh_bounds(_rider)
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(bounds.size.x, 0.3), maxf(bounds.size.y, 0.8), maxf(bounds.size.z, 0.2))
	var flat_speed := Vector3(speed_before.x, 0.0, speed_before.z) * RIDER_FLIES_ON
	_thrown_rider = KnockDown.throw(get_parent(), Transform3D(Basis(Vector3.UP, rotation.y), _rider.global_position),
			box, bounds.get_center(), RIDER_MASS, flat_speed, impact, _random, 1.0, RIDER_TUMBLE)
	if _wreck:
		_thrown_rider.add_collision_exception_with(_wreck)
	_rider.reparent(_thrown_rider, true)


## A bicycle has nothing to burn; a motor two-wheeler can catch fire as any vehicle.
func _catch_fire() -> void:
	if bicycle:
		return
	super()


## Towed back: the rider in the saddle again.
func _tow() -> void:
	if _thrown_rider and is_instance_valid(_thrown_rider):
		_rider.reparent(_body, false)
		_rider.transform = _rider_seat
		_rider.lean_body(_rider_lean)
		_pose_rider(_crank_angle)
		_thrown_rider.queue_free()
	_thrown_rider = null
	super()
