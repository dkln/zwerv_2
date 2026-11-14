extends RefCounted
## The camera of the isometric-looking view, shared by the follow camera (follow_camera.gd),
## the free camera (free_camera.gd), DetailNiveau and the screenshot tools: it sets a Camera3D
## up as the iso camera and reads from one what it looks at. This is the part that touches
## the camera (graphics; docs/CODE_LAGEN.md); the sums are in iso_camera_rules.gd, handed on
## here under the same names for everyone who has this script.
##   const Iso = preload("res://scripts/camera/iso_camera.gd")
##
## The camera is rotated 45 degrees and tilted ~35 degrees down. By default a real
## perspective camera with a narrow field of view, so it looks almost isometric (Godot only
## computes shadow splits and SSR correctly with a perspective camera). Truly isometric, an
## orthographic one, can be switched on to try it: the project setting ORTHO_SETTING
## (Project Settings > zwervr > camera > orthografisch), or for one run `-- --ortho` /
## `-- --perspectief` (orthographic()). It stands at the same distance either way, so what
## hides with distance (visibility ranges) stays the same.
##
## "view_size" = how many metres you see vertically around the focus point (like the
## `size` of an orthographic camera). Zooming = changing the camera distance; the field
## of view stays fixed.

const IsoRules = preload("res://scripts/camera/iso_camera_rules.gd")

## Vertical field of view in degrees.
const FOV := IsoRules.FOV
## Clip planes of the perspective view (metres).
const NEAR := IsoRules.NEAR
const FAR := IsoRules.FAR
## The depth of the orthographic view before and behind the ground in view (IsoRules).
const ORTHO_DEPTH_FRONT := IsoRules.ORTHO_DEPTH_FRONT
const ORTHO_DEPTH_BACK := IsoRules.ORTHO_DEPTH_BACK
## The project setting that makes the view orthographic (truly isometric).
const ORTHO_SETTING := IsoRules.ORTHO_SETTING
## Camera rotation in degrees (pitch, yaw, roll), and the unit vector from the focus point
## to the camera (IsoRules).
const ROTATION := IsoRules.ROTATION
const DIRECTION := IsoRules.DIRECTION


## Whether the iso view is orthographic now: `-- --ortho` or `-- --perspectief` for this run,
## else the project setting ORTHO_SETTING (off when it is not there).
static func orthographic() -> bool:
	return IsoRules.orthographic_for(OS.get_cmdline_user_args(), bool(ProjectSettings.get_setting(ORTHO_SETTING, false)))


## Camera distance (metres) from the focus point for a view size in metres.
static func distance(view_size: float) -> float:
	return IsoRules.distance(view_size)


## Unit vector from the focus point to the camera when the view is turned to `yaw`
## (degrees round the vertical; ROTATION.y is the standard view).
static func direction(yaw := ROTATION.y) -> Vector3:
	return IsoRules.direction(yaw)


## Camera position that looks at `focus` (world, metres) with `view_size` metres in view,
## the view turned to `yaw` degrees.
static func position(focus: Vector3, view_size: float, yaw := ROTATION.y) -> Vector3:
	return IsoRules.position(focus, view_size, yaw)


## Configures `cam` as the iso camera (projection, FOV, clip planes, rotation) and
## places it looking at `focus` with `view_size` metres in view, turned to `yaw` degrees.
static func place(cam: Camera3D, focus: Vector3, view_size: float, yaw := ROTATION.y) -> void:
	cam.fov = FOV
	if orthographic():
		var clip := IsoRules.ortho_clip(view_size)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = view_size
		cam.near = clip.x
		cam.far = clip.y
	else:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.near = NEAR
		cam.far = FAR
	cam.rotation_degrees = IsoRules.rotation(yaw)
	cam.global_position = position(focus, view_size, yaw)


## Distance (metres) from the camera to the ground plane (y = 0) along the view direction.
## Returns a quarter of the far plane when the camera looks (nearly) horizontally.
static func distance_to_ground(cam: Camera3D) -> float:
	return IsoRules.distance_to_ground(cam.global_position.y, -cam.global_transform.basis.z, cam.far)


## Point on the ground plane (y = 0) the camera is looking at, in world metres.
static func ground_focus(cam: Camera3D) -> Vector3:
	return IsoRules.ground_focus(cam.global_position, -cam.global_transform.basis.z, cam.far)


## Current view size (metres in view vertically), for orthographic and perspective cameras.
static func view_size(cam: Camera3D) -> float:
	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return cam.size
	return IsoRules.perspective_view_size(distance_to_ground(cam), cam.fov)
