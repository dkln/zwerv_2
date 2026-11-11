extends Node3D
## The buildings you can walk into (the node "Binnenruimtes" of scenes/stad.tscn), one entry
## of KINDS each: the snack bars and Den Haag Centraal. Every way in on the map gets an
## entrance on the pavement before it (a door point, the side of the facade with no building:
## Entrance), with a big arrow bobbing up and down over it as you come near (InteractionMark:
## so you see that you can go in; above the roof of a low building, so trees don't hide it)
## and "[E] Naar binnen" once you stand at it (PlayerController, the group DOORS_GROUP).
## Going in: a swipe (SwipeTransition), and under it the player is put in the interior (its
## scene, scenes/binnen/<name>.tscn, an Interior: scripts/world/interior.gd or a script that
## extends it), far off the map at its own spot ("at"), dressed for the place (its name, its
## seed), the camera with it at once and without its turning round buildings; at one of its
## doors (the markers Deur, Deur1, Deur2, ...: Interior.doors()) "[E] Naar buiten" takes you
## back out onto the pavement before the matching way in (door 1 the first from the west),
## facing the street. While you are outside an interior stands still and is hidden.
## Inside, the minimap of the HUD shows the floor plan of the interior with its ways out
## (GameHud.show_interior_plan).
## Inside there is no day and night: the day cycle (Dagcyclus, DayCycle.set_indoors) keeps
## the light constant while you are in, its clock running on.
##
## A new interior (see INSTRUCTIONS.md, "Binnenruimtes maken"): its tiles in
## tools/voxgen/tiles/interior.py (binnen/<name>/), a builder in tools/build/build_interiors.gd,
## its scene in scenes/binnen/, and a line in KINDS saying where its ways in are:
##   "front": a fragment of the name of the facade tile (Gebouwen) that is a way in: every
##            such shop front is one (the snack bars); its name from the name signs (NAMES)
##            or the place on the map (PLACE_NAMES);
##   "doors": the name of a door tile (Gebouwen) and "place" with "place_reach": the door
##            tiles within that many metres of that place of the map are its ways in, from
##            west to east door 1, 2, ... (Den Haag Centraal: the three doors of the hall).
## Further: "scene", "music" (the loop inside, "" none), "at" (where it lies, far off the map),
## "name" (else the name found at the way in), "zoom" (metres in view inside, else the
## camera's indoor_zoom: the big hall of Den Haag Centraal is seen from further out),
## "location" (the neighbourhood, a key of the "wijken" metadata, the HUD shows under the
## minimap while inside: GameHud.set_indoor_location; else the name of the spot off the map).

