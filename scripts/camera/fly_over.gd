extends Node
## Slow flight over the map at startup (the "Rondvlucht" node of scenes/stad.tscn): the
## iso camera glides along a closed, smooth route through the places of the map (the
## "places" metadata the builder saved on the scene root, see build_city.gd), round and
## round. Over every place it zooms in, between places it zooms out; the speed over the
## ground follows the zoom, so the picture moves equally calmly at every zoom. Any key,
## mouse click or wheel hands the camera back to the free camera (free_camera.gd);
## `active` off = start with the free camera.

const Iso = preload("res://scripts/camera/iso_camera.gd")

## Fly at startup.
@export var active := true
## Speed over the ground in metres per second at a view size of 100 m (scales with the zoom).
@export var speed := 7.0
## Metres in view above a place (zoomed in; iso view size, see scripts/camera/iso_camera.gd).
@export var zoom_near := 45.0
## Metres in view halfway between two places (zoomed out).
@export var zoom_far := 230.0
## Places (keys of the scene's "places" metadata) in the order they are visited; unknown
## names are skipped.
@export var route: PackedStringArray = [
	"noordeinde", "lange_voorhout", "denneweg", "haagse_bos", "huis_ten_bosch", "prins_clauslaan",
	"over_de_a12", "theresiastraat", "bezuidenhout_oost", "station_laan_van_noi", "schenkviaduct", "beatrixkwartier", "centraal", "malieveld",
	"plein", "binnenhof", "spui", "passage", "chinatown", "grote_markt", "grote_kerk"]

var _points: Array[Vector2] = []
var _segment := 0
var _t := 0.0
var _cam: Camera3D


func _ready() -> void:
	_cam = get_viewport().get_camera_3d()
	var places: Dictionary = owner.get_meta("places", {}) if owner else {}
	for slug in route:
		if places.has(slug):
			_points.append(places[slug])
	if not active or _cam == null or _points.size() < 3:
		set_process(false)
		set_process_unhandled_input(false)
		return
	_cam.set_process(false)
	_cam.set_process_unhandled_input(false)
	_place()


## Hands the camera to the player on the first key press, click or wheel turn.
func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		stop()


## Stops the flight; the free camera takes over from where it is.
func stop() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	if _cam:
		_cam.set_process(true)
		_cam.set_process_unhandled_input(true)
		if _cam.has_method("_ready"):
			_cam.call("_ready")


func _process(delta: float) -> void:
	# advance by a fixed distance: the parameter step follows the local speed of the curve
	var step := speed * delta * _zoom() / 100.0
	var d := (_sample(_segment, _t + 0.01) - _sample(_segment, _t)).length() / 0.01
	_t += step / maxf(d, 0.001)
	while _t >= 1.0:
		_t -= 1.0
		_segment = (_segment + 1) % _points.size()
	_place()


func _place() -> void:
	var p := _sample(_segment, _t)
	Iso.place(_cam, Vector3(p.x, 0.0, p.y), _zoom())


## View size for the current spot: zoom_near at a place, zoom_far halfway, smooth between.
func _zoom() -> float:
	return lerpf(zoom_near, zoom_far, sin(PI * _t) ** 2)


## Point on the closed Catmull-Rom curve through the route points: segment i runs from
## point i to point i + 1, t in 0..1.
func _sample(i: int, t: float) -> Vector2:
	var n := _points.size()
	var p0 := _points[(i - 1 + n) % n]
	var p1 := _points[i % n]
	var p2 := _points[(i + 1) % n]
	var p3 := _points[(i + 2) % n]
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
