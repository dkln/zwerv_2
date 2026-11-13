extends RigidBody3D
## The body of someone knocked over (KnockDown.throw): every time it hits something hard (the
## street, a wall, a vehicle, anything) the shards of a crash fly (CrashBurst), as when a
## vehicle hits someone; the harder the blow, the more. A blow counts from HARD_SPEED (m/s,
## the speed it had just before), and not twice within QUIET_SECONDS (a body sliding over the
## street keeps touching it).

## Fires at every hard blow (from HARD_SPEED), with the speed it had (m/s): landing.
signal hit_hard(speed: float)

const HARD_SPEED := 3.0
const QUIET_SECONDS := 0.12
## The speed (m/s) of a blow that throws the most shards.
const FULLEST_SPEED := 16.0

var shard_colour := Color("#6B5844")
var _speed_before := 0.0
var _quiet := 0.0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_hit)


func _physics_process(delta: float) -> void:
	_quiet = maxf(_quiet - delta, 0.0)
	_speed_before = linear_velocity.length()


func _on_hit(_other: Node) -> void:
	if _speed_before < HARD_SPEED or _quiet > 0.0:
		return
	_quiet = QUIET_SECONDS
	var strength := clampf(_speed_before / FULLEST_SPEED, 0.15, 1.0)
	CrashBurst.spawn(get_parent(), global_position + Vector3.UP * 0.4, shard_colour, strength)
	hit_hard.emit(_speed_before)
