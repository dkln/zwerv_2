class_name PathFollower
extends Node
## Steers its parent VoxCharacter (scripts/characters/vox_character.gd) along a path:
## the "legs" of an NPC. Give it a path from GridNav.path() (points plus the indices of
## jump/drop links) with follow(); it sets the character's move_direction every
## physics frame, jumps the jump links (jump_to) and walks off the edge for the drops.
##
## It reports, but does not fix: `stuck` when the character hardly moves for
## `stuck_time` seconds (the caller decides: wait, re-plan, put it back on the path).

## The end of the path has been reached.
signal arrived
## Hardly any progress for stuck_time seconds, at `at`.
signal stuck(at: Vector3)

## A path point counts as reached within this distance (metres, horizontal).
@export var reach := 0.3
## Stuck: less than `stuck_distance` progress in `stuck_time` seconds.
@export var stuck_time := 2.0
@export var stuck_distance := 0.25
## Extra height over a jump's ends (metres).
@export var jump_clearance := 0.6

var character: VoxCharacter
## The path being followed and the index of the next point.
var points := PackedVector3Array()
var next := 0
## Indices i where points[i] -> points[i + 1] is a link (jump or drop).
var links := PackedInt32Array()
var paused := false

var _following := false
var _stuck_clock := 0.0
var _stuck_from := Vector3.ZERO


func _ready() -> void:
	character = get_parent() as VoxCharacter


## Follows `path` ({"points", "links"} from GridNav.path(), or a plain
## PackedVector3Array) from its first point.
func follow(path) -> void:
	if path is Dictionary:
		points = path["points"]
		links = path.get("links", PackedInt32Array())
	else:
		points = path
		links = PackedInt32Array()
	next = 1
	_following = points.size() > 1
	_stuck_clock = 0.0
	if character:
		_stuck_from = character.global_position


func stop() -> void:
	_following = false
	if character:
		character.move_direction = Vector3.ZERO


func is_following() -> bool:
	return _following


## Puts the character on the next path point and goes on from there (after `stuck`).
func skip_ahead() -> void:
	if not _following or character == null:
		return
	character.global_position = points[mini(next, points.size() - 1)] + Vector3.UP * 0.1
	character.velocity = Vector3.ZERO
	next = mini(next + 1, points.size())


## Horizontal distance from the character to the segment it is walking.
func distance_from_path() -> float:
	if character == null or next < 1 or next >= points.size():
		return 0.0
	var p := _flat(character.global_position)
	return Geometry3D.get_closest_point_to_segment(p, _flat(points[next - 1]), _flat(points[next])).distance_to(p)


func _physics_process(delta: float) -> void:
	if character == null or not _following:
		return
	if paused:
		character.move_direction = Vector3.ZERO
		return
	if character.is_airborne():
		return   # a jump or fall: the character carries on by itself
	var pos := character.global_position
	while next < points.size() and _flat(points[next] - pos).length() < reach:
		next += 1
	if next >= points.size():
		stop()
		arrived.emit()
		return
	var target := points[next]
	var to := _flat(target - pos)
	# a jump link: jump when standing at its start (a drop is just walked off)
	if (next - 1) in links and target.y > pos.y - character.step and _flat(points[next - 1] - pos).length() < reach * 2.0:
		if character.jump_to(target, jump_clearance):
			next += 1
			return
	character.move_direction = to.normalized() if to.length() > 0.001 else Vector3.ZERO
	_stuck_clock += delta
	if _stuck_clock >= stuck_time:
		if character.global_position.distance_to(_stuck_from) < stuck_distance:
			stuck.emit(character.global_position)
		_stuck_clock = 0.0
		_stuck_from = character.global_position


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)
