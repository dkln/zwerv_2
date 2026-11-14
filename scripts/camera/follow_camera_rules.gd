extends RefCounted
## The rules of the follow camera (logic; docs/CODE_LAGEN.md): where the view should be for a
## target that moves, how far it is zoomed for its speed, how the arrival comes down through
## the clouds, which way the view turns for the street round the player and when, what hides
## the player from it, the close-up and the shake of a crash, and which key does what when
## the player turns the view. No camera and no map here: follow_camera.gd keeps the state,
## asks these and places the camera; what stands on the map it hands in as a Callable.
##   const FollowCameraRules = preload("res://scripts/camera/follow_camera_rules.gd")

const IsoRules = preload("res://scripts/camera/iso_camera_rules.gd")
const CameraTurning = preload("res://scripts/camera/camera_turning.gd")

## Above this speed (m/s) between two frames the target did not move but jumped.
const JUMP_SPEED := 80.0
## The arrival: its speed in the clouds (share of the speed outside them), and the steps of
## its sum (arrival_descent).
const ARRIVAL_CLOUD_SPEED := 0.35
## From this share of the arrival on its speed runs out softly.
const ARRIVAL_SETTLE_FROM := 0.7
const ARRIVAL_STEPS := 128
## The longest frame the arrival counts (s): a hitch (the first frame after loading) skips nothing.
const ARRIVAL_LONGEST_FRAME := 1.0 / 30.0
## Between these shares of the arrival the clouds thin out.
const CLOUDS_THIN_FROM := 0.62
const CLOUDS_GONE_AT := 0.92
## Street views (street_turn): how many cells round the player tell where the street lies,
## how clear the street side must be to turn to it (0..1), and the way the view always turns
## round (-1: clockwise seen from above, "rechtsom"; 1 the other way).
const STREET_REACH := 3
const STREET_CLEAR := 0.2
const TURN_DIRECTION := -1.0
## The views straight along a street (between the iso ones) and the iso views, as turns.
const STRAIGHT_TURNS := [45.0, 135.0, 225.0, 315.0]
const ISO_TURNS := [0.0, 90.0, 180.0, 270.0]
## The player's own zoom: a press zooms ZOOM_STEP times, between ZOOM_MOST.x and .y times the
## view; it glides there at ZOOM_QUICKNESS (1/s).
const ZOOM_STEP := 1.15
const ZOOM_MOST := Vector2(0.5, 2.0)
const ZOOM_QUICKNESS := 8.0
## "Held long enough": the seconds since the last turn of a view that was never turned.
const NEVER_TURNED := 1000.0
## The view size (m) at which a crash shakes the view as hard as set, and the least and most
## it counts for.
const SHAKE_VIEW := 40.0
const SHAKE_VIEW_SHARE := Vector2(0.4, 1.5)
## The shares of a close-up over which it eases in and out.
const CLOSEUP_IN := 0.25
const CLOSEUP_OUT := 0.75


# ------------------------------------------------------------------ gliding

## One frame of a critically damped spring from `value` (moving at `velocity`) towards
## `goal`, settling in about `time` seconds: returns (new value, new velocity). Its speed
## changes smoothly, also when the goal jumps.
static func glide(value: float, goal: float, velocity: float, time: float, delta: float) -> Vector2:
	var omega := 2.0 / maxf(time, 0.01)
	var x := omega * delta
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := value - goal
	var push := (velocity + omega * change) * delta
	return Vector2(goal + (change + push) * decay, (velocity - omega * push) * decay)


## Whether the target jumped (a respawn) rather than moved from `from` to `to` in `delta` s.
static func jumped(from: Vector3, to: Vector3, delta: float) -> bool:
	return delta > 0.0 and to.distance_to(from) / delta > JUMP_SPEED


## The target's velocity smoothed over `smoothing` seconds, after a frame of `delta` s in
## which it went from `from` to `to` (`velocity`: the smoothed velocity so far).
static func smoothed_velocity(velocity: Vector3, from: Vector3, to: Vector3, smoothing: float, delta: float) -> Vector3:
	if delta <= 0.0:
		return velocity
	return velocity.lerp((to - from) / delta, 1.0 - exp(-delta / maxf(smoothing, 0.01)))


## How far ahead of the target the view looks: `lead_time` seconds at its `velocity`, at most
## `max_lead` times the view (`zoom` metres).
static func lead(velocity: Vector3, lead_time: float, zoom: float, max_lead: float) -> Vector3:
	return (velocity * lead_time).limit_length(zoom * max_lead)


