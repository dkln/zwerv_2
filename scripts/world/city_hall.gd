extends "res://scripts/world/interior.gd"
## The city hall on the Spui (scenes/binnen/stadhuis.tscn, built by
## tools/build/build_interiors.gd from scripts/world/city_hall_layout.gd, editable by hand
## after): five floors, Etage0..Etage4, side by side in the scene; only the floor the player is
## on is shown (plan_root: its floor plan on the minimap). You come in on floor 0, the hall
## with the reception.
## The lift: before its doors on every floor (the marker Lift) [E] "Lift": the story box asks
## which floor (the floors with their names). Then the ride, a scene of its own (ride): the
## doors slide open, the swipe, and you see yourself standing in the lift cabin (Liftcabine:
## steel, a mirror, the button panel), the camera from the front, close in, and on the display
## behind you the floor the lift is at, an arrow up or down, a floor every FLOOR_SECONDS; there
## the "ding-dong", the swipe, and you step out of the lift on that floor as its doors slide
## open (the floor at the top of the screen: GameHud.show_notice). Over the doors on every
## floor its number.
## The people (the markers Persoon_<n>: metadata "role", "sit", "seat") are made the first
## time you come onto their floor: the receptionists, the guard, the civil servants, the
## council and the mayor talk as themselves (data/gesprekken/personeel.json), visitors as the
## people in the street. Signs (Bord_<n>, metadata "text") in the city's green. At
## Burgerzaken you take a number at the machine ([E] "Nummertje trekken") and the boards over
## the counters (Loket_<n>) call the next numbers now and then.