const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const SNACK_BAR_SCENE := "res://scenes/binnen/snackbar.tscn"
const SNACK_BAR_FRONT := "_bg_snackbar"
## The music inside (GameHud.set_indoor_music) and the sounds of the door, going in and out
## (assets/audio/geluiden/, tools/megadrive/geluiden.py).
const SNACK_BAR_MUSIC := "handelaar_loop.ogg"
const KINDS := {
	"snackbar": {"scene": SNACK_BAR_SCENE, "music": SNACK_BAR_MUSIC, "front": SNACK_BAR_FRONT,
		"at": Vector3(-600.0, 0.0, -600.0)},
	"centraal": {"scene": "res://scenes/binnen/centraal.tscn", "music": "", "name": "Den Haag Centraal",
		"doors": "hallen/hal_glas_wand_deur_dak", "place": "centraal", "place_reach": 70.0,
		"at": Vector3(-900.0, 0.0, 300.0), "zoom": 20.0, "location": "Centraal Station"},
}
const SOUND_FOLDER := "res://assets/audio/geluiden/"
const DOOR_IN_SOUND := "deur_binnen"
const DOOR_OUT_SOUND := "deur_buiten"
const DOOR_SOUND_DB := -2.0
const SNACK_BAR := "Snackbar"
## The name signs of the snack bars (Details items) and the names on them.
const NAMES := {"tekst/naam_snackbar_1": "Frietje Fatsoen", "tekst/naam_snackbar_2": "Jan Blammage"}
## Places on the map that are snack bars (the "places" metadata) and their names.
const PLACE_NAMES := {"snackbar_de_vrijheid": "Snackbar De Vrijheid"}
## Who can go through a door (PlayerController looks in it): entrances and the way out.
const DOORS_GROUP := "deuren"
## Interiors itself, so others can report an offence (note_offence) without a path to it.
const GROUP := "binnenruimtes"
## Thrown out (throw_out): who says what for which offence where (data/gesprekken/uitzetten.json),
## how hard the player is thrown out of the door (m/s), and the colour of "niet_binnen".
const THROW_OUT_FILE := "res://data/gesprekken/uitzetten.json"
const THROW_SPEED := 10.0
## The level-of-detail node (its loading screen), and how many frames an interior is drawn
## under it to warm up (_warm_up).
const DETAIL_PATH := NodePath("../DetailNiveau")
const WARM_UP_FRAMES := 3
## How far the throw may turn from straight out of the door (radians, either way).
const THROW_SPREAD := deg_to_rad(18.0)
## The bang before the throw (_bang_at): its sound, the colour of its burst, how bright its
## flash is, and how long all stands still before the flight (seconds).
const BANG_SOUND := "klap"
const BANG_COLOUR := Color("#FFE9B8")
const BANG_FLASH_ENERGY := 6.0
const BANG_HOLD := 0.15
const BARRED_COLOUR := Color("#FF5A4A")
const Conversations = preload("res://scripts/story/conversations.gd")
const Ambience = preload("res://scripts/audio/ambience.gd")
## The background sound of each kind of interior (Ambience); outside "straat".
const AMBIENCE_OF := {"centraal": "station", "snackbar": "winkel"}
## Where the snack bar is, far off the map (metres; KINDS has it too).
const INTERIOR_AT := Vector3(-600.0, 0.0, -600.0)
## How far from a door point you can go through (metres).
const DOOR_REACH := 1.8
## The arrow over a way in (InteractionMark): its point between MARK_BOTTOM and MARK_TOP over
## the pavement; over a building no higher than ROOF_MARK_HIGHEST (metres above the street)
## it hangs above the roof instead, ROOF_MARK_CLEARANCE over it and that far into the facade
## (so trees and awnings before the shop do not hide it).
const MARK_TOP := 3.3
const MARK_BOTTOM := 2.5
const ROOF_MARK_HIGHEST := 14.0
const ROOF_MARK_CLEARANCE := 0.6
const ROOF_MARK_INTO_FACADE := 1.5
const InteractionMark = preload("res://scripts/world/interaction_mark.gd")

@export var player_path := NodePath("../Speler")
@export var buildings_path := NodePath("../Gebouwen")
@export var details_path := NodePath("../Details")
@export var follow_camera_path := NodePath("../Volgcamera")
@export var hud_path := NodePath("../HUD")
@export var day_cycle_path := NodePath("../Dagcyclus")

var _player: Node3D
var _interior: Node3D               # the interior the player is in (or was in last)
var _exit: Entrance                 # its first way out
var _interiors := {}                # kind -> its interior, once made
var _exits := {}                    # kind -> Array[Entrance]: its ways out
var _inside: Dictionary = {}        # the way in the player came through (empty: outside)
## The ways in: {"kind", "name", "seed", "door" (Vector3), "outward" (Vector3), "door_index"}.
var _bars: Array[Dictionary] = []
var _offences := {}                 # offence -> times in this visit (note_offence)
var _barred_until := {}             # kind -> msec until which the player may not come in
var _throwing := false              # a throw-out under way
var _throw_out_data := {}
var _ambience: Ambience             # the background sound of where the player is
var _last_swipe: Node                # the swipe of the last way out (_go_out), to wait for its end


