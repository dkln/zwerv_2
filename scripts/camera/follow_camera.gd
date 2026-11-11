extends Node
## Iso camera that follows the player (the "Volgcamera" node of scenes/stad.tscn, following
## the node Speler, scripts/player/player_controller.gd; any node with a position works): it
## keeps the target in view, a little ahead of it in the direction it moves and at the height
## it is at (down into the tunnel trough), and zooms with its speed: close in when it stands
## still, a little further out the faster it goes. The camera is the game's only view: it
## takes over at the start and is never handed back (no free camera, no keys).
## It does not chase the target itself (every bump, corner and stop would show in the
## view): it follows a point ahead of it, where the target will be in `lead_time`
## seconds at its velocity smoothed over `velocity_smoothing` seconds, on a critically
## damped spring (`glide_time`). That point moves on continuously, so at a steady speed
## the view moves at that same steady speed (no surges), and when the target speeds up
## or stops the view follows gradually. The spring lags `glide_time` times the speed
## behind a moving point, so the point lies that much further ahead.
## Optionally (`closeups`, off by default) it moves in for a close-up now and then: it zooms
## in, drops a little lower and swings round the target, then glides back (`closeup_*`).
## Under the ground the iso view would only show the roof of the tunnel. So when the target
## is about to go into a covered tunnel tile (on layer -6 of the ground layer), the camera
## comes down into the open trough behind it and follows it as a chase camera; once out
## in the open again it glides back up (`tunnel_*`). A target that jumps (a respawn) gets a
## glide over (`switch_time`).
## When buildings stand between the player and the camera, the view turns round the player
## in whole steps of `turn_step` degrees (a quarter turn by default, so it stays isometric;
## at most `turn_most` either way) to where they no longer hide it,
## gliding there over `turn_glide_time` s; once the usual view is free again for
## `turn_back_after` s it turns back (`view_yaw` is the turned view, for the walking keys).

const CloudShroud = preload("res://scripts/effects/cloud_shroud.gd")
const LoadingScreenScript = preload("res://scripts/ui/loading_screen.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")
const TunnelLights = preload("res://scripts/world/tunnel_lights.gd")
## Layer of the ground layer that tunnel tiles are placed on.
const TUNNEL_LEVEL := -6
## Above this speed (m/s) between two frames the vehicle did not drive but jumped.
const JUMP_SPEED := 80.0
## The arrival: its speed in the clouds (share of the speed outside them), and the steps of
## its sum (_arrival_descent).
const ARRIVAL_CLOUD_SPEED := 0.35
## From this share of the arrival on its speed runs out softly.
const ARRIVAL_SETTLE_FROM := 0.7
const ARRIVAL_STEPS := 128