const Layout = preload("res://scripts/world/city_hall_layout.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const InteriorSpot = preload("res://scripts/world/interior_spot.gd")
const SignBoard = preload("res://scripts/world/sign_board.gd")
const LIBRARY := "res://assets/libraries/binnen.res"
const LIFT_SOUND := "lift_ding"
## The doors: how far each leaf slides aside (metres) and how long that takes (seconds).
const DOOR_LEAF := 0.75
const DOOR_SLIDE := 0.5
## The city's colours on the signs, and the lit numbers.
const SIGN_PLATE := Color("#2E7D32")
const SIGN_INK := Color("#FFFFFF")
const DISPLAY_INK := Color("#FF6A3A")
## How often a counter calls the next number (seconds).
const CALL_EVERY := Vector2(14.0, 30.0)
const NOTICE_HEADING := "— ETAGE %d —"
## The ride: seconds per floor going by, and after arriving before you step out.
const FLOOR_SECONDS := 1.4
const ARRIVE_SECONDS := 0.9
## The camera of the ride: in the cabin's space, at the doors looking in at the player (from
## the front, close in), and how far the view dips as the cabin starts and stops (metres).
const CABIN_CAMERA_AT := Vector3(0.0, 1.45, -1.9)
const CABIN_LOOK_AT := Vector3(0.0, 1.45, 0.6)
const CABIN_FOV := 48.0
const JOLT := 0.035
## The motor while the lift moves (assets/audio/geluiden/, tools/megadrive/geluiden.py).
const MOVING_SOUND := "lift_rijden_loop"
const MOTOR_DB := -8.0
const PlayerModel = preload("res://scripts/player/player_model.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

var current_floor := 0
var _floors: Array[Node3D] = []
var _people_made := {}               # floor number -> true
var _doors := {}                     # floor number -> [left leaf, right leaf]
var _riding := false
var _player: Node3D
var in_cabin := false                # the player is in the lift cabin
var cabin_floor := 0                 # the floor the cabin is at
var _cabin: Node3D
var _display: Node3D                 # the floor display in the cabin
var _cabin_camera: Camera3D
var _camera_before: Camera3D
var _stand_in: Node3D                # the player's figure in the cabin during the ride
var _hum: AudioStreamPlayer          # the motor of the lift
var _number_taken := 0
var _next_number := 41
var _call_clock := 10.0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.seed = 2026
	var number := 0
	while has_node("Etage%d" % number):
		_floors.append(get_node("Etage%d" % number) as Node3D)
		number += 1
	for floor_node in _floors:
		_dress_floor(floor_node)
	_cabin = get_node_or_null("Liftcabine") as Node3D
	_dress_cabin()
	_show_floor(0)


## The floor of `number` (its node: Etage<number>).
func floor_node(number: int) -> Node3D:
	return _floors[clampi(number, 0, _floors.size() - 1)]


func floor_count() -> int:
	return _floors.size()


func plan_root() -> Node3D:
	if in_cabin and _cabin:
		return _cabin
	return floor_node(current_floor) if not _floors.is_empty() else null


## Every time you come in: on floor 0, the people of the hall there.
func dress(bar_name: String, _seed: int) -> void:
	snack_bar_name = bar_name
	_riding = false
	in_cabin = false
	_show_floor(0)
	_make_people(0)
	for floor_number in _doors:
		_set_doors(int(floor_number), true, false)


func player_came_in(player: Node3D) -> void:
	_player = player


func player_went_out() -> void:
	_riding = false
	in_cabin = false


## The lift, the doors, the floor display, the signs, the number machine and the boards of
## a floor (not its people: _make_people, the first time you are there).
func _dress_floor(floor_node: Node3D) -> void:
	var number := _floors.find(floor_node)
	var lift := floor_node.get_node_or_null("Lift") as Node3D
	if lift:
		var spot: Node3D = InteriorSpot.create("Liftknop", lift.position, "Lift", _call_lift.bind(number))
		floor_node.add_child(spot)
	var door_marker := floor_node.get_node_or_null("Liftdeur") as Node3D
	if door_marker:
		var library: MeshLibrary = load(LIBRARY)
		var item := library.find_item_by_name("stadhuis/lift_deur")
		var leaves: Array[Node3D] = []
		for side in [-1.0, 1.0]:
			var leaf := Node3D.new()
			leaf.name = "Liftdeur_links" if side < 0.0 else "Liftdeur_rechts"
			leaf.transform = door_marker.transform
			leaf.set_meta("side", side)
			leaf.set_meta("home", door_marker.position)
			if item >= 0:
				var mesh_node := MeshInstance3D.new()
				mesh_node.mesh = library.get_item_mesh(item)
				mesh_node.transform = library.get_item_mesh_transform(item)
				mesh_node.position.x += side * DOOR_LEAF * 0.5
				leaf.add_child(mesh_node)
			floor_node.add_child(leaf)
			leaves.append(leaf)
		_doors[number] = leaves
		_set_doors(number, false, false)
		# the floor display over the doors
		var display: Node3D = SignBoard.create(str(number) if number > 0 else "0", Color("#101418"), DISPLAY_INK, 0.2, false, 0.9)
		display.name = "Etagedisplay"
		display.transform = door_marker.transform
		display.position += Vector3(0.0, 2.6, 0.0) + door_marker.transform.basis.z * -0.02
		floor_node.add_child(display)
	for child in floor_node.get_children():
		if child is Marker3D and child.name.begins_with("Bord_"):
			var board: Node3D = SignBoard.create(String(child.get_meta("text", "")), SIGN_PLATE, SIGN_INK)
			board.transform = (child as Node3D).transform
			floor_node.add_child(board)
		elif child is Marker3D and child.name.begins_with("Loket_"):
			var display: Node3D = SignBoard.create("B %03d" % (_next_number - 4 + int(String(child.name).trim_prefix("Loket_"))),
				Color("#101418"), DISPLAY_INK, 0.12, false, 1.3)
			display.name = "Nummerbord_" + String(child.name).trim_prefix("Loket_")
			display.transform = (child as Node3D).transform
			floor_node.add_child(display)
	var dispenser := floor_node.get_node_or_null("Nummerautomaat") as Node3D
	if dispenser:
		floor_node.add_child(InteriorSpot.create("Nummertje", dispenser.position, "Nummertje trekken", _take_number))


## The people of floor `number`, made once.
func _make_people(number: int) -> void:
	if _people_made.has(number) or _floors.is_empty():
		return
	_people_made[number] = true
	var floor_node := floor_node(number)
	var index := 0
	for child in floor_node.get_children():
		if not (child is Marker3D and child.name.begins_with("Persoon_")):
			continue
		var role := String(child.get_meta("role", "klant"))
		var sit := bool(child.get_meta("sit", false))
		var seat := float(child.get_meta("seat", InteriorPerson.SEAT_HEIGHT))
		var person := InteriorPerson.create(role, 7000 + number * 100 + index, sit, seat, _outfit(role))
		person.name = role.capitalize().replace(" ", "")
		person.role = role
		floor_node.add_child(person)
		person.transform = (child as Node3D).transform
		_people.append(person)
		index += 1


## What who works here wears: the receptionists in the city's green, the guard in black
## with yellow, the mayor in dark blue; civil servants and visitors their own clothes.
static func _outfit(role: String) -> Dictionary:
	match role:
		"receptioniste":
			return {"jas": "#2E7D32", "rand": "#F2C200", "broek": "#22242A"}
		"beveiliger":
			return {"jas": "#1E2024", "rand": "#F2C200", "broek": "#1E2024", "pet": "#1E2024"}
		"burgemeester":
			return {"jas": "#1A2440", "rand": "#C9A23A", "broek": "#1A2440"}
		"raadslid":
			return {"jas": "#3A3E48", "rand": "#E8E6E0", "broek": "#2A2C32"}
	return {}


## Only floor `number` shown and live; the others and the cabin hidden and still (far apart,
## they do not meet anyway).
func _show_floor(number: int) -> void:
	current_floor = clampi(number, 0, maxi(_floors.size() - 1, 0))
	for index in _floors.size():
		var floor_node := _floors[index]
		floor_node.visible = index == current_floor
		floor_node.process_mode = Node.PROCESS_MODE_INHERIT if index == current_floor else Node.PROCESS_MODE_DISABLED
	if _cabin:
		_cabin.visible = false
		_cabin.process_mode = Node.PROCESS_MODE_DISABLED


## Only the cabin shown and live.
func _show_cabin() -> void:
	for floor_node in _floors:
		floor_node.visible = false
		floor_node.process_mode = Node.PROCESS_MODE_DISABLED
	if _cabin:
		_cabin.visible = true
		_cabin.process_mode = Node.PROCESS_MODE_INHERIT


# ------------------------------------------------------------------ the lift

## The cabin (Liftcabine): the panel on its wall, the display on its back wall, its camera
## (from the front, close in on whoever stands in it). No one walks in it: the ride is a little
## scene of its own (ride), with a stand-in of the player in it.
func _dress_cabin() -> void:
	if _cabin == null:
		return
	var library: MeshLibrary = load(LIBRARY)
	var panel_place := _cabin.get_node_or_null("Paneelkast") as Node3D
	var panel_item := library.find_item_by_name("stadhuis/liftcabine_paneel")
	if panel_place and panel_item >= 0:
		var panel := MeshInstance3D.new()
		panel.name = "Knoppenpaneel"
		panel.mesh = library.get_item_mesh(panel_item)
		panel.transform = panel_place.transform * library.get_item_mesh_transform(panel_item)
		_cabin.add_child(panel)
	var display_place := _cabin.get_node_or_null("Display") as Node3D
	if display_place:
		_display = SignBoard.create("0", Color("#101418"), DISPLAY_INK, 0.24, false, 1.1)
		_display.name = "Etagedisplay"
		_display.transform = display_place.transform
		_cabin.add_child(_display)
	_cabin_camera = Camera3D.new()
	_cabin_camera.name = "Liftcamera"
	_cabin_camera.fov = CABIN_FOV
	_cabin.add_child(_cabin_camera)
	_cabin_camera.position = CABIN_CAMERA_AT
	_hum = AudioStreamPlayer.new()
	_hum.name = "Liftmotor"
	_hum.stream = _sound(MOVING_SOUND, true)
	_hum.volume_db = -80.0
	_cabin.add_child(_hum)


static func _floor_label(number: int) -> String:
	return "begane grond" if number == 0 else "etage %d" % number


## [E] at the lift on floor `from`: which floor? (the story box), then the ride.
func _call_lift(from: int) -> void:
	if _riding:
		return
	var hud := _hud()
	if hud == null or not hud.has_method("show_story"):
		ride((from + 1) % maxi(_floors.size(), 1), false)
		return
	var choices: Array = []
	for index in _floors.size():
		var label := ("Begane grond" if index == 0 else "%de etage" % index) + " · " + String(Layout.NAMES[index] if index < Layout.NAMES.size() else "")
		choices.append(label + ("  (hier)" if index == from else ""))
	var chosen := [-1]
	var page := {"kind": "verhaal", "speaker": "LIFT", "text": "Ding. De liftdeuren gaan open. Naar welke etage?", "choices": choices}
	page["on_choice"] = func(choice: int) -> Array:
		chosen[0] = choice
		return []
	UiSounds.play(self, "kies", -6.0)
	hud.show_story([page], func() -> void:
		if chosen[0] >= 0 and chosen[0] != current_floor:
			ride(int(chosen[0])))


## The ride to floor `to`, a scene of its own: the doors of this floor open, the swipe, and you
## see yourself in the lift (the camera from the front, close in), the display behind you
## counting the floors by with an arrow, a floor every FLOOR_SECONDS; there the ding, the
## swipe, and you step out of the lift on that floor as its doors open. `animate` false: at
## once (the checks).
func ride(to: int, animate := true) -> void:
	if _riding or to == current_floor or to < 0 or to >= _floors.size():
		return
	_riding = true
	var from := current_floor
	if animate:
		_ding(floor_node(from).get_node_or_null("Lift") as Node3D)
		_set_doors(from, true, true)
		await get_tree().create_timer(DOOR_SLIDE + 0.1).timeout
	var swipe: Node = SwipeTransition.swipe(get_tree()) if animate else null
	if swipe:
		await swipe.covered
	# in the lift: the cabin, the player's stand-in in it, its camera
	in_cabin = true
	cabin_floor = from
	_show_cabin()
	_make_stand_in()
	if _player:
		_player.visible = false
	_camera_before = get_viewport().get_camera_3d()
	if _cabin_camera:
		_cabin_camera.look_at(_cabin.global_transform * CABIN_LOOK_AT, Vector3.UP)
		_cabin_camera.make_current()
	var hud := _hud()
	if hud and hud.has_method("show_interior_plan"):
		hud.show_interior_plan(self, plan_points())
	var direction := 1 if to > from else -1
	_show_display(cabin_floor, direction)
	if swipe and is_instance_valid(swipe) and swipe.has_signal("finished"):
		await swipe.finished
	if animate:
		_jolt()
		_motor(true)
	# floor by floor (the further, the longer)
	while cabin_floor != to:
		_show_display(cabin_floor, direction)
		if animate:
			await get_tree().create_timer(FLOOR_SECONDS).timeout
		cabin_floor += direction
	_show_display(cabin_floor, 0)
	_motor(false)
	_ding(_display)
	if animate:
		_jolt()
		await get_tree().create_timer(ARRIVE_SECONDS).timeout
		swipe = SwipeTransition.swipe(get_tree())
		await swipe.covered
	# out on the floor
	in_cabin = false
	if _stand_in and is_instance_valid(_stand_in):
		_stand_in.queue_free()
	_stand_in = null
	if _camera_before and is_instance_valid(_camera_before):
		_camera_before.make_current()
	if _player:
		_player.visible = true
	_make_people(to)
	_set_doors(to, true, false)
	_show_floor(to)
	var lift := floor_node(to).get_node_or_null("Lift") as Node3D
	_move_player(lift)
	if hud and hud.has_method("show_notice"):
		hud.show_notice(NOTICE_HEADING % to if to > 0 else "— BEGANE GROND —", String(Layout.NAMES[to]))
	if swipe and is_instance_valid(swipe) and swipe.has_signal("finished"):
		await swipe.finished
	_riding = false


## The "ding-dong" of the doors opening, at `where` (the lift of a floor, the cabin's display).
func _ding(where: Node3D) -> void:
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	if audio and audio.has_method("play_event") and where:
		audio.play_event(where.global_position, LIFT_SOUND)


## The motor of the lift humming while it moves (fading in, fading out as it stops).
func _motor(running: bool) -> void:
	if _hum == null or _hum.stream == null:
		return
	if running and not _hum.playing:
		_hum.volume_db = -30.0
		_hum.play()
	var fade := _hum.create_tween()
	fade.tween_property(_hum, "volume_db", MOTOR_DB if running else -40.0, 0.4 if running else 0.5)
	if not running:
		fade.tween_callback(_hum.stop)


func motor_running() -> bool:
	return _hum != null and _hum.playing and _hum.volume_db > -30.0


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


## The player's figure standing in the cabin, facing the camera (the real one waits outside).
func _make_stand_in() -> void:
	if _stand_in and is_instance_valid(_stand_in):
		_stand_in.queue_free()
	var model := PlayerModel.new()
	model.name = "Speler"
	model.archetype_id = PlayerCharacter.current_id()
	model.figure_scale = float(_player.get("FIGURE_SCALE")) if _player and _player.get("FIGURE_SCALE") != null else 0.78
	model.backpack = bool(_player.get("has_backpack")) if _player and _player.get("has_backpack") != null else false
	model.idle = true
	_cabin.add_child(model)
	var stand := _cabin.get_node_or_null("Instap") as Node3D
	model.position = stand.position if stand else Vector3.ZERO
	model.rotation.y = PI   # facing the doors (the camera)
	_stand_in = model


## The cabin starting or stopping: the view dips a little and comes back.
func _jolt() -> void:
	if _cabin_camera == null:
		return
	var rest := _cabin_camera.position
	var dip := _cabin_camera.create_tween()
	dip.tween_property(_cabin_camera, "position", rest - Vector3.UP * JOLT, 0.12).set_trans(Tween.TRANS_SINE)
	dip.tween_property(_cabin_camera, "position", rest, 0.35).set_trans(Tween.TRANS_SINE)


## The player put at `marker` (its place and the way it faces), the camera and the minimap
## with it (Interiors.move_inside).
func _move_player(marker: Node3D) -> void:
	if marker == null:
		return
	var interiors := get_parent()
	if interiors and interiors.has_method("move_inside"):
		interiors.move_inside(marker.global_position, marker.global_basis.z, plan_points())
	elif _player:
		_player.global_position = marker.global_position


## The display in the cabin: the floor (0 the ground floor), an arrow up or down while going.
func _show_display(number: int, direction: int) -> void:
	if _display == null:
		return
	var arrow := "▲ " if direction > 0 else ("▼ " if direction < 0 else "")
	SignBoard.set_text(_display, arrow + str(number))


func display_text() -> String:
	var label := _display.get_node_or_null("Tekst") as Label3D if _display else null
	return label.text if label else ""


func is_riding() -> bool:
	return _riding


## The points the minimap marks on this floor: the way out on floor 0, the lift everywhere;
## in the cabin its doors.
func plan_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	if in_cabin and _cabin and _cabin.has_node("Uitstap"):
		points.append((_cabin.get_node("Uitstap") as Node3D).global_position)
		return points
	if current_floor == 0 and has_node("Deur"):
		points.append((get_node("Deur") as Node3D).global_position)
	var lift := floor_node(current_floor).get_node_or_null("Lift") as Node3D
	if lift:
		points.append(lift.global_position)
	return points


## The doors of the lift on floor `number` open or shut, sliding (`animate`) or at once.
func _set_doors(number: int, open: bool, animate: bool) -> void:
	for leaf: Node3D in _doors.get(number, []):
		var side := float(leaf.get_meta("side", 1.0))
		var home: Vector3 = leaf.get_meta("home", leaf.position)
		var aside := leaf.transform.basis.x * side * (DOOR_LEAF if open else 0.0)
		# the leaves slide along the front of the lift (its x), from the middle outwards
		var goal := home + aside
		if animate:
			leaf.create_tween().tween_property(leaf, "position", goal, DOOR_SLIDE).set_trans(Tween.TRANS_SINE)
		else:
			leaf.position = goal


func doors_open(number: int) -> bool:
	var leaves: Array = _doors.get(number, [])
	if leaves.is_empty():
		return false
	var leaf: Node3D = leaves[0]
	return leaf.position.distance_to(leaf.get_meta("home", leaf.position)) > DOOR_LEAF * 0.5


# ------------------------------------------------------------------ Burgerzaken

## A number from the machine: it floats up, and the boards will call it in a while.
func _take_number() -> void:
	_number_taken = _next_number + 3 + _random.randi() % 4
	var hud := _hud()
	if hud and hud.has_method("show_floating_number") and _player:
		hud.show_floating_number(_player.global_position + Vector3.UP * 2.0, "Uw nummer: B %03d" % _number_taken, Color("#FFE9B8"), 15)
	UiSounds.play(self, "kies", -4.0)


func number_taken() -> int:
	return _number_taken


func _process(delta: float) -> void:
	if current_floor != 1:
		return
	_call_clock -= delta
	if _call_clock > 0.0:
		return
	_call_clock = _random.randf_range(CALL_EVERY.x, CALL_EVERY.y)
	var boards := floor_node(1).get_children().filter(func(node: Node) -> bool: return node.name.begins_with("Nummerbord_"))
	if boards.is_empty():
		return
	var board: Node3D = boards[_random.randi() % boards.size()]
	SignBoard.set_text(board, "B %03d" % _next_number)
	if _number_taken == _next_number:
		var hud := _hud()
		if hud and hud.has_method("show_floating_number") and _player:
			hud.show_floating_number(_player.global_position + Vector3.UP * 2.2,
				"B %03d: naar loket %s" % [_next_number, String(board.name).trim_prefix("Nummerbord_")], Color("#7CFC9A"), 15)
	_next_number += 1
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	if audio and audio.has_method("play_event"):
		audio.play_event(board.global_position, "ov_inchecken")


func _hud() -> Node:
	var interiors := get_parent()
	var hud_path: Variant = interiors.get("hud_path") if interiors else null
	return interiors.get_node_or_null(hud_path) if hud_path is NodePath else null