## A door: an entrance from the pavement, or the way out of an interior.
class Entrance:
	extends Node3D
	var interiors: Node
	var bar := {}
	var leading_out := false
	var door_index := 1             # a way out: which door of its interior (1 = Deur / Deur1)
	var mark: InteractionMark

	func action_text() -> String:
		return "Naar buiten" if leading_out else "Naar binnen"

	func go_through() -> void:
		if leading_out:
			interiors.leave(door_index)
		else:
			interiors.enter(bar)

	func reach() -> float:
		return DOOR_REACH

	func show_mark(player: Node3D) -> void:
		if mark:
			mark.follow(player, not leading_out)

	## The arrow over this way in: over the pavement, or above the roof when `roof_height`
	## (metres above the street, NAN: unknown) is low enough.
	func add_mark(roof_height: float) -> void:
		if not is_nan(roof_height) and roof_height <= ROOF_MARK_HIGHEST:
			var low := roof_height + ROOF_MARK_CLEARANCE
			mark = InteractionMark.create(low, low + MARK_TOP - MARK_BOTTOM)
			var outward: Vector3 = bar.get("outward", Vector3.ZERO)
			mark.position = -outward * ROOF_MARK_INTO_FACADE
		else:
			mark = InteractionMark.create(MARK_BOTTOM, MARK_TOP)
		add_child(mark)


func _ready() -> void:
	add_to_group(GROUP)
	# the interiors built and drawn once under the loading screen, so going in never stalls
	var detail := get_node_or_null(DETAIL_PATH)
	if detail and detail.has_method("hold_screen"):
		detail.hold_screen()
	_prepare_interiors.call_deferred(detail)
	_ambience = Ambience.new()
	_ambience.name = "Omgevingsgeluid"
	add_child(_ambience)
	_ambience.set_place("straat")
	_player = get_node_or_null(player_path)
	_find_snack_bars()
	_find_door_tiles()


func _process(_delta: float) -> void:
	# the group also has the gates, machines and posts of the station: only the ways in
	for entrance in get_tree().get_nodes_in_group(DOORS_GROUP):
		if entrance is Entrance:
			(entrance as Entrance).show_mark(_player)


## The snack bars you can walk into (name, seed, door point and the way out to the street).
func snack_bars() -> Array:
	return _bars.filter(func(spot: Dictionary) -> bool: return spot.kind == "snackbar")


## Every way in of every interior (see _bars).
func ways_in() -> Array[Dictionary]:
	return _bars


func is_inside() -> bool:
	return not _inside.is_empty()


## Under the loading screen: every interior made (and prepared: the station built), and
## drawn once by a camera of its own (WARM_UP_FRAMES frames: the GPU gets its meshes and
## compiles its shaders now, not on the first walk in, which would stall the game); then the
## loading screen may go (LevelOfDetail.release_screen).
func _prepare_interiors(detail: Node) -> void:
	for frame_index in 2:
		await get_tree().process_frame
	var screen_up: bool = detail != null and detail.has_method("screen_is_up") and detail.call("screen_is_up")
	for kind: String in KINDS:
		var interior := interior_of(kind)
		if interior.has_method("prepare"):
			interior.call("prepare")
		await get_tree().process_frame
		if screen_up:
			await _warm_up(interior)
	if detail and detail.has_method("release_screen"):
		detail.release_screen()


## Draws `interior` a few frames from above by a camera of its own (under the loading screen),
## then puts it to rest again and the camera back.
func _warm_up(interior: Node3D) -> void:
	var before := get_viewport().get_camera_3d()
	var camera := Camera3D.new()
	camera.name = "Opwarmcamera"
	add_child(camera)
	camera.global_position = interior.global_position + Vector3(0.0, 40.0, 40.0)
	camera.look_at(interior.global_position, Vector3.UP)
	camera.make_current()
	_rest(interior, false)
	for frame_index in WARM_UP_FRAMES:
		await get_tree().process_frame
	_rest(interior, true)
	if before and is_instance_valid(before):
		before.make_current()
	camera.queue_free()


## The interior of a kind (KINDS), made the first time it is asked for.
func interior_of(kind: String) -> Node3D:
	if _interiors.has(kind):
		return _interiors[kind]
	var settings: Dictionary = KINDS[kind]
	var interior := (load(settings.scene) as PackedScene).instantiate() as Node3D
	add_child(interior)
	interior.global_position = settings.at
	var exits: Array[Entrance] = []
	var doors: Array = interior.call("doors") if interior.has_method("doors") else [interior.call("door")]
	for index in doors.size():
		var way_out := Entrance.new()
		way_out.name = "Uitgang%d" % (index + 1)
		way_out.interiors = self
		way_out.leading_out = true
		way_out.door_index = index + 1
		interior.add_child(way_out)
		way_out.global_transform = doors[index]
		way_out.add_to_group(DOORS_GROUP)
		exits.append(way_out)
	_interiors[kind] = interior
	_exits[kind] = exits
	_rest(interior, true)
	return interior


