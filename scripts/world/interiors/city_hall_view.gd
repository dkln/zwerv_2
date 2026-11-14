extends Node
## What you see and hear of the city hall (graphics, docs/CODE_LAGEN.md): the leaves of the
## lift doors and the floor display over them, the signs in the city's green, the number
## boards over the counters, the waiting board and the big board of the number called now,
## the caretaker's cart; the doors sliding, the lift's "ding-dong". Everything is built into
## the floor it belongs to (as a child of that floor, so the names stay where they were:
## Liftdeur_links, Etagedisplay, Nummerbord_<n>, Wachtbord_<n>, NuAanDeBeurt). It decides
## nothing: the behaviour (city_hall.gd) says what to build and what the boards say. Where
## things hang: city_hall_layout.gd.
##   const CityHallView = preload("res://scripts/world/interiors/city_hall_view.gd")

const CityHallLayout = preload("res://scripts/world/interiors/city_hall_layout.gd")
const SignBoard = preload("res://scripts/world/things/sign_board.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const LIBRARY := "res://assets/libraries/binnen.res"
const DOOR_TILE := "stadhuis/lift_deur"
const CART_TILE := "stadhuis/schoonmaakkar"
const CART_NAME := "Schoonmaakkar"
const LIFT_SOUND := "lift_ding"
const CHOICE_SOUND := "kies"
## How long the doors take to slide (seconds).
const DOOR_SLIDE := 0.5
## The city's colours on the signs, the lit numbers on their dark plate, and the number
## that floats up when you take one (with its size).
const SIGN_PLATE := Color("#2E7D32")
const SIGN_INK := Color("#FFFFFF")
const DISPLAY_PLATE := Color("#101418")
const DISPLAY_INK := Color("#FF6A3A")
const TICKET_INK := Color("#FFE9B8")
const TICKET_SIZE := 15

var _doors := {}                     # floor number -> [left leaf, right leaf]
var _waiting_lines: Array[Node3D] = []
var _now_board: Node3D


func _init() -> void:
	name = "Beeld"


# ------------------------------------------------------------------ the lift doors

## The two leaves of the lift doors of floor `number` at `door_marker`, into `floor_node`, shut.
func build_lift_doors(floor_node: Node3D, door_marker: Node3D, number: int) -> void:
	var library: MeshLibrary = load(LIBRARY)
	var item := library.find_item_by_name(DOOR_TILE)
	var leaves: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var leaf := Node3D.new()
		leaf.name = "Liftdeur_links" if side < 0.0 else "Liftdeur_rechts"
		leaf.transform = door_marker.transform
		leaf.set_meta("side", side)
		leaf.set_meta("home", door_marker.position)
		if item >= 0:
			var mesh_node := MeshInstance3D.new()
			mesh_node.mesh = library.get_item_mesh(item)
			mesh_node.transform = library.get_item_mesh_transform(item)
			mesh_node.position.x += side * CityHallLayout.DOOR_LEAF * 0.5
			leaf.add_child(mesh_node)
		floor_node.add_child(leaf)
		leaves.append(leaf)
	_doors[number] = leaves
	show_doors(number, false, false)


## The floor display over the lift doors at `door_marker`, saying `text`.
func build_floor_display(floor_node: Node3D, door_marker: Node3D, text: String) -> Node3D:
	var display: Node3D = SignBoard.create(text, DISPLAY_PLATE, DISPLAY_INK, 0.2, false, 0.9)
	display.name = "Etagedisplay"
	display.transform = door_marker.transform
	display.position += Vector3(0.0, CityHallLayout.FLOOR_DISPLAY_RISE, 0.0) + door_marker.transform.basis.z * CityHallLayout.FLOOR_DISPLAY_OUT
	floor_node.add_child(display)
	return display


## The floors that have lift doors.
func floors_with_doors() -> Array:
	return _doors.keys()


## The doors of the lift on floor `number` open or shut, sliding (`animate`) or at once.
func show_doors(number: int, open: bool, animate: bool) -> void:
	for leaf: Node3D in _doors.get(number, []):
		var side := float(leaf.get_meta("side", 1.0))
		var home: Vector3 = leaf.get_meta("home", leaf.position)
		# the leaves slide along the front of the lift (its x), from the middle outwards
		var goal := CityHallLayout.door_leaf_at(home, leaf.transform.basis.x, side, open)
		if animate:
			leaf.create_tween().tween_property(leaf, "position", goal, DOOR_SLIDE).set_trans(Tween.TRANS_SINE)
		else:
			leaf.position = goal


## Whether the doors of floor `number` stand open now.
func doors_open(number: int) -> bool:
	var leaves: Array = _doors.get(number, [])
	if leaves.is_empty():
		return false
	var leaf: Node3D = leaves[0]
	return CityHallLayout.is_leaf_open(leaf.position, leaf.get_meta("home", leaf.position))


## The "ding-dong" of the lift at `where`.
func play_ding(where: Node3D) -> void:
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	if audio and audio.has_method("play_event") and where:
		audio.play_event(where.global_position, LIFT_SOUND)


## The blip of a choice made (the lift called, a number taken), `softer_db` softer.
func play_choice(softer_db: float) -> void:
	UiSounds.play(self, CHOICE_SOUND, softer_db)


# ------------------------------------------------------------------ signs and boards

## A sign in the city's green saying `text`, where `marker` is.
func build_sign(floor_node: Node3D, marker: Node3D, text: String) -> Node3D:
	var board: Node3D = SignBoard.create(text, SIGN_PLATE, SIGN_INK)
	board.transform = marker.transform
	floor_node.add_child(board)
	return board


## The number board over the counter at `marker` (Nummerbord_<counter_name>), saying `text`.
func build_counter_board(floor_node: Node3D, marker: Node3D, counter_name: String, text: String) -> Node3D:
	var display: Node3D = SignBoard.create(text, DISPLAY_PLATE, DISPLAY_INK, 0.12, false, 1.3)
	display.name = "Nummerbord_" + counter_name
	display.transform = marker.transform
	floor_node.add_child(display)
	return display


## Writes `text` on a board (a counter's number board).
func show_board_text(board: Node3D, text: String) -> void:
	if board:
		SignBoard.set_text(board, text)


## The waiting board on the left wall, made once: a heading (`heading`) and `line_count`
## lines under it, empty.
func build_waiting_board(floor_node: Node3D, heading: String, line_count: int) -> void:
	if not _waiting_lines.is_empty():
		return
	for line_index in line_count + 1:
		var is_heading := line_index == 0
		var board: Node3D = SignBoard.create(heading if is_heading else "", SIGN_PLATE if is_heading else DISPLAY_PLATE,
			SIGN_INK if is_heading else DISPLAY_INK, 0.11, false, 2.2)
		board.name = "Wachtbord_%d" % line_index
		board.position = CityHallLayout.waiting_board_line_at(line_index)
		board.rotation.y = PI * 0.5   # facing into the room (+x)
		floor_node.add_child(board)
		_waiting_lines.append(board)


## Writes `texts` on the lines of the waiting board under its heading, top to bottom.
func show_waiting_board(texts: Array[String]) -> void:
	for line_index in mini(texts.size(), _waiting_lines.size() - 1):
		SignBoard.set_text(_waiting_lines[line_index + 1], texts[line_index])


## What the waiting board says now: its lines top to bottom, the heading first.
func waiting_board_lines() -> Array[String]:
	var lines: Array[String] = []
	for board in _waiting_lines:
		var label := board.get_node_or_null("Tekst") as Label3D
		lines.append(label.text if label else "")
	return lines


## The big board of the number called now (NuAanDeBeurt, saying `text`) with its heading
## over it, facing the room.
func build_now_board(floor_node: Node3D, heading: String, text: String) -> Node3D:
	_now_board = SignBoard.create(text, DISPLAY_PLATE, DISPLAY_INK, 0.3, false, 4.6)
	_now_board.name = "NuAanDeBeurt"
	_now_board.position = CityHallLayout.NOW_BOARD_AT
	_now_board.rotation.y = PI
	floor_node.add_child(_now_board)
	var heading_board: Node3D = SignBoard.create(heading, SIGN_PLATE, SIGN_INK, 0.13, false, 4.6)
	heading_board.name = "NuAanDeBeurtKop"
	heading_board.position = CityHallLayout.now_heading_at()
	heading_board.rotation.y = PI
	floor_node.add_child(heading_board)
	return _now_board


## Writes `text` on the big board of the number called now.
func show_now_board(text: String) -> void:
	if _now_board:
		SignBoard.set_text(_now_board, text)


# ------------------------------------------------------------------ the caretaker's cart

## The cleaning cart before `person` (once): its long side across his way, the push bar at him.
func build_cart(person: Node3D) -> void:
	if person.has_node(CART_NAME):
		return
	var library: MeshLibrary = load(LIBRARY)
	var item := library.find_item_by_name(CART_TILE)
	if item < 0:
		return
	var cart := MeshInstance3D.new()
	cart.name = CART_NAME
	cart.mesh = library.get_item_mesh(item)
	cart.position = Vector3(0.0, 0.0, CityHallLayout.CART_AHEAD)
	cart.rotation.y = PI * 0.5
	person.add_child(cart)