## Follow at startup.
@export var active := true
## What the camera follows (the player).
@export var target: NodePath = ^"../Speler"
## Metres in view when the target stands still (closer, so the figure shows well).
@export var zoom_still := 18.0
## Metres in view at `walk_pace` (walking), and the speed (m/s) that is.
@export var zoom_walk := 38.0
@export var walk_pace := 3.0
## Metres in view at `fast_speed` and above.
@export var zoom_fast := 44.0
## Speed (m/s) at which the view is zoomed out furthest (running).
@export var fast_speed := 7.0
## Seconds the view looks ahead of the target (times its average velocity), at most
## `max_lead` times the view size: the target should stay near the middle of the view.
@export var lead_time := 0.8
@export var max_lead := 0.12
## Seconds over which the vehicle's velocity is smoothed (for the point ahead and the zoom).
@export var velocity_smoothing := 0.6
## Seconds the view takes to catch up (about); the zoom takes `zoom_glide_time` going out
## (starting to walk) and `zoom_in_glide_time` coming back in (standing still again: quicker,
## so the figure is soon close again).
@export var glide_time := 0.6
@export var zoom_glide_time := 3.5
@export var zoom_in_glide_time := 0.8
@export_group("Gliding over")
## Seconds the view takes to glide over to the target after it jumped.
@export var switch_time := 2.0
## Metres of extra view per metre to go, at most `switch_zoom_out_most`: on a long way
## over you still see where you are going.
@export var switch_zoom_out := 0.5
@export var switch_zoom_out_most := 150.0
@export_group("Tunnels")
## The ground layer, whose tiles tell where a tunnel is covered.
@export var ground_path: NodePath = ^"../Grond"
## Below this height (metres) the vehicle can be in a tunnel.
@export var tunnel_below_height := -0.5
## Seconds ahead of the vehicle that are checked for cover: the camera should be down
## behind the vehicle before it reaches the portal.
@export var tunnel_anticipation := 2.5
## Seconds the glide into the tunnel and back up takes (about).
@export var tunnel_glide_time := 0.9
## Metres behind the vehicle and above it (the tunnel has 4.75 m of headroom).
@export var tunnel_chase_distance := 9.0
@export var tunnel_chase_height := 3.0
## Metres ahead of the vehicle and above it that the camera looks at.
@export var tunnel_look_ahead := 8.0
@export var tunnel_look_height := 0.6
## Field of view of the chase camera (degrees) and its near plane (metres).
@export var tunnel_fov := 62.0
@export var tunnel_near := 0.2
@export_group("Turning round buildings")
## Turn away from buildings that hide the player (see the top).
@export var turn_round_buildings := true
## The Gebouwen GridMap whose cells hide the player.
@export var buildings_path: NodePath = ^"../Gebouwen"
## The view only turns in whole steps of `turn_step` degrees from the usual one (and glides
## from one step to the next, never stopping in between), at most `turn_most` either way.
## 90 keeps the isometric look: the usual view looks diagonally across the grid (yaw 135),
## so does every quarter turn from it (45, 225, 315), only from another corner; 45 would
## also allow views straight along the streets, which look flat (not isometric).
@export var turn_most := 180.0
@export_range(15.0, 180.0, 15.0) var turn_step := 90.0
## Seconds the turn takes (about), and how long the usual view has to be free before it turns back.
@export var turn_glide_time := 2.8
@export var turn_back_after := 1.5
## Seconds between two looks round.
@export var turn_check_interval := 0.2
## Heights (metres over the feet) of the points that have to stay in sight, and the
## metres beside the figure (across the view) that count too.
@export var turn_test_heights := PackedFloat32Array([0.4, 1.0, 1.7])
@export var turn_test_reach := 0.4
@export_group("Close-ups")
@export var closeups := false
## Seconds between close-ups (a random time between the two).
@export var closeup_every := Vector2(20.0, 35.0)
## Seconds a close-up lasts, gliding in and out included.
@export var closeup_time := 7.0
## Metres in view at the closest.
@export var closeup_zoom := 7.0
## Degrees the view swings round the vehicle during a close-up (from half this on one
## side to half on the other).
@export var closeup_orbit := 70.0
## Downward angle of the view at the closest (degrees; the iso view looks 35 down).
@export var closeup_pitch := -24.0
## Shake of the view at a crash in view (Vehicle.last_crash): metres at the hardest crash,
## and seconds it dies down over.
@export var crash_shake := 0.6
@export var crash_shake_time := 0.7
@export_group("Dramatic")
## A dramatic moment (the player run over and killed, PlayerController): the view zooms in
## on what it follows to `dramatic_zoom` metres in view, settling in `dramatic_glide` seconds,
## in real time also while the game runs slowed down (Engine.time_scale).
## A conversation (PlayerController.talk_to, talk_close_up): the view glides slowly in on the
## middle between the player and who it talks to, `talk_zoom` metres in view, in about
## `talk_glide` seconds (also while the game stands still for the story box), and back after.
## Inside a building (set_indoors): metres in view, the same standing or walking (the room
## is small), and how long the view takes to get there. A big interior (Den Haag Centraal)
## passes its own metres in view to set_indoors.
@export var indoor_zoom := 9.0
@export var talk_zoom := 7.0
@export var talk_glide := 2.6
@export var dramatic_zoom := 6.0
@export var dramatic_glide := 0.45
@export_group("Arrival")
## At the start of the game (once the loading screen has gone and the town is merged) the
## view comes down from high in the sky onto the player: from `arrival_zoom` metres in view
## to zoom_still in `arrival_seconds`, through a layer of clouds (scripts/effects/cloud_shroud.gd)
## about halfway down.
@export var arrival := true
@export var arrival_zoom := 300.0
@export var arrival_seconds := 5.5