## Goes in through `bar` (a way in): the swipe, and under it into the dressed interior, at
## the door that matches the way in.
func enter(bar: Dictionary) -> void:
	if is_inside() or _player == null or _throwing:
		return
	var kind_barred := String(bar.get("kind", "snackbar"))
	if Time.get_ticks_msec() < int(_barred_until.get(kind_barred, 0)):
		# thrown out a little while ago: not yet back in
		var hud := get_node_or_null(hud_path)
		if hud and hud.has_method("show_floating_number"):
			hud.show_floating_number(_player.global_position + Vector3.UP * 2.2,
					String(_throw_outs().get("niet_binnen", "Je mag hier niet in")), BARRED_COLOUR, 14)
		return
	_offences = {}
	_play_sound(DOOR_IN_SOUND)
	var swipe := SwipeTransition.swipe(get_tree())
	await swipe.covered
	var kind: String = bar.get("kind", "snackbar")
	_set_music(String(KINDS[kind].get("music", "")))
	_ambience.set_place(String(AMBIENCE_OF.get(kind, "winkel")))
	_set_location(String(KINDS[kind].get("location", "")))
	_interior = interior_of(kind)
	_rest(_interior, false)
	_interior.call("dress", String(bar.name), int(bar.seed))
	var exits: Array = _exits[kind]
	var door_index := clampi(int(bar.get("door_index", 1)), 1, exits.size())
	_exit = exits[0]
	_inside = bar
	var door: Transform3D = (exits[door_index - 1] as Entrance).global_transform
	if _interior.has_method("player_came_in"):
		_interior.call("player_came_in", _player)
	_put_player(door.origin, door.basis.z)
	_camera_indoors(true, float(KINDS[kind].get("zoom", 0.0)))
	_light_indoors(true)
	_minimap_indoors(exits)


## Goes back out through door `door_index` of the interior: the swipe, and under it onto the
## pavement before the matching way in (or the one you came in through), facing the street.
func leave(door_index := 0) -> void:
	if not is_inside() or _throwing:
		return
	await _go_out(door_index)


## Out through door `door_index` (0: the one of the way in): the swipe, and under it onto
## the pavement before it, the camera, light and minimap back as outside. Returns the way in
## it came out of (its "door" and "outward").
func _go_out(door_index: int) -> Dictionary:
	_play_sound(DOOR_OUT_SOUND)
	var swipe := SwipeTransition.swipe(get_tree())
	_last_swipe = swipe
	await swipe.covered
	_set_music("")
	_set_location("")
	_ambience.set_place("straat")
	var bar := _inside
	# an interior with more doors (KINDS "doors"): out before the way in of that door
	if KINDS.get(String(bar.kind), {}).has("doors") and door_index > 0:
		for other in _bars:
			if other.kind == bar.kind and int(other.get("door_index", 1)) == door_index:
				bar = other
	_inside = {}
	if _interior and _interior.has_method("player_went_out"):
		_interior.call("player_went_out")
	_rest(_interior, true)
	_put_player(bar.door + (bar.outward as Vector3) * 0.6, bar.outward)
	_camera_indoors(false)
	_light_indoors(false)
	_minimap_indoors([])
	return bar


# ------------------------------------------------------------------ thrown out

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _throw_outs() -> Dictionary:
	if _throw_out_data.is_empty():
		_throw_out_data = _read_json(THROW_OUT_FILE)
	return _throw_out_data


## What the place of `kind` does about `offence` (uitzetten.json), empty when nothing.
func _rule(kind: String, offence: String) -> Dictionary:
	var places: Dictionary = _throw_outs().get("plekken", {})
	return ((places.get(kind, {}) as Dictionary).get("overtredingen", {}) as Dictionary).get(offence, {})


## Someone reports an offence of the player (anywhere: it only counts inside an interior
## whose uitzetten.json knows it): "bedelen", "geen_geld", "zwartrijden".
static func note_offence(tree: SceneTree, offence: String) -> void:
	var interiors := tree.get_first_node_in_group(GROUP) if tree else null
	if interiors and interiors.has_method("offence"):
		interiors.call("offence", offence)


