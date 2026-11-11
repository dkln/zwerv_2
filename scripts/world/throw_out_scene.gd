extends Node3D
## Being thrown out of an interior, the part inside (Interiors.throw_out): a little scene of its
## own, far off the map, with a camera of its own. On a piece of floor and wall of the place
## (STAGES: the snack bar's tiles, the station's, the chain's, the city hall's), someone of the
## place (uitzetten.json "uitzetter" of the place: "wie" a role, dressed for it, and "kreten"
## what they shout; the snack bar owner, a BOA at Den Haag Centraal, the cashier of the chain,
## the guard of the city hall) walks up to the player, shouts, grabs them by the collar and
## lifts them off their feet (they kick and flail), and carries them off to the door; there
## `carried_out` fires, and Interiors takes it from there (the swipe, the street, the throw).
## The player is a stand-in (a PlayerModel of their character); the real one waits inside.
##   var scene := ThrowOutScene.new()
##   add_child(scene)
##   scene.start("snackbar", rules, player, hud)
##   await scene.carried_out

signal carried_out

const PlayerModel = preload("res://scripts/player/player_model.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const SpeechBalloon = preload("res://scripts/ui/widgets/speech_balloon.gd")
const Babble = preload("res://scripts/audio/babble.gd")
const LIBRARY := "res://assets/libraries/binnen.res"
## The floor, the wall and (if any) a mat at the door, per kind of place (the library binnen).
const STAGES := {
	"snackbar": ["snackbar/vloer_zwartwit", "snackbar/muur_zwartwit", "snackbar/deurmat"],
	"centraal": ["station/vloer", "station/wand_laag", ""],
	"derrek": ["supermarkt/vloer_derrek", "supermarkt/muur_derrek", ""],
	"alfred_steyhn": ["supermarkt/vloer_alfred_steyhn", "supermarkt/muur_alfred_steyhn", ""],
	"stadhuis": ["stadhuis/vloer_steen", "stadhuis/muur", "stadhuis/deurmat"],
}
## What the one who throws you out wears, per role (InteriorPerson outfit: jas, rand, broek,
## pet); the snack bar owner has the white coat of its role, a cashier the chain's clothes.
const OUTFITS := {
	"handhaver": {"jas": "#2A4A8A", "rand": "#9FC4EC", "broek": "#1E3050", "pet": "#2A4A8A"},
	"beveiliger": {"jas": "#1E2024", "rand": "#F2C200", "broek": "#1E2024", "pet": "#1E2024"},
}
const SUPERMARKETS_FILE := "res://data/gesprekken/supermarkten.json"
## Where things stand on the stage (its middle at the node; the door on the left at the front).
const PLAYER_AT := Vector3(1.0, 0.0, 0.0)
const COMES_FROM := Vector3(5.5, 0.0, 1.5)
const DOOR_WAY := [Vector3(-3.5, 0.0, -1.5), Vector3(-7.0, 0.0, -1.5)]
## How it goes: walking up (m/s), the grab (seconds, how high the player is lifted, how far
## before the one holding them), carrying (m/s).
const WALK_SPEED := 2.4
const GRAB_SECONDS := 0.9
const LIFT := 0.35
const HOLD_AHEAD := 0.5
const CARRY_SPEED := 1.9
const CAMERA_OFFSET := Vector3(6.5, 7.5, -10.5)

var _bouncer: InteriorPerson
var _stand_in: Node3D               # the player's figure (PlayerModel)
var _camera: Camera3D
var _camera_before: Camera3D
var _phase := ""                    # "naar", "pakken", "dragen", "klaar"
var _clock := 0.0
var _walk_phase := 0.0
var _way: Array = []
var _shouts: Array = []
var _hud: Node


## Builds the stage for `kind` and starts: `rules` the place's entry of uitzetten.json (its
## "uitzetter"), `player` the real player (its character), `hud` for the speech balloon.
func start(kind: String, rules: Dictionary, player: Node3D, hud: Node) -> void:
	name = "Eruitgooien"
	_hud = hud
	var thrower: Dictionary = rules.get("uitzetter", {})
	var role := String(thrower.get("wie", "beveiliger"))
	_shouts = thrower.get("kreten", ["Eruit!"])
	_build_stage(kind)
	_add_lights()
	# the player's stand-in, standing where it was caught, facing the camera a little
	var model := PlayerModel.new()
	model.name = "Speler"
	model.archetype_id = PlayerCharacter.current_id()
	model.figure_scale = float(player.get("FIGURE_SCALE")) if player and player.get("FIGURE_SCALE") != null else 0.78
	model.backpack = bool(player.get("has_backpack")) if player and player.get("has_backpack") != null else false
	model.idle = true
	_stand_in = model
	add_child(model)
	model.position = PLAYER_AT
	model.rotation.y = PI * 1.15
	# who throws them out, coming in from the back
	_bouncer = InteriorPerson.create(role, 9001, false, InteriorPerson.SEAT_HEIGHT, _outfit(kind, role))
	_bouncer.name = "Uitzetter"
	_bouncer.remove_from_group(InteriorPerson.TALKABLE_GROUP)
	add_child(_bouncer)
	_bouncer.position = COMES_FROM
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = 36.0
	add_child(_camera)
	_camera.position = PLAYER_AT + CAMERA_OFFSET
	_camera.look_at(global_transform * (PLAYER_AT + Vector3(-1.5, 0.9, -0.5)), Vector3.UP)
	_camera_before = get_viewport().get_camera_3d()
	_camera.make_current()
	_phase = "naar"
	_clock = 0.0


## The camera back to what it was (Interiors, once the street is under the swipe).
func finish() -> void:
	if _camera_before and is_instance_valid(_camera_before):
		_camera_before.make_current()


func phase() -> String:
	return _phase


func _process(delta: float) -> void:
	if _phase == "" or _phase == "klaar" or _bouncer == null:
		return
	_clock += delta
	match _phase:
		"naar":
			# up to the player, beside them on their right
			var grab_at := PLAYER_AT + Vector3(0.55, 0.0, 0.3)
			if _walk_to(grab_at, WALK_SPEED, delta):
				_phase = "pakken"
				_clock = 0.0
				_shout()
		"pakken":
			var towards := _stand_in.position - _bouncer.position
			_bouncer.rotation.y = lerp_angle(_bouncer.rotation.y, atan2(towards.x, towards.z), 1.0 - exp(-10.0 * delta))
			var lift := clampf((_clock - 0.35) / 0.3, 0.0, 1.0)
			_stand_in.position = PLAYER_AT + Vector3.UP * LIFT * lift
			_reach_for_collar()
			_struggle(lift)
			if _clock >= GRAB_SECONDS:
				_phase = "dragen"
				_clock = 0.0
				_way = DOOR_WAY.duplicate()
		"dragen":
			if _way.is_empty():
				_phase = "klaar"
				carried_out.emit()
				return
			if _walk_to(_way[0], CARRY_SPEED, delta):
				_way.pop_front()
			# held up before them by the collar, kicking
			var ahead := _bouncer.global_basis.z
			_stand_in.position = _bouncer.position + Vector3(ahead.x, 0.0, ahead.z).normalized() * HOLD_AHEAD + Vector3.UP * LIFT
			_stand_in.rotation.y = _bouncer.rotation.y
			_reach_for_collar()
			_struggle(1.0)


## A step towards `target` at `speed`, walking; true once there.
func _walk_to(target: Vector3, speed: float, delta: float) -> bool:
	var offset := target - _bouncer.position
	offset.y = 0.0
	var distance := offset.length()
	if distance < 0.05:
		_bouncer.figure.walk(_walk_phase, 0.0)
		return true
	var step := minf(speed * delta, distance)
	_bouncer.position += offset / distance * step
	_bouncer.rotation.y = lerp_angle(_bouncer.rotation.y, atan2(offset.x, offset.z), 1.0 - exp(-10.0 * delta))
	_walk_phase += step / TownsfolkFigure.STRIDE * PI
	_bouncer.figure.walk(_walk_phase, 1.0)
	return false


## Both hands out to the collar of the one in front of them.
func _reach_for_collar() -> void:
	for side: String in ["left", "right"]:
		var shoulder := _bouncer.figure.rest_joint("arm_" + side)
		_bouncer.figure.aim_arm(side, Vector3(shoulder.x * 0.6, shoulder.y + 0.05, 0.45))


## The player kicking and flailing, as much as `amount` (0..1).
func _struggle(amount: float) -> void:
	if not _stand_in.has_method("pose_limb"):
		return
	var time := _clock * 14.0
	_stand_in.call("pose_limb", "leg_left", Vector3(sin(time) * 40.0 * amount, 0.0, 0.0))
	_stand_in.call("pose_limb", "leg_right", Vector3(-sin(time) * 40.0 * amount, 0.0, 0.0))
	_stand_in.call("pose_limb", "arm_left", Vector3(-120.0 * amount + sin(time * 1.3) * 25.0 * amount, 0.0, -20.0 * amount))
	_stand_in.call("pose_limb", "arm_right", Vector3(-120.0 * amount - sin(time * 1.3) * 25.0 * amount, 0.0, 20.0 * amount))


## What they shout as they grab the player, in a speech balloon over them, in their voice.
func _shout() -> void:
	if _shouts.is_empty():
		return
	var line := String(_shouts[randi() % _shouts.size()])
	if _hud and _hud is CanvasLayer:
		var balloon := SpeechBalloon.new()
		balloon.name = "Uitzetkreet"
		balloon.head_height = 2.1
		_hud.add_child(balloon)
		balloon.follow(_bouncer, _camera)
		balloon.finished.connect(balloon.queue_free)
		tree_exiting.connect(balloon.queue_free, CONNECT_ONE_SHOT)
		balloon.say(line, 1.4)
	Babble.play_at(get_tree(), _bouncer.global_position + Vector3.UP * 1.8, _bouncer.voice(), "boos")


## The piece of the place: 12 x 8 m of its floor, its wall along the back and the left (the
## door out at the front of the left), a mat at the door.
func _build_stage(kind: String) -> void:
	var tiles: Array = STAGES.get(kind, STAGES.stadhuis)
	var library: MeshLibrary = load(LIBRARY)
	var floor_map := _grid_map("Vloer", library, Vector3(0.0, -0.125, 0.0))
	var walls := _grid_map("Inrichting", library, Vector3.ZERO)
	for x in [-4.0, 0.0, 4.0]:
		for z in [-2.0, 2.0]:
			_put(floor_map, String(tiles[0]), Vector3(x, 0.0, z), 0.0)
		_put(walls, String(tiles[1]), Vector3(x, 0.0, 4.0), PI)
	_put(walls, String(tiles[1]), Vector3(-6.0, 0.0, 2.0), PI * 0.5)
	if String(tiles[2]) != "":
		_put(walls, String(tiles[2]), Vector3(-5.5, 0.0, -1.5), PI * 0.5)


func _grid_map(map_name: String, library: MeshLibrary, at: Vector3) -> GridMap:
	var grid := GridMap.new()
	grid.name = map_name
	grid.mesh_library = library
	grid.cell_size = Vector3(0.5, 0.5, 0.5)
	grid.cell_center_x = false
	grid.cell_center_y = false
	grid.cell_center_z = false
	grid.position = at
	add_child(grid)
	return grid


func _put(grid: GridMap, item_name: String, at: Vector3, turn: float) -> void:
	var item := grid.mesh_library.find_item_by_name(item_name)
	if item < 0:
		return
	grid.set_cell_item(Vector3i(roundi(at.x * 2.0), roundi(at.y * 2.0), roundi(at.z * 2.0)), item,
		grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, turn)))


func _add_lights() -> void:
	for spot in [Vector3(-2.5, 3.0, 0.0), Vector3(2.5, 3.0, 0.0)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("#FFF1DC")
		lamp.light_energy = 1.4
		lamp.omni_range = 9.0
		add_child(lamp)
		lamp.position = spot


## The clothes of the one who throws you out: the chain's at a supermarket (supermarkten.json
## "kleding"), the role's (OUTFITS), or none (the snack bar owner has its own white coat).
static func _outfit(kind: String, role: String) -> Dictionary:
	if role == "kassamedewerker":
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SUPERMARKETS_FILE))
		if parsed is Dictionary:
			return (((parsed as Dictionary).get("ketens", {}) as Dictionary).get(kind, {}) as Dictionary).get("kleding", {})
	return OUTFITS.get(role, {})
