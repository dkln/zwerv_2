extends "res://scripts/world/interiors/interior.gd"
## The city hall on the Spui (scenes/binnen/stadhuis.tscn, built by
## tools/build/build_interiors.gd from scripts/world/interiors/city_hall_layout.gd, editable by hand
## after): five floors, Etage0..Etage4, side by side in the scene; only the floor the player is
## on is shown (plan_root: its floor plan on the minimap). You come in on floor 0, the hall
## with the reception.
## Behaviour (docs/CODE_LAGEN.md): the floors, the lift, the people and the queue in time. Its
## logic: city_hall_rules.gd (floors, lift, people) and city_hall_queue_rules.gd (the queue);
## where things stand: city_hall_layout.gd; what you see and hear: city_hall_view.gd; the
## caretaker's round: city_hall_caretaker.gd; the lift ride: lift_ride.gd.
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
## The basement (Layout.BASEMENT, level -1: the lift rides down to it, "K" on its displays):
## the storage, and the caretaker going round with his cleaning cart (_advance_caretaker: along
## Layout.CARETAKER_ROUND, now and then standing still to mop), who can be talked to
## (personeel.json "concierge").
## (talk_gate): before that they send you to the machine or tell you to wait, crosser every
## time, and it is an offence ("voordringen", data/gesprekken/uitzetten.json: the guard warns
## you, the third time puts you out); not there within PLAYER_WAIT seconds, the turn is gone
## (and the slip).

const Layout = preload("res://scripts/world/interiors/city_hall_layout.gd")
const CityHallRules = preload("res://scripts/world/interiors/city_hall_rules.gd")
const CityHallQueueRules = preload("res://scripts/world/interiors/city_hall_queue_rules.gd")
const CityHallView = preload("res://scripts/world/interiors/city_hall_view.gd")
const CityHallCaretaker = preload("res://scripts/world/interiors/city_hall_caretaker.gd")
const Spot = preload("res://scripts/world/interiors/interior_spot.gd")
const Announcer = preload("res://scripts/world/interiors/announcer.gd")
## What the rest of the game reads here (the values live in the layers they belong to).
const LIBRARY := CityHallView.LIBRARY
const LIFT_SOUND := CityHallView.LIFT_SOUND
const DOOR_LEAF := Layout.DOOR_LEAF
const DOOR_SLIDE := CityHallView.DOOR_SLIDE
const SERVE_SECONDS := CityHallQueueRules.SERVE_SECONDS
const NO_SHOW_SECONDS := CityHallQueueRules.NO_SHOW_SECONDS
const PLAYER_WAIT := CityHallQueueRules.PLAYER_WAIT
const CALL_PAUSE := CityHallQueueRules.CALL_PAUSE
const VISITOR_PACE := CityHallQueueRules.VISITOR_PACE
const TICKET_GAP := CityHallQueueRules.TICKET_GAP
const BOARD_LINES := CityHallQueueRules.BOARD_LINES
const TICKET_META := CityHallQueueRules.TICKET_META
const TICKET_ITEM := CityHallQueueRules.TICKET_ITEM
const COUNTER_FLOOR := CityHallQueueRules.COUNTER_FLOOR
const WAITING_BOARD_AT := Layout.WAITING_BOARD_AT
const WAITING_BOARD_LINE := Layout.WAITING_BOARD_LINE
const NOW_BOARD_AT := Layout.NOW_BOARD_AT
const COUNTER_TALK_AHEAD := Layout.COUNTER_TALK_AHEAD
const COUNTER_TALK_REACH := Layout.COUNTER_TALK_REACH
const AT_SPOT := CityHallQueueRules.AT_SPOT
const CARETAKER_PACE := CityHallRules.CARETAKER_PACE
const CARETAKER_MOP := CityHallRules.CARETAKER_MOP
const CART_AHEAD := Layout.CART_AHEAD
const CART_TILE := CityHallView.CART_TILE
const CROSS_NO_TICKET := CityHallQueueRules.CROSS_NO_TICKET
const CROSS_NOT_YET := CityHallQueueRules.CROSS_NOT_YET
const NOTICE_HEADING := CityHallRules.NOTICE_HEADING
## The lift of the building: reusable, a scene of its own.
const LIFT_SCENE := "res://scenes/binnen/lift.tscn"