## Counts `offence` in this visit; at the number the place allows ("na"), the player is
## thrown out (throw_out).
func offence(offence_name: String) -> void:
	if not is_inside() or _throwing:
		return
	var rule := _rule(String(_inside.kind), offence_name)
	if rule.is_empty():
		return
	_offences[offence_name] = int(_offences.get(offence_name, 0)) + 1
	if int(_offences[offence_name]) >= int(rule.get("na", 1)):
		throw_out(offence_name)


## Thrown out of the interior for `offence_name`: once the conversation or the shop screen
## is closed (closing the shop at once), the swipe, and once it is through out of the door the
## player flies (a KLAP and a bang at the door, a kick, a close-up in slow motion, a groan as
## they land), tumbling onto the
## pavement; once up again, the narrator tells what happened (story pages: uitzetten.json
## "tekst"); for "terug_na" seconds they may not come back in.
func throw_out(offence_name: String) -> void:
	if not is_inside() or _throwing:
		return
	_throwing = true
	var kind := String(_inside.kind)
	var rule := _rule(kind, offence_name)
	var hud := get_node_or_null(hud_path)
	if hud and hud.has_method("is_showing_shop") and hud.is_showing_shop():
		var shop: Node = hud.get("_shop_screen")
		if shop and shop.has_method("leave"):
			shop.call("leave")
	while hud and ((hud.has_method("is_showing_story") and hud.is_showing_story())
			or (hud.has_method("is_showing_shop") and hud.is_showing_shop())):
		await get_tree().process_frame
	var bar := await _go_out(0)
	# not seen standing before the door: out of sight until the throw starts
	_player.visible = false
	_barred_until[kind] = Time.get_ticks_msec() + int(float(_throw_outs().get("terug_na", 90)) * 1000.0)
	_offences = {}
	# the throw only once the swipe is through, so it is seen whole
	if is_instance_valid(_last_swipe) and _last_swipe.is_inside_tree():
		await _last_swipe.finished
	_player.visible = true
	# the BANG at the door before it flies: a KLAP, a burst and a flash, a moment's stillness
	await _bang_at(_player.global_position + Vector3.UP * 1.0)
	if _player.has_method("thrown_out"):
		# out of the entrance, a little to the left or right each time
		var turn := randf_range(-THROW_SPREAD, THROW_SPREAD)
		_player.call("thrown_out", (bar.outward as Vector3).rotated(Vector3.UP, turn) * THROW_SPEED)
	# once the player is up again
	var waited := 0.0
	# and standing (its rise played out: the story box would pause it halfway)
	while (_player.get("_ragdoll") != null or float(_player.get("_rising_left") if _player.get("_rising_left") != null else 0.0) > 0.0) \
			and waited < 10.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if hud and hud.has_method("show_story"):
		hud.show_story(_throw_out_pages(rule))
	_throwing = false


## The bang of being flung out (throw_out): the KLAP, a burst of shards and a white flash at
## `at`, and BANG_HOLD seconds (real time) of stillness before the flight.
func _bang_at(at: Vector3) -> void:
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	if audio and audio.has_method("play_event"):
		audio.play_event(at, BANG_SOUND)
	CrashBurst.spawn(get_parent(), at, BANG_COLOUR, 1.0)
	var flash := OmniLight3D.new()
	flash.light_color = Color("#FFF4D8")
	flash.light_energy = BANG_FLASH_ENERGY
	flash.omni_range = 6.0
	get_parent().add_child(flash)
	flash.global_position = at
	var fade := flash.create_tween()
	fade.tween_property(flash, "light_energy", 0.0, 0.25)
	fade.tween_callback(flash.queue_free)
	await get_tree().create_timer(BANG_HOLD, true, false, true).timeout


## The pages of what happened, told by the narrator (story pages): each line of "tekst" one.
func _throw_out_pages(rule: Dictionary) -> Array:
	var pages := []
	for line: String in rule.get("tekst", []):
		pages.append({"kind": "verhaal", "text": line})
	return pages


