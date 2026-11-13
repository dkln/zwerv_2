extends RefCounted
## Unit tests of the OV gates of Den Haag Centraal (scripts/world/station/station_gates.gd): the lane
## someone gets (the right way, the shortest queue), checking in (one at a time, the queue moves
## on), the paddles opening and shutting in time, the player without a card refused, and where
## you stand before and after a lane. The clock, the station and the player are stand-ins.

const OvCard = preload("res://scripts/world/station/ov_card.gd")


## The gates with a clock of the test's own.
class TestGates:
	extends StationGates
	var now := 0.0

	func clock() -> float:
		return now


## The station: who the player is, and the lines it shows.
class TestStation:
	extends Node3D
	var the_player: Node3D
	var said: Array[String] = []

	func player() -> Node3D:
		return the_player

	func say(_at: Vector3, text: String, _colour: Color) -> void:
		said.append(text)


class TestPlayer:
	extends Node3D
	var inventory := {}

	func drop_item(item_id: String) -> void:
		inventory[item_id] = int(inventory.get(item_id, 1)) - 1
		if int(inventory[item_id]) <= 0:
			inventory.erase(item_id)


func _gates(directions: Array) -> TestGates:
	var gates := TestGates.new()
	for index in directions.size():
		var lane := StationGates.Lane.new()
		lane.gates = gates
		lane.direction = directions[index]
		lane.position = Vector3(index * 1.8, 0.0, 0.0)
		gates.add_child(lane)
		gates.lanes.append(lane)
	return gates


## Someone gets a gate that goes their way, the one with the shortest queue (a busy gate
## counts as longer), and none when no gate goes that way.
func test_the_right_way_and_the_shortest_queue(test) -> void:
	var gates := _gates([1, 1, -1])
	var someone := Node.new()
	var waiting := Node.new()
	test.check(gates.lane_for(-1, someone) == gates.lanes[2], "eruit: het poortje dat eruit gaat")
	gates.lanes[0].queue.append(waiting)
	test.check(gates.lane_for(1, someone) == gates.lanes[1], "erin: het poortje zonder rij")
	gates.lanes[1].occupant = waiting
	gates.lanes[1].queue.append(Node.new())
	test.check(gates.lane_for(1, someone) == gates.lanes[0], "een bezet poortje met rij telt langer")
	test.check(_gates([1]).lane_for(-1, someone) == null, "geen poortje die kant op: geen")
	for lane in gates.lanes:
		for queued in lane.queue:
			if is_instance_valid(queued) and queued != waiting:
				queued.free()
	someone.free()
	waiting.free()
	gates.free()


## One person checks in at a gate at a time: the first leaves the queue, the second waits
## and goes after.
func test_one_at_a_time(test) -> void:
	var gates := _gates([1])
	var lane: StationGates.Lane = gates.lanes[0]
	var first := Node.new()
	var second := Node.new()
	lane.queue.append(first)
	lane.queue.append(second)
	test.check(lane.request(first), "de eerste checkt in")
	test.check(lane.occupant == first and not lane.queue.has(first), "is aan de beurt en uit de rij")
	test.check(not lane.request(second), "de tweede moet wachten")
	lane.release(first)
	test.check(lane.request(second), "daarna de tweede")
	first.free()
	second.free()
	gates.free()


## After checking in the paddles swing open, shut again once someone is through, and also
## shut by themselves when nobody walks on.
func test_the_paddles_open_and_shut_in_time(test) -> void:
	var gates := _gates([1])
	var lane: StationGates.Lane = gates.lanes[0]
	var someone := Node.new()
	lane.request(someone)
	for step in 30:   # half a second
		gates.now += 1.0 / 60.0
		lane.update(1.0 / 60.0, gates.now)
	test.check(lane.is_open(), "na het inchecken gaan de kleppen open (%.2f s draaien)" % StationGates.SWING_TIME)
	lane.release(someone)
	for step in 90:
		gates.now += 1.0 / 60.0
		lane.update(1.0 / 60.0, gates.now)
	test.check(not lane.is_open(), "erdoor: ze gaan weer dicht")
	var forgetful := Node.new()
	lane.request(forgetful)
	for step in int((StationGates.OPEN_SECONDS + StationGates.SWING_TIME + 0.5) * 60.0):
		gates.now += 1.0 / 60.0
		lane.update(1.0 / 60.0, gates.now)
	test.check(not lane.is_open(), "en ook als niemand doorloopt, na %.0f s" % StationGates.OPEN_SECONDS)
	someone.free()
	forgetful.free()
	gates.free()


