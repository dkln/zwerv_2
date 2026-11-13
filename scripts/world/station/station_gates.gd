class_name StationGates
extends Node3D
## The OV gates before one platform of Den Haag Centraal (at a marker Poortjes_<n> of
## scenes/binnen/centraal.tscn; scripts/world/station/station.gd makes them): a row of steel cabinets
## (binnen/station/poortje_kast) across the head of the platform with lanes between them
## (StationLayout.gate_lanes), each lane one way: into the station (from the hall to the
## platform, +z) or out of it. In every lane two glass paddles (binnen/station/poortje_klep)
## that really close it: they have a collider while shut, so no one walks through without
## checking in. Holding an OV-chipkaart to the reader (Lane.request) beeps (two high beeps in,
## one longer high beep out), the paddles swing open the way you go, and shut again once you are through.
## The player checks in at a lane with "[E] Inchecken" / "[E] Uitchecken" (only from the side
## the lane lets you in from); without an OV-chipkaart with RIDE_FARE on it or a single ticket
## (OvCard, scripts/world/station/ov_card.gd: checking in costs the fare, a ticket is kept going out) the reader
## refuses with the error tone (high, low, high: ov_geweigerd) and the paddles stay shut. People in the station queue at a lane, check in,
## wait for the paddles and only then walk through (StationPerson).
## A lamp on each end of the reader cabinet: green on the side you may come from, red on the
## other; it flashes white on a beep.

const Layout = preload("res://scripts/world/station/station_layout.gd")
const OvCard = preload("res://scripts/world/station/ov_card.gd")
const DOORS_GROUP := "deuren"
const CARD_ITEM := "ov_chipkaart"
## A check-in by the player lets them through the gate line for this many seconds (the
## player's metadata PASS_META, read by station.gd: crossing without it is fare dodging).
const PASS_SECONDS := 10.0
const PASS_META := "ov_doorgang_tot"
## The player holds a lane open only while in it (between the cabinets, PLAYER_HOLD_REACH
## past their ends) and at most PLAYER_HOLD_SECONDS: standing about at the gates must not
## keep a queue waiting.
const PLAYER_HOLD_REACH := 0.3
const PLAYER_HOLD_SECONDS := 6.0
## Seconds the paddles take to swing, and how long they stay open after a check-in if no one
## goes through.
const SWING_TIME := 0.45
const OPEN_SECONDS := 4.0
## Metres before and after the cabinets where you stand to go through.
const STAND_OFF := 0.9
const PADDLE_HEIGHT := 1.0
const CABINET_HEIGHT := 1.0
const GREEN := Color("#3CE06A")
const RED := Color("#E83A30")

var platform_index := 0
var lanes: Array[Lane] = []
var station: Node3D