var current_floor := 0
## Its picture.
var view: CityHallView
var _floors: Array[Node3D] = []
var _people_made := {}               # floor number -> true
var _riding := false
var _lift: Node3D                    # the lift (LiftRide)
var _player: Node3D
var _number_taken := 0
## The queue (Burgerzaken): the numbers handed out, in turn (CityHallQueueRules.ticket); the
## counters ({"number", "board", "stand" (where a visitor stands, global), "clerk", "state",
## "ticket", "clock", "visitor"}); the last number given out; the last numbers called (for
## the waiting board).
var _queue: Array[Dictionary] = []
var _counters: Array[Dictionary] = []
var _last_issued := CityHallQueueRules.LAST_ISSUED
var _called: Array[String] = []
var _talking_at := -1                # the counter whose clerk the player talks to now
var _cut_in_line := 0                # times the player came to a counter out of turn
var _sent_away_from: Array[int] = []  # counters whose clerk sent you on ("doorverwezen"): not there again
var _caretaker_round: CityHallCaretaker   # the caretaker of the basement on his round
var _announcer: Node                 # the loudspeakers of Burgerzaken (Announcer)
var _now_board: Node3D               # the big board of the number called now, over the counters
var _seats: Array[Transform3D] = []  # the seats of the visitors of Burgerzaken (floor space)
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.seed = 2026
	view = CityHallView.new()
	add_child(view)
	_caretaker_round = CityHallCaretaker.new(self, _random)
	add_child(_caretaker_round)
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
	for floor_number in view.floors_with_doors():
		view.show_doors(int(floor_number), true, false)


func player_came_in(player: Node3D) -> void:
	_player = player
	if player.has_signal("talk_ended") and not player.is_connected("talk_ended", _on_talk_ended):
		player.connect("talk_ended", _on_talk_ended)


func player_went_out() -> void:
	_riding = false
	if _announcer:
		_announcer.call("stop")
	_drop_ticket()   # the slip does not go out of the door with you


## Putting the player out (Eviction) waits while the lift rides; on another floor than the
## guard, one comes up with the lift (evictor_entry: the lift of the floor you are on).
func evicting_held() -> bool:
	return _riding


func evictor_outfit(role: String) -> Dictionary:
	return CityHallRules.outfit(role)


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
		floor_node.add_child(Spot.create("Liftknop", lift.position, "Lift", _call_lift.bind(number)))
	var door_marker := floor_node.get_node_or_null("Liftdeur") as Node3D
	if door_marker:
		view.build_lift_doors(floor_node, door_marker, number)
		view.build_floor_display(floor_node, door_marker, CityHallRules.level_text(Layout.level_of(number)))
	for child in floor_node.get_children():
		if child is Marker3D and child.name.begins_with("Bord_"):
			view.build_sign(floor_node, child as Node3D, String(child.get_meta("text", "")))
		elif child is Marker3D and child.name.begins_with("Loket_"):
			var counter_name := String(child.name).trim_prefix("Loket_")
			view.build_counter_board(floor_node, child as Node3D, counter_name, CityHallQueueRules.counter_start_text(int(counter_name)))
	var dispenser := floor_node.get_node_or_null("Nummerautomaat") as Node3D
	if dispenser:
		floor_node.add_child(Spot.create("Nummertje", dispenser.position, "Nummertje trekken", _take_number))


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
		var person := InteriorPerson.create(role, CityHallRules.person_seed(number, index), sit, seat, CityHallRules.outfit(role))
		person.name = CityHallRules.person_name(role)
		person.role = role
		if CityHallRules.talks_across_counter(role):
			# behind a counter: talked to across it, from before it
			person.talk_ahead = Layout.COUNTER_TALK_AHEAD
			person.talk_reach = Layout.COUNTER_TALK_REACH
		floor_node.add_child(person)
		person.transform = (child as Node3D).transform
		_people.append(person)
		index += 1


## What who works here wears (CityHallRules.outfit).
static func _outfit(role: String) -> Dictionary:
	return CityHallRules.outfit(role)


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
		ride(CityHallRules.next_floor(from, _floors.size()), false)
		return
	var levels: Array = []
	for index in _floors.size():
		levels.append(Layout.level_of(index))
	var chosen := [-1]
	var page := CityHallRules.lift_page(CityHallRules.floor_choices(levels, Layout.NAMES, from))
	page["on_choice"] = func(choice: int) -> Array:
		chosen[0] = choice
		return []
	view.play_choice(-6.0)
	hud.show_story([page], func() -> void:
		if CityHallRules.is_ride_chosen(int(chosen[0]), current_floor):
			ride(int(chosen[0])))


