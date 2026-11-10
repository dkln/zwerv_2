extends RefCounted
## A wheelie now and then: the front up on the rear wheel for a few seconds, wobbling a
## little, then down again with a small bounce. For the fatbikes, mopeds, scooters and
## motorbikes (TwoWheeler `wheelie_degrees`) and the wheelchairs (MobilityAid, Pedestrian).
## While `allowed` (going straight at speed, not braking) one starts on average every
## MEAN_PAUSE seconds; `step` says when one starts, so the rider can shout something
## (DriverShout, mood "wheelie"). `tilt_about` turns the drawn body about the point where the
## rear wheel touches the road.
##   var wheelie := Wheelie.new(deg_to_rad(28.0), route_seed)
##   if wheelie.step(delta, going_straight): DriverShout.shout(self, "motor", "wheelie", 2.0)
##   _body.global_transform *= wheelie.tilt_about(rear_contact)

## Mean seconds between two wheelies of one rider while it may do one.
const MEAN_PAUSE := 45.0
## Seconds the front stays up (shortest, longest).
const UP_SECONDS := Vector2(1.4, 3.0)
## How fast the front goes up and comes down (1/s), and the wobble while up.
const RISE_RATE := 5.0
const DROP_RATE := 7.0
const WOBBLE_SHARE := 0.12
const WOBBLE_SPEED := 6.0
## The bounce of the front wheel landing: share of the height, how fast it dies out.
const BOUNCE_SHARE := 0.18
const BOUNCE_DAMPING := 9.0

## The angle it goes up to at most (radians), and how far up it is now.
var most_angle := 0.4
var angle := 0.0
var _height := 0.0        # the angle of this wheelie
var _up_left := 0.0       # seconds the front stays up
var _clock := 0.0
var _bounce := 0.0        # seconds since the front wheel landed (-1: no bounce going on)
var _random := RandomNumberGenerator.new()


func _init(most_radians: float, seed: int) -> void:
	most_angle = most_radians
	_random.seed = seed * 31 + 17
	_bounce = -1.0


func is_up() -> bool:
	return _up_left > 0.0 or angle > 0.01


## Moves the wheelie on by `delta` seconds; `allowed`: it may do one now (and keep it up).
## Returns true the moment one starts.
func step(delta: float, allowed: bool) -> bool:
	var started := false
	_clock += delta
	if _up_left > 0.0:
		_up_left -= delta
		if not allowed:
			_up_left = 0.0
		if _up_left <= 0.0:
			_bounce = 0.0
	elif allowed and angle < 0.01 and _random.randf() < delta / MEAN_PAUSE:
		_up_left = _random.randf_range(UP_SECONDS.x, UP_SECONDS.y)
		_height = most_angle * _random.randf_range(0.7, 1.0)
		started = true
	if _up_left > 0.0:
		var wanted := _height * (1.0 + WOBBLE_SHARE * sin(_clock * WOBBLE_SPEED))
		angle = lerpf(angle, wanted, 1.0 - exp(-RISE_RATE * delta))
	else:
		angle = lerpf(angle, 0.0, 1.0 - exp(-DROP_RATE * delta))
		if _bounce >= 0.0:
			_bounce += delta
			# the front wheel hits the road and springs up a little once or twice
			var spring := absf(sin(_bounce * 14.0)) * exp(-_bounce * BOUNCE_DAMPING) * BOUNCE_SHARE * _height
			if angle < 0.02:
				angle = maxf(angle, spring)
			if _bounce > 0.8:
				_bounce = -1.0
	return started


## Ends it at once (a crash, knocked over).
func stop() -> void:
	_up_left = 0.0
	_bounce = -1.0
	angle = 0.0


## The turn of the body (in its own space: front +z, up +y) that lifts the front by `angle`
## about `pivot`, the point where its rear wheel touches the road.
func tilt_about(pivot: Vector3) -> Transform3D:
	var turn := Basis(Vector3.RIGHT, -angle)
	return Transform3D(turn, pivot - turn * pivot)
