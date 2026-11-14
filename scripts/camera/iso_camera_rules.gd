extends RefCounted
## The sums of the isometric-looking view (logic; docs/CODE_LAGEN.md): where the camera stands
## for a focus point, a view size and a turn, how deep the orthographic view reaches (near and
## far), and what a camera that already stands somewhere is looking at. No camera here: the
## camera itself is placed by iso_camera.gd, which hands these on under the same names.
##   const IsoRules = preload("res://scripts/camera/iso_camera_rules.gd")
##
## "view_size" = how many metres you see vertically around the focus point (like the `size`
## of an orthographic camera). Zooming = changing the camera distance; the field of view
## stays fixed.

## Vertical field of view in degrees.
const FOV := 20.0
## Clip planes of the perspective view (metres).
const NEAR := 2.0
const FAR := 6000.0
## With the orthographic view the clip planes hug the town round the focus point: Godot
## ignores a sun's shadow max distance for an orthographic camera and spreads its shadow
## over the whole depth from near to far (6 km: big blurred shadow blots). How far in front
## of the ground at the focus may something still be seen (a tall building, metres along the
## view) and how far behind it (below street level, the far edge of the view). The less depth,
## the sharper the shadow: 60 m in front holds a building of ~35 m (1.73 x its height) at the
## bottom edge of the view; a taller one there loses its top.
const ORTHO_DEPTH_FRONT := 60.0
const ORTHO_DEPTH_BACK := 40.0
## The ground in view lies up to ~0.71 x view_size before and behind the focus point.
const ORTHO_GROUND_DEPTH := 0.75
## The project setting that makes the view orthographic (truly isometric), and the arguments
## that choose for one run.
const ORTHO_SETTING := "zwervr/camera/orthografisch"
const ORTHO_ARGUMENT := "--ortho"
const PERSPECTIVE_ARGUMENT := "--perspectief"
## Camera rotation in degrees (pitch, yaw, roll): the camera stands north-east of what it
## looks at, so the north and east fronts face it (the front of Centraal Station with its
## "DEN HAAG CENTRAAL" lettering faces north, onto the square).
const ROTATION := Vector3(-35.264, 135.0, 0.0)
## Unit vector from the focus point to the camera (the inverse of the view direction).
const DIRECTION := Vector3(0.57735, 0.57735, -0.57735)
## A camera looking less far down than this (the y of its view direction) never reaches the
## ground: its distance to it counts as GROUND_FAR_SHARE of its far plane.
const LEVEL_VIEW := -0.05
const GROUND_FAR_SHARE := 0.25


## Whether the iso view is orthographic: `--ortho` or `--perspectief` among the arguments of
## this run (`arguments`), else the project setting (`setting`).
static func orthographic_for(arguments: PackedStringArray, setting: bool) -> bool:
	if ORTHO_ARGUMENT in arguments:
		return true
	if PERSPECTIVE_ARGUMENT in arguments:
		return false
	return setting


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


## The rotation (degrees) of the camera turned to `yaw`.
static func rotation(yaw := ROTATION.y) -> Vector3:
	return Vector3(ROTATION.x, yaw, ROTATION.z)


## The near (x) and far (y) clip plane of the orthographic view with `view_size` metres in
## view: round the ground in view, ORTHO_DEPTH_FRONT before it and ORTHO_DEPTH_BACK behind.
static func ortho_clip(view_size: float) -> Vector2:
	var ground_depth := view_size * ORTHO_GROUND_DEPTH
	return Vector2(maxf(distance(view_size) - ground_depth - ORTHO_DEPTH_FRONT, NEAR),
			distance(view_size) + ground_depth + ORTHO_DEPTH_BACK)


## Distance (metres) from a camera `height` metres up to the ground plane (y = 0) along its
## view direction `forward` (unit). A quarter of the far plane (`far`) when it looks (nearly)
## horizontally.
static func distance_to_ground(height: float, forward: Vector3, far: float) -> float:
	if forward.y > LEVEL_VIEW:
		return far * GROUND_FAR_SHARE
	return height / -forward.y


## Point on the ground plane (y = 0) a camera at `camera_position` looking along `forward`
## (unit) is looking at, in world metres.
static func ground_focus(camera_position: Vector3, forward: Vector3, far: float) -> Vector3:
	var focus := camera_position + forward * distance_to_ground(camera_position.y, forward, far)
	focus.y = 0.0
	return focus


## The view size (metres in view vertically) of a perspective camera with field of view
## `fov` (degrees) that is `ground_distance` metres from the ground it looks at.
static func perspective_view_size(ground_distance: float, fov: float) -> float:
	return 2.0 * ground_distance * tan(deg_to_rad(fov * 0.5))