## The ride to floor `to`: the doors of this floor open (a "ding-dong"), and the ride is the
## scene of the lift (LiftRide, scenes/binnen/lift.tscn: you in the cabin, the camera from the
## front, the display, the motor); under its last swipe you are put out on that floor, its
## doors open, the floor at the top of the screen. `animate` false: at once (the checks).
func ride(to: int, animate := true) -> void:
	if _lift == null or not CityHallRules.may_ride(_riding, current_floor, to, _floors.size()):
		return
	_riding = true
	var from := current_floor
	if animate:
		view.play_ding(floor_node(from).get_node_or_null("Lift") as Node3D)
		view.show_doors(from, true, true)
		await get_tree().create_timer(CityHallView.DOOR_SLIDE + 0.1).timeout
	# the lift counts in levels (the basement is -1, under the ground floor)
	await _lift.ride(Layout.level_of(from), Layout.level_of(to), _player, _arrive.bind(to), animate)
	_riding = false


## Out of the lift on floor `to` (under the lift's last swipe).
func _arrive(to: int) -> void:
	_make_people(to)
	view.show_doors(to, true, false)
	_show_floor(to)
	var lift := floor_node(to).get_node_or_null("Lift") as Node3D
	_move_player(lift)
	var hud := _hud()
	if hud and hud.has_method("show_notice"):
		hud.show_notice(CityHallRules.arrival_heading(Layout.level_of(to)), String(Layout.NAMES[to]))


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


func doors_open(number: int) -> bool:
	return view.doors_open(number)


# ------------------------------------------------------------------ Burgerzaken

## A number from the machine (see the top): a few places on, the slip in the pockets, a thought.
func _take_number() -> void:
	var hud := _hud()
	if _player == null:
		return
	_set_up_queue()
	_drop_ticket()   # a new number: the old one gone (from the pockets and the queue)
	var places := _random.randi_range(CityHallQueueRules.TICKET_GAP.x, CityHallQueueRules.TICKET_GAP.y)
	for skipped in CityHallQueueRules.skipped_before(places):
		_queue.append(CityHallQueueRules.ticket(_issue(), ""))
	_number_taken = _issue()
	_queue.append(CityHallQueueRules.ticket(_number_taken, CityHallQueueRules.PLAYER))
	_player.set_meta(CityHallQueueRules.TICKET_META, _number_taken)
	if _player.has_method("add_item"):
		_player.call("add_item", CityHallQueueRules.TICKET_ITEM, 1, true)
	view.play_choice(-4.0)
	_think(CityHallQueueRules.ticket_thought(_number_taken, _called))
	_update_waiting_board()
	if hud and hud.has_method("show_floating_number"):
		hud.show_floating_number(_player.global_position + Vector3.UP * 2.0, CityHallQueueRules.number_text(_number_taken),
			CityHallView.TICKET_INK, CityHallView.TICKET_SIZE)


func number_taken() -> int:
	return _number_taken


## The number the player holds (0: none).
func player_ticket() -> int:
	return int(_player.get_meta(CityHallQueueRules.TICKET_META, 0)) if _player else 0


func _issue() -> int:
	_last_issued += 1
	return _last_issued


