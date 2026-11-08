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

const Iso = preload("res://scripts/camera/iso_camera.gd")
const TunnelLights = preload("res://scripts/world/tunnel_lights.gd")
## Layer of the ground layer that tunnel tiles are placed on.
const TUNNEL_LEVEL := -6
## Above this speed (m/s) between two frames the vehicle did not drive but jumped.
const JUMP_SPEED := 80.0

## Follow at startup.
@export var active := true
## What the camera follows (the player).
@export var target: NodePath = ^"../Speler"
## Metres in view when the target stands still.
@export var zoom_still := 18.0
## Metres in view at `fast_speed` and above.
@export var zoom_fast := 24.0
## Speed (m/s) at which the view is zoomed out furthest (running).
@export var fast_speed := 7.0
## Seconds the view looks ahead of the target (times its average velocity), at most
## `max_lead` times the view size: the target should stay near the middle of the view.
@export var lead_time := 0.8
@export var max_lead := 0.12
## Seconds over which the vehicle's velocity is smoothed (for the point ahead and the zoom).
@export var velocity_smoothing := 0.6
## Seconds the view takes to catch up (about); the zoom takes `zoom_glide_time`.
@export var glide_time := 0.6
@export var zoom_glide_time := 2.0
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

## The followed node (for scripts/world/building_fade.gd and the HUD).
var target_node: Node3D:
	get:
		return _followed


func _ready() -> void:
	_cam = get_viewport().get_camera_3d()
	_followed = get_node_or_null(target) as Node3D
	if _cam == null or _followed == null:
		set_process(false)
		return
	_ground = get_node_or_null(ground_path) as GridMap
	_focus = _followed.global_position
	_zoom = zoom_still
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


## True while the camera follows its target.
func is_following() -> bool:
	return _following


func _process(delta: float) -> void:
	var target_position := _target_position()
	if delta > 0.0 and target_position.distance_to(_target_last) / delta > JUMP_SPEED:
		_glide_over(target_position)
	var closeness := _advance_closeup(delta) * (1.0 - _underground)   # 0 = iso view .. 1 = closest
	if delta > 0.0:
		var frame_velocity := (target_position - _target_last) / delta
		_target_velocity = _target_velocity.lerp(frame_velocity, 1.0 - exp(-delta / maxf(velocity_smoothing, 0.01)))
	_target_last = target_position
	# the point ahead; close by it only makes up for the spring's lag (the target in the middle)
	var lead := (_target_velocity * lead_time).limit_length(_zoom * max_lead)
	var goal := target_position + lead.lerp(Vector3.ZERO, closeness) + _target_velocity * glide_time
	goal.y = target_position.y + _target_velocity.y * glide_time   # up and down ramps without lag
	var speed := Vector2(_target_velocity.x, _target_velocity.z).length()
	var goal_zoom := lerpf(zoom_still, zoom_fast, clampf(speed / fast_speed, 0.0, 1.0))
	_glide_over_left = maxf(_glide_over_left - delta, 0.0)
	if _glide_over_left > 0.0:
		goal_zoom += _glide_over_zoom
	for axis in 3:
		var glided := _glide(_focus[axis], goal[axis], _focus_velocity[axis], glide_time, delta)
		_focus[axis] = glided.x
		_focus_velocity[axis] = glided.y
	var zoomed := _glide(_zoom, goal_zoom, _zoom_velocity, zoom_glide_time, delta)
	_zoom = zoomed.x
	_zoom_velocity = zoomed.y
	var view_size := lerpf(_zoom, closeup_zoom, closeness)
	var way_to_go := _glide_over_from * smoothstep(0.0, 1.0, _glide_over_left / maxf(switch_time, 0.01))
	_view_focus = _focus + way_to_go
	Iso.place(_cam, _view_focus, view_size)
	if closeness > 0.0:
		# lower and swung round the vehicle, at the same distance
		var progress := _closeup_clock / closeup_time
		var swing := closeup_orbit * (progress - 0.5) * _closeup_side * closeness
		_cam.rotation_degrees = Vector3(lerpf(Iso.ROTATION.x, closeup_pitch, closeness), Iso.ROTATION.y + swing, 0.0)
		_cam.global_position = _view_focus + _cam.global_basis.z * Iso.distance(view_size)
	_place_in_tunnel(target_position, way_to_go, delta)
	_shake_for_crash(view_size)


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
