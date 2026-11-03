extends Node
## Iso camera that follows a vehicle (the "Volgcamera" node of scenes/stad.tscn, following
## the car): it keeps the vehicle in view, a little ahead of it in its driving direction
## and at the height it drives at (down into the tunnel trough), and zooms with its
## speed: close in when it stands still, further out the faster it goes.
## It does not chase the vehicle every frame (every bump, corner and stop would show in
## the view): every `retarget_time` seconds it picks a point, where the vehicle will be
## in `lead_time` seconds at its average velocity of the last stretch, and glides there
## on a critically damped spring (`glide_time`), so its speed never jumps. If the vehicle
## gets too far from the middle of the view, it picks a new point at once.
## Now and then (every `closeup_every` seconds) it moves in for a close-up: it zooms in
## on the vehicle, drops a little lower and swings round it, then glides back to the
## iso view (`closeup_*`, off with `closeups`). F follows the car
## (also during the flight over the map, which it then ends); any other key or mouse
## click hands the camera to the free camera (free_camera.gd).

const Iso = preload("res://scripts/camera/iso_camera.gd")

## Follow at startup (instead of the flight over the map, node Rondvlucht).
@export var active := false
## The vehicle (a node with `speed` and `velocity`, scripts/characters/vehicle.gd).
@export var target: NodePath = ^"../Auto"
## Metres in view when the vehicle stands still.
@export var zoom_still := 16.0
## Metres in view at `fast_speed` and above.
@export var zoom_fast := 55.0
## Speed (m/s) at which the view is zoomed out furthest (100 km/h).
@export var fast_speed := 28.0
## Seconds the view looks ahead of the car (times its average velocity), at most
## `max_lead` times the view size: the car should stay near the middle, in the sharp
## band of the tilt-shift lens.
@export var lead_time := 0.8
@export var max_lead := 0.12
## Seconds between two points the view glides to.
@export var retarget_time := 1.0
## Seconds the glide to a point takes (about); the zoom takes `zoom_glide_time`.
@export var glide_time := 0.9
@export var zoom_glide_time := 2.0
## A new point at once when the vehicle is further than this share of the view size from
## the middle of the view.
@export var keep_in_view := 0.3
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
var _goal := Vector3.ZERO            # the point the view glides to
var _goal_zoom := 16.0
var _focus_velocity := Vector3.ZERO
var _zoom_velocity := 0.0
var _since_goal := 0.0               # seconds since the last point was picked
var _car_at_goal := Vector3.ZERO     # where the vehicle was then
var _car_velocity := Vector3.ZERO    # the vehicle's velocity, smoothed over a few frames
var _car_last := Vector3.ZERO        # where it was drawn last frame
var _closeup_wait := 0.0             # seconds until the next close-up
var _closeup_clock := -1.0           # seconds into the current close-up (< 0: none)
var _closeup_side := 1.0             # which way it swings round
var _random := RandomNumberGenerator.new()

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
	_goal = _focus
	_car_at_goal = _focus
	_focus_velocity = Vector3.ZERO
	_zoom_velocity = 0.0
	_since_goal = 0.0
	_closeup_clock = -1.0
	_closeup_wait = _random.randf_range(closeup_every.x, closeup_every.y)
	_car_last = _focus
	_car_velocity = Vector3.ZERO


## True while the camera follows the vehicle.
func is_following() -> bool:
	return _following


## Hands the camera to the free camera.
func stop() -> void:
	_following = false
	set_process(false)
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
	elif _following:
		stop()


func _process(delta: float) -> void:
	var car_position := _car_position()
	var closeness := _advance_closeup(delta)   # 0 = iso view .. 1 = closest
	if delta > 0.0:
		_car_velocity = _car_velocity.lerp((car_position - _car_last) / delta, 1.0 - exp(-8.0 * delta))
	_car_last = car_position
	_since_goal += delta
	var off_centre := Vector2(car_position.x - _focus.x, car_position.z - _focus.z).length()
	if _since_goal >= retarget_time or off_centre > _zoom * keep_in_view or closeness > 0.0:
		# the average velocity since the last point: no jitter from single steps
		var average_velocity := (car_position - _car_at_goal) / maxf(_since_goal, 0.05)
		var lead := (average_velocity * lead_time).limit_length(_zoom * max_lead)
		# close by: aim where the spring will catch up with it (no lag behind the car)
		lead = lead.lerp(_car_velocity * glide_time, closeness)
		_goal = car_position + lead
		_goal.y = car_position.y
		var speed := Vector2(average_velocity.x, average_velocity.z).length()
		_goal_zoom = lerpf(zoom_still, zoom_fast, clampf(speed / fast_speed, 0.0, 1.0))
		_car_at_goal = car_position
		_since_goal = 0.0
	for axis in 3:
		var glided := _glide(_focus[axis], _goal[axis], _focus_velocity[axis], glide_time, delta)
		_focus[axis] = glided.x
		_focus_velocity[axis] = glided.y
	var zoomed := _glide(_zoom, _goal_zoom, _zoom_velocity, zoom_glide_time, delta)
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