## The queue made once, when Burgerzaken has its people: every visitor a number (in a random
## order), every counter its board, its clerk and where who is called stands.
func _set_up_queue() -> void:
	if not _counters.is_empty() or _floors.size() <= CityHallQueueRules.COUNTER_FLOOR:
		return
	_make_people(CityHallQueueRules.COUNTER_FLOOR)
	var floor_node := floor_node(CityHallQueueRules.COUNTER_FLOOR)
	var clerks: Array[InteriorPerson] = []
	var clerk_xs: Array = []
	var visitors: Array[InteriorPerson] = []
	for person in _people:
		if person.get_parent() != floor_node:
			continue
		if person.role == CityHallQueueRules.CLERK_ROLE:
			clerks.append(person)
			clerk_xs.append(person.position.x)
		elif person.role == CityHallQueueRules.VISITOR_ROLE:
			visitors.append(person)
	var index := 1
	while floor_node.has_node("Loket_%d" % index):
		var marker := floor_node.get_node("Loket_%d" % index) as Node3D
		var clerk_index := CityHallQueueRules.nearest_clerk(clerk_xs, marker.position.x)
		var clerk: InteriorPerson = clerks[clerk_index] if clerk_index >= 0 else null
		var counter := {"number": index, "board": floor_node.get_node_or_null("Nummerbord_%d" % index),
			"stand": floor_node.to_global(Layout.counter_stand(marker.position)), "clerk": clerk,
			"state": CityHallQueueRules.FREE, "ticket": {},
			"clock": _random.randf_range(CityHallQueueRules.FIRST_CALL.x, CityHallQueueRules.FIRST_CALL.y), "visitor": null}
		_counters.append(counter)
		if clerk:
			clerk.set_meta("talk_gate", _talk_gate.bind(index))
			clerk.set_meta("talk_consequence", _talk_consequence.bind(index))
		index += 1
	visitors.shuffle()
	for visitor in visitors:
		_queue.append(CityHallQueueRules.ticket(_issue(), visitor))
		if visitor.sitting:
			_seats.append(visitor.transform)
	view.build_waiting_board(floor_node, CityHallQueueRules.WAITING_HEADING, CityHallQueueRules.BOARD_LINES + 1)
	_update_waiting_board()
	_now_board = view.build_now_board(floor_node, CityHallQueueRules.NOW_HEADING, CityHallQueueRules.NOW_NOBODY)


## The queue moves on (on Burgerzaken only): every counter calls, waits, serves, sends back.
func _advance_queue(delta: float) -> void:
	if current_floor != CityHallQueueRules.COUNTER_FLOOR:
		return
	_set_up_queue()
	for counter in _counters:
		var visitor := counter.visitor as InteriorPerson
		match String(counter.state):
			CityHallQueueRules.FREE:
				counter.clock = float(counter.clock) - delta
				# your number is never called at a counter whose clerk sent you on
				if float(counter.clock) <= 0.0 and CityHallQueueRules.may_call(_queue, int(counter.number), _sent_away_from):
					_call_next(counter)
			CityHallQueueRules.WALKING:
				if not is_instance_valid(visitor):
					_free_counter(counter)
					continue
				walk_evictor(visitor, counter.stand, CityHallQueueRules.VISITOR_PACE, delta)
				if CityHallQueueRules.is_at_spot(visitor.global_position, counter.stand, _path_used_up(visitor)):
					evictor_stops(visitor)
					visitor.global_position = Vector3(counter.stand.x, visitor.global_position.y, counter.stand.z)
					visitor.global_rotation.y = 0.0   # facing the counter
					counter.state = CityHallQueueRules.SERVING
					counter.clock = _random.randf_range(CityHallQueueRules.SERVE_SECONDS.x, CityHallQueueRules.SERVE_SECONDS.y)
			CityHallQueueRules.SERVING:
				counter.clock = float(counter.clock) - delta
				if float(counter.clock) <= 0.0:
					counter.state = CityHallQueueRules.GOING_BACK
					_to_a_free_seat(visitor)
			CityHallQueueRules.GOING_BACK:
				if not is_instance_valid(visitor):
					_free_counter(counter)
					continue
				var home: Dictionary = visitor.get_meta(HOME_META, {})
				var home_at: Vector3 = visitor.get_parent().to_global((home.get("transform", visitor.transform) as Transform3D).origin)
				walk_evictor(visitor, home_at, CityHallQueueRules.VISITOR_PACE, delta)
				if CityHallQueueRules.is_at_spot(visitor.global_position, home_at, _path_used_up(visitor)):
					evictor_done(visitor)
					_queue.append(CityHallQueueRules.ticket(_issue(), visitor))   # a new number: waits again
					_free_counter(counter)
			CityHallQueueRules.NOBODY:
				counter.clock = float(counter.clock) - delta
				if float(counter.clock) <= 0.0:
					_free_counter(counter)
			CityHallQueueRules.FOR_PLAYER:
				counter.clock = float(counter.clock) - delta
				if float(counter.clock) <= 0.0 and _talking_at != int(counter.number):
					_player_missed(counter)
	_update_waiting_board()


