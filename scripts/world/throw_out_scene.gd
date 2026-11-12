extends Node3D
## Being thrown out of an interior, the part inside (Interiors.throw_out): a little scene of its
## own, far off the map, with a camera of its own. On a piece of floor and wall of the place
## (STAGES: the snack bar's tiles, the station's, the chain's, the city hall's), someone of the
## place (uitzetten.json "uitzetter" of the place: "wie" a role, dressed for it, and "kreten"
## what they shout; the snack bar owner, a BOA at Den Haag Centraal, the cashier of the chain,
## the guard of the city hall) comes for the player, now and then with helpers (HELPERS: more
## guards, a colleague, a customer lending a hand), and they carry the player off to the door
## in one of the CARRIES:
##   "kraag"  alone, from behind: by the collar and the belt, lifted and marched off;
##   "armen"  two, one at each arm, the player lifted between them, legs kicking;
##   "plank"  three, the player flat like a plank: two at the shoulders, one at the feet.
## It is seen from the front: the door is at the front of the stage, the camera inside it
## looking in, backing off before them as they come at it; sometimes someone of the place
## stands at the side and points (`_onlooker`). At the door `carried_out` fires, and
## Interiors takes it from there (the swipe, the street, the throw).
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
## Who lends a hand, per role of the one who comes for you (drawn for each helper).
const HELPERS := {
	"snackbarhouder": ["klant", "klant", "snackbarhouder"],
	"handhaver": ["handhaver", "handhaver", "beveiliger"],
	"kassamedewerker": ["beveiliger", "beveiliger", "kassamedewerker"],
	"beveiliger": ["beveiliger"],
}
## The ways of carrying (see the top) with their weights, and how many carry in each.
const CARRIES := {"kraag": 4.0, "armen": 4.0, "plank": 2.0}
const CARRIERS := {"kraag": 1, "armen": 2, "plank": 3}
## The share of the scenes with someone at the side pointing.
const ONLOOKER_CHANCE := 0.5
const SUPERMARKETS_FILE := "res://data/gesprekken/supermarkten.json"
## Where things stand on the stage (its middle at the node): the player at the back, facing
## the door at the front (-z); the carriers come from the back corners; the door way.
const PLAYER_AT := Vector3(0.0, 0.0, 3.0)
const COME_FROM := [Vector3(2.6, 0.0, 6.5), Vector3(-2.6, 0.0, 6.5), Vector3(0.6, 0.0, 7.2)]
const DOOR_Z := -6.0
## How it goes: walking up (m/s), the grab (seconds, how high the player is lifted), carrying
## (m/s); the longest the walking up may take.
const WALK_SPEED := 2.4
const GRAB_SECONDS := 1.0
const LIFT := 0.35
const PLANK_HEIGHT := 0.95
const CARRY_SPEED := 1.8
const LONGEST_WALK_UP := 4.0
## The camera: from the front, inside the door, a little to the side and above the heads,
## looking at what comes; it backs off before them, but never out of the door.
const CAMERA_BACK := 4.4
const CAMERA_HEIGHT := 1.7
const CAMERA_ASIDE := 0.7
const CAMERA_LOOK := Vector3(0.0, 1.0, 0.0)
const CAMERA_FOV := 46.0
const CAMERA_FOLLOW := 4.0

var _bouncer: InteriorPerson          # who comes for you (the place's "uitzetter")
var _carriers: Array[InteriorPerson] = []   # the bouncer first, then the helpers
var _holds: Array[Vector3] = []       # where each carrier stands, from the player's feet
var _walk_phases: Array[float] = []
var _onlooker: InteriorPerson
var _carry := "kraag"
var _stand_in: Node3D               # the player's figure (PlayerModel)
var _camera: Camera3D
var _camera_before: Camera3D
var _phase := ""                    # "naar", "pakken", "dragen", "klaar"
var _clock := 0.0
var _carried_at := PLAYER_AT          # the player's feet (lying: where the feet are)
var _shouts: Array = []
var _shouters_left: Array[InteriorPerson] = []
var _hud: Node
var _focus := Vector3.ZERO           # what the camera follows
var _random := RandomNumberGenerator.new()


