extends Node
## Iso camera that follows a vehicle (the "Volgcamera" node of scenes/stad.tscn, following
## the car): it keeps the vehicle in view, a little ahead of it in its driving direction
## and at the height it drives at (down into the tunnel trough), and zooms with its
## speed: close in when it stands still, further out the faster it goes. F follows the car
## (also during the flight over the map, which it then ends); any other key or mouse
## click hands the camera to the free camera (free_camera.gd).

const Iso = preload("res://scripts/camera/iso_camera.gd")

## Follow at startup (instead of the flight over the map, node Rondvlucht).
@export var active := false
## The vehicle (a node with `speed` and `velocity`, scripts/characters/vehicle.gd).
@export var target: NodePath = ^"../Auto"
## Metres in view when the vehicle stands still.
@export var zoom_still := 28.0
## Metres in view at `fast_speed` and above.
@export var zoom_fast := 110.0
## Speed (m/s) at which the view is zoomed out furthest (100 km/h).
@export var fast_speed := 28.0
## Seconds the view looks ahead of the car (times its velocity).
@export var lead_time := 0.9
## How quickly the view follows the car and the zoom follows the speed (1/s).
@export var follow_rate := 3.0
@export var zoom_rate := 0.8

var _cam: Camera3D
var _car: Node3D
var _focus := Vector3.ZERO
var _zoom := 40.0
var _following := false


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
	_focus = _car.global_position


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
	var speed: float = _car.get("speed")
	var velocity: Vector3 = _car.get("velocity")
	var wanted_focus := _car.global_position + velocity * lead_time
	wanted_focus.y = _car.global_position.y
	_focus = _focus.lerp(wanted_focus, 1.0 - exp(-follow_rate * delta))
	var wanted_zoom := lerpf(zoom_still, zoom_fast, clampf(speed / fast_speed, 0.0, 1.0))
	_zoom = lerpf(_zoom, wanted_zoom, 1.0 - exp(-zoom_rate * delta))
	Iso.place(_cam, _focus, _zoom)
