extends Node
## What you see and hear of a lift ride (graphics, docs/CODE_LAGEN.md): the button panel,
## the floor display, the camera of the ride, the stand-in of the player and the hum of the
## motor, all built into the cabin (build: as children of the cabin itself, so they keep
## their names there: Knoppenpaneel, Etagedisplay, Liftcamera, Liftmotor, Speler); the dip
## of the view, the motor fading in and out, the "ding-dong". It decides nothing: the
## behaviour (lift_ride.gd) says what to show. Where things stand: lift_ride_layout.gd.
##   const LiftRideView = preload("res://scripts/world/interiors/lift_ride_view.gd")

const LiftRideLayout = preload("res://scripts/world/interiors/lift_ride_layout.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")
const SignBoard = preload("res://scripts/world/things/sign_board.gd")
const SoundFiles = preload("res://scripts/audio/sound_files.gd")
const LIBRARY := "res://assets/libraries/binnen.res"
const PREFIX := "lift/"
const DING_SOUND := "lift_ding"
const MOVING_SOUND := "lift_rijden_loop"
const MOTOR_DB := -8.0
const FOV := 48.0
const DISPLAY_PLATE := Color("#101418")
const DISPLAY_INK := Color("#FF6A3A")

## The camera of the ride and the stand-in of the player (null when nobody rides).
var camera: Camera3D
var stand_in: Node3D

var _cabin: Node3D
var _display: Node3D
var _camera_before: Camera3D
var _hum: AudioStreamPlayer


func _init() -> void:
	name = "Beeld"


## Builds the panel, the display, the camera and the motor's hum into `cabin`.
func build(cabin: Node3D) -> void:
	_cabin = cabin
	var plan := LiftRideLayout.cabin_plan()
	var library: MeshLibrary = load(LIBRARY)
	var panel_item := library.find_item_by_name(PREFIX + "cabine_paneel")
	if panel_item >= 0:
		var panel := MeshInstance3D.new()
		panel.name = "Knoppenpaneel"
		panel.mesh = library.get_item_mesh(panel_item)
		panel.transform = Transform3D(Basis(Vector3.UP, float(plan.panel_mesh[1])), plan.panel_mesh[0]) * library.get_item_mesh_transform(panel_item)
		cabin.add_child(panel)
	_display = SignBoard.create("0", DISPLAY_PLATE, DISPLAY_INK, 0.24, false, 1.1)
	_display.name = "Etagedisplay"
	_display.position = plan.display[0]
	_display.rotation.y = float(plan.display[1])
	cabin.add_child(_display)
	camera = Camera3D.new()
	camera.name = "Liftcamera"
	camera.fov = FOV
	cabin.add_child(camera)
	camera.position = LiftRideLayout.CAMERA_AT
	_hum = AudioStreamPlayer.new()
	_hum.name = "Liftmotor"
	_hum.stream = sound(MOVING_SOUND, true)
	_hum.volume_db = -80.0
	cabin.add_child(_hum)


## Writes `text` on the display ("▲ 2", "3").
func show_display(text: String) -> void:
	SignBoard.set_text(_display, text)


## The text on the display now.
func display_text() -> String:
	var label := _display.get_node_or_null("Tekst") as Label3D if _display else null
	return label.text if label else ""


## The view of the ride: the camera of the lift at the doors, looking in (the camera that
## was current is kept for show_usual_camera).
func show_cabin_camera() -> void:
	_camera_before = camera.get_viewport().get_camera_3d()
	camera.position = LiftRideLayout.CAMERA_AT
	camera.look_at(_cabin.global_transform * LiftRideLayout.LOOK_AT, Vector3.UP)
	camera.make_current()


## The camera of before the ride again.
func show_usual_camera() -> void:
	if _camera_before and is_instance_valid(_camera_before):
		_camera_before.make_current()


## You in the cabin: a figure of the character `archetype_id` at `figure_scale`, with or
## without its coat, facing the doors (the camera).
func show_stand_in(archetype_id: String, figure_scale: float, coat: bool) -> void:
	hide_stand_in()
	var model := PlayerModel.new()
	model.name = "Speler"
	model.archetype_id = archetype_id
	model.figure_scale = figure_scale
	model.coat = coat
	model.idle = true
	_cabin.add_child(model)
	model.position = LiftRideLayout.cabin_plan().stand
	model.rotation.y = PI
	stand_in = model


## The stand-in gone.
func hide_stand_in() -> void:
	if stand_in and is_instance_valid(stand_in):
		stand_in.queue_free()
	stand_in = null


## The view dips as the cabin starts or stops.
func play_jolt() -> void:
	var dip := camera.create_tween()
	dip.tween_property(camera, "position", LiftRideLayout.camera_dipped(), 0.12).set_trans(Tween.TRANS_SINE)
	dip.tween_property(camera, "position", LiftRideLayout.CAMERA_AT, 0.35).set_trans(Tween.TRANS_SINE)


## The motor's hum fades in (`running`) or out; `fade_out` false: silent at once.
func play_motor(running: bool, fade_out := true) -> void:
	if _hum == null or _hum.stream == null or not is_inside_tree():
		return
	if not running and not fade_out:
		_hum.stop()
		return
	if running and not _hum.playing:
		_hum.volume_db = -30.0
		_hum.play()
	var fade := _hum.create_tween()
	fade.tween_property(_hum, "volume_db", MOTOR_DB if running else -40.0, 0.4 if running else 0.5)
	if not running:
		fade.tween_callback(_hum.stop)


## Whether the motor is heard now.
func motor_running() -> bool:
	return _hum != null and _hum.playing and _hum.volume_db > -30.0


## The "ding-dong" of arriving, from the display.
func play_ding() -> void:
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	if audio and audio.has_method("play_event"):
		audio.play_event(_display.global_position, DING_SOUND)


## A sound of assets/audio/geluiden/ (looping or not), also when not imported yet.
static func sound(sound_name: String, looping: bool) -> AudioStream:
	var path: String = SoundFiles.path_of(sound_name)
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if stream == null and FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)
	if stream is AudioStreamOggVorbis:
		stream = (stream as AudioStreamOggVorbis).duplicate()
		(stream as AudioStreamOggVorbis).loop = looping
	return stream