## Builds the stage for `kind` and starts: `rules` the place's entry of uitzetten.json (its
## "uitzetter"), `player` the real player (its character), `hud` for the speech balloon.
func start(kind: String, rules: Dictionary, player: Node3D, hud: Node) -> void:
	name = "Eruitgooien"
	_hud = hud
	_random.randomize()
	var thrower: Dictionary = rules.get("uitzetter", {})
	var role := String(thrower.get("wie", "beveiliger"))
	_shouts = thrower.get("kreten", ["Eruit!"])
	_build_stage(kind)
	_add_lights()
	_carry = _draw_carry()
	# the player's stand-in, standing where it was caught, facing the door (and the camera)
	var model := PlayerModel.new()
	model.name = "Speler"
	model.archetype_id = PlayerCharacter.current_id()
	model.figure_scale = float(player.get("FIGURE_SCALE")) if player and player.get("FIGURE_SCALE") != null else 0.78
	model.backpack = bool(player.get("has_backpack")) if player and player.get("has_backpack") != null else false
	model.idle = true
	_stand_in = model
	add_child(model)
	model.position = PLAYER_AT
	model.rotation.y = PI
	# who comes for you and who helps, from the back
	var helper_roles: Array = HELPERS.get(role, ["beveiliger"])
	for carrier_index in CARRIERS[_carry]:
		var carrier_role := role if carrier_index == 0 else String(helper_roles[_random.randi() % helper_roles.size()])
		var carrier := InteriorPerson.create(carrier_role, 9001 + carrier_index * 37 + _random.randi() % 30, false,
				InteriorPerson.SEAT_HEIGHT, _outfit(kind, carrier_role))
		carrier.name = "Uitzetter" if carrier_index == 0 else "Helper%d" % carrier_index
		carrier.remove_from_group(InteriorPerson.TALKABLE_GROUP)
		add_child(carrier)
		carrier.position = COME_FROM[carrier_index]
		_carriers.append(carrier)
		_walk_phases.append(_random.randf() * TAU)
	_bouncer = _carriers[0]
	_holds = _holds_for(_carry)
	_shouters_left = _carriers.duplicate()
	if _random.randf() < ONLOOKER_CHANCE:
		_add_onlooker(role)
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = CAMERA_FOV
	add_child(_camera)
	_focus = PLAYER_AT
	_aim_camera()
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


## How the player is carried this time, drawn by the weights of CARRIES.
func _draw_carry() -> String:
	var total := 0.0
	for carry: String in CARRIES:
		total += float(CARRIES[carry])
	var roll := _random.randf() * total
	for carry: String in CARRIES:
		roll -= float(CARRIES[carry])
		if roll < 0.0:
			return carry
	return "kraag"


## Where each carrier stands, from the player's feet (all facing the door, -z). Lying ("plank")
## the player's head is towards the door: the shoulders some 1.1 m before the feet.
static func _holds_for(carry: String) -> Array[Vector3]:
	match carry:
		"armen":
			return [Vector3(0.55, 0.0, 0.05), Vector3(-0.55, 0.0, 0.05)]
		"plank":
			return [Vector3(0.55, 0.0, -1.0), Vector3(-0.55, 0.0, -1.0), Vector3(0.0, 0.0, 0.45)]
		_:
			return [Vector3(0.0, 0.0, 0.5)]


func _process(delta: float) -> void:
	if _phase == "" or _phase == "klaar" or _bouncer == null:
		return
	_clock += delta
	_focus = _focus.lerp(_carried_at + Vector3(0.0, 0.0, -0.4 if _carry == "plank" else 0.0), 1.0 - exp(-CAMERA_FOLLOW * delta))
	_aim_camera()
	_point_onlooker()
	match _phase:
		"naar":
			# each to their place at the player
			var all_there := true
			for carrier_index in _carriers.size():
				if not _walk_to(carrier_index, _carried_at + _holds[carrier_index], WALK_SPEED, delta):
					all_there = false
			if all_there or _clock > LONGEST_WALK_UP:
				_phase = "pakken"
				_clock = 0.0
				_shout(_bouncer)
		"pakken":
			var lift := clampf((_clock - 0.3) / 0.4, 0.0, 1.0)
			_face_all_towards_door(delta)
			_place_stand_in(lift)
			_hold_on()
			_struggle(lift)
			if _clock >= GRAB_SECONDS:
				_phase = "dragen"
				_clock = 0.0
		"dragen":
			# all together towards the door, at the camera
			_carried_at.z -= CARRY_SPEED * delta
			for carrier_index in _carriers.size():
				var carrier := _carriers[carrier_index]
				carrier.position = _carried_at + _holds[carrier_index]
				carrier.rotation.y = lerp_angle(carrier.rotation.y, PI, 1.0 - exp(-10.0 * delta))
				_walk_phases[carrier_index] += CARRY_SPEED * delta / TownsfolkFigure.STRIDE * PI
				carrier.figure.walk(_walk_phases[carrier_index], 1.0)
			_place_stand_in(1.0)
			_hold_on()
			_struggle(1.0)
			# the helpers have their say on the way
			if not _shouters_left.is_empty() and _clock > 0.9 * (_carriers.size() - _shouters_left.size()):
				_shout(_shouters_left[0])
			if _carried_at.z + minf(_holds[0].z, 0.0) < DOOR_Z + 0.3:
				_phase = "klaar"
				carried_out.emit()