## The point the view glides to: the target, the point ahead (less the closer a close-up is,
## `closeness` 0..1) and what the spring lags behind (`glide_time` times the velocity); up and
## down it follows the target itself (ramps without lag).
static func focus_goal(target_position: Vector3, velocity: Vector3, ahead: Vector3, closeness: float, glide_time: float) -> Vector3:
	var goal := target_position + ahead.lerp(Vector3.ZERO, closeness) + velocity * glide_time
	goal.y = target_position.y + velocity.y * glide_time
	return goal


## Metres in view for a target moving at `speed` (m/s over the ground): `zoom_still` standing,
## `zoom_walk` at `walk_pace`, `zoom_fast` at `fast_speed` and above.
static func zoom_for_speed(speed: float, zoom_still: float, zoom_walk: float, zoom_fast: float, walk_pace: float, fast_speed: float) -> float:
	if speed < walk_pace:
		return lerpf(zoom_still, zoom_walk, clampf(speed / walk_pace, 0.0, 1.0))
	return lerpf(zoom_walk, zoom_fast, clampf((speed - walk_pace) / maxf(fast_speed - walk_pace, 0.1), 0.0, 1.0))


## The extra metres in view while gliding over `way` (from the target to where the view
## was): `per_metre` a metre to go, at most `most`.
static func glide_over_zoom(way: Vector3, per_metre: float, most: float) -> float:
	return minf(way.length() * per_metre, most)


## What is left of the way over (`from`: where the view started, as seen from the target),
## `seconds_left` of the `switch_time` it takes: eased at both ends.
static func way_to_go(from: Vector3, seconds_left: float, switch_time: float) -> Vector3:
	return from * smoothstep(0.0, 1.0, seconds_left / maxf(switch_time, 0.01))


# ------------------------------------------------------------------ the arrival

## How far the arrival is (0..1), `clock` seconds into the `seconds` it takes.
static func arrival_progress(clock: float, seconds: float) -> float:
	return clampf(clock / maxf(seconds, 0.1), 0.0, 1.0)


## How far down (0..1, in a log scale of the heights) the view is at `progress` of the
## arrival: the sum of its speed so far, the speed slowing down towards the end and to
## ARRIVAL_CLOUD_SPEED in the clouds (the first part, high up), so you drift down through
## them, and from ARRIVAL_SETTLE_FROM on settling softly onto the player.
static func arrival_descent(progress: float) -> float:
	var done := 0.0
	var total := 0.0
	for step in ARRIVAL_STEPS:
		var at := (step + 0.5) / ARRIVAL_STEPS
		var in_clouds := 1.0 - smoothstep(0.3, 0.6, at)
		var speed := pow(1.0 - at, 0.3) * lerpf(1.0, ARRIVAL_CLOUD_SPEED, in_clouds)
		# the last part settling softly onto the player, the speed running out to nothing
		speed *= 1.0 - smoothstep(ARRIVAL_SETTLE_FROM, 1.0, at)
		total += speed
		if at < progress:
			done += speed * minf(1.0, (progress - at) * ARRIVAL_STEPS + 0.5)
	return clampf(done / total, 0.0, 1.0)


## Metres in view at `progress` of the arrival, from `arrival_zoom` high up to `zoom_still`.
static func arrival_view_size(arrival_zoom: float, zoom_still: float, progress: float) -> float:
	return exp(lerpf(log(arrival_zoom), log(zoom_still), arrival_descent(progress)))


## How much the clouds hide (1..0) at `progress` of the arrival: only at the end they thin
## out, so none are left when the view has come down.
static func cloud_cover(progress: float) -> float:
	return 1.0 - smoothstep(CLOUDS_THIN_FROM, CLOUDS_GONE_AT, progress)


## How much bigger the town has grown since the start of the arrival, the view now
## `view_size` metres: the clouds go with the zoom.
static func cloud_magnify(arrival_zoom: float, view_size: float) -> float:
	return arrival_zoom / maxf(view_size, 0.01)


# ------------------------------------------------------------------ the player's zoom and turn

## The player's zoom after `steps` presses (< 0 in, > 0 out), within ZOOM_MOST.
static func user_zoom_after(user_zoom: float, steps: int) -> float:
	return clampf(user_zoom * pow(ZOOM_STEP, steps), ZOOM_MOST.x, ZOOM_MOST.y)


## The player's zoom as it is shown, gliding from `now` to `goal` over a frame of `delta` s.
static func user_zoom_now(now: float, goal: float, delta: float) -> float:
	return lerpf(now, goal, 1.0 - exp(-delta * ZOOM_QUICKNESS))


