class_name VoxCharacter
extends CharacterBody3D
## A walking character for the voxel world, for the player and for NPCs alike: a
## kinematic body (move_and_slide; no rigid-body simulation) with gravity, floor
## snapping, stepping and jumping. Something else steers it: a player controller sets
## `move_direction` from the input and calls jump(); an NPC has a PathFollower
## (scripts/characters/path_follower.gd) that does the same along a GridNav path.
##
## Collider: a capsule from `step` up to `height`, and a separation ray from the bottom
## of the capsule down to the feet. The ray holds the body up, so it rides up anything
## up to `step` high (kerbs, stair treads) without a step-up routine. The origin is at
## the feet. Front = -Z of the body; `facing` follows the walking direction.
##
## Built in _ready from the exported sizes; add the model as a child.

## A jump started (with the place it should land, or Vector3.INF for a jump on the spot).
signal jumped(target: Vector3)
## Back on the floor after a fall or jump; `drop` = metres lower than where it left the floor.
signal landed(drop: float)

## Height of the character and radius of its capsule (metres).
@export var height := 1.8
@export var radius := 0.25
## Highest step it walks up without jumping (metres).
@export var step := 0.25
## Walking speed (m/s) and gravity (m/s²).
@export var speed := 1.4
@export var gravity := 9.8
## Height of jump() (metres).
@export var jump_height := 1.0
## Turning speed of `facing` (1/s).
@export var turn_speed := 8.0

## Wanted walking direction (horizontal, length 0..1); the controller sets it every frame.
var move_direction := Vector3.ZERO
## Horizontal direction the character faces (unit vector).
var facing := Vector3.FORWARD

## Height where it last left the floor (NAN = on the floor).
var _left_floor_at := NAN
## In a jump_to(): horizontal velocity of the jump (the steering is ignored meanwhile).
var _jump_velocity := Vector3.ZERO
var _in_jump := false


func _ready() -> void:
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = step + 0.05
	floor_constant_speed = true
	floor_block_on_wall = true
	var capsule := CapsuleShape3D.new()
	capsule.height = height - step
	capsule.radius = radius
	var cs := CollisionShape3D.new()
	cs.name = "Capsule"
	cs.shape = capsule
	cs.position.y = step + capsule.height * 0.5
	add_child(cs)
	var ray := SeparationRayShape3D.new()
	ray.length = step
	var rs := CollisionShape3D.new()
	rs.name = "Stap"
	rs.shape = ray
	rs.position.y = step
	rs.rotation_degrees.x = 90.0   # the ray points along +Z: now straight down
	add_child(rs)


## Jumps up on the spot (keeps walking in move_direction). False if not on the floor.
func jump() -> bool:
	if not is_on_floor():
		return false
	velocity.y = sqrt(2.0 * gravity * jump_height)
	jumped.emit(Vector3.INF)
	return true


## Jumps to `target` (feet position) in an arc that clears both ends by `clearance`
## metres: over a low obstacle or up a ledge. False if not on the floor.
func jump_to(target: Vector3, clearance := 0.6) -> bool:
	if not is_on_floor():
		return false
	var from := global_position
	var apex := maxf(target.y - from.y, 0.0) + clearance
	var up := sqrt(2.0 * gravity * apex)
	var t := up / gravity + sqrt(2.0 * maxf(apex - (target.y - from.y), 0.01) / gravity)
	var flat := Vector3(target.x - from.x, 0, target.z - from.z)
	_jump_velocity = flat / t
	velocity = _jump_velocity + Vector3.UP * up
	_in_jump = true
	if flat.length() > 0.01:
		facing = flat.normalized()
	jumped.emit(target)
	return true


## In the air (jumping or falling).
func is_airborne() -> bool:
	return not is_on_floor()


func _physics_process(delta: float) -> void:
	var dir := Vector3(move_direction.x, 0, move_direction.z).limit_length(1.0)
	if _in_jump:
		velocity.x = _jump_velocity.x
		velocity.z = _jump_velocity.z
	else:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		if dir.length() > 0.01:
			facing = facing.slerp(dir.normalized(), minf(1.0, delta * turn_speed)).normalized()
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	var was_on_floor := is_on_floor()
	move_and_slide()
	if was_on_floor and not is_on_floor():
		_left_floor_at = global_position.y
	elif not was_on_floor and is_on_floor():
		_in_jump = false
		var drop := (_left_floor_at - global_position.y) if not is_nan(_left_floor_at) else 0.0
		_left_floor_at = NAN
		landed.emit(drop)