## One lane between two cabinets.
class Lane:
	extends Node3D
	var gates: StationGates
	var direction := 1                 # 1: from the hall to the platform (+z); -1 back out
	var width := 1.4
	var occupant: Node = null          # who checked in and is going through
	var queue: Array[Node] = []        # who waits for it
	var _amount := 0.0                 # 0 shut .. 1 open
	var _open_until := 0.0
	var _paddles: Array[Node3D] = []   # the two hinges, left (-x) and right
	var _bodies: Array[CollisionShape3D] = []
	var _lamps: Array[MeshInstance3D] = []
	var _flash := 0.0
	var _sound_played_for := 0.0       # the way the paddles last made a sound for (1 open, 0 shut)
	var _held_since := -1.0            # since when the player holds it (clock)

	## The middle of the lane across the hall (x, in the space of the station).
	func station_x() -> float:
		return gates.position.x + position.x

	## Where you stand before it, on the side you may come from (in the space of the station).
	func entry_point() -> Vector3:
		return Vector3(station_x(), 0.0, Layout.GATE_Z - direction * (Layout.GATE_LENGTH * 0.5 + StationGates.STAND_OFF))

	## Where you are once through.
	func exit_point() -> Vector3:
		return Vector3(station_x(), 0.0, Layout.GATE_Z + direction * (Layout.GATE_LENGTH * 0.5 + StationGates.STAND_OFF))

	## The reader you hold your card to: on the right cabinet, at the end you come from.
	func reader_point() -> Vector3:
		return Vector3(station_x() + width * 0.5 + Layout.GATE_CABINET_WIDTH * 0.5, CABINET_HEIGHT,
				Layout.GATE_Z - direction * (Layout.GATE_LENGTH * 0.5 - 0.2))

	func is_free_for(who: Node) -> bool:
		return occupant == null or occupant == who or not is_instance_valid(occupant)

	func is_open() -> bool:
		return _amount >= 0.95

	## Someone holds a card to the reader: it beeps and opens (true), or it is taken by
	## someone else (false).
	func request(who: Node) -> bool:
		if not is_free_for(who):
			return false
		occupant = who
		queue.erase(who)
		_open_until = gates.clock() + StationGates.OPEN_SECONDS
		_flash = 0.3
		StationAudio.play_at(gates.station, "ov_inchecken" if direction > 0 else "ov_uitchecken", reader_point(), -6.0)
		return true

	## No card: the error tone (high, low, high), and it stays shut.
	func refuse() -> void:
		_flash = -0.5
		StationAudio.play_at(gates.station, "ov_geweigerd", reader_point(), -6.0)

	## Through: it shuts behind them.
	func release(who: Node) -> void:
		if occupant == who:
			occupant = null
			_open_until = minf(_open_until, gates.clock() + 0.3)

	func action_text() -> String:
		return "Inchecken" if direction > 0 else "Uitchecken"

	func reach() -> float:
		return 1.3

	## The player at the lane: with a card it opens (and stays open while they are in it).
	func go_through() -> void:
		var player := gates.player()
		if player == null:
			return
		# a card with enough balance, or a single ticket (OvCard); checking in costs the fare
		var ticket := OvCard.check_in(player, false) if direction > 0 else OvCard.check_out(player, false)
		if ticket == "saldo" or ticket == "geen":
			refuse()
			gates.say(reader_point() + Vector3.UP * 0.6, OvCard.refusal(ticket, player), StationGates.RED)
			return
		if request(player):
			# a trip not checked out: the next check-in keeps the boarding fare (OvCard)
			var charge := OvCard.missed_check_out_charge(player) if direction > 0 and ticket == "kaart" else 0.0
			if direction > 0:
				OvCard.check_in(player)
			else:
				OvCard.check_out(player)
			player.set_meta(StationGates.PASS_META, gates.clock() + StationGates.PASS_SECONDS)
			var text := OvCard.check_in_text(charge) if direction > 0 else "Uitgecheckt"
			gates.say(reader_point() + Vector3.UP * 0.6, text, StationGates.RED if charge > 0.0 else StationGates.GREEN)

	func build(library: MeshLibrary) -> void:
		var item := library.find_item_by_name("station/poortje_klep") if library else -1
		var half := width * 0.5 - 0.02
		for side: float in [-1.0, 1.0]:
			var hinge := Node3D.new()
			hinge.name = "Klep_links" if side < 0.0 else "Klep_rechts"
			# the hinge at the cabinet's side, halfway along it; the paddle reaches to the middle
			hinge.position = Vector3(side * width * 0.5, 0.0, 0.0)
			add_child(hinge)
			if item >= 0:
				var paddle := MeshInstance3D.new()
				paddle.mesh = library.get_item_mesh(item)
				var mesh_box := library.get_item_mesh_transform(item) * paddle.mesh.get_aabb()
				var stretch := half / maxf(mesh_box.size.x, 0.01)
				paddle.transform = Transform3D(Basis.from_scale(Vector3(stretch, 1.0, 1.0)), Vector3(-side * half * 0.5, 0.0, 0.0))
				hinge.add_child(paddle)
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(half, PADDLE_HEIGHT, 0.12)
			shape.shape = box
			shape.position = Vector3(-side * half * 0.5, PADDLE_HEIGHT * 0.5, 0.0)
			body.add_child(shape)
			hinge.add_child(body)
			_paddles.append(hinge)
			_bodies.append(shape)
		# the lamps on the reader cabinet: green where you may come from, red at the other end
		for end: float in [-1.0, 1.0]:
			var lamp := MeshInstance3D.new()
			var cube := BoxMesh.new()
			cube.size = Vector3(0.14, 0.03, 0.14)
			lamp.mesh = cube
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			lamp.material_override = material
			lamp.position = Vector3(width * 0.5 + Layout.GATE_CABINET_WIDTH * 0.5, CABINET_HEIGHT + 0.02, end * (Layout.GATE_LENGTH * 0.5 - 0.35))
			add_child(lamp)
			_lamps.append(lamp)
		_update_lamps()

	func update(delta: float, now: float) -> void:
		var player := gates.player()
		if player and occupant == player:
			# the player holds it open while in it (not for ever)
			if _held_since < 0.0:
				_held_since = now
			var offset := player.global_position - global_position
			var inside := absf(offset.x) < width * 0.5 + 0.2 and absf(offset.z) < Layout.GATE_LENGTH * 0.5 + StationGates.PLAYER_HOLD_REACH
			if inside and now - _held_since < StationGates.PLAYER_HOLD_SECONDS:
				_open_until = maxf(_open_until, now + 0.4)
			elif now > _open_until:
				occupant = null
		else:
			_held_since = -1.0
		if occupant != null and not is_instance_valid(occupant):
			occupant = null
		# no one gone (out of the station, into a train) left in the queue
		for index in range(queue.size() - 1, -1, -1):
			if not is_instance_valid(queue[index]) or not queue[index].is_inside_tree():
				queue.remove_at(index)
		var wanted := 1.0 if now < _open_until else 0.0
		var amount := move_toward(_amount, wanted, delta / StationGates.SWING_TIME)
		if amount != _amount:
			if wanted != _sound_played_for:
				_sound_played_for = wanted
				var sound := "poortje_open" if wanted > 0.5 else "poortje_dicht"
				StationAudio.play_at(gates.station, sound, Vector3(station_x(), 0.6, Layout.GATE_Z), -10.0)
			_amount = amount
			for index in _paddles.size():
				var side := -1.0 if index == 0 else 1.0
				# they swing the way you go: the left one turns its free end to +z for "in"
				_paddles[index].rotation.y = side * direction * PI * 0.5 * _amount
		for shape in _bodies:
			shape.disabled = _amount > 0.2
		if _flash != 0.0:
			_flash = move_toward(_flash, 0.0, delta)
			_update_lamps()

	func _update_lamps() -> void:
		for index in _lamps.size():
			var end := -1.0 if index == 0 else 1.0
			var colour := StationGates.GREEN if end * direction < 0.0 else StationGates.RED
			if _flash > 0.0:
				colour = Color.WHITE
			elif _flash < 0.0:
				colour = StationGates.RED
			(_lamps[index].material_override as StandardMaterial3D).albedo_color = colour