var _cam: Camera3D
var _followed: Node3D
var _focus := Vector3.ZERO
var _zoom := 40.0
var _following := false
var _focus_velocity := Vector3.ZERO
var _zoom_velocity := 0.0
var _target_velocity := Vector3.ZERO    # the vehicle's velocity, smoothed (velocity_smoothing)
var _target_last := Vector3.ZERO        # where it was drawn last frame
var _closeup_wait := 0.0             # seconds until the next close-up
var _closeup_clock := -1.0           # seconds into the current close-up (< 0: none)
var _closeup_side := 1.0             # which way it swings round
var _random := RandomNumberGenerator.new()
var _ground: GridMap
var _underground := 0.0              # 0 = the iso view .. 1 = the chase camera in the tunnel
var _underground_velocity := 0.0
var _chase_heading := Vector3.FORWARD  # last driving direction of the vehicle, for the chase camera
var _covered_items := {}             # ground item -> is it a covered tunnel tile
var _view_focus := Vector3.ZERO      # the point the view was placed around last frame
var _glide_over_left := 0.0          # seconds left of gliding over to the vehicle
var _glide_over_from := Vector3.ZERO # where the view started, as seen from the vehicle
var _glide_over_zoom := 0.0          # extra metres in view while gliding over
var _dramatic := false               # zoomed in on a dramatic moment (dramatic_close_up)
var _talk_partner: Node3D            # who the player talks to (talk_close_up), else null
var _turn_round_buildings_default := true   # turn_round_buildings as set, outside
var _indoors := false
var _indoor_zoom_now := 9.0          # metres in view inside the interior you are in
var _arrival_clock := -1.0           # seconds into the arrival (< 0: waiting for the town)
var _arriving := false               # the arrival is still to come or going on
var _clouds: Node                    # the cloud layer of the arrival
var _buildings: GridMap
var _turn := 0.0                     # degrees the view is turned from Iso.ROTATION.y now
var _turn_velocity := 0.0
var _turn_goal := 0.0                # degrees it turns to
var _turn_check_clock := 0.0
var _usual_free_for := 0.0           # seconds the usual view (no turn) has been free

## The followed node (for scripts/world/building_fade.gd and the HUD).
var target_node: Node3D:
	get:
		return _followed


func _ready() -> void:
	_turn_round_buildings_default = turn_round_buildings
	_cam = get_viewport().get_camera_3d()
	_followed = get_node_or_null(target) as Node3D
	if _cam == null or _followed == null:
		set_process(false)
		return
	_ground = get_node_or_null(ground_path) as GridMap
	_buildings = get_node_or_null(buildings_path) as GridMap
	_focus = _followed.global_position
	_zoom = zoom_still
	if arrival and active:
		_arriving = true
		_zoom = arrival_zoom
		_clouds = CloudShroud.new()
		add_child(_clouds)
	if active:
		start.call_deferred()
	else:
		set_process(false)


## Takes over the camera (the free camera's own moving and input stay off) and follows.
func start() -> void:
	_following = true
	set_process(true)
	_cam.set_process(false)
	_cam.set_process_unhandled_input(false)
	_focus = _target_position()
	_focus_velocity = Vector3.ZERO
	_zoom_velocity = 0.0
	_closeup_clock = -1.0
	_closeup_wait = _random.randf_range(closeup_every.x, closeup_every.y)
	_target_last = _focus
	_target_velocity = Vector3.ZERO
	_underground = 0.0
	_underground_velocity = 0.0
	_view_focus = _focus
	_glide_over_left = 0.0


## The view leaves from where it is now and glides to the vehicle, at `target_position`. The
## spring starts at the vehicle again, so what it does stays apart from the glide.
func _glide_over(target_position: Vector3) -> void:
	_glide_over_from = _view_focus - target_position
	_glide_over_left = switch_time
	_glide_over_zoom = minf(_glide_over_from.length() * switch_zoom_out, switch_zoom_out_most)
	_focus = target_position
	_focus_velocity = Vector3.ZERO
	_target_velocity = Vector3.ZERO
	_target_last = target_position


## Zooms in close on what it follows (on) or back to the usual view (off), in real time.
func dramatic_close_up(on: bool) -> void:
	_dramatic = on
	if on:
		_end_arrival()


