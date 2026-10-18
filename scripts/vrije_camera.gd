extends Camera3D
## Vrij vliegende camera om je kaart te bekijken.
## Rechtermuisknop ingedrukt = rondkijken, WASD = bewegen, Q/E = omlaag/omhoog,
## Shift = sneller, muiswiel = snelheid aanpassen.

@export var snelheid := 12.0
@export var gevoeligheid := 0.003
## Isometrische weergave (perspectief met smalle kijkhoek, 45 graden gedraaid,
## ~35 graden naar beneden; zie scripts/iso_camera.gd).
@export var isometrisch := true
## Meter in beeld bij het starten.
@export var iso_grootte := 140.0

const Iso = preload("res://scripts/iso_camera.gd")

var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	if isometrisch:
		# focus = het punt op de grond waar de camera nu naar kijkt
		var focus := global_position + (-global_transform.basis.z) * Iso.afstand_tot_grond(self)
		focus.y = 0.0
		Iso.plaats(self, focus, iso_grootte)
	_yaw = rotation.y
	_pitch = rotation.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			snelheid = minf(snelheid * 1.2, 200.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			snelheid = maxf(snelheid / 1.2, 1.0)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * gevoeligheid
		_pitch = clampf(_pitch - event.relative.y * gevoeligheid, -1.5, 1.5)
		rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	dir.z += Input.get_action_strength("cam_achteruit") - Input.get_action_strength("cam_vooruit")
	dir.x += Input.get_action_strength("cam_rechts") - Input.get_action_strength("cam_links")
	var up := Input.get_action_strength("cam_omhoog") - Input.get_action_strength("cam_omlaag")
	var s := snelheid * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	global_position += (global_transform.basis * dir) * s * delta + Vector3.UP * up * s * delta
