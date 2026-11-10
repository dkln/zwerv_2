extends RefCounted
## Camera math for the isometric-looking view, shared by the free camera
## (free_camera.gd), DetailNiveau and the screenshot tools.
##
## The camera is a real perspective camera, rotated 45 degrees and tilted ~35 degrees
## down, with a narrow field of view so it looks almost isometric. Godot only computes
## shadow splits and SSR correctly with a perspective camera, hence no orthographic one.
##
## "view_size" = how many metres you see vertically around the focus point (like the
## `size` of an orthographic camera). Zooming = changing the camera distance; the field
## of view stays fixed.

## Vertical field of view in degrees.
const FOV := 20.0
## Camera rotation in degrees (pitch, yaw, roll): the camera stands north-east of what it
## looks at, so the north and east fronts face it (the front of Centraal Station with its
## "DEN HAAG CENTRAAL" lettering faces north, onto the square).
const ROTATION := Vector3(-35.264, 135.0, 0.0)
## Unit vector from the focus point to the camera (the inverse of the view direction).
const DIRECTION := Vector3(0.57735, 0.57735, -0.57735)


## Camera distance (metres) from the focus point for a view size in metres.
static func distance(view_size: float) -> float:
	return view_size * 0.5 / tan(deg_to_rad(FOV * 0.5))


## Unit vector from the focus point to the camera when the view is turned to `yaw`
## (degrees round the vertical; ROTATION.y is the standard view).
static func direction(yaw := ROTATION.y) -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(yaw - ROTATION.y)) * DIRECTION


## Camera position that looks at `focus` (world, metres) with `view_size` metres in view,
## the view turned to `yaw` degrees.
static func position(focus: Vector3, view_size: float, yaw := ROTATION.y) -> Vector3:
	return focus + direction(yaw) * distance(view_size)


## Configures `cam` as the iso camera (projection, FOV, clip planes, rotation) and
## places it looking at `focus` with `view_size` metres in view, turned to `yaw` degrees.
static func place(cam: Camera3D, focus: Vector3, view_size: float, yaw := ROTATION.y) -> void:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = FOV
	cam.near = 2.0
	cam.far = 6000.0
	cam.rotation_degrees = Vector3(ROTATION.x, yaw, ROTATION.z)
	cam.global_position = position(focus, view_size, yaw)


## Distance (metres) from the camera to the ground plane (y = 0) along the view direction.
## Returns a quarter of the far plane when the camera looks (nearly) horizontally.
static func distance_to_ground(cam: Camera3D) -> float:
	var forward := -cam.global_transform.basis.z
	if forward.y > -0.05:
		return cam.far * 0.25
	return cam.global_position.y / -forward.y


## Point on the ground plane (y = 0) the camera is looking at, in world metres.
static func ground_focus(cam: Camera3D) -> Vector3:
	var focus := cam.global_position + (-cam.global_transform.basis.z) * distance_to_ground(cam)
	focus.y = 0.0
	return focus


## Current view size (metres in view vertically), for orthographic and perspective cameras.
static func view_size(cam: Camera3D) -> float:
	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return cam.size
	return 2.0 * distance_to_ground(cam) * tan(deg_to_rad(cam.fov * 0.5))
