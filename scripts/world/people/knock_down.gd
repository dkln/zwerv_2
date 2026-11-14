extends RefCounted
## Knocked over: the figure of someone becomes a rigid body (a box as big as they are) thrown
## along with what hit them, tumbling, until it lies still. One way for everyone: the player
## (PlayerController), the people on the street (Pedestrian) and the people in the station
## (StationPerson), hit by a vehicle, a train, or thrown out of a building. The body throws
## the shards of a crash each time it lands hard on something (knock_down_body.gd).
## Behaviour (docs/CODE_LAGEN.md); how fast and which way it is thrown: knock_down_rules.gd.
##   var body := KnockDown.throw(get_parent(), Transform3D(Basis(Vector3.UP, rotation.y), global_position),
##           shape, shape_offset, mass, push, impact, random)
##   figure.reparent(body, true)

const KnockDownRules = preload("res://scripts/world/people/knock_down_rules.gd")
const FRICTION := KnockDownRules.FRICTION
const BOUNCE := KnockDownRules.BOUNCE
const UP_BASE := KnockDownRules.UP_BASE
const UP_PER_IMPACT := KnockDownRules.UP_PER_IMPACT
const MOST_UP := KnockDownRules.MOST_UP
const SPIN_PER_IMPACT := KnockDownRules.SPIN_PER_IMPACT
const MOST_SPIN := KnockDownRules.MOST_SPIN
const DIVE_PITCH := KnockDownRules.DIVE_PITCH
const DIVE_LIFT := KnockDownRules.DIVE_LIFT
const DIVE_UP := KnockDownRules.DIVE_UP
const DIVE_SPIN := KnockDownRules.DIVE_SPIN


## A rigid body under `parent` at `at`, its collision `shape` at `shape_offset`, of `mass`,
## thrown with `push` (m/s, along the ground; `push_factor` times it) and up by the blow of
## `impact` (m/s), tumbling forward over (with `extra_spin` rad/s more) and a little round.
static func throw(parent: Node, at: Transform3D, shape: Shape3D, shape_offset: Vector3, mass: float,
		push: Vector3, impact: float, random: RandomNumberGenerator, push_factor := 1.0, extra_spin := 0.0,
		collision_mask := -1, dive := false) -> RigidBody3D:
	# a body that throws the shards of a crash every time it hits something hard
	var body := (load("res://scripts/world/people/knock_down_body.gd") as GDScript).new() as RigidBody3D
	body.name = "Valpartij"
	body.mass = mass
	body.continuous_cd = true
	if collision_mask >= 0:
		body.collision_layer = 0
		body.collision_mask = collision_mask
	var material := PhysicsMaterial.new()
	material.friction = FRICTION
	material.bounce = BOUNCE
	body.physics_material_override = material
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = shape_offset
	body.add_child(collision)
	parent.add_child(body)
	var way := KnockDownRules.towards(push, at.basis.z)
	if dive:
		body.global_transform = KnockDownRules.dive_start(way, at.origin)
		body.linear_velocity = KnockDownRules.dive_velocity(push, push_factor)
		body.angular_velocity = KnockDownRules.dive_spin(way,
			random.randf_range(-KnockDownRules.MOST_DIVE_ROLL, KnockDownRules.MOST_DIVE_ROLL))
		return body
	body.global_transform = at.translated(Vector3.UP * KnockDownRules.START_LIFT)
	body.linear_velocity = KnockDownRules.thrown_velocity(push, push_factor, impact)
	body.angular_velocity = KnockDownRules.thrown_spin(way, impact, extra_spin,
		random.randf_range(-KnockDownRules.MOST_TWIST, KnockDownRules.MOST_TWIST))
	return body