## Whether `person`'s path (Interior.walk_evictor) is used up: at the end of where it could go.
func _path_used_up(person: Node3D) -> bool:
	var has_path := person.has_meta("uitzetter_pad")
	var path_left := (person.get_meta("uitzetter_pad") as PackedVector3Array).size() if has_path else 0
	return CityHallQueueRules.is_path_used_up(has_path, path_left, float(person.get_meta("uitzetter_klok", 1.0)), EVICTOR_REPLAN)


## After its turn a visitor goes to sit on a free seat, any of them (not its own one per se):
## its home (Interior HOME_META, where evictor_done seats it) becomes that seat.
func _to_a_free_seat(visitor: InteriorPerson) -> void:
	if _seats.is_empty() or not visitor.has_meta(HOME_META):
		return
	var taken: Array[Vector3] = []
	for person in _people:
		if person != visitor and person.sitting and person.get_parent() == visitor.get_parent():
			taken.append(person.position)
		if person != visitor and person.has_meta(HOME_META):
			taken.append(((person.get_meta(HOME_META) as Dictionary).transform as Transform3D).origin)
	var free := CityHallQueueRules.free_seats(_seats, taken)
	if free.is_empty():
		return
	var home: Dictionary = visitor.get_meta(HOME_META)
	home["transform"] = free[_random.randi() % free.size()]
	home["sitting"] = true
	visitor.set_meta(HOME_META, home)


## Calls the first number of the queue at `counter`: its board, the waiting board, the gong
## and the voice; who has it comes (a visitor walks there, the player is waited for).
func _call_next(counter: Dictionary) -> void:
	var ticket: Dictionary = _queue.pop_front()
	counter.ticket = ticket
	view.show_board_text(counter.board, CityHallQueueRules.number_text(int(ticket.number)))
	_called = CityHallQueueRules.remember_called(_called, CityHallQueueRules.called_line(int(ticket.number), int(counter.number)))
	_announce(int(ticket.number), int(counter.number))
	var who: Variant = ticket.who
	var visitor_comes: bool = who is InteriorPerson and is_instance_valid(who)
	counter.state = CityHallQueueRules.state_after_call(ticket, visitor_comes)
	if visitor_comes:
		counter.visitor = who
	else:
		counter.clock = CityHallQueueRules.wait_seconds(String(counter.state))


func _free_counter(counter: Dictionary) -> void:
	counter.state = CityHallQueueRules.FREE
	counter.ticket = {}
	counter.visitor = null
	counter.clock = _random.randf_range(CityHallQueueRules.CALL_PAUSE.x, CityHallQueueRules.CALL_PAUSE.y)


## The gong, the number at the top of the screen, the voice over the loudspeakers.
func _announce(number: int, counter_number: int) -> void:
	# the big board over the counters at once; the words over the loudspeakers (Announcer: the
	# gong, the voice, the line typing out at the bottom, as at the station and in the shops)
	view.show_now_board(CityHallQueueRules.now_text(number, counter_number))
	if current_floor != CityHallQueueRules.COUNTER_FLOOR or not _player:
		return
	if _announcer == null:
		_announcer = Announcer.new(_hud)
		add_child(_announcer)
	_announcer.say(CityHallQueueRules.announcement(number, counter_number))


## Your number called but you did not come in time: the turn and the slip are gone.
func _player_missed(counter: Dictionary) -> void:
	_use_ticket()
	_free_counter(counter)
	_think(CityHallQueueRules.MISSED_THOUGHT)


## The player's number out of the queue and the slip out of the pockets (going out, a new
## number); a counter waiting for it is free again.
func _drop_ticket() -> void:
	if _player == null or not _player.has_meta(CityHallQueueRules.TICKET_META):
		return
	var number := int(_player.get_meta(CityHallQueueRules.TICKET_META))
	_queue = CityHallQueueRules.without_player(_queue)
	for counter in _counters:
		if String(counter.state) == CityHallQueueRules.FOR_PLAYER and int((counter.ticket as Dictionary).get("number", -1)) == number:
			_free_counter(counter)
	_use_ticket()


## The slip used (or the turn missed): out of the pockets.
func _use_ticket() -> void:
	if _player == null:
		return
	_player.remove_meta(CityHallQueueRules.TICKET_META)
	if _player.has_method("drop_item") and int(_player.get("inventory").get(CityHallQueueRules.TICKET_ITEM, 0)) > 0:
		_player.call("drop_item", CityHallQueueRules.TICKET_ITEM)