## An interior no one is in stands still and is not drawn.
func _rest(interior: Node3D, resting: bool) -> void:
	if interior == null:
		return
	interior.visible = not resting
	interior.process_mode = Node.PROCESS_MODE_DISABLED if resting else Node.PROCESS_MODE_INHERIT


func _set_music(file: String) -> void:
	var hud := get_node_or_null(hud_path)
	if hud and hud.has_method("set_indoor_music"):
		hud.set_indoor_music(file)


func _set_location(wijk: String) -> void:
	var hud := get_node_or_null(hud_path)
	if hud and hud.has_method("set_indoor_location"):
		hud.set_indoor_location(wijk)


## A sound of the door, not placed in the world (you are going through it).
func _play_sound(sound_name: String) -> void:
	var path := SOUND_FOLDER + sound_name + ".ogg"
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if stream == null and FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)   # not imported yet
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = DOOR_SOUND_DB
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _put_player(at: Vector3, facing: Vector3) -> void:
	if _player.has_method("teleport"):
		_player.call("teleport", at, atan2(facing.x, facing.z))
	else:
		_player.global_position = at


## The floor plan of the interior on the minimap with its ways out (`exits`, Entrances), or
## the town's map again (no exits: going out).
func _minimap_indoors(exits: Array) -> void:
	var hud := get_node_or_null(hud_path)
	if hud == null:
		return
	if exits.is_empty():
		if hud.has_method("show_town_plan"):
			hud.show_town_plan()
		return
	var exit_points: Array[Vector3] = []
	for way_out: Node3D in exits:
		exit_points.append(way_out.global_position)
	if hud.has_method("show_interior_plan"):
		hud.show_interior_plan(_interior, exit_points)


## The constant light of the interiors (on) or the light of the hour again (off).
func _light_indoors(indoors: bool) -> void:
	var day_cycle := get_node_or_null(day_cycle_path)
	if day_cycle and day_cycle.has_method("set_indoors"):
		day_cycle.set_indoors(indoors)


func _camera_indoors(indoors: bool, zoom_in_view := 0.0) -> void:
	var follow := get_node_or_null(follow_camera_path)
	if follow == null:
		return
	if follow.has_method("set_indoors"):
		follow.set_indoors(indoors, zoom_in_view)
	if follow.has_method("snap_to_target"):
		follow.snap_to_target()


# ------------------------------------------------------------------ finding the snack bars

func _find_snack_bars() -> void:
	var buildings := get_node_or_null(buildings_path) as GridMap
	if buildings == null or buildings.mesh_library == null:
		return
	var library := buildings.mesh_library
	var signs := _name_signs()
	var places: Dictionary = (owner if owner else get_parent()).get_meta("places", {})
	for item in library.get_item_list():
		if not library.get_item_name(item).contains(SNACK_BAR_FRONT):
			continue
		for cell in buildings.get_used_cells_by_item(item):
			var centre := buildings.to_global(buildings.map_to_local(cell))
			var spot := Vector2(centre.x, centre.z)
			if _bars.any(func(other: Dictionary) -> bool: return Vector2(other.door.x, other.door.z).distance_to(spot) < 6.0):
				continue
			var outward := _outward(buildings, cell)
			if outward == Vector3.ZERO:
				continue
			var door := Vector3(centre.x, buildings.global_position.y, centre.z) + outward * (buildings.cell_size.x * 0.5 + 0.9)
			var bar := {"kind": "snackbar", "name": _name_for(spot, signs, places), "seed": absi(cell.x * 73856093 ^ cell.z * 19349663) % 100000,
				"door": door, "outward": outward, "door_index": 1}
			_add_way_in(bar)


