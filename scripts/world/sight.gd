extends RefCounted
## How often something in the town is updated, by where it is seen (vehicles, vehicle.gd;
## pedestrians, pedestrian.gd): what is on the screen every physics step; what is off it by
## more than OFF_SCREEN_MARGIN (a share of the screen round it) only every NEAR_STEPS steps
## (with the time of all of them at once); and what is also further than FAR_METRES from the
## point the camera looks at (or FARTHEST_METRES from a perspective camera) every FAR_STEPS
## steps. Things look again every LOOK_STEPS steps (each at its own moment, so not all at once).
## Nothing out of sight is drawn moving (no wheels turning, no walking limbs).

const Iso = preload("res://scripts/camera/iso_camera.gd")
const OFF_SCREEN_MARGIN := 0.3
const FAR_METRES := 150.0
const FARTHEST_METRES := 300.0
const NEAR_STEPS := 4
const FAR_STEPS := 8
const LOOK_STEPS := 15


## Physics steps between two updates of something at `spot`: 1 in sight, else NEAR_STEPS or
## FAR_STEPS (see above). 1 without a camera (the tools).
static func steps_between(viewport: Viewport, spot: Vector3) -> int:
	var camera := viewport.get_camera_3d() if viewport else null
	if camera == null:
		return 1
	var from_camera := camera.global_position.distance_to(spot)
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE and from_camera > FARTHEST_METRES:
		return FAR_STEPS
	if not camera.is_position_behind(spot):
		var screen := viewport.get_visible_rect()
		var grown := screen.grow_individual(screen.size.x * OFF_SCREEN_MARGIN, screen.size.y * OFF_SCREEN_MARGIN,
				screen.size.x * OFF_SCREEN_MARGIN, screen.size.y * OFF_SCREEN_MARGIN)
		if grown.has_point(camera.unproject_position(spot)):
			return 1
	var focus := Iso.ground_focus(camera)
	if Vector2(spot.x - focus.x, spot.z - focus.z).length() > FAR_METRES:
		return FAR_STEPS
	return NEAR_STEPS

