extends Camera3D
## Free-flying camera to look around the map (the "Camera" node of the world scene).
##
## Right mouse button held = look around, WASD = move, Q/E = down/up,
## Shift = faster, mouse wheel = adjust speed. The movement keys are the `cam_*`
## input actions from the project settings. When the tour (tour.gd) is active
## it disables this script's processing and steers the camera itself.

const Iso = preload("res://scripts/iso_camera.gd")

## Movement speed in metres per second (changed with the mouse wheel, 1 to 200).
@export var speed := 12.0
## Mouse-look sensitivity in radians per pixel of mouse movement.
@export var sensitivity := 0.003
## Isometric view (perspective with a narrow field of view, rotated 45 degrees,
## ~35 degrees downwards; see scripts/iso_camera.gd).
@export var isometric := true
## Metres in view at startup (iso view size, see scripts/iso_camera.gd).
@export var iso_size := 140.0

var _yaw := 0.0
var _pitch := 0.0


## Snaps to the iso view around the ground point the camera currently looks at,
## then takes over the resulting rotation for mouse look.
func _ready() -> void:
	if isometric:
		Iso.place(self, Iso.ground_focus(self), iso_size)
	_yaw = rotation.y
	_pitch = rotation.x


## Mouse look (while the right button is held) and speed changes (mouse wheel).
func _unhandled_input(event: InputEvent) -> void:
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


## Moves relative to the view direction (WASD) and vertically in world space (Q/E).
func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	dir.z += Input.get_action_strength("cam_achteruit") - Input.get_action_strength("cam_vooruit")
	dir.x += Input.get_action_strength("cam_rechts") - Input.get_action_strength("cam_links")
	var up := Input.get_action_strength("cam_omhoog") - Input.get_action_strength("cam_omlaag")
	var s := speed * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	global_position += (global_transform.basis * dir) * s * delta + Vector3.UP * up * s * delta
