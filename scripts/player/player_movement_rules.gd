extends RefCounted
## The arithmetic of the player walking, jumping, talking and waking (logic;
## docs/CODE_LAGEN.md): the keys as a direction, turning and walking the way it faces
## ("tank") or along the screen ("scherm"), when it runs and how fast, how hard a jump takes
## off, how the figure follows, who is nearest to talk to, which ground counts, where to look
## for a spot to stand, and when the sleeper wakes. The behaviour is player_controller.gd,
## which asks the keys and the town's colliders and hands the answers here.
##   const PlayerMovementRules = preload("res://scripts/player/player_movement_rules.gd")

const TANK := "tank"
## Walking speeds the figure's walk goes up to (PlayerModel.walking: 1 = walking, above it running).
const FASTEST_WALKING := 1.7
## Seconds the figure's walk takes to follow the speed.
const WALKING_FOLLOW_SECONDS := 0.08
## Slower than this (m/s over the ground) it stands still: no safe spot is noted.
const STANDING_SPEED := 0.01
## A move shorter than this (squared metres) is no move; and not having moved further than
## STUCK (squared metres) in a step is being stopped (pushing against something).
const NO_MOVE := 0.00000001
const STUCK := 0.0001
## How far ahead (metres) it feels for water it pushes against.
const WATER_AHEAD := 0.6
## Someone it faces counts as this many metres nearer (talking); and how far above or below
## (metres) someone may stand.
const FACING_COUNTS := 0.8
const TALK_HEIGHT := 1.2
## Walking off an edge: the ray may hit its upright side, so it also looks up to EDGE_HOP
## metres further on and hops that far over the edge.
const EDGE_HOP := 0.4
## Looking for a spot to stand (walkable_near): rings this far apart, a try every so far along them.
const RING_STEP := 0.75
## How far the view's coming down (FollowCamera.arrival_progress) has to be for it to wake.
const WAKE_AT_ARRIVAL := 0.8
## Ground tile folders a start spot is looked for on, best first; the last: anything walkable.
const PREFERRED_GROUND := [["plein/"], ["plein/", "stoep/"]]
const WATER_FOLDER := "water/"
const QUAY_WALL := "kademuur"
const TUNNEL := "tunnel"


## The four direction keys as a vector: x right, y down the screen (backwards).
static func keys_vector(left: bool, right: bool, up: bool, down: bool) -> Vector2:
	var input := Vector2.ZERO
	if left:
		input.x -= 1.0
	if right:
		input.x += 1.0
	if up:
		input.y -= 1.0
	if down:
		input.y += 1.0
	return input


## What steers: the keys, or without any the stick of a controller (at most 1 long).
static func steering(keys: Vector2, stick: Vector2) -> Vector2:
	return (keys + stick).limit_length(1.0) if keys == Vector2.ZERO else keys


## "tank": the heading after turning for `delta` seconds at `turn_speed` degrees a second.
static func turned(yaw: float, steer_x: float, turn_speed: float, delta: float) -> float:
	return yaw - steer_x * deg_to_rad(turn_speed) * delta