## Stops the arrival where it is (a dramatic moment goes first) and takes the clouds away.
func _end_arrival() -> void:
	_arriving = false
	if _clouds:
		_clouds.queue_free()
		_clouds = null


## Zooms in slowly on the player and `partner` (a conversation), or back (null). Runs on
## while the game stands still (the story box pauses it) until the view is back.
func talk_close_up(partner: Node3D) -> void:
	_talk_partner = partner
	process_mode = Node.PROCESS_MODE_ALWAYS if partner else Node.PROCESS_MODE_INHERIT


## Inside a building (Interiors): no turning round buildings (there are none to hide the
## player; the walls of an interior are low at the camera's side), the view as it was.
## `zoom_in_view`: metres in view inside this interior (0: indoor_zoom).
func set_indoors(indoors: bool, zoom_in_view := 0.0) -> void:
	_indoors = indoors
	_indoor_zoom_now = zoom_in_view if zoom_in_view > 0.0 else indoor_zoom
	turn_round_buildings = not indoors and _turn_round_buildings_default
	# straight to the zoom of inside or outside (under the swipe)
	_zoom = _indoor_zoom_now if indoors else zoom_still
	_zoom_velocity = 0.0
	_turn_goal = 0.0
	_turn = 0.0
	_turn_velocity = 0.0


## The view on its target at once, without gliding over (after the target was put elsewhere).
func snap_to_target() -> void:
	if _followed == null:
		return
	var target := _target_position()
	_focus = target
	_focus_velocity = Vector3.ZERO
	_target_velocity = Vector3.ZERO
	_target_last = target
	_glide_over_left = 0.0
	_glide_over_from = Vector3.ZERO
	_view_focus = target


func is_dramatic() -> bool:
	return _dramatic


## True while the view still comes down from the sky at the start (for the tests).
func is_arriving() -> bool:
	return _arriving


## How far the arrival is (0 .. 1; 1 when there is none, or it is over).
func arrival_progress() -> float:
	if not _arriving:
		return 1.0
	if _arrival_clock < 0.0:
		return 0.0
	return clampf(_arrival_clock / maxf(arrival_seconds, 0.1), 0.0, 1.0)


## The arrival: how much it is still zoomed out, waiting while the town loads, then down
## through the clouds. Returns the view size it wants now (or -1 when it is over).
func _advance_arrival(delta: float) -> float:
	if not _arriving:
		return -1.0
	if _arrival_clock < 0.0:
		var level_of_detail := get_node_or_null(^"../DetailNiveau")
		var merging: bool = level_of_detail != null and level_of_detail.has_method("is_merging") and level_of_detail.is_merging()
		if LoadingScreenScript.showing(get_tree()) or merging:
			_set_clouds(0.0, arrival_zoom)   # (under the loading screen: as it will start)
			return arrival_zoom
		_arrival_clock = 0.0
	_arrival_clock += minf(delta, 1.0 / 30.0)   # a hitch (the first frame after loading) skips nothing
	var progress := clampf(_arrival_clock / maxf(arrival_seconds, 0.1), 0.0, 1.0)
	var view_size := exp(lerpf(log(arrival_zoom), log(zoom_still), _arrival_descent(progress)))
	_set_clouds(progress, view_size)
	if progress >= 1.0:
		_end_arrival()
		return -1.0
	return view_size


## How far down (0..1, in a log scale of the heights) the view is at `progress` of the
## arrival: the sum of its speed so far, the speed slowing down towards the end and to
## ARRIVAL_CLOUD_SPEED in the clouds (the first part, high up), so you drift down through
## them, and from ARRIVAL_SETTLE_FROM on settling softly onto the player.
static func _arrival_descent(progress: float) -> float:
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


## The clouds at `progress` of the arrival, the view `view_size` metres: they go with the
## zoom (`magnify`: as much bigger as the town has grown since the start), so zooming in
## pushes them aside from the middle outwards (cloud_shroud.gdshader); only at the end they
## thin out too (`cover`), so none are left when the view has come down.
func _set_clouds(progress: float, view_size: float) -> void:
	if _clouds == null:
		return
	_clouds.cover = 1.0 - smoothstep(0.62, 0.92, progress)
	_clouds.dive = progress
	_clouds.magnify = arrival_zoom / maxf(view_size, 0.01)


## True while the camera follows its target.
func is_following() -> bool:
	return _following


