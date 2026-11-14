extends RefCounted
## The rules of the free camera (logic; docs/CODE_LAGEN.md): how fast it moves and looks
## round in the perspective view, and in the iso view how it pans over the ground, zooms
## within its limits, turns a quarter and drags the map under the mouse. No camera and no
## input here: free_camera.gd reads the keys and the mouse, asks these and places the camera.
##   const FreeCameraRules = preload("res://scripts/camera/free_camera_rules.gd")

const IsoRules = preload("res://scripts/camera/iso_camera_rules.gd")

## Least and most metres in view when zooming the iso view.
const ISO_MIN_VIEW := 6.0
const ISO_MAX_VIEW := 600.0
## Perspective: the mouse wheel makes it SPEED_STEP times faster or slower, between the two
## of SPEED_MOST (m/s); the view looks at most PITCH_MOST (radians) up or down.
const SPEED_STEP := 1.2
const SPEED_MOST := Vector2(1.0, 200.0)
const PITCH_MOST := 1.5
## How many times faster with Shift held.
const FAST := 3.0
## A quarter turn (degrees) with Z / X.
const QUARTER := 90.0


## The speed (m/s) after a click of the mouse wheel: up faster, down slower.
static func speed_after_wheel(speed: float, wheel_up: bool) -> float:
	return minf(speed * SPEED_STEP, SPEED_MOST.y) if wheel_up else maxf(speed / SPEED_STEP, SPEED_MOST.x)


## The pitch (x) and yaw (y), in radians, after the mouse moved `relative` pixels at
## `sensitivity` radians a pixel.
static func look_after(pitch: float, yaw: float, relative: Vector2, sensitivity: float) -> Vector2:
	return Vector2(clampf(pitch - relative.y * sensitivity, -PITCH_MOST, PITCH_MOST), yaw - relative.x * sensitivity)


## How many times faster it goes: FAST with Shift held.
static func haste(shift_held: bool) -> float:
	return FAST if shift_held else 1.0


## Metres the perspective camera moves in a frame of `delta` s: `direction` in its own
## `basis` (x right, z back) and `up` straight up, at `speed` m/s.
static func flight(basis: Basis, direction: Vector3, up: float, speed: float, delta: float) -> Vector3:
	return (basis * direction) * speed * delta + Vector3.UP * up * speed * delta


## Where a quarter turn (left or right) heads from `target_yaw` (degrees): the next whole
## quarter from the usual view.
static func quarter_turn(target_yaw: float, to_the_left: bool) -> float:
	var quarter := -QUARTER if to_the_left else QUARTER
	return snappedf(target_yaw - IsoRules.ROTATION.y, QUARTER) + IsoRules.ROTATION.y + quarter


## The basis of the iso view turned to `yaw` degrees.
static func iso_basis(yaw: float) -> Basis:
	return Basis.from_euler(Vector3(IsoRules.ROTATION.x, yaw, IsoRules.ROTATION.z) * PI / 180.0)


## The direction the iso camera turned to `yaw` looks in, flat over the ground.
static func ground_forward(yaw: float) -> Vector3:
	var forward := -iso_basis(yaw).z
	return Vector3(forward.x, 0.0, forward.z).normalized()


## The screen's right of the iso camera turned to `yaw`, flat over the ground.
static func ground_right(yaw: float) -> Vector3:
	var right := iso_basis(yaw).x
	return Vector3(right.x, 0.0, right.z).normalized()


## Metres the map shifts when the mouse drags it `relative` pixels, the view `view_size`
## metres over a screen `screen_height` pixels high: the ground under the mouse follows it.
static func drag_shift(yaw: float, relative: Vector2, view_size: float, screen_height: float) -> Vector3:
	var metres_per_pixel := view_size / maxf(screen_height, 1.0)
	# screen up, stretched over the tilted ground
	var ground_along := ground_forward(yaw) / sin(deg_to_rad(-IsoRules.ROTATION.x))
	return -ground_right(yaw) * relative.x * metres_per_pixel + ground_along * relative.y * metres_per_pixel


## Metres the focus pans in a frame of `delta` s with the keys at `forward` and `sideways`
## (-1..1): `pan_speed` shares of the view a second, `haste` times faster.
static func pan(yaw: float, forward: float, sideways: float, view_size: float, pan_speed: float, hurry: float, delta: float) -> Vector3:
	var way := (ground_forward(yaw) * forward + ground_right(yaw) * sideways).limit_length(1.0)
	return way * view_size * pan_speed * hurry * delta


## The view size after a frame of zooming with the keys (`zoom` -1..1: out, in): it grows or
## shrinks `zoom_speed` times a second.
static func zoomed(view_size: float, zoom_speed: float, zoom: float, hurry: float, delta: float) -> float:
	return view_size * pow(zoom_speed, -zoom * hurry * delta)


## The view size within the zoom limits.
static func within_limits(view_size: float) -> float:
	return clampf(view_size, ISO_MIN_VIEW, ISO_MAX_VIEW)


## Whether the iso camera has nothing to do this frame: no key held, not turning, and it
## looks down at the iso angle (`straight`).
static func is_at_rest(forward: float, sideways: float, zoom: float, turning: bool, straight: bool) -> bool:
	return forward == 0.0 and sideways == 0.0 and zoom == 0.0 and not turning and straight
