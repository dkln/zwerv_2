extends Node
## Iso camera that follows a vehicle (the "Volgcamera" node of scenes/stad.tscn, following
## the car): it keeps the vehicle in view, a little ahead of it in its driving direction
## and at the height it drives at (down into the tunnel trough), and zooms with its
## speed: close in when it stands still, further out the faster it goes.
## It does not chase the vehicle itself (every bump, corner and stop would show in the
## view): it follows a point ahead of it, where the vehicle will be in `lead_time`
## seconds at its velocity smoothed over `velocity_smoothing` seconds, on a critically
## damped spring (`glide_time`). That point moves on continuously, so at a steady speed
## the view moves at that same steady speed (no surges), and when the vehicle speeds up
## or brakes the view follows gradually. The spring lags `glide_time` times the speed
## behind a moving point, so the point lies that much further ahead.
## Now and then (every `closeup_every` seconds) it moves in for a close-up: it zooms in
## on the vehicle, drops a little lower and swings round it, then glides back to the
## iso view (`closeup_*`, off with `closeups`).
## Under the ground the iso view would only show the roof of the tunnel. So when the vehicle
## is about to drive into a covered tunnel tile (on layer -6 of the ground layer), the camera
## comes down into the open trough behind it and follows it through the tunnel as a chase
## camera; once the vehicle and the camera are out in the open again it glides back up
## (`tunnel_*`). F follows the car
## (also during the flight over the map, which it then ends); B, while following, sends
## another vehicle the wrong way into the followed one (the demo crash, Vehicle.drive_into);
## T, while following, runs the game `fast_forward` times as fast (and back), to see more
## of the town and the traffic without waiting;
## any other key or mouse click hands the camera to the free camera (free_camera.gd).

const Iso = preload("res://scripts/camera/iso_camera.gd")
const TunnelLights = preload("res://scripts/world/tunnel_lights.gd")
## Layer of the ground layer that tunnel tiles are placed on.
const TUNNEL_LEVEL := -6

## Follow at startup (instead of the flight over the map, node Rondvlucht).
@export var active := false
## The vehicle (a node with `speed` and `velocity`, scripts/vehicles/vehicle.gd).
@export var target: NodePath = ^"../Auto"
## Metres in view when the vehicle stands still.
@export var zoom_still := 16.0
## Metres in view at `fast_speed` and above.
@export var zoom_fast := 55.0
## Speed (m/s) at which the view is zoomed out furthest (100 km/h).
@export var fast_speed := 28.0
## Seconds the view looks ahead of the car (times its average velocity), at most
## `max_lead` times the view size: the car should stay near the middle of the view.
@export var lead_time := 0.8
@export var max_lead := 0.12
## Seconds over which the vehicle's velocity is smoothed (for the point ahead and the zoom).
@export var velocity_smoothing := 0.6
## Seconds the view takes to catch up (about); the zoom takes `zoom_glide_time`.
@export var glide_time := 0.6
@export var zoom_glide_time := 2.0
## Speed-up of the game with T while following (the physics steps scale with it, so the
## driving and the crashes stay as precise).
@export var fast_forward := 4.0
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
@export var closeups := true
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

var _cam: Camera3D
var _car: Node3D
var _focus := Vector3.ZERO
var _zoom := 40.0
var _following := false
var _focus_velocity := Vector3.ZERO
var _zoom_velocity := 0.0
var _car_velocity := Vector3.ZERO    # the vehicle's velocity, smoothed (velocity_smoothing)
var _car_last := Vector3.ZERO        # where it was drawn last frame
var _closeup_wait := 0.0             # seconds until the next close-up
var _closeup_clock := -1.0           # seconds into the current close-up (< 0: none)
var _closeup_side := 1.0             # which way it swings round
var _random := RandomNumberGenerator.new()
var _ground: GridMap
var _underground := 0.0              # 0 = the iso view .. 1 = the chase camera in the tunnel
var _underground_velocity := 0.0
var _chase_heading := Vector3.FORWARD  # last driving direction of the vehicle, for the chase camera
var _covered_items := {}             # ground item -> is it a covered tunnel tile
var _base_physics_ticks := 0         # physics steps per second at normal speed

## The followed vehicle (for scripts/world/building_fade.gd).
var target_node: Node3D:
	get:
		return _car


func _ready() -> void:
	_cam = get_viewport().get_camera_3d()
	_car = get_node_or_null(target) as Node3D
	if _cam == null or _car == null:
		set_process(false)
		set_process_unhandled_input(false)
		return
	_ground = get_node_or_null(ground_path) as GridMap
	_focus = _car.global_position
	_zoom = zoom_still
	if active:
		start.call_deferred()
	else:
		set_process(false)


## Takes over the camera and follows the car; ends the flight over the map.
func start() -> void:
	var flight := get_node_or_null(^"../Rondvlucht")
	if flight and flight.is_processing() and flight.has_method("stop"):
		flight.call("stop")
	_following = true
	set_process(true)
	_cam.set_process(false)
	_cam.set_process_unhandled_input(false)
	_focus = _car_position()
	_focus_velocity = Vector3.ZERO
	_zoom_velocity = 0.0
	_closeup_clock = -1.0
	_closeup_wait = _random.randf_range(closeup_every.x, closeup_every.y)
	_car_last = _focus
	_car_velocity = Vector3.ZERO
	_underground = 0.0
	_underground_velocity = 0.0


## Runs the game `scale` times as fast, with as many more physics steps per second.
func _set_time_scale(scale: float) -> void:
	if not _base_physics_ticks:
		_base_physics_ticks = Engine.physics_ticks_per_second
	Engine.time_scale = scale
	Engine.physics_ticks_per_second = roundi(_base_physics_ticks * scale)
	Engine.max_physics_steps_per_frame = maxi(8, roundi(8 * scale))


