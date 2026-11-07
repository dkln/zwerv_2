extends Camera3D
## Free camera to look around the map (the "Camera" node of the world scene).
##
## Isometric (`isometric`): WASD or the arrow keys = pan over the map, mouse wheel = zoom
## in and out, Q/E = zoom out/in smoothly, right mouse button held = drag the map,
## Z/X = turn the view a quarter left/right, middle mouse button held = turn it freely,
## Shift = faster. The view keeps its iso angle and pans and zooms round the point on
## the ground in the middle of the screen (ISO_MIN_VIEW .. ISO_MAX_VIEW metres in view).
## Perspective: right mouse button held = look around, WASD = move, Q/E = down/up,
## Shift = faster, mouse wheel = adjust speed.
## The movement keys are the `cam_*` input actions from the project settings.

const Iso = preload("res://scripts/camera/iso_camera.gd")

## Movement speed in metres per second (changed with the mouse wheel, 1 to 200).
@export var speed := 12.0
## Mouse-look sensitivity in radians per pixel of mouse movement.
@export var sensitivity := 0.003
## Isometric view (perspective with a narrow field of view, rotated 45 degrees,
## ~35 degrees downwards; see scripts/camera/iso_camera.gd).
@export var isometric := true
## Metres in view at startup (iso view size, see scripts/camera/iso_camera.gd).
@export var iso_size := 140.0
## Iso panning speed: the share of the view it crosses per second.
@export var iso_pan_speed := 0.8
## Iso zoom step per click of the mouse wheel (view size times or divided by this).
@export var iso_zoom_step := 1.15
## Iso zoom speed with Q/E: the view size grows or shrinks this many times per second.
@export var iso_zoom_speed := 2.0
## Iso turning speed for a quarter turn with Z/X (degrees per second).
@export var iso_turn_speed := 240.0
## Iso free turning with the middle mouse button (degrees per pixel).
@export var iso_turn_sensitivity := 0.3

## Least and most metres in view when zooming the iso view.
const ISO_MIN_VIEW := 6.0
const ISO_MAX_VIEW := 600.0

var _yaw := 0.0
var _pitch := 0.0
var _iso_yaw := Iso.ROTATION.y         # where the iso view is turned now (degrees)
var _iso_target_yaw := Iso.ROTATION.y  # where a quarter turn with Z/X is heading


## Snaps to the iso view around the ground point the camera currently looks at,
## then takes over the resulting rotation for mouse look.
func _ready() -> void:
	if isometric:
		Iso.place(self, Iso.ground_focus(self), iso_size)
	_yaw = rotation.y
	_pitch = rotation.x