func _process(delta: float) -> void:
	if _dramatic:
		# in real time, also when the game is slowed down
		delta /= maxf(Engine.time_scale, 0.01)
	var target_position := _target_position()
	if delta > 0.0 and target_position.distance_to(_target_last) / delta > JUMP_SPEED:
		_glide_over(target_position)
	var closeness := _advance_closeup(delta) * (1.0 - _underground)   # 0 = iso view .. 1 = closest
	if delta > 0.0:
		var frame_velocity := (target_position - _target_last) / delta
		_target_velocity = _target_velocity.lerp(frame_velocity, 1.0 - exp(-delta / maxf(velocity_smoothing, 0.01)))
	_target_last = target_position
	# the point ahead; close by it only makes up for the spring's lag (the target in the middle)
	var lead := (_target_velocity * lead_time).limit_length(_zoom * max_lead) if not _dramatic else Vector3.ZERO
	var goal := target_position + lead.lerp(Vector3.ZERO, closeness) + _target_velocity * glide_time
	goal.y = target_position.y + _target_velocity.y * glide_time   # up and down ramps without lag
	var speed := Vector2(_target_velocity.x, _target_velocity.z).length()
	var goal_zoom := lerpf(zoom_still, zoom_walk, clampf(speed / walk_pace, 0.0, 1.0)) if speed < walk_pace \
		else lerpf(zoom_walk, zoom_fast, clampf((speed - walk_pace) / maxf(fast_speed - walk_pace, 0.1), 0.0, 1.0))
	_glide_over_left = maxf(_glide_over_left - delta, 0.0)
	if _glide_over_left > 0.0:
		goal_zoom += _glide_over_zoom
	if _dramatic:
		goal_zoom = dramatic_zoom
		goal = target_position
	if _indoors and not _dramatic:
		goal_zoom = _indoor_zoom_now
	var talking := _talk_partner != null and is_instance_valid(_talk_partner) and not _dramatic
	if talking:
		goal_zoom = talk_zoom
		goal = (target_position + _talk_partner.global_position) * 0.5
	var focus_time := dramatic_glide if _dramatic else (talk_glide if talking else glide_time)
	for axis in 3:
		var glided := _glide(_focus[axis], goal[axis], _focus_velocity[axis], focus_time, delta)
		_focus[axis] = glided.x
		_focus_velocity[axis] = glided.y
	var zoom_time := zoom_in_glide_time if goal_zoom < _zoom else zoom_glide_time
	var zoomed := _glide(_zoom, goal_zoom, _zoom_velocity, dramatic_glide if _dramatic else (talk_glide if talking else zoom_time), delta)
	_zoom = zoomed.x
	_zoom_velocity = zoomed.y
	var arrival_size := _advance_arrival(delta)
	if arrival_size > 0.0:
		_zoom = arrival_size
		_zoom_velocity = 0.0
		_focus = target_position
		_focus_velocity = Vector3.ZERO
		_glide_over_left = 0.0
	var view_size := lerpf(_zoom, closeup_zoom, closeness)
	var way_to_go := _glide_over_from * smoothstep(0.0, 1.0, _glide_over_left / maxf(switch_time, 0.01))
	_view_focus = _focus + way_to_go
	_advance_turn(target_position, view_size, delta)
	Iso.place(_cam, _view_focus, view_size, view_yaw())
	if closeness > 0.0:
		# lower and swung round the vehicle, at the same distance
		var progress := _closeup_clock / closeup_time
		var swing := closeup_orbit * (progress - 0.5) * _closeup_side * closeness
		_cam.rotation_degrees = Vector3(lerpf(Iso.ROTATION.x, closeup_pitch, closeness), view_yaw() + swing, 0.0)
		_cam.global_position = _view_focus + _cam.global_basis.z * Iso.distance(view_size)
	_place_in_tunnel(target_position, way_to_go, delta)
	_shake_for_crash(view_size)


## The yaw of the view (degrees round the vertical): Iso.ROTATION.y, turned round buildings.
func view_yaw() -> float:
	return Iso.ROTATION.y + _turn