## The demo crash: the nearest other vehicle drives the wrong way into the followed one.
func crash_demo() -> void:
	var nearest: Node3D = null
	for vehicle in Vehicle.all_vehicles:
		if vehicle != _car and not vehicle.crashed and not vehicle is RailVehicle and (nearest == null
				or vehicle.global_position.distance_to(_car.global_position) < nearest.global_position.distance_to(_car.global_position)):
			nearest = vehicle
	if nearest:
		nearest.call("drive_into", _car)


## True while the camera follows the vehicle.
func is_following() -> bool:
	return _following


## Hands the camera to the free camera.
func stop() -> void:
	if Engine.time_scale > 1.0:
		_set_time_scale(1.0)
	_following = false
	set_process(false)
	_underground = 0.0
	_underground_velocity = 0.0
	_cam.set_process(true)
	_cam.set_process_unhandled_input(true)
	if _cam.has_method("_ready"):
		_cam.call("_ready")


func _unhandled_input(event: InputEvent) -> void:
	if not ((event is InputEventKey or event is InputEventMouseButton) and event.is_pressed()):
		return
	if event is InputEventKey and event.keycode == KEY_F:
		if not _following:
			start.call_deferred()   # after the flight has handled this key press too
	elif event is InputEventKey and event.keycode == KEY_B and _following:
		crash_demo()
	elif event is InputEventKey and event.keycode == KEY_T and _following:
		_set_time_scale(1.0 if Engine.time_scale > 1.0 else fast_forward)
	elif _following:
		stop()


func _process(delta: float) -> void:
	var car_position := _car_position()
	var closeness := _advance_closeup(delta) * (1.0 - _underground)   # 0 = iso view .. 1 = closest
	if delta > 0.0:
		var frame_velocity := (car_position - _car_last) / delta
		_car_velocity = _car_velocity.lerp(frame_velocity, 1.0 - exp(-delta / maxf(velocity_smoothing, 0.01)))
	_car_last = car_position
	# the point ahead; close by it only makes up for the spring's lag (the car in the middle)
	var lead := (_car_velocity * lead_time).limit_length(_zoom * max_lead)
	var goal := car_position + lead.lerp(Vector3.ZERO, closeness) + _car_velocity * glide_time
	goal.y = car_position.y + _car_velocity.y * glide_time   # up and down ramps without lag
	var speed := Vector2(_car_velocity.x, _car_velocity.z).length()
	var goal_zoom := lerpf(zoom_still, zoom_fast, clampf(speed / fast_speed, 0.0, 1.0))
	for axis in 3:
		var glided := _glide(_focus[axis], goal[axis], _focus_velocity[axis], glide_time, delta)
		_focus[axis] = glided.x
		_focus_velocity[axis] = glided.y
	var zoomed := _glide(_zoom, goal_zoom, _zoom_velocity, zoom_glide_time, delta)
	_zoom = zoomed.x
	_zoom_velocity = zoomed.y
	var view_size := lerpf(_zoom, closeup_zoom, closeness)
	Iso.place(_cam, _focus, view_size)
	if closeness > 0.0:
		# lower and swung round the vehicle, at the same distance
		var progress := _closeup_clock / closeup_time
		var swing := closeup_orbit * (progress - 0.5) * _closeup_side * closeness
		_cam.rotation_degrees = Vector3(lerpf(Iso.ROTATION.x, closeup_pitch, closeness), Iso.ROTATION.y + swing, 0.0)
		_cam.global_position = _focus + _cam.global_basis.z * Iso.distance(view_size)
	_place_in_tunnel(car_position, delta)


## Blends the camera, just placed for the normal view, towards the chase camera as far
## as the vehicle is under the ground.
func _place_in_tunnel(car_position: Vector3, delta: float) -> void:
	var flat_velocity := Vector3(_car_velocity.x, 0.0, _car_velocity.z)
	if flat_velocity.length() > 1.0:
		_chase_heading = flat_velocity.normalized()
	var goal := 1.0 if _wants_chase_view(car_position, flat_velocity) else 0.0
	var glided := _glide(_underground, goal, _underground_velocity, tunnel_glide_time, delta)
	_underground = clampf(glided.x, 0.0, 1.0)
	_underground_velocity = glided.y
	if _underground < 0.001:
		return
	var blend := smoothstep(0.0, 1.0, _underground)
	var chase := Transform3D.IDENTITY.translated(
		car_position - _chase_heading * tunnel_chase_distance + Vector3.UP * tunnel_chase_height)
	chase = chase.looking_at(car_position + _chase_heading * tunnel_look_ahead + Vector3.UP * tunnel_look_height, Vector3.UP)
	_cam.global_position = _cam.global_position.lerp(chase.origin, blend)
	_cam.global_basis = _cam.global_basis.slerp(chase.basis, blend).orthonormalized()
	_cam.fov = lerpf(_cam.fov, tunnel_fov, blend)
	_cam.near = lerpf(_cam.near, tunnel_near, blend)


## True while the chase camera is wanted: the vehicle is low and it, the point it reaches
## soon or the spot of the chase camera behind it lies under cover.
func _wants_chase_view(car_position: Vector3, flat_velocity: Vector3) -> bool:
	if car_position.y >= tunnel_below_height:
		return false
	return _is_covered(car_position) or _is_covered(car_position + flat_velocity * tunnel_anticipation) \
		or _is_covered(car_position - _chase_heading * tunnel_chase_distance)


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
func _car_position() -> Vector3:
	return _car.call("drawn_position") if _car.has_method("drawn_position") else _car.global_position


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