## The turn that is the usual view again from `turn_goal` degrees: the nearest whole turn
## (never round further than half).
static func turn_back_goal(turn_goal: float) -> float:
	return roundf(turn_goal / 360.0) * 360.0


## The whole turns to take off the turn and its goal once the view has got there (`turn`
## at `turn_goal`, a whole turn or more): the same view in smaller numbers. 0 when not.
static func whole_turns_done(turn: float, turn_goal: float) -> float:
	if absf(turn - turn_goal) < 0.01 and absf(turn_goal) >= 360.0:
		return roundf(turn_goal / 360.0) * 360.0
	return 0.0


## What a key does when the player turns the view: {"turn": -1 or 1} (a quarter left or
## right), {"back": true} (to the usual view), {"zoom": -1 or 1} (in or out), {} nothing.
static func key_action(keycode: Key) -> Dictionary:
	if keycode == CameraTurning.KEY_LEFT_TURN:
		return {"turn": -1}
	if keycode == CameraTurning.KEY_RIGHT_TURN:
		return {"turn": 1}
	if keycode == CameraTurning.KEY_TURN_BACK:
		return {"back": true}
	if keycode in CameraTurning.KEYS_ZOOM_IN:
		return {"zoom": -1}
	if keycode in CameraTurning.KEYS_ZOOM_OUT:
		return {"zoom": 1}
	return {}


## The zoom steps of a mouse button: the wheel up zooms in (-1), down out (1), the rest 0.
static func wheel_zoom(button: MouseButton) -> int:
	if button == MOUSE_BUTTON_WHEEL_UP:
		return -1
	return 1 if button == MOUSE_BUTTON_WHEEL_DOWN else 0


# ------------------------------------------------------------------ turning to the street

## The way from what the camera looks at to the camera (unit), the view turned `turn` degrees
## from the usual one and looking down at `pitch` degrees.
static func towards_camera(turn: float, pitch: float) -> Vector3:
	return Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(IsoRules.ROTATION.y + turn), 0.0)).z


## Whether the street asks for another view than it did (`previous`; NAN: none yet).
static func is_other_view(wanted: float, previous: float) -> bool:
	return is_nan(previous) or absf(wrapf(wanted - previous, -180.0, 180.0)) > 1.0


## How far round (degrees, 0..360) the view `wanted` lies from `turn_goal`, going the one way
## (TURN_DIRECTION): never the short way back.
static func turn_ahead(wanted: float, turn_goal: float) -> float:
	return wrapf((wanted - turn_goal) * TURN_DIRECTION, 0.0, 360.0)


## Whether `ahead` degrees (turn_ahead) is a turn at all (not the view it has already).
static func is_a_turn(ahead: float) -> bool:
	return ahead > 1.0 and ahead < 359.0


## Seconds the player has to be hidden before the view looks down steeper: twice `turn_after`
## when it turns to the streets (the turn goes first), else `top_down_after`.
static func steep_after(turn_to_streets: bool, turn_after: float, top_down_after: float) -> float:
	return turn_after * 2.0 if turn_to_streets else top_down_after


## The view (degrees from the usual one, 0..360) the street round the player asks for.
## `built` (dx, dz -> bool) tells whether a building stands at street level that many cells
## from the player's cell: built is closed, the rest open. Buildings close on both sides of
## one axis and open along it (a narrow street): straight along it (a view between the iso
## ones), the end that comes first going round from `turn_goal`. Else the open side within
## STREET_REACH cells, weighed by nearness, if it is clear enough (STREET_CLEAR): the iso
## view whose camera stands most on that side. NAN when neither (a square, a park, a court).
static func street_turn(built: Callable, turn_goal: float) -> float:
	var east: bool = built.call(1, 0) or built.call(2, 0)
	var west: bool = built.call(-1, 0) or built.call(-2, 0)
	var south: bool = built.call(0, 1) or built.call(0, 2)
	var north: bool = built.call(0, -1) or built.call(0, -2)
	var straight := Vector2.ZERO
	if east and west and not (north or south):
		straight = Vector2(0.0, 1.0)   # a street running north-south
	elif north and south and not (east or west):
		straight = Vector2(1.0, 0.0)   # a street running east-west
	if straight != Vector2.ZERO:
		return first_turn_round(STRAIGHT_TURNS, func(from: Vector2) -> float: return absf(from.dot(straight)), turn_goal)
	var side := open_side(built)
	if side.length() < STREET_CLEAR:
		return NAN
	return first_turn_round(ISO_TURNS, func(from: Vector2) -> float: return from.dot(side.normalized()), turn_goal)