## Looks every turn_check_interval s whether buildings hide the player from the view turned
## to its goal; if so, picks the nearest turn (within turn_most) from which they hide it least.
## Back to the usual view once that has been free for turn_back_after s. Then glides there.
func _advance_turn(target_position: Vector3, view_size: float, delta: float) -> void:
	var may_turn := turn_round_buildings and _buildings != null and not _arriving and not _dramatic \
			and _underground < 0.001 and _glide_over_left <= 0.0
	if not may_turn:
		_turn_goal = _turn_goal if _dramatic else 0.0
	else:
		_turn_check_clock -= delta
		if _turn_check_clock <= 0.0:
			_turn_check_clock = turn_check_interval
			_choose_turn(target_position, view_size)
	var glided := _glide(_turn, _turn_goal, _turn_velocity, turn_glide_time, delta)
	_turn = glided.x
	_turn_velocity = glided.y


func _choose_turn(target_position: Vector3, view_size: float) -> void:
	var distance := Iso.distance(view_size)
	var usual_hidden := _hidden_points(target_position, 0.0, distance)
	_usual_free_for = _usual_free_for + turn_check_interval if usual_hidden == 0 else 0.0
	if _turn_goal != 0.0 and _usual_free_for >= turn_back_after:
		_turn_goal = 0.0
		return
	var goal_hidden := usual_hidden if _turn_goal == 0.0 else _hidden_points(target_position, _turn_goal, distance)
	if goal_hidden == 0:
		return
	# the nearest turn (from the usual view, then from where it is) that hides the least
	var best_turn := _turn_goal
	var best_hidden := goal_hidden
	var steps := int(turn_most / maxf(turn_step, 1.0))
	for step in range(1, steps + 1):
		for side: float in [1.0, -1.0]:
			var turn := side * step * turn_step
			# half round is the same view either way: looked at once
			if side < 0.0 and is_equal_approx(step * turn_step, 180.0):
				continue
			var hidden := _hidden_points(target_position, turn, distance)
			if hidden < best_hidden or (hidden == best_hidden and hidden < goal_hidden
					and absf(turn - _turn) < absf(best_turn - _turn)):
				best_turn = turn
				best_hidden = hidden
		if best_hidden == 0:
			break
	_turn_goal = best_turn


## How many of the test points round the target (turn_test_heights, and turn_test_reach to
## either side across the view) a Gebouwen cell hides from a camera turned `turn` degrees.
## Walks each line of sight in 1 m steps (cells are 4 m) up to the camera; only cells on the
## camera's side of the target count (it never hides behind a building at its back).
func _hidden_points(target_position: Vector3, turn: float, distance: float) -> int:
	var towards_camera := Iso.direction(Iso.ROTATION.y + turn)
	var across := Vector3.UP.cross(towards_camera).normalized()
	var flat_towards := Vector2(towards_camera.x, towards_camera.z)
	var to_map := _buildings.global_transform.affine_inverse()
	var hidden := 0
	for height in turn_test_heights:
		for side: float in [-1.0, 0.0, 1.0]:
			var start := target_position + Vector3.UP * height + across * side * turn_test_reach
			for step in range(1, int(distance)):
				var point := start + towards_camera * float(step)
				var cell := _buildings.local_to_map(to_map * point)
				if _buildings.get_cell_item(cell) == GridMap.INVALID_CELL_ITEM:
					continue
				var middle := _buildings.to_global(_buildings.map_to_local(cell))
				if Vector2(middle.x - target_position.x, middle.z - target_position.z).dot(flat_towards) > 0.0:
					hidden += 1
					break
	return hidden


## Shakes the view for a crash that just happened within it (harder the harder the crash,
## dying down over crash_shake_time).
func _shake_for_crash(view_size: float) -> void:
	var age: float = Time.get_ticks_msec() / 1000.0 - Vehicle.last_crash["time"]
	if age < 0.0 or age > crash_shake_time:
		return
	var crash_at: Vector3 = Vehicle.last_crash["at"]
	if crash_at.distance_to(_view_focus) > view_size:
		return
	var fade := 1.0 - age / crash_shake_time
	var amount: float = crash_shake * Vehicle.last_crash["strength"] * fade * fade * clampf(view_size / 40.0, 0.4, 1.5)
	_cam.global_position += (_cam.global_basis.x * _random.randf_range(-1.0, 1.0)
			+ _cam.global_basis.y * _random.randf_range(-1.0, 1.0)) * amount


