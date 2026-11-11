extends RefCounted
## Knocked over: the figure of someone becomes a rigid body (a box as big as they are) thrown
## along with what hit them, tumbling, until it lies still. One way for everyone: the player
## (PlayerController), the people on the street (Pedestrian) and the people in the station
## (StationPerson), hit by a vehicle, a train, or thrown out of a building.
##   var body := KnockDown.throw(get_parent(), Transform3D(Basis(Vector3.UP, rotation.y), global_position),
##           shape, shape_offset, mass, push, impact, random)
##   figure.reparent(body, true)

## Friction and bounce of a body on the street.
const FRICTION := 0.9
const BOUNCE := 0.2
## How high it is thrown (m/s up: this, plus this per m/s of the blow, at most MOST_UP), and
## how fast it tumbles (rad/s per m/s of the blow, at most MOST_SPIN).
const UP_BASE := 1.5
const UP_PER_IMPACT := 0.22
const MOST_UP := 7.0
const SPIN_PER_IMPACT := 0.6
const MOST_SPIN := 14.0


## A rigid body under `parent` at `at`, its collision `shape` at `shape_offset`, of `mass`,
## thrown with `push` (m/s, along the ground; `push_factor` times it) and up by the blow of
## `impact` (m/s), tumbling forward over (with `extra_spin` rad/s more) and a little round.
static func throw(parent: Node, at: Transform3D, shape: Shape3D, shape_offset: Vector3, mass: float,
		push: Vector3, impact: float, random: RandomNumberGenerator, push_factor := 1.0, extra_spin := 0.0,
		collision_mask := -1) -> RigidBody3D:
	var body := RigidBody3D.new()
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
	body.global_transform = at.translated(Vector3.UP * 0.05)
	var flat_push := Vector3(push.x, 0.0, push.z)
	var towards := flat_push.normalized() if flat_push.length_squared() > 0.01 else at.basis.z
	body.linear_velocity = flat_push * push_factor + Vector3.UP * minf(UP_BASE + impact * UP_PER_IMPACT, MOST_UP)
	body.angular_velocity = Vector3.UP.cross(towards) * minf(impact * SPIN_PER_IMPACT + extra_spin, MOST_SPIN) \
		+ Vector3.UP * random.randf_range(-3.0, 3.0)
	return body
