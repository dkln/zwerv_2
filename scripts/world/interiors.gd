extends Node3D
## The buildings you can walk into (the node "Binnenruimtes" of scenes/stad.tscn), one entry
## of KINDS each: the snack bars and Den Haag Centraal. Every way in on the map gets an
## entrance on the pavement before it (a door point, the side of the facade with no building:
## Entrance), with a big arrow bobbing up and down over it as you come near (so you see
## that you can go in; with the faux 3D of the texts under it)
## and "[E] Naar binnen" once you stand at it (PlayerController, the group DOORS_GROUP).
## Going in: a swipe (SwipeTransition), and under it the player is put in the interior (its
## scene, scenes/binnen/<name>.tscn, an Interior: scripts/world/interior.gd or a script that
## extends it), far off the map at its own spot ("at"), dressed for the place (its name, its
## seed), the camera with it at once and without its turning round buildings; at one of its
## doors (the markers Deur, Deur1, Deur2, ...: Interior.doors()) "[E] Naar buiten" takes you
## back out onto the pavement before the matching way in (door 1 the first from the west),
## facing the street. While you are outside an interior stands still and is hidden.
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
## "name" (else the name found at the way in).

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
		"at": Vector3(-900.0, 0.0, 300.0)},
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
## Where the snack bar is, far off the map (metres; KINDS has it too).
const INTERIOR_AT := Vector3(-600.0, 0.0, -600.0)
## How far from a door point you can go through (metres), and from how far its arrow shows.
const DOOR_REACH := 1.8
const MARK_FROM := 22.0
## The arrow over a way in: its size, colour, how it bobs (between MARK_BOTTOM and MARK_TOP,
## once up and down in MARK_BOB_SECONDS), its turning, and its faux 3D copy under it (that
## far down, and that far behind it seen from the camera).
const MARK_SIZE := Vector3(0.8, 0.9, 0.2)
const MARK_COLOUR := Color("#FFB830")
const MARK_TOP := 3.3
const MARK_BOTTOM := 2.5
const MARK_BOB_SECONDS := 1.2
const MARK_SPIN := 1.0
const MARK_SHADOW_DROP := 0.09
const MARK_SHADOW_BEHIND := 0.08
const UiStyle = preload("res://scripts/ui/ui_style.gd")

@export var player_path := NodePath("../Speler")
@export var buildings_path := NodePath("../Gebouwen")
@export var details_path := NodePath("../Details")
@export var follow_camera_path := NodePath("../Volgcamera")
@export var hud_path := NodePath("../HUD")

var _player: Node3D
var _interior: Node3D               # the interior the player is in (or was in last)
var _exit: Entrance                 # its first way out
var _interiors := {}                # kind -> its interior, once made
var _exits := {}                    # kind -> Array[Entrance]: its ways out
var _inside: Dictionary = {}        # the way in the player came through (empty: outside)
## The ways in: {"kind", "name", "seed", "door" (Vector3), "outward" (Vector3), "door_index"}.
var _bars: Array[Dictionary] = []


## A door: an entrance from the pavement, or the way out of an interior.
class Entrance:
	extends Node3D
	var interiors: Node
	var bar := {}
	var leading_out := false
	var door_index := 1             # a way out: which door of its interior (1 = Deur / Deur1)
	var _mark: MeshInstance3D
	var _mark_shadow: MeshInstance3D
	var _clock := 0.0

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
		if _mark == null:
			return
		var near := player != null and player.global_position.distance_to(global_position) < MARK_FROM
		_mark.visible = near and not leading_out
		_mark_shadow.visible = _mark.visible
		if not _mark.visible:
			return
		_clock += get_process_delta_time()
		# up and down between MARK_BOTTOM and MARK_TOP, turning slowly
		var swing := 0.5 + 0.5 * sin(_clock * TAU / MARK_BOB_SECONDS)
		_mark.position.y = lerpf(MARK_BOTTOM, MARK_TOP, swing)
		_mark.rotation.y = _clock * MARK_SPIN
		# the copy straight under it, a little further from the camera so it lies behind it
		var away := Vector3.ZERO
		var camera := get_viewport().get_camera_3d() if get_viewport() else null
		if camera:
			away = -camera.global_transform.basis.z * MARK_SHADOW_BEHIND
		_mark_shadow.position = _mark.position + Vector3(0.0, -MARK_SHADOW_DROP, 0.0) + away
		_mark_shadow.rotation.y = _mark.rotation.y

	func add_mark() -> void:
		_mark = _arrow("Ingang", MARK_COLOUR)
		# the faux 3D of the texts (UiStyle.faux_3d): a darker copy straight under it, drawn behind
		_mark_shadow = _arrow("Ingang_schaduw", UiStyle.faux_3d_colour(MARK_COLOUR))

	func _arrow(arrow_name: String, colour: Color) -> MeshInstance3D:
		var arrow := MeshInstance3D.new()
		arrow.name = arrow_name
		var diamond := PrismMesh.new()
		diamond.size = MARK_SIZE
		arrow.mesh = diamond
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = colour
		arrow.material_override = material
		arrow.rotation_degrees.z = 180.0   # the point down, to the door
		arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arrow.position.y = MARK_TOP
		add_child(arrow)
		return arrow


func _ready() -> void:
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
	if is_inside() or _player == null:
		return
	_play_sound(DOOR_IN_SOUND)
	var swipe := SwipeTransition.swipe(get_tree())
	await swipe.covered
	var kind: String = bar.get("kind", "snackbar")
	_set_music(String(KINDS[kind].get("music", "")))
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
	_camera_indoors(true)


## Goes back out through door `door_index` of the interior: the swipe, and under it onto the
## pavement before the matching way in (or the one you came in through), facing the street.
func leave(door_index := 0) -> void:
	if not is_inside():
		return
	_play_sound(DOOR_OUT_SOUND)
	var swipe := SwipeTransition.swipe(get_tree())
	await swipe.covered
	_set_music("")
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


func _camera_indoors(indoors: bool) -> void:
	var follow := get_node_or_null(follow_camera_path)
	if follow == null:
		return
	if follow.has_method("set_indoors"):
		follow.set_indoors(indoors)
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
	entrance.add_mark()
	entrance.add_to_group(DOORS_GROUP)


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