## Mouse look (while the right button is held) and speed changes (mouse wheel); in the
## iso view dragging the map and zooming.
func _unhandled_input(event: InputEvent) -> void:
	if isometric:
		_iso_input(event)
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			speed = minf(speed * 1.2, 200.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			speed = maxf(speed / 1.2, 1.0)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * sensitivity
		_pitch = clampf(_pitch - event.relative.y * sensitivity, -1.5, 1.5)
		rotation = Vector3(_pitch, _yaw, 0.0)


## Moves relative to the view direction (WASD) and vertically in world space (Q/E); in
## the iso view pans over the ground and zooms.
func _process(delta: float) -> void:
	if isometric:
		_iso_process(delta)
		return
	var dir := Vector3.ZERO
	dir.z += Input.get_action_strength("cam_achteruit") - Input.get_action_strength("cam_vooruit")
	dir.x += Input.get_action_strength("cam_rechts") - Input.get_action_strength("cam_links")
	var up := Input.get_action_strength("cam_omhoog") - Input.get_action_strength("cam_omlaag")
	var s := speed * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	global_position += (global_transform.basis * dir) * s * delta + Vector3.UP * up * s * delta


# ------------------------------------------------------------------ iso view

## Iso view: the right mouse button drags the map, the wheel zooms, Z/X and the middle
## mouse button turn the view.
func _iso_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_Z, KEY_X]:
		_adopt_yaw()
		var quarter := -90.0 if event.keycode == KEY_Z else 90.0
		_iso_target_yaw = snappedf(_iso_target_yaw - Iso.ROTATION.y, 90.0) + Iso.ROTATION.y + quarter
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_adopt_yaw()
		_iso_yaw -= event.relative.x * iso_turn_sensitivity
		_iso_target_yaw = _iso_yaw
		_iso_place(Iso.ground_focus(self), Iso.view_size(self))
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_iso_place(Iso.ground_focus(self), Iso.view_size(self) / iso_zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_iso_place(Iso.ground_focus(self), Iso.view_size(self) * iso_zoom_step)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		# the ground under the mouse follows it: a pixel is this many metres on the ground
		var metres_per_pixel := Iso.view_size(self) / maxf(get_viewport().get_visible_rect().size.y, 1.0)
		var ground_along := _ground_forward() / sin(deg_to_rad(-Iso.ROTATION.x))   # screen up, stretched over the tilted ground
		var shift: Vector3 = -_ground_right() * event.relative.x * metres_per_pixel + ground_along * event.relative.y * metres_per_pixel
		_iso_place(Iso.ground_focus(self) + shift, Iso.view_size(self))


## Iso view: WASD / arrow keys pan over the ground, Q/E zoom.
func _iso_process(delta: float) -> void:
	var view := Iso.view_size(self)
	var focus := Iso.ground_focus(self)
	var forward := Input.get_action_strength("cam_vooruit") - Input.get_action_strength("cam_achteruit")
	var sideways := Input.get_action_strength("cam_rechts") - Input.get_action_strength("cam_links")
	if Input.is_key_pressed(KEY_UP):
		forward += 1.0
	if Input.is_key_pressed(KEY_DOWN):
		forward -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		sideways += 1.0
	if Input.is_key_pressed(KEY_LEFT):
		sideways -= 1.0
	var zoom := Input.get_action_strength("cam_omhoog") - Input.get_action_strength("cam_omlaag")
	var turning := not is_equal_approx(_iso_yaw, _iso_target_yaw)
	if not turning:
		_adopt_yaw()
	if turning:
		_iso_yaw = move_toward(_iso_yaw, _iso_target_yaw, iso_turn_speed * delta)
	var straight := is_equal_approx(rotation_degrees.x, Iso.ROTATION.x) and is_equal_approx(rotation_degrees.z, Iso.ROTATION.z)
	if forward == 0.0 and sideways == 0.0 and zoom == 0.0 and not turning and straight:
		return
	var pan := (_ground_forward() * forward + _ground_right() * sideways).limit_length(1.0)
	var fast := 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	focus += pan * view * iso_pan_speed * fast * delta
	view *= pow(iso_zoom_speed, -zoom * fast * delta)
	_iso_place(focus, view)


## Puts the iso camera over `focus` with `view` metres in view (within the zoom limits),
## turned to the current `_iso_yaw`.
func _iso_place(focus: Vector3, view: float) -> void:
	focus.y = 0.0
	Iso.place(self, focus, clampf(view, ISO_MIN_VIEW, ISO_MAX_VIEW), _iso_yaw)


## Takes over the turn of the view when another camera (the flight, following a vehicle)
## has placed it, as long as the view looks down at the iso angle.
func _adopt_yaw() -> void:
	if is_equal_approx(rotation_degrees.x, Iso.ROTATION.x) and not is_equal_approx(rotation_degrees.y, _iso_yaw):
		_iso_yaw = rotation_degrees.y
		_iso_target_yaw = _iso_yaw


## The basis of the iso view turned to `_iso_yaw`.
func _iso_basis() -> Basis:
	return Basis.from_euler(Vector3(Iso.ROTATION.x, _iso_yaw, Iso.ROTATION.z) * PI / 180.0)


## The direction the iso camera looks in, flat over the ground.
func _ground_forward() -> Vector3:
	var forward := -_iso_basis().z
	return Vector3(forward.x, 0.0, forward.z).normalized()


## The screen's right, flat over the ground.
func _ground_right() -> Vector3:
	var right := _iso_basis().x
	return Vector3(right.x, 0.0, right.z).normalized()