## Whether a clerk talks to the player (Conversations through PlayerController.talk_to): only
## at the counter where the player's number is called now; else what they say instead (pages).
func _talk_gate(counter_number: int) -> Array:
	var where := CityHallQueueRules.called_where(_counters, counter_number)
	if bool(where.here):
		_talking_at = counter_number
		return []
	if int(where.elsewhere) > 0:
		return [CityHallQueueRules.elsewhere_page(int(where.elsewhere))]
	# not your turn: the clerk is cross, and doing it again and again is an offence (uitzetten.json
	# "voordringen": the guard warns you, then puts you out)
	_cut_in_line += 1
	var line := CityHallQueueRules.cross_line(_cut_in_line, player_ticket() > 0)
	var interiors := get_parent()
	if interiors and interiors.has_method("offence"):
		interiors.call_deferred("offence", CityHallQueueRules.OFFENCE)
	return [CityHallQueueRules.cross_page(line)]


## What a clerk's answer brings about (Conversations, a node's "gevolg"): "doorverwezen" (this is
## for a colleague: a new number, and that counter not again; can happen again and again, and
## when every counter has sent you on the oldest is forgotten).
func _talk_consequence(gevolg: String, counter_number: int) -> void:
	if gevolg != CityHallQueueRules.SENT_ON:
		return
	# the story hears of it (missie 3: a goal "check" "doorverwezen")
	if _player and _player.has_signal("checked"):
		_player.emit_signal("checked", CityHallQueueRules.SENT_ON, true)
	_sent_away_from = CityHallQueueRules.sent_away_after(_sent_away_from, counter_number, _counters.size())


## The counters whose clerk sent the player on (for the checks).
func sent_away_from() -> Array[int]:
	return _sent_away_from


## The player's conversation with a clerk is over (PlayerController.talk_ended): helped, the
## slip used, the counter free for the next.
func _on_talk_ended(_persona: String) -> void:
	if _talking_at < 0:
		return
	for counter in _counters:
		if int(counter.number) == _talking_at and String(counter.state) == CityHallQueueRules.FOR_PLAYER:
			_use_ticket()
			_free_counter(counter)
	_talking_at = -1


func _update_waiting_board() -> void:
	view.show_waiting_board(CityHallQueueRules.board_texts(_called, _queue.size()))


## What the waiting board says now (for the checks): its lines top to bottom.
func waiting_board_lines() -> Array[String]:
	return view.waiting_board_lines()


func _think(text: String) -> void:
	var hud := _hud()
	if hud and hud.has_method("show_story"):
		hud.show_story([{"kind": "gedachte", "text": text}])


func _process(delta: float) -> void:
	_advance_queue(delta)
	_advance_caretaker(delta)


## The text of a level on the displays: "K" for the basement, else its number.
static func level_text(level: int) -> String:
	return CityHallRules.level_text(level)


# ------------------------------------------------------------------ the basement

## The caretaker goes round the basement with his cart (see the top; CityHallCaretaker): only
## while you are down there.
func _advance_caretaker(delta: float) -> void:
	if current_floor != Layout.BASEMENT or _floors.size() <= Layout.BASEMENT:
		return
	if _caretaker_round.person == null:
		_caretaker_round.take(_find_caretaker())
	var basement := floor_node(Layout.BASEMENT)
	var round_points: Array[Vector3] = []
	for round_point: Vector3 in Layout.CARETAKER_ROUND:
		round_points.append(basement.to_global(round_point))
	_caretaker_round.advance(delta, round_points)


## The caretaker of the basement (made with its people), his cart before him.
func _find_caretaker() -> InteriorPerson:
	for person in _people:
		if person.role == CityHallRules.CARETAKER_ROLE and person.get_parent() == floor_node(Layout.BASEMENT):
			view.build_cart(person)
			return person
	return null


## The caretaker (for the checks): null before the basement was visited.
func caretaker() -> InteriorPerson:
	return _caretaker_round.person as InteriorPerson if _caretaker_round else null


func _hud() -> Node:
	var interiors := get_parent()
	var hud_path: Variant = interiors.get("hud_path") if interiors else null
	return interiors.get_node_or_null(hud_path) if hud_path is NodePath else null