## The player without an OV card is refused and told why; with a card they are checked in
## and told so.
func test_no_card_no_way_through(test) -> void:
	var gates := _gates([1])
	var station := TestStation.new()
	var player := TestPlayer.new()
	station.the_player = player
	gates.station = station
	var lane: StationGates.Lane = gates.lanes[0]
	lane.go_through()
	test.check(lane.occupant == null, "zonder OV-chipkaart blijft het dicht")
	test.check(station.said.has("Geen OV-chipkaart"), "en zegt het waarom")
	player.inventory[StationGates.CARD_ITEM] = 1
	player.set_meta(OvCard.BALANCE_META, 5.0)   # a card with balance: checking in costs the fare
	gates.now = 100.0
	lane.go_through()
	test.check(lane.occupant == player, "met kaart: ingecheckt")
	test.check(station.said.has("Ingecheckt"), "en zegt het")
	test.check(is_equal_approx(float(player.get_meta(StationGates.PASS_META)), 100.0 + StationGates.PASS_SECONDS),
		"doorgang voor %.0f s (anders zwartrijden)" % StationGates.PASS_SECONDS)
	test.check(player.get_meta("ov_ingecheckt") == true, "ingecheckt erin")
	player.free()
	station.free()
	gates.free()


## The spots before and after a lane lie straight in front of the gate.
func test_where_you_stand(test) -> void:
	var gates := _gates([1, -1])
	for lane: StationGates.Lane in gates.lanes:
		var before := lane.entry_point().z - StationLayout.GATE_Z
		var after := lane.exit_point().z - StationLayout.GATE_Z
		test.check(signf(before) == -lane.direction and signf(after) == lane.direction,
			"richting %d: ervoor aan de kant waar je vandaan komt, erna aan de andere" % lane.direction)
		test.check(is_equal_approx(lane.entry_point().x, lane.station_x()), "recht voor het poortje")
	test.check(gates.lanes[0].action_text() == "Inchecken" and gates.lanes[1].action_text() == "Uitchecken",
		"erin inchecken, eruit uitchecken")
	gates.free()


## Not checked out (out of the station still checked in): the next check-in at a gate keeps
## the rest of the boarding fare and says so; a check-in after a check-out costs the fare.
func test_not_checked_out_costs_the_boarding_fare(test) -> void:
	var gates := _gates([1, -1])
	var station := TestStation.new()
	var player := TestPlayer.new()
	station.the_player = player
	gates.station = station
	player.inventory[StationGates.CARD_ITEM] = 1
	player.set_meta(OvCard.BALANCE_META, 10.0)
	var lane_in: StationGates.Lane = gates.lanes[0]
	lane_in.go_through()
	test.check(OvCard.is_checked_in(player) and is_equal_approx(OvCard.balance(player), 9.0), "ingecheckt: € 1 eraf")
	test.check(OvCard.leave_open_trip(player) == "kaart" and not OvCard.is_checked_in(player), "het station uit zonder uitchecken")
	test.check(is_equal_approx(OvCard.missed_check_out_charge(player), OvCard.BOARDING_FARE - OvCard.RIDE_FARE), "de rit staat open: het instaptarief")
	lane_in.release(player)
	lane_in.go_through()
	test.check(is_equal_approx(OvCard.balance(player), 9.0 - OvCard.BOARDING_FARE), "volgende keer inchecken: het instaptarief ingehouden (€ %.2f over)" % OvCard.balance(player))
	test.check(station.said.has("Niet uitgecheckt: € 3,00 ingehouden"), "en de lezer zegt het (%s)" % str(station.said))
	# in again without checking out: the same
	lane_in.release(player)
	lane_in.go_through()
	test.check(is_equal_approx(OvCard.balance(player), 5.0 - OvCard.BOARDING_FARE), "nog eens inchecken zonder uitchecken: weer het instaptarief")
	# out at the out gate, then in: the fare only
	var lane_out: StationGates.Lane = gates.lanes[1]
	lane_out.go_through()
	test.check(not OvCard.is_checked_in(player), "uitgecheckt")
	lane_in.release(player)
	lane_in.go_through()
	test.check(is_equal_approx(OvCard.balance(player), 0.0), "netjes uitgecheckt: daarna alleen de ritprijs")
	# the boarding fare owed and too little on the card: no
	OvCard.leave_open_trip(player)
	player.set_meta(OvCard.BALANCE_META, 2.0)
	lane_in.release(player)
	test.check(OvCard.check_in(player, false) == "saldo", "te weinig voor het instaptarief en de rit: nee")
	test.check(OvCard.refusal("saldo", player) == "Saldo te laag (€ 4,00 nodig)", "en hoeveel nodig is (%s)" % OvCard.refusal("saldo", player))
	player.free()
	station.free()
	gates.free()


## A single ticket not checked out is used up.
func test_ticket_not_checked_out_is_used_up(test) -> void:
	var player := TestPlayer.new()
	player.inventory[OvCard.TICKET_ITEM] = 1
	test.check(OvCard.check_in(player) == "kaartje" and OvCard.is_checked_in(player), "ingecheckt met een los kaartje")
	test.check(OvCard.leave_open_trip(player) == "kaartje" and not OvCard.has_ticket(player), "niet uitgecheckt: het kaartje is op")
	test.check(OvCard.missed_check_out_charge(player) == 0.0, "geen instaptarief zonder kaart")
	player.free()