## The camera before them, inside the door, looking at `_focus`.
func _aim_camera() -> void:
	var at := Vector3(_focus.x, 0.0, _focus.z)
	var camera_z := maxf(at.z - CAMERA_BACK, DOOR_Z - 1.0)
	_camera.position = Vector3(at.x + CAMERA_ASIDE, CAMERA_HEIGHT, camera_z)
	_camera.look_at(global_transform * (at + CAMERA_LOOK), Vector3.UP)


## A step of carrier `carrier_index` towards `target` at `speed`, walking; true once there.
func _walk_to(carrier_index: int, target: Vector3, speed: float, delta: float) -> bool:
	var carrier := _carriers[carrier_index]
	var offset := target - carrier.position
	offset.y = 0.0
	var distance := offset.length()
	if distance < 0.05:
		carrier.figure.walk(_walk_phases[carrier_index], 0.0)
		carrier.rotation.y = lerp_angle(carrier.rotation.y, PI, 1.0 - exp(-8.0 * delta))
		return true
	var step := minf(speed * delta, distance)
	carrier.position += offset / distance * step
	carrier.rotation.y = lerp_angle(carrier.rotation.y, atan2(offset.x, offset.z), 1.0 - exp(-10.0 * delta))
	_walk_phases[carrier_index] += step / TownsfolkFigure.STRIDE * PI
	carrier.figure.walk(_walk_phases[carrier_index], 1.0)
	return false


func _face_all_towards_door(delta: float) -> void:
	for carrier in _carriers:
		carrier.rotation.y = lerp_angle(carrier.rotation.y, PI, 1.0 - exp(-10.0 * delta))
		carrier.figure.walk(0.0, 0.0)


## The player where they are held, lifted by `lift` (0..1): upright off their feet, or flat
## on their back, head first (towards the door).
func _place_stand_in(lift: float) -> void:
	if _carry == "plank":
		_stand_in.position = _carried_at + Vector3.UP * PLANK_HEIGHT * lift
		# from standing (facing the door) to flat on the back, the head towards the door (-z)
		var standing := Quaternion(Vector3.UP, PI)
		var lying := Quaternion(Vector3.RIGHT, -PI * 0.5)
		_stand_in.basis = Basis(standing.slerp(lying, lift))
	else:
		_stand_in.position = _carried_at + Vector3.UP * LIFT * lift
		_stand_in.basis = Basis(Vector3.UP, PI)


## The hands of the carriers on the player: collar and belt, an arm each, or the shoulders
## and the ankles.
func _hold_on() -> void:
	var height := float(_stand_in.get("figure_scale")) if _stand_in.get("figure_scale") != null else 0.78
	for carrier_index in _carriers.size():
		var carrier := _carriers[carrier_index]
		var grips: Array[Vector3] = []
		match _carry:
			"kraag":
				# the left hand at the collar, the right at the belt
				grips = [_stand_in.global_position + Vector3(0.05, 1.75 * height, 0.12),
						_stand_in.global_position + Vector3(-0.05, 1.05 * height, 0.15)]
			"armen":
				# both hands round the upper arm on their side
				var arm_at := _stand_in.global_position + Vector3(signf(_holds[carrier_index].x) * 0.28, 1.45 * height, 0.0)
				grips = [arm_at + Vector3(0.0, 0.06, 0.0), arm_at - Vector3(0.0, 0.08, 0.0)]
			"plank":
				var under := _stand_in.global_position + Vector3(0.0, -0.05, 0.0)
				if carrier_index < 2:
					# under the shoulders
					var shoulders := under + Vector3(signf(_holds[carrier_index].x) * 0.2, 0.0, -1.3 * height)
					grips = [shoulders, shoulders + Vector3(0.0, 0.0, 0.15)]
				else:
					# an ankle in each hand
					grips = [under + Vector3(0.12, 0.0, 0.0), under + Vector3(-0.12, 0.0, 0.0)]
		var sides := ["left", "right"]
		for side_index in sides.size():
			carrier.figure.aim_arm(sides[side_index], carrier.figure.to_local(grips[side_index]))