## The way a figure turned to `yaw` faces, over the ground.
static func facing(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


## "tank": whether the stick or keys walk backwards.
static func is_backwards(steer_y: float) -> bool:
	return steer_y > 0.0


## "tank": where it walks: the way it faces or straight back; ZERO when it does not walk.
static func tank_direction(yaw: float, steer_y: float) -> Vector3:
	if steer_y == 0.0:
		return Vector3.ZERO
	return facing(yaw) * (-1.0 if is_backwards(steer_y) else 1.0)


## "scherm": where it walks along the screen (up = into it), for a camera that looks from
## `towards_camera`; ZERO when nothing steers.
static func screen_direction(steer: Vector2, towards_camera: Vector3) -> Vector3:
	if steer == Vector2.ZERO:
		return Vector3.ZERO
	var pressed := steer.normalized()
	var into_screen := -Vector3(towards_camera.x, 0.0, towards_camera.z).normalized()
	var screen_right := into_screen.cross(Vector3.UP)
	return screen_right * pressed.x - into_screen * pressed.y


## Whether it runs: going somewhere forwards with the run key down, not exhausted, stamina left.
static func runs(direction: Vector3, backwards: bool, run_key: bool, exhausted: bool, stamina: Vector2) -> bool:
	return direction != Vector3.ZERO and not backwards and run_key and not exhausted and stamina.x > 0.0


## Metres a second: running or walking, backwards at `backward_share` of it.
static func speed(walk_speed: float, run_speed: float, running: bool, backwards: bool, backward_share: float) -> float:
	var metres_a_second := run_speed if running else walk_speed
	if backwards:
		metres_a_second *= backward_share
	return metres_a_second


## The share of the way something that follows smoothly comes in `delta` seconds, when it
## takes about `seconds`.
static func follow_share(delta: float, seconds: float) -> float:
	return 1.0 - exp(-delta / maxf(seconds, 0.001))


## The heading that looks along `direction` (over the ground).
static func yaw_along(direction: Vector3) -> float:
	return atan2(direction.x, direction.z)


## Metres a second moved from `start` to `end` in `delta` seconds.
static func velocity(start: Vector3, end: Vector3, delta: float) -> Vector3:
	return (end - start) / maxf(delta, 0.0001)


## Metres a second over the ground.
static func flat_speed(moved: Vector3) -> float:
	return Vector2(moved.x, moved.z).length()


## How hard the figure walks (PlayerModel.walking) at `ground_speed`: 1 at walking speed, up
## to FASTEST_WALKING; 0 in the air.
static func walking_amount(ground_speed: float, walk_speed: float, airborne: bool) -> float:
	return 0.0 if airborne else clampf(ground_speed / walk_speed, 0.0, FASTEST_WALKING)


## Whether it stands on a spot worth remembering (to stand up at): moving, on the ground.
static func is_safe_spot(ground_speed: float, airborne: bool) -> bool:
	return ground_speed > STANDING_SPEED and not airborne


## Whether a step was stopped: it stands (almost) where it started.
static func is_stuck(start: Vector3, end: Vector3) -> bool:
	return end.distance_squared_to(start) < STUCK


## Whether it goes into the water it pushes against: at once when running, else after
## `push_time` seconds of pushing.
static func falls_in(running: bool, pushed_seconds: float, push_time: float) -> bool:
	return running or pushed_seconds >= push_time


## Whether a jump can start: not exhausted and the stamina for it.
static func can_jump(exhausted: bool, stamina: Vector2, cost: float) -> bool:
	return not exhausted and not stamina.x < cost


## Metres a second up at the start of a jump that reaches `height` under `gravity`.
static func takeoff_speed(gravity: float, height: float) -> float:
	return sqrt(2.0 * gravity * height)


## How deep under the feet a figure in the air looks for ground: as far as it rose above
## where it left, and `max_fall` below that.
static func fall_depth(height: float, takeoff_height: float, max_fall: float) -> float:
	return height - takeoff_height + max_fall


## Whether a figure coming down has landed: going down and at (or under) the ground.
static func has_landed(vertical_speed: float, height: float, ground: float) -> bool:
	return vertical_speed <= 0.0 and height <= ground


## Whether ground with this normal is too steep to walk on (`max_slope` degrees).
static func too_steep(normal: Vector3, max_slope: float) -> bool:
	return normal.y < cos(deg_to_rad(max_slope))


## How far past an edge it looks for ground to fall onto, nearest first.
static func edge_hops() -> Array:
	return [0.0, EDGE_HOP * 0.5, EDGE_HOP]


## Whether someone at `distance` over the ground and `height_difference` up or down is in `reach`.
static func in_talk_reach(distance: float, reach: float, height_difference: float) -> bool:
	return not (distance > reach or absf(height_difference) > TALK_HEIGHT)


## How near someone counts (lowest is talked to): the distance, less for the one it faces.
## `facing_flat` is the way the player faces, `offset` from the player to them (x, z).
static func talk_score(facing_flat: Vector2, offset: Vector2) -> float:
	var distance := offset.length()
	return distance - FACING_COUNTS * maxf(facing_flat.dot(offset / maxf(distance, 0.001)), 0.0)


## The heading that turns a figure's face along `towards` (over the ground); NAN when that
## is no direction (right on top of it).
static func yaw_towards(towards: Vector3) -> float:
	if Vector2(towards.x, towards.z).length_squared() < 0.0001:
		return NAN
	return atan2(towards.x, towards.z)


## Whether `towards` is a direction over the ground to turn to (not right on top of it).
static func is_apart(towards: Vector3) -> bool:
	return Vector2(towards.x, towards.z).length_squared() > 0.0001


## Whether a ground tile of this name is water (the quay wall in the water folder is not).
static func is_water_tile(tile_name: String) -> bool:
	return tile_name.begins_with(WATER_FOLDER) and not tile_name.contains(QUAY_WALL)


## Whether a ground tile of this name can be started on: no water, no tunnel, and (unless
## `folders` is empty) from one of these tile folders.
static func is_start_ground(tile_name: String, folders: Array) -> bool:
	if tile_name.begins_with(WATER_FOLDER) or tile_name.contains(TUNNEL):
		return false
	return folders.is_empty() or folders.any(func(folder: String) -> bool: return tile_name.begins_with(folder))


## The tile folders to look for a start spot on, in turn (the last: any).
static func start_ground_choices() -> Array:
	return PREFERRED_GROUND + [[]]


## Whether a cell is on the ring `ring` cells round the centre (a square ring).
static func on_ring(cell_offset_x: int, cell_offset_z: int, ring: int) -> bool:
	return maxi(absi(cell_offset_x), absi(cell_offset_z)) == ring


## The spots to try round `around` for a place to stand, nearest first: rings RING_STEP apart
## out to `reach` metres, a spot about every RING_STEP along each.
static func spots_near(around: Vector3, reach: float) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	var distance := 0.0
	while distance <= reach:
		var tries := 1 if distance == 0.0 else int(ceil(TAU * distance / RING_STEP))
		for attempt in tries:
			var angle := TAU * attempt / tries
			spots.append(around + Vector3(cos(angle), 0.0, sin(angle)) * distance)
		distance += RING_STEP
	return spots


## Whether the town is there for the sleeper: merged, and the view far enough down
## (`arrival` 0..1; 1 without a camera that arrives).
static func town_ready(merging: bool, arrival: float) -> bool:
	return not merging and not arrival < WAKE_AT_ARRIVAL


## Whether the sleeper wakes: slept out, or a key pressed once the town is there.
static func wakes(sleep_left: float, is_town_ready: bool, key_pressed: bool) -> bool:
	return sleep_left <= 0.0 or (is_town_ready and key_pressed)
