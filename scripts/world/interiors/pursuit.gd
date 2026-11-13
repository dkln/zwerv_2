extends RefCounted
## Someone of a place going after the player: the rules of a chase, the same everywhere. The
## conductor after a fare dodger in Den Haag Centraal (scripts/world/station/station.gd) and whoever
## comes to put the player out of an interior (scripts/world/interiors/eviction.gd: the snack bar
## owner, a BOA, the cashier, the guard) both use it. How the chaser walks is up to the
## place (its floor, its routes); this only says how it stands: caught once the chaser is
## within `catch_reach` of the player (along the floor, and less than `height_reach` above
## or below them: not from the platform onto the rails), given up after `give_up_seconds`
## more than `give_up_distance` away or after `longest` seconds in all (0: never).
##   var pursuit := Pursuit.new(conductor, 1.0)
##   pursuit.give_up_distance = 15.0
##   match pursuit.update(delta, player.global_position):
##       Pursuit.CAUGHT: ...
##       Pursuit.GAVE_UP: ...

const CAUGHT := "gepakt"
const GAVE_UP := "opgegeven"

var chaser: Node3D
var catch_reach := 1.0
var height_reach := 1.2
## 0: never too far.
var give_up_distance := 0.0
var give_up_seconds := 3.0
## 0: no end to it.
var longest := 0.0
## How long it has been going, and how long the chaser has been too far off in a row.
var seconds := 0.0
var far_seconds := 0.0


func _init(who: Node3D, reach := 1.0) -> void:
	chaser = who
	catch_reach = reach


## How far the chaser is from `player_at` (global) along the floor; INF without a chaser.
func gap_to(player_at: Vector3) -> float:
	if chaser == null or not is_instance_valid(chaser) or not chaser.is_inside_tree():
		return INF
	var at := chaser.global_position
	return Vector2(player_at.x - at.x, player_at.z - at.z).length()


## Whether the chaser is at the player at `player_at` (global) now.
func is_at(player_at: Vector3) -> bool:
	return gap_to(player_at) <= catch_reach and absf(player_at.y - chaser.global_position.y) < height_reach


## The chase `delta` seconds on, the player at `player_at` (global): CAUGHT, GAVE_UP (also
## when the chaser is gone), or "" while it goes on.
func update(delta: float, player_at: Vector3) -> String:
	if chaser == null or not is_instance_valid(chaser) or not chaser.is_inside_tree():
		return GAVE_UP
	seconds += delta
	if is_at(player_at):
		return CAUGHT
	if give_up_distance > 0.0 and gap_to(player_at) > give_up_distance:
		far_seconds += delta
	else:
		far_seconds = 0.0
	if give_up_distance > 0.0 and far_seconds >= give_up_seconds:
		return GAVE_UP
	if longest > 0.0 and seconds >= longest:
		return GAVE_UP
	return ""