## The ways in by door tiles near a place (KINDS "doors"): from west to east door 1, 2, ...
func _find_door_tiles() -> void:
	var buildings := get_node_or_null(buildings_path) as GridMap
	if buildings == null or buildings.mesh_library == null:
		return
	var places: Dictionary = (owner if owner else get_parent()).get_meta("places", {})
	for kind: String in KINDS:
		var settings: Dictionary = KINDS[kind]
		if not settings.has("doors") or not places.has(settings.place):
			continue
		var item := buildings.mesh_library.find_item_by_name(settings.doors)
		if item < 0:
			continue
		var place: Vector2 = places[settings.place]
		var found := []
		for cell in buildings.get_used_cells_by_item(item):
			var centre := buildings.to_global(buildings.map_to_local(cell))
			if Vector2(centre.x, centre.z).distance_to(place) > float(settings.place_reach):
				continue
			var outward := _outward(buildings, cell)
			if outward == Vector3.ZERO:
				continue
			found.append([centre, outward])
		found.sort_custom(func(first: Array, second: Array) -> bool: return (first[0] as Vector3).x < (second[0] as Vector3).x)
		for index in found.size():
			var centre: Vector3 = found[index][0]
			var outward: Vector3 = found[index][1]
			var door := Vector3(centre.x, buildings.global_position.y, centre.z) + outward * (buildings.cell_size.x * 0.5 + 0.9)
			_add_way_in({"kind": kind, "name": String(settings.get("name", kind)), "seed": 1, "door": door,
				"outward": outward, "door_index": index + 1})


func _add_way_in(bar: Dictionary) -> void:
	_bars.append(bar)
	var entrance := Entrance.new()
	entrance.name = "Ingang"
	entrance.interiors = self
	entrance.bar = bar
	add_child(entrance)
	entrance.global_position = bar.door
	entrance.add_mark(_roof_height(bar.door - (bar.outward as Vector3) * ROOF_MARK_INTO_FACADE))
	entrance.add_to_group(DOORS_GROUP)


## How high the buildings stand at `spot` (the top of the highest tile in the Gebouwen
## column there, metres above the street), NAN when there is no building.
func _roof_height(spot: Vector3) -> float:
	var buildings := get_node_or_null(buildings_path) as GridMap
	if buildings == null or buildings.mesh_library == null:
		return NAN
	var column := buildings.local_to_map(buildings.to_local(spot))
	var highest := NAN
	for cell in buildings.get_used_cells():
		if cell.x != column.x or cell.z != column.z:
			continue
		var mesh := buildings.mesh_library.get_item_mesh(buildings.get_cell_item(cell))
		if mesh == null:
			continue
		var mesh_place := buildings.mesh_library.get_item_mesh_transform(buildings.get_cell_item(cell))
		var top := buildings.to_global(buildings.map_to_local(cell) + mesh_place * mesh.get_aabb().end).y
		if is_nan(highest) or top > highest:
			highest = top
	return highest - spot.y if not is_nan(highest) else NAN


## The street side of a facade cell, as a world direction: the way its front faces (the tile
## turned in the map; a tile's front is +z), if no building stands there, else any side with
## no building next to it at the ground; ZERO when there is none.
static func _outward(buildings: GridMap, cell: Vector3i) -> Vector3:
	var front := buildings.get_basis_with_orthogonal_index(buildings.get_cell_item_orientation(cell)) * Vector3.BACK
	var front_side := Vector3i(roundi(front.x), 0, roundi(front.z))
	if front_side != Vector3i.ZERO and buildings.get_cell_item(cell + front_side) == GridMap.INVALID_CELL_ITEM:
		return Vector3(front_side.x, 0.0, front_side.z)
	for side: Vector3i in [Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(-1, 0, 0)]:
		if buildings.get_cell_item(cell + side) == GridMap.INVALID_CELL_ITEM:
			return Vector3(side.x, 0.0, side.z)
	return Vector3.ZERO


## The name signs of the snack bars: [world x, z, name] each.
func _name_signs() -> Array:
	var details := get_node_or_null(details_path) as GridMap
	var signs := []
	if details == null or details.mesh_library == null:
		return signs
	for sign_name: String in NAMES:
		var item := details.mesh_library.find_item_by_name(sign_name)
		if item < 0:
			continue
		for cell in details.get_used_cells_by_item(item):
			var at := details.to_global(details.map_to_local(cell))
			signs.append([Vector2(at.x, at.z), NAMES[sign_name]])
	return signs


static func _name_for(spot: Vector2, signs: Array, places: Dictionary) -> String:
	for place_key: String in PLACE_NAMES:
		if places.has(place_key) and (places[place_key] as Vector2).distance_to(spot) < 6.0:
			return PLACE_NAMES[place_key]
	for sign: Array in signs:
		if (sign[0] as Vector2).distance_to(spot) < 4.5:
			return sign[1]
	return SNACK_BAR