## The player kicking and flailing, as much as `amount` (0..1); held by the arms, those stay
## out to the sides, flat on their back the legs kick up.
func _struggle(amount: float) -> void:
	if not _stand_in.has_method("pose_limb"):
		return
	var time := _clock * 14.0
	var kick := 40.0 if _carry != "plank" else 25.0
	_stand_in.call("pose_limb", "leg_left", Vector3(sin(time) * kick * amount, 0.0, 0.0))
	_stand_in.call("pose_limb", "leg_right", Vector3(-sin(time) * kick * amount, 0.0, 0.0))
	match _carry:
		"armen":
			_stand_in.call("pose_limb", "arm_left", Vector3(-20.0 * amount, 0.0, -70.0 * amount + sin(time * 1.3) * 8.0 * amount))
			_stand_in.call("pose_limb", "arm_right", Vector3(-20.0 * amount, 0.0, 70.0 * amount - sin(time * 1.3) * 8.0 * amount))
		"plank":
			_stand_in.call("pose_limb", "arm_left", Vector3(-150.0 * amount + sin(time * 1.1) * 30.0 * amount, 0.0, -10.0 * amount))
			_stand_in.call("pose_limb", "arm_right", Vector3(-150.0 * amount - sin(time * 1.1) * 30.0 * amount, 0.0, 10.0 * amount))
		_:
			_stand_in.call("pose_limb", "arm_left", Vector3(-120.0 * amount + sin(time * 1.3) * 25.0 * amount, 0.0, -20.0 * amount))
			_stand_in.call("pose_limb", "arm_right", Vector3(-120.0 * amount - sin(time * 1.3) * 25.0 * amount, 0.0, 20.0 * amount))


## Someone of the place at the side, watching and pointing at the player (a customer at a
## supermarket or the snack bar, a traveller at the station).
func _add_onlooker(role: String) -> void:
	var onlooker_role := "klant" if role != "handhaver" else "reiziger"
	_onlooker = InteriorPerson.create(onlooker_role, 4400 + _random.randi() % 500, false)
	_onlooker.name = "Toeschouwer"
	_onlooker.remove_from_group(InteriorPerson.TALKABLE_GROUP)
	add_child(_onlooker)
	var side := 1.0 if _random.randf() < 0.5 else -1.0
	_onlooker.position = Vector3(side * 3.2, 0.0, -1.5 + _random.randf() * 2.0)


func _point_onlooker() -> void:
	if _onlooker == null:
		return
	var towards := _stand_in.global_position - _onlooker.global_position
	_onlooker.rotation.y = atan2(towards.x, towards.z)
	# one arm stretched out at the player (pointing), the other at the mouth
	var target := _stand_in.global_position + Vector3.UP * 1.2
	var shoulder := _onlooker.figure.to_global(_onlooker.figure.rest_joint("arm_right"))
	_onlooker.figure.aim_arm("right", _onlooker.figure.to_local(shoulder + (target - shoulder).normalized() * 0.7))
	_onlooker.figure.aim_arm("left", _onlooker.figure.rest_joint("arm_left") + Vector3(0.1, 0.25, 0.2))


## What `shouter` shouts, in a speech balloon over them, in their voice (the bouncer from the
## place's "kreten", helpers too).
func _shout(shouter: InteriorPerson) -> void:
	_shouters_left.erase(shouter)
	if _shouts.is_empty():
		return
	var line := String(_shouts[_random.randi() % _shouts.size()])
	if _hud and _hud is CanvasLayer:
		var balloon := SpeechBalloon.new()
		balloon.name = "Uitzetkreet"
		balloon.head_height = 2.1
		_hud.add_child(balloon)
		balloon.follow(shouter, _camera)
		balloon.finished.connect(balloon.queue_free)
		tree_exiting.connect(balloon.queue_free, CONNECT_ONE_SHOT)
		balloon.say(line, 1.4)
	Babble.play_at(get_tree(), shouter.global_position + Vector3.UP * 1.8, shouter.voice(), "boos")


## The piece of the place: 12 x 16 m of its floor, its wall along the back and both sides, the
## door at the front (open: the camera stands there), a mat at the door.
func _build_stage(kind: String) -> void:
	var tiles: Array = STAGES.get(kind, STAGES.stadhuis)
	var library: MeshLibrary = load(LIBRARY)
	var floor_map := _grid_map("Vloer", library, Vector3(0.0, -0.125, 0.0))
	var walls := _grid_map("Inrichting", library, Vector3.ZERO)
	for x in [-4.0, 0.0, 4.0]:
		for z in [-6.0, -2.0, 2.0, 6.0]:
			_put(floor_map, String(tiles[0]), Vector3(x, 0.0, z), 0.0)
		_put(walls, String(tiles[1]), Vector3(x, 0.0, 8.0), PI)
	for z in [-6.0, -2.0, 2.0, 6.0]:
		_put(walls, String(tiles[1]), Vector3(-6.0, 0.0, z), PI * 0.5)
		_put(walls, String(tiles[1]), Vector3(6.0, 0.0, z), -PI * 0.5)
	if String(tiles[2]) != "":
		_put(walls, String(tiles[2]), Vector3(0.0, 0.0, DOOR_Z + 0.5), 0.0)


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
	for spot in [Vector3(-2.5, 3.0, -2.0), Vector3(2.5, 3.0, -2.0), Vector3(0.0, 3.0, 4.0)]:
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
