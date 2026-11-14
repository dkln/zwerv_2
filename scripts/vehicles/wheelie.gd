extends RefCounted
## A wheelie now and then: the front up on the rear wheel for several seconds (a daredevil's
## stunt: the rider then races and looks out for nothing, Vehicle.daredevil), wobbling a
## little, then down again with a small bounce. For the fatbikes, mopeds, scooters and
## motorbikes (TwoWheeler `wheelie_degrees`) and the wheelchairs (MobilityAid, Pedestrian).
## While `allowed` (going straight at speed, not braking) one starts on average every
## MEAN_PAUSE seconds; `step` says when one starts, so the rider can shout something
## (DriverShout, mood "wheelie"). `tilt_about` turns the drawn body about the point where the
## rear wheel touches the road.
## The state of one rider's wheelie (its clock, its draws); the sums are wheelie_rules.gd's
## (docs/CODE_LAGEN.md).
##   const Wheelie = preload("res://scripts/vehicles/wheelie.gd")
##   var wheelie := Wheelie.new(deg_to_rad(28.0), route_seed)
##   if wheelie.step(delta, going_straight): DriverShout.shout(self, "motor", "wheelie", 2.0)
##   _body.global_transform *= wheelie.tilt_about(rear_contact)

const WheelieRules = preload("res://scripts/vehicles/wheelie_rules.gd")

## The numbers of the rules, under the names they had here.
const MEAN_PAUSE := WheelieRules.MEAN_PAUSE
const UP_SECONDS := WheelieRules.UP_SECONDS
const RISE_RATE := WheelieRules.RISE_RATE
const DROP_RATE := WheelieRules.DROP_RATE
const WOBBLE_SHARE := WheelieRules.WOBBLE_SHARE
const WOBBLE_SPEED := WheelieRules.WOBBLE_SPEED
const BOUNCE_SHARE := WheelieRules.BOUNCE_SHARE
const BOUNCE_DAMPING := WheelieRules.BOUNCE_DAMPING

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
	return WheelieRules.is_up(_up_left, angle)


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
	elif WheelieRules.may_start(allowed, angle) and _random.randf() < WheelieRules.start_chance(delta):
		_up_left = _random.randf_range(UP_SECONDS.x, UP_SECONDS.y)
		_height = most_angle * _random.randf_range(WheelieRules.HEIGHT_SHARE.x, WheelieRules.HEIGHT_SHARE.y)
		started = true
	if _up_left > 0.0:
		angle = WheelieRules.risen(angle, WheelieRules.wanted_angle(_height, _clock), delta)
	else:
		angle = WheelieRules.dropped(angle, delta)
		if _bounce >= 0.0:
			_bounce += delta
			# the front wheel hits the road and springs up a little once or twice
			angle = WheelieRules.bounced(angle, WheelieRules.spring(_bounce, _height))
			if WheelieRules.bounce_done(_bounce):
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
	return WheelieRules.tilt_about(angle, pivot)
