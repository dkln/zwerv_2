extends "res://scripts/world/interiors/interior.gd"
## The city hall on the Spui (scenes/binnen/stadhuis.tscn, built by
## tools/build/build_interiors.gd from scripts/world/interiors/city_hall_layout.gd, editable by hand
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
## people in the street. Signs (Bord_<n>, metadata "text") in the city's green.
## Burgerzaken works with numbers (the queue, _advance_queue): every visitor waiting there has
## one; a free counter calls the next (the gong, the number at the top of the screen and a voice
## over the loudspeakers, its board over the counter, the waiting board on the left wall: the
## last numbers called and how many wait); who has it gets up, walks to that counter, stands
## there a while (SERVE_SECONDS) and goes back to a bench, with a new number; only then that
## counter calls the next. You take a number at the machine ([E] "Nummertje trekken"): a few
## places on (random: TICKET_GAP; who has the ones between does not come: NO_SHOW_SECONDS),
## the slip in your pockets (Items "wachtnummer", the number on it: TICKET_META) and a thought
## saying it. The clerks at the counters only talk to you when your number is called at theirs
## (talk_gate): before that they send you to the machine or tell you to wait, crosser every
## time, and it is an offence ("voordringen", data/gesprekken/uitzetten.json: the guard warns
## you, the third time puts you out); not there within PLAYER_WAIT seconds, the turn is gone
## (and the slip).

