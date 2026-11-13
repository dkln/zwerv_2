extends RefCounted
## Knocked over: the figure of someone becomes a rigid body (a box as big as they are) thrown
## along with what hit them, tumbling, until it lies still. One way for everyone: the player
## (PlayerController), the people on the street (Pedestrian) and the people in the station
## (StationPerson), hit by a vehicle, a train, or thrown out of a building. The body throws
## the shards of a crash each time it lands hard on something (knock_down_body.gd).
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
## A dive (`dive`: thrown out of a door head first, as a pike dive): the body already flat
## (pitched this far forward), lifted this high so it flies over the street, a little up
## (m/s) and hardly turning in the air; hitting the street it tumbles over by itself.
const DIVE_PITCH := deg_to_rad(80.0)
const DIVE_LIFT := 1.2
const DIVE_UP := 3.6
const DIVE_SPIN := 0.8


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
	var flat_push := Vector3(push.x, 0.0, push.z)
	var towards := flat_push.normalized() if flat_push.length_squared() > 0.01 else at.basis.z
	if dive:
		# flat in the air, head first the way it is thrown
		var facing := Basis.looking_at(-towards, Vector3.UP)
		var tipped := Basis(towards.cross(Vector3.UP).normalized(), -DIVE_PITCH) * facing
		body.global_transform = Transform3D(tipped, at.origin + Vector3.UP * DIVE_LIFT)
		body.linear_velocity = flat_push * push_factor + Vector3.UP * DIVE_UP
		body.angular_velocity = Vector3.UP.cross(towards) * DIVE_SPIN + towards * random.randf_range(-1.0, 1.0)
		return body
	body.global_transform = at.translated(Vector3.UP * 0.05)
	body.linear_velocity = flat_push * push_factor + Vector3.UP * minf(UP_BASE + impact * UP_PER_IMPACT, MOST_UP)
	body.angular_velocity = Vector3.UP.cross(towards) * minf(impact * SPIN_PER_IMPACT + extra_spin, MOST_SPIN) \
		+ Vector3.UP * random.randf_range(-3.0, 3.0)
	return body