## Blends the camera, just placed for the normal view, towards the chase camera as far
## as the vehicle is under the ground. While gliding over to a vehicle it leaves the tunnel
## (it may have to go down again at the other end), still looking the way it did.
func _place_in_tunnel(target_position: Vector3, way_to_go: Vector3, delta: float) -> void:
	var flat_velocity := Vector3(_target_velocity.x, 0.0, _target_velocity.z)
	var gliding_over := _glide_over_left > 0.0
	if flat_velocity.length() > 1.0 and not gliding_over:
		_chase_heading = flat_velocity.normalized()
	var goal := 1.0 if not gliding_over and _wants_chase_view(target_position, flat_velocity) else 0.0
	var glided := _glide(_underground, goal, _underground_velocity, tunnel_glide_time, delta)
	_underground = clampf(glided.x, 0.0, 1.0)
	_underground_velocity = glided.y
	if _underground < 0.001:
		return
	var blend := smoothstep(0.0, 1.0, _underground)
	var chased := target_position + way_to_go
	var chase := Transform3D.IDENTITY.translated(
		chased - _chase_heading * tunnel_chase_distance + Vector3.UP * tunnel_chase_height)
	chase = chase.looking_at(chased + _chase_heading * tunnel_look_ahead + Vector3.UP * tunnel_look_height, Vector3.UP)
	_cam.global_position = _cam.global_position.lerp(chase.origin, blend)
	_cam.global_basis = _cam.global_basis.slerp(chase.basis, blend).orthonormalized()
	_cam.fov = lerpf(_cam.fov, tunnel_fov, blend)
	_cam.near = lerpf(_cam.near, tunnel_near, blend)


## True while the chase camera is wanted: the vehicle is low and it, the point it reaches
## soon or the spot of the chase camera behind it lies under cover.
func _wants_chase_view(target_position: Vector3, flat_velocity: Vector3) -> bool:
	if target_position.y >= tunnel_below_height:
		return false
	return _is_covered(target_position) or _is_covered(target_position + flat_velocity * tunnel_anticipation) \
		or _is_covered(target_position - _chase_heading * tunnel_chase_distance)


## True if a covered tunnel tile (not an open trough or a ramp) lies at this spot.
func _is_covered(point: Vector3) -> bool:
	if _ground == null:
		return false
	var cell := _ground.local_to_map(_ground.to_local(point))
	var item := _ground.get_cell_item(Vector3i(cell.x, TUNNEL_LEVEL, cell.z))
	if item == GridMap.INVALID_CELL_ITEM:
		return false
	if not _covered_items.has(item):
		_covered_items[item] = TunnelLights.is_covered_tile(_ground.mesh_library.get_item_name(item))
	return _covered_items[item]


## Runs the close-up clock; returns how close in the view is now (0 = the normal iso
## view, 1 = the closest), easing in and out.
func _advance_closeup(delta: float) -> float:
	if not closeups:
		return 0.0
	if _closeup_clock < 0.0:
		_closeup_wait -= delta
		if _closeup_wait > 0.0:
			return 0.0
		_closeup_clock = 0.0
		_closeup_side = 1.0 if _random.randf() < 0.5 else -1.0
	_closeup_clock += delta
	var progress := _closeup_clock / closeup_time
	if progress >= 1.0:
		_closeup_clock = -1.0
		_closeup_wait = _random.randf_range(closeup_every.x, closeup_every.y)
		return 0.0
	return smoothstep(0.0, 0.25, progress) * (1.0 - smoothstep(0.75, 1.0, progress))


## Where the vehicle is drawn this frame (between physics steps, see vehicle.gd).
func _target_position() -> Vector3:
	return _followed.call("drawn_position") if _followed.has_method("drawn_position") else _followed.global_position


## One frame of a critically damped spring from `value` (moving at `velocity`) towards
## `goal`, settling in about `time` seconds: returns (new value, new velocity). Its speed
## changes smoothly, also when the goal jumps.
static func _glide(value: float, goal: float, velocity: float, time: float, delta: float) -> Vector2:
	var omega := 2.0 / maxf(time, 0.01)
	var x := omega * delta
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := value - goal
	var push := (velocity + omega * change) * delta
	return Vector2(goal + (change + push) * decay, (velocity - omega * push) * decay)