## The side the street is on (flat, x east and y south; its length says how clear, 0..1):
## the cells within STREET_REACH, built ones pushing away and open ones pulling, the near
## ones most.
static func open_side(built: Callable) -> Vector2:
	var side := Vector2.ZERO
	var total := 0.0
	for dz in range(-STREET_REACH, STREET_REACH + 1):
		for dx in range(-STREET_REACH, STREET_REACH + 1):
			var offset := Vector2(dx, dz)
			var length := offset.length()
			if length == 0.0 or length > STREET_REACH + 0.5:
				continue
			var weight := 1.0 / length
			side += offset / length * weight * (-1.0 if built.call(dx, dz) else 1.0)
			total += weight
	return side / maxf(total, 0.001)


## Of `turns`, the one whose camera side (`score` of the flat way from the player to the camera)
## is best; of equally good ones the first going round (TURN_DIRECTION) from `turn_goal`.
static func first_turn_round(turns: Array, score: Callable, turn_goal: float) -> float:
	var best := NAN
	var best_score := -INF
	var best_ahead := INF
	for turn: float in turns:
		var to_camera := towards_camera(turn, IsoRules.ROTATION.x)
		var value: float = score.call(Vector2(to_camera.x, to_camera.z).normalized())
		var ahead := turn_ahead(turn, turn_goal)
		if value > best_score + 0.01 or (absf(value - best_score) <= 0.01 and ahead < best_ahead):
			best = turn
			best_score = value
			best_ahead = ahead
	return best


# ------------------------------------------------------------------ what hides the player

## The points round the target that have to stay in sight: at each of `heights` (metres over
## the feet) the middle and `reach` metres to either side across the view (`to_camera`).
static func sight_points(target_position: Vector3, to_camera: Vector3, heights: PackedFloat32Array, reach: float) -> Array[Vector3]:
	var across := Vector3.UP.cross(to_camera).normalized()
	var points: Array[Vector3] = []
	for height in heights:
		for side: float in [-1.0, 0.0, 1.0]:
			points.append(target_position + Vector3.UP * height + across * side * reach)
	return points


## How many of `points` are hidden from a camera `distance` metres away along `to_camera`:
## each line of sight is walked in 1 m steps up to the camera, and `hides` (a point -> bool)
## tells whether something stands there that hides the target.
static func hidden_points(points: Array[Vector3], to_camera: Vector3, distance: float, hides: Callable) -> int:
	var hidden := 0
	for start in points:
		for step in range(1, int(distance)):
			if hides.call(start + to_camera * float(step)):
				hidden += 1
				break
	return hidden


## Whether something with its middle at `middle` stands on the camera's side of the target
## (flat): the target never hides behind a building at its back.
static func on_camera_side(middle: Vector3, target_position: Vector3, to_camera: Vector3) -> bool:
	return Vector2(middle.x - target_position.x, middle.z - target_position.z).dot(Vector2(to_camera.x, to_camera.z)) > 0.0


# ------------------------------------------------------------------ close-up and shake

## How close in the view is (0 = the normal iso view, 1 = the closest) at `progress` (0..1)
## of a close-up, easing in and out.
static func closeness(progress: float) -> float:
	return smoothstep(0.0, CLOSEUP_IN, progress) * (1.0 - smoothstep(CLOSEUP_OUT, 1.0, progress))


## Degrees the view is swung round the target at `progress` of a close-up: from half `orbit`
## on one side to half on the other (`side` 1 or -1), as far as it is close in (`close`).
static func closeup_swing(orbit: float, progress: float, side: float, close: float) -> float:
	return orbit * (progress - 0.5) * side * close


## Whether a crash that happened `age` seconds ago still shakes the view (`shake_time` s).
static func is_shaking(age: float, shake_time: float) -> bool:
	return age >= 0.0 and age <= shake_time


## Metres the view shakes for a crash of `strength` (0..1) that happened `age` seconds ago
## (is_shaking), `crash_shake` metres at the hardest, dying down over `shake_time`; less
## zoomed in, more zoomed out (`view_size`).
static func shake_amount(crash_shake: float, strength: float, age: float, shake_time: float, view_size: float) -> float:
	var fade := 1.0 - age / shake_time
	return crash_shake * strength * fade * fade * clampf(view_size / SHAKE_VIEW, SHAKE_VIEW_SHARE.x, SHAKE_VIEW_SHARE.y)
