extends Node3D
## Now and then the police helicopter (scripts/vehicles/police_helicopter.gd, as in the
## main menu) flies over the town: in from far off, in a gentle curve over the spot the
## camera looks at (within PASS_OFFSET metres of it, so it is seen), and away on the other
## side; then it is gone until the next flight. The first comes FIRST_AFTER seconds into
## the game, then one every EVERY (from .. to) seconds. About LOW_SHARE of the flights are
## low passes: it comes in high and dips to LOW_HEIGHT over that spot, then climbs away;
## a ray down keeps it at least ROOF_CLEARANCE above whatever roof is under it.
## Not while the player is inside a building (Interiors.player_inside): the interiors lie far
## off the map, and it would fly over their roofless rooms; a flight under way then ends at
## once, and the next comes a while after going out.
## Its search light goes on at night
## (the Dagcyclus, day_cycle_path).
## Placed by tools/build/build_city.gd (_helicopter_flights).

const PoliceHelicopter = preload("res://scripts/vehicles/police_helicopter.gd")
const Interiors = preload("res://scripts/world/interiors/interiors.gd")

const FIRST_AFTER := 25.0
const EVERY := Vector2(70.0, 140.0)
## How far off it comes in and goes away (metres from the spot looked at), how high
## (metres, from .. to), how fast (m/s) and how far beside that spot it passes at most.
const REACH := 380.0
const HEIGHT := Vector2(38.0, 55.0)
const SPEED := 32.0
const PASS_OFFSET := 50.0
## Low passes: how many of the flights (share), how low over the spot (metres, from .. to),
## how far above roofs it stays at least, and how fast it follows that roof line (per s).
const LOW_SHARE := 0.4
const LOW_HEIGHT := Vector2(14.0, 22.0)
const ROOF_CLEARANCE := 8.0
const ROOF_FOLLOW := 2.5
## How much the curve bows (share of the flight's length to the side), and how far it
## banks into it (degrees at most) and dips its nose.
const BOW := 0.12
const BANK_DEGREES := 12.0
const NOSE_DOWN_DEGREES := 7.0

@export var day_cycle_path := NodePath("../Dagcyclus")

var _helicopter: Node3D
var _random := RandomNumberGenerator.new()
var _next_at := FIRST_AFTER
var _clock := 0.0
## The flight under way (empty when none): start, bend (the curve's middle control point),
## end (all metres, at the height), its length in seconds and the time it began.
var _flight := {}
## The height it actually flies at (the curve, lifted above roofs, smoothed).
var _flown_height := 0.0


func _ready() -> void:
	_random.randomize()


func _process(delta: float) -> void:
	_clock += delta
	if Interiors.player_inside(get_tree()):
		if not _flight.is_empty():
			_helicopter.visible = false
			_flight = {}
		_next_at = maxf(_next_at, _clock + _random.randf_range(EVERY.x, EVERY.y) * 0.5)
		return
	if _flight.is_empty():
		if _clock >= _next_at:
			_start_flight()
		return
	var share := (_clock - float(_flight.began)) / float(_flight.seconds)
	if share >= 1.0:
		_helicopter.visible = false
		_flight = {}
		_next_at = _clock + _random.randf_range(EVERY.x, EVERY.y)
		return
	var here := _on_curve(share)
	var wanted := maxf(here.y, _roof_below(here) + ROOF_CLEARANCE)
	# climbs quickly, sinks gently
	var follow := ROOF_FOLLOW * (3.0 if wanted > _flown_height else 1.0)
	_flown_height = lerpf(_flown_height, wanted, minf(1.0, follow * delta))
	here.y = _flown_height
	var ahead := _on_curve(minf(share + 0.01, 1.0)) - _on_curve(share)
	ahead.y = 0.0
	if ahead.length() < 0.001:
		return
	ahead = ahead.normalized()
	# banked into the bend: by how fast the heading turns
	var later := _on_curve(minf(share + 0.03, 1.0)) - _on_curve(minf(share + 0.02, 1.0))
	later.y = 0.0
	var turn := ahead.cross(later.normalized()).y if later.length() > 0.001 else 0.0
	var bank := Basis(ahead, clampf(-turn * 25.0, -1.0, 1.0) * deg_to_rad(BANK_DEGREES))
	var facing := Basis.looking_at(-ahead, Vector3.UP)   # its front is +Z
	var nose_down := Basis(Vector3.RIGHT, deg_to_rad(NOSE_DOWN_DEGREES))
	_helicopter.global_transform = Transform3D(bank * facing * nose_down, here)


## A new flight: from a random side, over (near) the spot the camera looks at, to the
## other side, bowing a little to one side.
func _start_flight() -> void:
	var spot := _looked_at()
	var height := _random.randf_range(HEIGHT.x, HEIGHT.y)
	var direction := Vector3.RIGHT.rotated(Vector3.UP, _random.randf() * TAU)
	var beside := Vector3(-direction.z, 0.0, direction.x)
	var passing := spot + beside * _random.randf_range(-PASS_OFFSET, PASS_OFFSET) + Vector3.UP * height
	var start := passing - direction * REACH
	var end := passing + direction * REACH
	var bend := passing + beside * REACH * 2.0 * BOW * (1.0 if _random.randf() < 0.5 else -1.0)
	if _random.randf() < LOW_SHARE:
		# the curve's middle is (start + 2 * bend + end) / 4, so to pass at `low`
		# over the spot the bend sits at 2 * low - height.
		var low := _random.randf_range(LOW_HEIGHT.x, LOW_HEIGHT.y)
		bend.y = 2.0 * low - height
	_flight = {"start": start, "bend": bend, "end": end, "seconds": start.distance_to(end) / SPEED, "began": _clock}
	if _helicopter == null:
		_helicopter = PoliceHelicopter.new()
		_helicopter.set("circling", false)
		_helicopter.set("day_cycle", get_node_or_null(day_cycle_path))
		add_child(_helicopter)
	_helicopter.global_position = start
	_helicopter.visible = true
	_flown_height = start.y


## Where on the quadratic curve start - bend - end it is at `share` (0 .. 1).
func _on_curve(share: float) -> Vector3:
	var start: Vector3 = _flight.start
	var bend: Vector3 = _flight.bend
	var end: Vector3 = _flight.end
	return start.lerp(bend, share).lerp(bend.lerp(end, share), share)


## The height of the highest thing (roof, tree, ground) straight under `point`; 0 if none.
func _roof_below(point: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 300.0, point.z), Vector3(point.x, -5.0, point.z))
	var hit := space.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else 0.0


## The spot on the ground (y = 0) the current camera looks at; under the camera if it
## looks up or level.
func _looked_at() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var from := camera.global_position
	var forward := -camera.global_basis.z
	if forward.y > -0.05:
		return Vector3(from.x, 0.0, from.z)
	return from + forward * (-from.y / forward.y)
