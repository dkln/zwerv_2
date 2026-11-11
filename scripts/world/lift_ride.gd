extends Node3D
## A lift ride, for any building with floors (scenes/binnen/lift.tscn, built by
## tools/build/build_interiors.gd from cabin_plan(); the city hall first,
## scripts/world/city_hall.gd). The ride is a scene of its own: the swipe, and you see yourself
## standing in the cabin (a stand-in of your character), the camera from the front, close in;
## the display behind you shows the floor the lift is at, an arrow up or down, a floor every
## FLOOR_SECONDS (the further, the longer); the motor hums while it moves (MOVING_SOUND), the
## view dips as it starts and stops; there the "ding-dong" (DING_SOUND), and under the next
## swipe the building puts you out on that floor (`arrive`). The real player is hidden
## meanwhile. Put the lift somewhere far off the map, out of sight of the rest.
##   const LIFT_SCENE := "res://scenes/binnen/lift.tscn"
##   var lift: Node3D = (load(LIFT_SCENE) as PackedScene).instantiate()
##   add_child(lift)
##   lift.position = Vector3(400, 0, 0)
##   await lift.ride(0, 3, player, func() -> void: ...)   # `arrive`: put the player on floor 3

const PlayerModel = preload("res://scripts/player/player_model.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const SignBoard = preload("res://scripts/world/sign_board.gd")
const LIBRARY := "res://assets/libraries/binnen.res"
const PREFIX := "lift/"
const DING_SOUND := "lift_ding"
const MOVING_SOUND := "lift_rijden_loop"
const MOTOR_DB := -8.0
## The ride: seconds per floor going by, and after arriving before you step out.
const FLOOR_SECONDS := 1.4
const ARRIVE_SECONDS := 0.9
## The camera: in the cabin's space, at the doors looking in at the player (from the front,
## close in), and how far the view dips as the cabin starts and stops (metres).
const CAMERA_AT := Vector3(0.0, 1.45, -1.9)
const LOOK_AT := Vector3(0.0, 1.45, 0.6)
const FOV := 48.0
const JOLT := 0.035
const DISPLAY_INK := Color("#FF6A3A")

## The floor the lift is at (during a ride the one it is passing).
var floor_number := 0
var riding := false
var _display: Node3D
var _camera: Camera3D
var _camera_before: Camera3D
var _stand_in: Node3D
var _hum: AudioStreamPlayer


## The cabin, 3 x 2 m: the doors at the front (-z, where the camera looks in from), the
## button panel on the left wall, the floor display on the back wall over the head of whoever
## stands in it. {"tiles": [[tile, at, turn]] (library binnen, without PREFIX), "floor",
## "stand", "panel_mesh": [at, turn], "display": [at, turn]}.
static func cabin_plan() -> Dictionary:
	var plan := {"floor": "cabine_vloer", "tiles": [
		["cabine_achterwand", Vector3(0.0, 0.0, 1.0), PI],
		["cabine_zijwand", Vector3(-1.5, 0.0, 0.0), PI * 0.5],
		["cabine_zijwand", Vector3(1.5, 0.0, 0.0), -PI * 0.5],
		["cabine_voorwand_laag", Vector3(-1.0, 0.0, -1.0), 0.0],
		["cabine_voorwand_laag", Vector3(1.0, 0.0, -1.0), 0.0],
	]}
	plan["stand"] = Vector3(0.0, 0.0, 0.25)
	plan["panel_mesh"] = [Vector3(-1.44, 0.0, -0.35), PI * 0.5]
	plan["display"] = [Vector3(0.0, 2.32, 0.93), PI]
	return plan


func _ready() -> void:
	var plan := cabin_plan()
	var library: MeshLibrary = load(LIBRARY)
	var panel_item := library.find_item_by_name(PREFIX + "cabine_paneel")
	if panel_item >= 0:
		var panel := MeshInstance3D.new()
		panel.name = "Knoppenpaneel"
		panel.mesh = library.get_item_mesh(panel_item)
		panel.transform = Transform3D(Basis(Vector3.UP, float(plan.panel_mesh[1])), plan.panel_mesh[0]) * library.get_item_mesh_transform(panel_item)
		add_child(panel)
	_display = SignBoard.create("0", Color("#101418"), DISPLAY_INK, 0.24, false, 1.1)
	_display.name = "Etagedisplay"
	_display.position = plan.display[0]
	_display.rotation.y = float(plan.display[1])
	add_child(_display)
	_camera = Camera3D.new()
	_camera.name = "Liftcamera"
	_camera.fov = FOV
	add_child(_camera)
	_camera.position = CAMERA_AT
	_hum = AudioStreamPlayer.new()
	_hum.name = "Liftmotor"
	_hum.stream = _sound(MOVING_SOUND, true)
	_hum.volume_db = -80.0
	add_child(_hum)
	_rest(true)


## The ride from floor `from` to `to` for `player` (see the top): `arrive` is called under
## the swipe at the end, to put the player out on that floor. `animate` false: at once.
func ride(from: int, to: int, player: Node3D, arrive: Callable, animate := true) -> void:
	if riding:
		return
	riding = true
	floor_number = from
	var swipe: Node = SwipeTransition.swipe(get_tree()) if animate else null
	if swipe:
		await swipe.covered
	_rest(false)
	_make_stand_in(player)
	if player:
		player.visible = false
	_camera_before = get_viewport().get_camera_3d()
	_camera.position = CAMERA_AT
	_camera.look_at(global_transform * LOOK_AT, Vector3.UP)
	_camera.make_current()
	var direction := 1 if to > from else -1
	_show_display(floor_number, direction if to != from else 0)
	if swipe and is_instance_valid(swipe) and swipe.has_signal("finished"):
		await swipe.finished
	if animate and to != from:
		_jolt()
		_motor(true)
	while floor_number != to:
		_show_display(floor_number, direction)
		if animate:
			await get_tree().create_timer(FLOOR_SECONDS).timeout
		floor_number += direction
	_show_display(floor_number, 0)
	_motor(false, animate)
	_ding()
	if animate:
		_jolt()
		await get_tree().create_timer(ARRIVE_SECONDS).timeout
		swipe = SwipeTransition.swipe(get_tree())
		await swipe.covered
	# out: the camera back, the player back, the building puts them on the floor
	if _stand_in and is_instance_valid(_stand_in):
		_stand_in.queue_free()
	_stand_in = null
	if _camera_before and is_instance_valid(_camera_before):
		_camera_before.make_current()
	if player:
		player.visible = true
	_rest(true)
	riding = false
	if arrive.is_valid():
		arrive.call()
	if swipe and is_instance_valid(swipe) and swipe.has_signal("finished"):
		await swipe.finished


## The text on the display ("▲ 2", "3").
func display_text() -> String:
	var label := _display.get_node_or_null("Tekst") as Label3D if _display else null
	return label.text if label else ""


func motor_running() -> bool:
	return _hum != null and _hum.playing and _hum.volume_db > -30.0


func camera() -> Camera3D:
	return _camera


func stand_in() -> Node3D:
	return _stand_in


## Not in use: hidden and still.
func _rest(resting: bool) -> void:
	visible = not resting
	process_mode = Node.PROCESS_MODE_DISABLED if resting else Node.PROCESS_MODE_INHERIT


func _make_stand_in(player: Node3D) -> void:
	if _stand_in and is_instance_valid(_stand_in):
		_stand_in.queue_free()
	var model := PlayerModel.new()
	model.name = "Speler"
	model.archetype_id = PlayerCharacter.current_id()
	model.figure_scale = float(player.get("FIGURE_SCALE")) if player and player.get("FIGURE_SCALE") != null else 0.78
	model.backpack = bool(player.get("has_backpack")) if player and player.get("has_backpack") != null else false
	model.idle = true
	add_child(model)
	model.position = cabin_plan().stand
	model.rotation.y = PI   # facing the doors (the camera)
	_stand_in = model


func _show_display(number: int, direction: int) -> void:
	var arrow := "▲ " if direction > 0 else ("▼ " if direction < 0 else "")
	SignBoard.set_text(_display, arrow + str(number))


func _jolt() -> void:
	var dip := _camera.create_tween()
	dip.tween_property(_camera, "position", CAMERA_AT - Vector3.UP * JOLT, 0.12).set_trans(Tween.TRANS_SINE)
	dip.tween_property(_camera, "position", CAMERA_AT, 0.35).set_trans(Tween.TRANS_SINE)


func _motor(running: bool, fade_out := true) -> void:
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


func _ding() -> void:
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	if audio and audio.has_method("play_event"):
		audio.play_event(_display.global_position, DING_SOUND)


## A sound of assets/audio/geluiden/ (looping or not), also when not imported yet.
static func _sound(sound_name: String, looping: bool) -> AudioStream:
	var path := "res://assets/audio/geluiden/" + sound_name + ".ogg"
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if stream == null and FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)
	if stream is AudioStreamOggVorbis:
		stream = (stream as AudioStreamOggVorbis).duplicate()
		(stream as AudioStreamOggVorbis).loop = looping
	return stream