## Builds the cabinets and lanes before platform `index` (at this node, in the gate line).
func build(index: int, library: MeshLibrary, owner_station: Node3D) -> void:
	platform_index = index
	station = owner_station
	var cabinet_item := library.find_item_by_name("station/poortje_kast") if library else -1
	for cabinet_x: float in Layout.gate_cabinets(index):
		var cabinet := StaticBody3D.new()
		cabinet.name = "Kast"
		cabinet.collision_layer = 1
		cabinet.collision_mask = 0
		cabinet.position = Vector3(cabinet_x - position.x, 0.0, 0.0)
		add_child(cabinet)
		if cabinet_item >= 0:
			var model := MeshInstance3D.new()
			model.mesh = library.get_item_mesh(cabinet_item)
			model.transform = library.get_item_mesh_transform(cabinet_item)
			cabinet.add_child(model)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(Layout.GATE_CABINET_WIDTH, CABINET_HEIGHT, Layout.GATE_LENGTH)
		shape.shape = box
		shape.position = Vector3(0.0, CABINET_HEIGHT * 0.5, 0.0)
		cabinet.add_child(shape)
	var width := Layout.gate_lane_width(index)
	for lane_data: Array in Layout.gate_lanes(index):
		var lane := Lane.new()
		lane.name = "Poortje_in" if int(lane_data[1]) > 0 else "Poortje_uit"
		lane.gates = self
		lane.direction = int(lane_data[1])
		lane.width = width
		add_child(lane)
		# the node in the middle of the lane; its interaction point is where you stand
		lane.position = Vector3(float(lane_data[0]) - position.x, 0.0, 0.0)
		lane.build(library)
		lanes.append(lane)
	# the interaction points for the player: before each lane, on the side it lets you in from
	for lane in lanes:
		var point := LanePoint.new()
		point.name = "Incheckpunt"
		point.lane = lane
		add_child(point)
		point.position = lane.entry_point() - position
		point.add_to_group(DOORS_GROUP)


## The spot the player stands at to use a lane (PlayerController finds it in DOORS_GROUP and
## asks it for its action).
class LanePoint:
	extends "res://scripts/world/things/interactable.gd"
	var lane: Lane

	func _init() -> void:
		kind = KIND_GATE

	func action_text() -> String:
		return lane.action_text()

	func reach() -> float:
		return lane.reach()

	func go_through() -> void:
		lane.go_through()


func _physics_process(delta: float) -> void:
	var now := clock()
	for lane in lanes:
		lane.update(delta, now)


## A lane of these gates going `direction` (1 in, -1 out) that is free for `who`, the one
## with the shortest queue; null if none.
func lane_for(direction: int, who: Node) -> Lane:
	var best: Lane = null
	var best_wait := 1 << 20
	for lane in lanes:
		if lane.direction != direction:
			continue
		var wait := lane.queue.size() + (0 if lane.is_free_for(who) else 1)
		if wait < best_wait:
			best_wait = wait
			best = lane
	return best


## Seconds since the start (the time of the gates).
func clock() -> float:
	return Time.get_ticks_msec() / 1000.0


func player() -> Node3D:
	return station.call("player") if station and station.has_method("player") else null


## A line rising over a spot of the gates (the HUD's floating text), if there is a HUD.
func say(at_local: Vector3, text: String, colour: Color) -> void:
	if station and station.has_method("say"):
		station.call("say", at_local, text, colour)