const Layout = preload("res://scripts/world/interiors/city_hall_layout.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const InteriorSpot = preload("res://scripts/world/interiors/interior_spot.gd")
const SignBoard = preload("res://scripts/world/things/sign_board.gd")
const LIBRARY := "res://assets/libraries/binnen.res"
const LIFT_SOUND := "lift_ding"
## The doors: how far each leaf slides aside (metres) and how long that takes (seconds).
const DOOR_LEAF := 0.75
const DOOR_SLIDE := 0.5
## The city's colours on the signs, and the lit numbers.
const SIGN_PLATE := Color("#2E7D32")
const SIGN_INK := Color("#FFFFFF")
const DISPLAY_INK := Color("#FF6A3A")
## The queue of Burgerzaken (see the top): seconds a visitor stands at the counter, a counter
## waits for a number nobody comes for, waits for you (your number), and rests before it calls
## the next; how fast visitors walk (m/s); how far on your number is (from .. to places);
## how many numbers the waiting board shows. The meta on the player with its number.
const SERVE_SECONDS := Vector2(8.0, 22.0)
const NO_SHOW_SECONDS := 5.0
const PLAYER_WAIT := 45.0
const CALL_PAUSE := Vector2(2.0, 6.0)
const VISITOR_PACE := 1.3
const TICKET_GAP := Vector2i(3, 7)
const BOARD_LINES := 4
const TICKET_META := "wachtnummer"
const TICKET_ITEM := "wachtnummer"
## The waiting board on the left wall of Burgerzaken (in the floor's space): where its top
## line is, and the drop from one line to the next.
const WAITING_BOARD_AT := Vector3(-23.8, 3.2, 3.0)
const WAITING_BOARD_LINE := 0.42
const COUNTER_FLOOR := 1
## What a clerk says, crosser every time, when you come to the counter out of turn: without a
## number, and with one that is not called yet.
const CROSS_NO_TICKET := ["Eerst een nummertje trekken, bij de automaat bij de ingang.",
	"Nee. Eerst een nummertje. Daar, bij de automaat.",
	"Hoe vaak moet ik het nog zeggen? Een NUMMERTJE. Beveiliging!"]
const CROSS_NOT_YET := ["U bent nog niet aan de beurt. Let op het bord, dan roepen we u om.",
	"U bent écht nog niet aan de beurt. Gaat u zitten.",
	"Nu is het klaar. Ik bel de beveiliging."]
const NOTICE_HEADING := "— ETAGE %d —"
## The lift of the building: reusable, a scene of its own.
const LIFT_SCENE := "res://scenes/binnen/lift.tscn"

var current_floor := 0
var _floors: Array[Node3D] = []
var _people_made := {}               # floor number -> true
var _doors := {}                     # floor number -> [left leaf, right leaf]
var _riding := false
var _lift: Node3D                    # the lift (LiftRide)
var _player: Node3D
var _number_taken := 0
var _next_number := 41
## The queue (Burgerzaken): the numbers handed out, in turn ({"number", "who": a visitor, or
## "speler", or "" for one who does not come}); the counters ({"number", "board", "stand" (where
## a visitor stands, global), "clerk", "state", "ticket", "clock"}); the last number given out;
## the last numbers called (for the waiting board).
var _queue: Array[Dictionary] = []
var _counters: Array[Dictionary] = []
var _last_issued := 40
var _called: Array[String] = []
var _waiting_lines: Array[Node3D] = []
var _talking_at := -1                # the counter whose clerk the player talks to now
var _cut_in_line := 0                # times the player came to a counter out of turn
var _sent_away_from: Array[int] = []  # counters whose clerk sent you on ("doorverwezen"): not there again
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.seed = 2026
	var number := 0
	while has_node("Etage%d" % number):
		_floors.append(get_node("Etage%d" % number) as Node3D)
		number += 1
	for floor_node in _floors:
		_dress_floor(floor_node)
	# the lift: a scene of its own (reusable), beside the floors
	_lift = (load(LIFT_SCENE) as PackedScene).instantiate() as Node3D
	_lift.name = "Lift"
	add_child(_lift)
	_lift.position = Layout.CABIN_AT
	_show_floor(0)


## The floor of `number` (its node: Etage<number>).
func floor_node(number: int) -> Node3D:
	return _floors[clampi(number, 0, _floors.size() - 1)]


func floor_count() -> int:
	return _floors.size()


func plan_root() -> Node3D:
	return floor_node(current_floor) if not _floors.is_empty() else null


## Every time you come in: on floor 0, the people of the hall there.
func dress(bar_name: String, _seed: int) -> void:
	snack_bar_name = bar_name
	_riding = false
	_show_floor(0)
	_make_people(0)
	for floor_number in _doors:
		_set_doors(int(floor_number), true, false)


func player_came_in(player: Node3D) -> void:
	_player = player
	if player.has_signal("talk_ended") and not player.is_connected("talk_ended", _on_talk_ended):
		player.connect("talk_ended", _on_talk_ended)


func player_went_out() -> void:
	_riding = false
	_drop_ticket()   # the slip does not go out of the door with you


## Putting the player out (Eviction) waits while the lift rides; on another floor than the
## guard, one comes up with the lift (evictor_entry: the lift of the floor you are on).
func evicting_held() -> bool:
	return _riding


func evictor_outfit(role: String) -> Dictionary:
	return _outfit(role)


func evictor_entry() -> Node3D:
	if _floors.is_empty():
		return null
	return floor_node(current_floor).get_node_or_null("Lift") as Node3D


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



# ------------------------------------------------------------------ the lift

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


## The ride to floor `to`: the doors of this floor open (a "ding-dong"), and the ride is the
## scene of the lift (LiftRide, scenes/binnen/lift.tscn: you in the cabin, the camera from the
## front, the display, the motor); under its last swipe you are put out on that floor, its
## doors open, the floor at the top of the screen. `animate` false: at once (the checks).
func ride(to: int, animate := true) -> void:
	if _riding or to == current_floor or to < 0 or to >= _floors.size() or _lift == null:
		return
	_riding = true
	var from := current_floor
	if animate:
		_ding(floor_node(from).get_node_or_null("Lift") as Node3D)
		_set_doors(from, true, true)
		await get_tree().create_timer(DOOR_SLIDE + 0.1).timeout
	await _lift.ride(from, to, _player, _arrive.bind(to), animate)
	_riding = false


## Out of the lift on floor `to` (under the lift's last swipe).
func _arrive(to: int) -> void:
	_make_people(to)
	_set_doors(to, true, false)
	_show_floor(to)
	var lift := floor_node(to).get_node_or_null("Lift") as Node3D
	_move_player(lift)
	var hud := _hud()
	if hud and hud.has_method("show_notice"):
		hud.show_notice(NOTICE_HEADING % to if to > 0 else "— BEGANE GROND —", String(Layout.NAMES[to]))


func _ding(where: Node3D) -> void:
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	if audio and audio.has_method("play_event") and where:
		audio.play_event(where.global_position, LIFT_SOUND)


## The lift of this building (LiftRide), and whether you are riding in it now.
func lift() -> Node3D:
	return _lift


func in_cabin() -> bool:
	return _lift != null and bool(_lift.get("riding"))


func display_text() -> String:
	return String(_lift.call("display_text")) if _lift else ""


func motor_running() -> bool:
	return _lift != null and bool(_lift.call("motor_running"))


func is_riding() -> bool:
	return _riding


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


## The points the minimap marks on this floor: the way out on floor 0, the lift everywhere;
## in the cabin its doors.
func plan_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
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

## A number from the machine (see the top): a few places on, the slip in the pockets, a thought.
func _take_number() -> void:
	var hud := _hud()
	if _player == null:
		return
	_set_up_queue()
	_drop_ticket()   # a new number: the old one gone (from the pockets and the queue)
	var gap := _random.randi_range(TICKET_GAP.x, TICKET_GAP.y)
	for skipped in gap - 1:
		_queue.append({"number": _issue(), "who": ""})
	_number_taken = _issue()
	_queue.append({"number": _number_taken, "who": "speler"})
	_player.set_meta(TICKET_META, _number_taken)
	if _player.has_method("add_item"):
		_player.call("add_item", TICKET_ITEM, 1, true)
	UiSounds.play(self, "kies", -4.0)
	if _called.is_empty():
		_think("Zo, nummertje B %03d. Er is nog niemand omgeroepen. Dat wordt even wachten." % _number_taken)
	else:
		_think("Zo, nummertje B %03d. Op het bord staat nu %s. Dat wordt even wachten." % [_number_taken, _called[0].get_slice(" →", 0)])
	_update_waiting_board()
	if hud and hud.has_method("show_floating_number"):
		hud.show_floating_number(_player.global_position + Vector3.UP * 2.0, "B %03d" % _number_taken, Color("#FFE9B8"), 15)


func number_taken() -> int:
	return _number_taken


## The number the player holds (0: none).
func player_ticket() -> int:
	return int(_player.get_meta(TICKET_META, 0)) if _player else 0


func _issue() -> int:
	_last_issued += 1
	return _last_issued


## The queue made once, when Burgerzaken has its people: every visitor a number (in a random
## order), every counter its board, its clerk and where who is called stands.
func _set_up_queue() -> void:
	if not _counters.is_empty() or _floors.size() <= COUNTER_FLOOR:
		return
	_make_people(COUNTER_FLOOR)
	var floor_node := floor_node(COUNTER_FLOOR)
	var clerks: Array[InteriorPerson] = []
	var visitors: Array[InteriorPerson] = []
	for person in _people:
		if person.get_parent() != floor_node:
			continue
		if person.role == "loketmedewerker":
			clerks.append(person)
		elif person.role == "klant":
			visitors.append(person)
	var index := 1
	while floor_node.has_node("Loket_%d" % index):
		var marker := floor_node.get_node("Loket_%d" % index) as Node3D
		var clerk: InteriorPerson = null
		for candidate in clerks:
			if clerk == null or absf(candidate.position.x - marker.position.x) < absf(clerk.position.x - marker.position.x):
				clerk = candidate
		var stand := floor_node.to_global(Vector3(marker.position.x, 0.0, marker.position.z - 0.98))
		var counter := {"number": index, "board": floor_node.get_node_or_null("Nummerbord_%d" % index), "stand": stand,
			"clerk": clerk, "state": "vrij", "ticket": {}, "clock": _random.randf_range(1.0, 8.0), "visitor": null}
		_counters.append(counter)
		if clerk:
			clerk.set_meta("talk_gate", _talk_gate.bind(index))
			clerk.set_meta("talk_consequence", _talk_consequence.bind(index))
		index += 1
	visitors.shuffle()
	for visitor in visitors:
		_queue.append({"number": _issue(), "who": visitor})
	_make_waiting_board(floor_node)


## The queue moves on (on Burgerzaken only): every counter calls, waits, serves, sends back.
func _advance_queue(delta: float) -> void:
	if current_floor != COUNTER_FLOOR:
		return
	_set_up_queue()
	for counter in _counters:
		var visitor := counter.visitor as InteriorPerson
		match String(counter.state):
			"vrij":
				counter.clock = float(counter.clock) - delta
				if float(counter.clock) <= 0.0 and not _queue.is_empty():
					# your number is never called at a counter whose clerk sent you on
					if _queue[0].who is String and String(_queue[0].who) == "speler" and _sent_away_from.has(int(counter.number)):
						continue
					_call_next(counter)
			"lopen":
				if not is_instance_valid(visitor):
					_free_counter(counter)
					continue
				walk_evictor(visitor, counter.stand, VISITOR_PACE, delta)
				var gap := Vector2(visitor.global_position.x - counter.stand.x, visitor.global_position.z - counter.stand.z)
				if gap.length() < 0.25:
					evictor_stops(visitor)
					visitor.global_rotation.y = 0.0   # facing the counter
					counter.state = "bediend"
					counter.clock = _random.randf_range(SERVE_SECONDS.x, SERVE_SECONDS.y)
			"bediend":
				counter.clock = float(counter.clock) - delta
				if float(counter.clock) <= 0.0:
					counter.state = "terug"
			"terug":
				if not is_instance_valid(visitor):
					_free_counter(counter)
					continue
				var home: Dictionary = visitor.get_meta(HOME_META, {})
				var home_at: Vector3 = visitor.get_parent().to_global((home.get("transform", visitor.transform) as Transform3D).origin)
				walk_evictor(visitor, home_at, VISITOR_PACE, delta)
				if Vector2(visitor.global_position.x - home_at.x, visitor.global_position.z - home_at.z).length() < 0.3:
					evictor_done(visitor)
					_queue.append({"number": _issue(), "who": visitor})   # a new number: waits again
					_free_counter(counter)
			"niemand":
				counter.clock = float(counter.clock) - delta
				if float(counter.clock) <= 0.0:
					_free_counter(counter)
			"speler":
				counter.clock = float(counter.clock) - delta
				if float(counter.clock) <= 0.0 and _talking_at != int(counter.number):
					_player_missed(counter)
	_update_waiting_board()


## Calls the first number of the queue at `counter`: its board, the waiting board, the gong
## and the voice; who has it comes (a visitor walks there, the player is waited for).
func _call_next(counter: Dictionary) -> void:
	var ticket: Dictionary = _queue.pop_front()
	counter.ticket = ticket
	var text := "B %03d" % int(ticket.number)
	if counter.board:
		SignBoard.set_text(counter.board, text)
	_called.push_front("%s → %d" % [text, int(counter.number)])
	_called.resize(mini(_called.size(), BOARD_LINES))
	_announce(int(ticket.number), int(counter.number))
	var who: Variant = ticket.who
	if who is InteriorPerson and is_instance_valid(who):
		counter.visitor = who
		counter.state = "lopen"
	elif who is String and String(who) == "speler":
		counter.state = "speler"
		counter.clock = PLAYER_WAIT
	else:
		counter.state = "niemand"
		counter.clock = NO_SHOW_SECONDS


func _free_counter(counter: Dictionary) -> void:
	counter.state = "vrij"
	counter.ticket = {}
	counter.visitor = null
	counter.clock = _random.randf_range(CALL_PAUSE.x, CALL_PAUSE.y)


## The gong, the number at the top of the screen, the voice over the loudspeakers.
func _announce(number: int, counter_number: int) -> void:
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	var hud := _hud()
	if audio and audio.has_method("play_event") and _player:
		audio.play_event(_player.global_position + Vector3.UP * 3.0, "omroep_gong")
	if hud and hud.has_method("show_notice"):
		hud.show_notice("— BURGERZAKEN —", "Nummer B %03d, loket %d" % [number, counter_number], 3.5)
	var babble: GDScript = load("res://scripts/audio/babble.gd")
	for word_index in 3:
		get_tree().create_timer(0.9 + word_index * 0.32).timeout.connect(func() -> void:
			if is_inside_tree() and current_floor == COUNTER_FLOOR:
				babble.call("play_near", self, "vrouw", "neutraal"))


## Your number called but you did not come in time: the turn and the slip are gone.
func _player_missed(counter: Dictionary) -> void:
	_use_ticket()
	_free_counter(counter)
	_think("Mijn nummer is al geweest. Gemist. Dan maar een nieuw nummertje trekken.")


## The player's number out of the queue and the slip out of the pockets (going out, a new
## number); a counter waiting for it is free again.
func _drop_ticket() -> void:
	if _player == null or not _player.has_meta(TICKET_META):
		return
	var number := int(_player.get_meta(TICKET_META))
	_queue = _queue.filter(func(ticket: Dictionary) -> bool: return not (ticket.who is String and String(ticket.who) == "speler"))
	for counter in _counters:
		if String(counter.state) == "speler" and int((counter.ticket as Dictionary).get("number", -1)) == number:
			_free_counter(counter)
	_use_ticket()


## The slip used (or the turn missed): out of the pockets.
func _use_ticket() -> void:
	if _player == null:
		return
	_player.remove_meta(TICKET_META)
	if _player.has_method("drop_item") and int(_player.get("inventory").get(TICKET_ITEM, 0)) > 0:
		_player.call("drop_item", TICKET_ITEM)


## Whether a clerk talks to the player (Conversations through PlayerController.talk_to): only
## at the counter where the player's number is called now; else what they say instead (pages).
func _talk_gate(counter_number: int) -> Array:
	var called_here := false
	var called_elsewhere := 0
	for counter in _counters:
		if String(counter.state) == "speler":
			if int(counter.number) == counter_number:
				called_here = true
			else:
				called_elsewhere = int(counter.number)
	if called_here:
		_talking_at = counter_number
		return []
	if called_elsewhere > 0:
		return [{"kind": "gesprek", "speaker": "AMBTENAAR", "text": "U moet bij loket %d zijn." % called_elsewhere}]
	# not your turn: the clerk is cross, and doing it again and again is an offence (uitzetten.json
	# "voordringen": the guard warns you, then puts you out)
	_cut_in_line += 1
	var lines: Array = CROSS_NO_TICKET if player_ticket() <= 0 else CROSS_NOT_YET
	var line: String = lines[mini(_cut_in_line - 1, lines.size() - 1)]
	var interiors := get_parent()
	if interiors and interiors.has_method("offence"):
		interiors.call_deferred("offence", "voordringen")
	return [{"kind": "gesprek", "speaker": "AMBTENAAR", "text": line, "mood": "boos"}]


## What a clerk's answer brings about (Conversations, a node's "gevolg"): "doorverwezen" (this is
## for a colleague: a new number, and that counter not again; can happen again and again, and
## when every counter has sent you on the oldest is forgotten).
func _talk_consequence(gevolg: String, counter_number: int) -> void:
	if gevolg != "doorverwezen":
		return
	if not _sent_away_from.has(counter_number):
		_sent_away_from.append(counter_number)
	if _sent_away_from.size() >= _counters.size():
		_sent_away_from.pop_front()


## The counters whose clerk sent the player on (for the checks).
func sent_away_from() -> Array[int]:
	return _sent_away_from


## The player's conversation with a clerk is over (PlayerController.talk_ended): helped, the
## slip used, the counter free for the next.
func _on_talk_ended(_persona: String) -> void:
	if _talking_at < 0:
		return
	for counter in _counters:
		if int(counter.number) == _talking_at and String(counter.state) == "speler":
			_use_ticket()
			_free_counter(counter)
	_talking_at = -1


## The waiting board on the left wall: a heading, the last numbers called (number and counter),
## and how many wait.
func _make_waiting_board(floor_node: Node3D) -> void:
	if not _waiting_lines.is_empty():
		return
	for line_index in BOARD_LINES + 2:
		var heading := line_index == 0
		var board: Node3D = SignBoard.create("AAN DE BEURT" if heading else "", SIGN_PLATE if heading else Color("#101418"),
			SIGN_INK if heading else DISPLAY_INK, 0.11, false, 2.2)
		board.name = "Wachtbord_%d" % line_index
		board.position = WAITING_BOARD_AT + Vector3(0.0, -line_index * WAITING_BOARD_LINE, 0.0)
		board.rotation.y = PI * 0.5   # facing into the room (+x)
		floor_node.add_child(board)
		_waiting_lines.append(board)
	_update_waiting_board()


func _update_waiting_board() -> void:
	if _waiting_lines.is_empty():
		return
	for line_index in BOARD_LINES:
		var text := _called[line_index] if line_index < _called.size() else ""
		SignBoard.set_text(_waiting_lines[line_index + 1], text)
	SignBoard.set_text(_waiting_lines[BOARD_LINES + 1], "WACHTEND: %d" % _queue.size())


## What the waiting board says now (for the checks): its lines top to bottom.
func waiting_board_lines() -> Array[String]:
	var lines: Array[String] = []
	for board in _waiting_lines:
		var label := board.get_node_or_null("Tekst") as Label3D
		lines.append(label.text if label else "")
	return lines


func _think(text: String) -> void:
	var hud := _hud()
	if hud and hud.has_method("show_story"):
		hud.show_story([{"kind": "gedachte", "text": text}])


func _process(delta: float) -> void:
	_advance_queue(delta)


func _hud() -> Node:
	var interiors := get_parent()
	var hud_path: Variant = interiors.get("hud_path") if interiors else null
	return interiors.get_node_or_null(hud_path) if hud_path is NodePath else null
