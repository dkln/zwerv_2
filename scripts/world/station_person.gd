class_name StationPerson
extends Node3D
## Someone in Den Haag Centraal (scripts/world/station.gd): a traveller ("reiziger"), a
## businessman or -woman ("zakenman", in a suit with a briefcase), a tourist ("toerist", a
## trolley case and often a rucksack), a student ("student", a rucksack), a conductor
## ("conducteur", NS blue with a cap) or one of the station's enforcement officers
## ("handhaver", black with yellow, a cap). A TownsfolkFigure with what it carries
## (CarriedItems), in the group of who can be talked to, as the pedestrians in the town.
## It works through a list of steps the station gives it (`steps`), one at a time:
##   {"type": "walk", "to": Vector3}            walk there (in the space of the station)
##   {"type": "gate", "lane": StationGates.Lane} queue at the lane, hold the card to the
##                                              reader, wait till the paddles are open, walk
##                                              through, let it shut behind
##   {"type": "tap", "at": Vector3, "face": Vector3, "sound": String}   hold the card to an
##                                              OV post (a beep: in or out)
##   {"type": "wait", "seconds": float, "face": Vector3}   stand (looking at a shop, a board)
##   {"type": "wait_train"}                     stand on the platform till the doors of
##                                              `departure`'s train open (the station then
##                                              gives the steps to get in)
##   {"type": "board", "spot": Vector3, "inside": Vector3}  to the door and into the train
##   {"type": "stand", "face": Vector3}         stand there till the station says otherwise
##   {"type": "leave"}                          gone (through a door, into a train)
##   {"type": "chase", "speed": float}          run after the player (a conductor after a
##                                              fare dodger; the station says when it ends)
##   {"type": "climb", "to": Vector3}           up the platform edge from the tracks (arms up,
##                                              a hop), to that spot on the platform
## A handhaver walking as the second of a pair has `follow`: it keeps beside the first.
## It stops for the player when they stand right in its way (at most PLAYER_PATIENCE s).
## The floor (station.floor_height: the hall and the platforms level, the tracks
## PLATFORM_DROP lower): it walks along it, up or down at most MAX_STEP; a higher or lower
## edge stops it (no walking off a platform, nor up one from the rails) except now and then
## by accident (station.stumbles: then it falls, cries out, lands on the rails and the
## station has it climb back up). It steers round the others close by (AVOID_RADIUS: a step
## aside, slower behind someone), and when it makes no headway STUCK_SECONDS on its way the
## station gives it another way (station.person_stuck).

const TALKABLE_GROUP := "aanspreekbaar"
const KnockDown = preload("res://scripts/world/knock_down.gd")
## Hit by a train (hit_by_moving, as the player and the people on the street): from this
## speed (m/s) it is knocked over, its body this heavy (kg), as big as this box (m); it lies
## LIE_SECONDS and is then taken away (the station counts it gone).
const HIT_FROM_SPEED := 1.5
const BODY_MASS := 70.0
const BODY_BOX := Vector3(0.6, 1.8, 0.4)
const LIE_SECONDS := 5.0
const HIT_SHARD_COLOUR := Color("#6B5844")
const TURN_SPEED := 7.0
const ARRIVED := 0.15
const PLAYER_GAP := 0.75
const PLAYER_PATIENCE := 1.6
## Seconds with the card at the reader, and with the whistle at the lips.
const TAP_SECONDS := 0.55
const WHISTLE_SECONDS := 1.3
const QUEUE_GAP := 0.85
## The highest step up or down it walks over (as the player's max_step).
const MAX_STEP := 0.6
const GRAVITY := 9.8
## Climbing up a platform edge: how long it takes, and how high the hop goes over the edge.
const CLIMB_SECONDS := 1.1
const CLIMB_HOP := 0.35
## Others closer than this (metres) it steers away from; slower behind someone this close.
const AVOID_RADIUS := 0.6
const AVOID_STRENGTH := 0.8
## Seconds without headway on its way (walking, to a gate, after the player) before the
## station is asked for another way (and again at every multiple).
const STUCK_SECONDS := 6.0

const UNIFORMS := {
	"conducteur": {"coat": Color("#1E2C55"), "trim": Color("#9FC4EC"), "trousers": Color("#1E2C55"), "cap": Color("#1E2C55")},
	"handhaver": {"coat": Color("#2A4A8A"), "trim": Color("#9FC4EC"), "trousers": Color("#1E3050"), "cap": Color("#2A4A8A")},
}
const SPEEDS := {"reiziger": 1.35, "zakenman": 1.55, "toerist": 1.1, "student": 1.45, "conducteur": 1.3, "handhaver": 1.05}

var role := "reiziger"
var mobility := ""
var sitting := false
var figure: TownsfolkFigure
var carries: Array[String] = []
var station: Node3D
var steps: Array[Dictionary] = []
## The departure (station.gd) it is going to catch, or {}.
var departure: Dictionary = {}
var speed := 1.35
var follow: StationPerson = null
var follow_offset := Vector3(0.9, 0.0, 0.0)

var _phase := 0.0
var _walk_amount := 0.0
var _step_clock := 0.0
var _gate_phase := ""
var _arm := ""                 # "" / "tikken" / "fluiten": the arm up for that
var _arm_clock := 0.0
var _blocked_clock := 0.0
var _falling := false
var _ragdoll: RigidBody3D      # knocked over by a train (hit_by_moving)
var _ragdoll_clock := 0.0
var _fall_speed := 0.0
var _climb_from := Vector3.ZERO
var _edge_rolled := false       # at this edge it has had its one chance of stumbling over
var _stuck_seconds := 0.0
var _stuck_calls := 0
## Seconds on its way without getting anywhere (for the checks and the station).
var stuck_seconds: float:
	get:
		return _stuck_seconds


## Someone of `person_role` with the look of `look_seed`.
static func create(person_role: String, look_seed: int, owner_station: Node3D) -> StationPerson:
	var person := StationPerson.new()
	person.role = person_role
	person.station = owner_station
	person.name = person_role.capitalize()
	var random := RandomNumberGenerator.new()
	random.seed = look_seed * 7919 + 13
	var look: Dictionary
	if person_role == "zakenman":
		look = CarriedItems.business_look(look_seed)
	else:
		look = TownsfolkFigure.look_for(look_seed)
	if UNIFORMS.has(person_role):
		for key: String in UNIFORMS[person_role]:
			look[key] = UNIFORMS[person_role][key]
		look["hair_style"] = "pet"
		look["skirt"] = false
		look["shoes"] = Color("#141210")
	person.figure = TownsfolkFigure.create(look)
	person.figure.name = "Figuur"
	person.add_child(person.figure)
	for kind in _carries_for(person_role, random):
		CarriedItems.attach(person.figure, kind, random.randi())
		person.carries.append(kind)
	person.speed = float(SPEEDS.get(person_role, 1.35)) * random.randf_range(0.9, 1.1)
	if person.carries.has("rolkoffer"):
		person.speed *= 0.9
	person.add_to_group(TALKABLE_GROUP)
	return person


static func _carries_for(person_role: String, random: RandomNumberGenerator) -> Array[String]:
	var found: Array[String] = []
	var roll := random.randf()
	match person_role:
		"zakenman":
			found.append("aktetas" if roll < 0.75 else "rolkoffer")
		"toerist":
			if roll < 0.85:
				found.append("rolkoffer")
			if random.randf() < 0.35 or found.is_empty():
				found.append("rugzak")
		"student":
			found.append("rugzak" if roll < 0.8 else "schoudertas")
		"reiziger":
			if roll < 0.3:
				found.append("handtas")
			elif roll < 0.55:
				found.append("schoudertas")
			elif roll < 0.75:
				found.append("rugzak")
			elif roll < 0.85:
				found.append("rolkoffer")
	return found


## The voice of the cries and the babble (as Pedestrian.voice).
func voice() -> String:
	var look: Dictionary = figure.look if figure else {}
	if look.get("hair_style", "") == "lang" or look.get("skirt", false):
		return "vrouw"
	if look.get("hair_style", "") == "kaal":
		return "oude_man"
	return "man"


func is_staff() -> bool:
	return role == "conducteur" or role == "handhaver"


func current_step() -> Dictionary:
	return steps[0] if not steps.is_empty() else {}


## Puts new steps in place of the ones it has (leaving a lane it was using).
func replace_steps(new_steps: Array[Dictionary]) -> void:
	_leave_lane()
	steps = new_steps
	_step_clock = 0.0
	_gate_phase = ""


## The conductor's whistle: the arm up, the shrill blast.
func blow_whistle() -> void:
	_arm = "fluiten"
	_arm_clock = WHISTLE_SECONDS
	StationAudio.play_at(station, "conducteur_fluit", position + Vector3(0.0, 1.6, 0.0), -2.0)


func _process(delta: float) -> void:
	if _ragdoll:
		_follow_ragdoll(delta)
		return
	var moved := 0.0
	if _falling:
		_fall(delta)
	elif follow != null:
		moved = _follow(delta)
	elif not steps.is_empty():
		moved = _do_step(delta)
	_watch_headway(delta, moved)
	_animate(delta, moved)


## Hit by something moving at `mover_velocity` from `from` (a train coming in or going out):
## as PlayerController.hit_by_moving, the same knock-over (KnockDown), a cry and shards.
## Returns whether it was a real hit.
func hit_by_moving(mover_velocity: Vector3, from: Vector3) -> bool:
	if _ragdoll or figure == null:
		return false
	var impact := mover_velocity.length()
	if impact < HIT_FROM_SPEED:
		return false
	_falling = false
	steps.clear()
	follow = null
	_leave_lane()
	var box := BoxShape3D.new()
	box.size = BODY_BOX
	var side := global_position - from
	side.y = 0.0
	var push := mover_velocity * 0.8 + (side.normalized() if side.length_squared() > 0.001 else Vector3.ZERO) * (impact * 0.3 + 1.0)
	var random := RandomNumberGenerator.new()
	random.seed = get_instance_id()
	_ragdoll = KnockDown.throw(get_parent(), Transform3D(Basis(Vector3.UP, rotation.y), global_position),
			box, Vector3(0.0, BODY_BOX.y * 0.5, 0.0), BODY_MASS, push, impact, random, 1.0, 2.0)
	figure.reparent(_ragdoll, true)
	var contact := global_position + Vector3.UP * 1.0
	CrashBurst.spawn(get_parent(), contact, HIT_SHARD_COLOUR, clampf(impact / 20.0, 0.15, 1.0))
	StationAudio.play_at(station, "lichaam_klap", station.to_local(contact), 0.0)
	StationAudio.play_at(station, "pijn_%s_hard" % voice(), station.to_local(contact), 0.0)
	_ragdoll_clock = 0.0
	return true


## While knocked over: it stays with its body; after LIE_SECONDS it is taken away.
func _follow_ragdoll(delta: float) -> void:
	_ragdoll_clock += delta
	if is_instance_valid(_ragdoll):
		global_position = _ragdoll.global_position
	if _ragdoll_clock >= LIE_SECONDS:
		if station and station.has_method("person_left"):
			station.person_left(self)
		if is_instance_valid(_ragdoll):
			_ragdoll.queue_free()
		queue_free()


## Falling off a platform edge (by accident): down onto the rails, a cry; then the station
## has it climb back up.
func _fall(delta: float) -> void:
	_fall_speed += GRAVITY * delta
	position.y -= _fall_speed * delta
	var floor_y := _floor_at(position)
	if position.y <= floor_y:
		position.y = floor_y
		_falling = false
		_fall_speed = 0.0
		if station and station.has_method("person_fell"):
			station.call("person_fell", self)


## On its way but getting nowhere: after STUCK_SECONDS (and every multiple) the station
## gives it another way (station.person_stuck, with how many times already).
func _watch_headway(delta: float, moved: float) -> void:
	var step := current_step()
	var on_its_way := not step.is_empty() and (String(step.type) in ["walk", "board", "chase"] \
		or (String(step.type) == "gate" and _gate_phase in ["naar", "door"]))
	if not on_its_way or moved > 0.0005 or follow != null or _falling:
		_stuck_seconds = 0.0
		_stuck_calls = 0
		return
	_stuck_seconds += delta
	if _stuck_seconds >= STUCK_SECONDS * (_stuck_calls + 1):
		_stuck_calls += 1
		if station and station.has_method("person_stuck"):
			station.call("person_stuck", self, _stuck_calls)


## Works on the first step; the distance walked.
func _do_step(delta: float) -> float:
	var step: Dictionary = steps[0]
	_step_clock += delta
	match String(step.type):
		"walk":
			var walked := _walk_to(step.to, delta, false, float(step.get("speed", speed)))
			if _at(step.to):
				_next()
			return walked
		"gate":
			return _through_gate(step, delta)
		"tap":
			if _gate_phase == "":
				var walked := _walk_to(step.at, delta)
				if _at(step.at):
					_gate_phase = "tikken"
					_step_clock = 0.0
					_arm = "tikken"
					_arm_clock = TAP_SECONDS
				return walked
			_face(step.face, delta)
			if _step_clock > TAP_SECONDS * 0.5 and not step.has("beeped"):
				step["beeped"] = true
				StationAudio.play_at(station, String(step.sound), (step.at as Vector3) + (step.face as Vector3) * 0.4 + Vector3.UP, -6.0)
			if _step_clock > TAP_SECONDS + 0.25:
				_gate_phase = ""
				_next()
		"wait":
			if step.has("face"):
				_face(step.face, delta)
			if _step_clock >= float(step.seconds):
				_next()
		"stand":
			if step.has("face"):
				_face(step.face, delta)
		"wait_train":
			if step.has("face"):
				_face(step.face, delta)
			if station and station.has_method("waiting_check"):
				station.call("waiting_check", self)
		"board":
			if not step.has("at_door"):
				# with its height: from the floor of a train or onto it (not the rails' floor)
				var walked := _walk_to(step.spot, delta, true)
				if _at(step.spot):
					step["at_door"] = true
				return walked
			var walked := _walk_to(step.inside, delta, true)
			if _at(step.inside):
				_next()
			return walked
		"chase":
			return _chase(float(step.get("speed", speed * 3.0)), delta)
		"climb":
			return _climb(step, delta)
		"climbed":
			_next()
			if station and station.has_method("person_climbed"):
				station.call("person_climbed", self)
		"leave":
			if station and station.has_method("person_left"):
				station.call("person_left", self)
			queue_free()
	return 0.0


func _through_gate(step: Dictionary, delta: float) -> float:
	var lane: StationGates.Lane = step.lane
	if lane == null or not is_instance_valid(lane):
		_next()
		return 0.0
	match _gate_phase:
		"", "naar":
			_gate_phase = "naar"
			if not lane.queue.has(self) and lane.occupant != self:
				lane.queue.append(self)
			var place := lane.queue.find(self)
			var first_in_line := place <= 0 and lane.is_free_for(self)
			var spot := lane.entry_point() - Vector3(0.0, 0.0, lane.direction * QUEUE_GAP * maxi(place, 0 if first_in_line else 1))
			var walked := _walk_to(spot, delta)
			if first_in_line and _at(spot):
				_gate_phase = "tikken"
				_step_clock = 0.0
				_arm = "tikken"
				_arm_clock = TAP_SECONDS
			return walked
		"tikken":
			_face(Vector3(0.0, 0.0, lane.direction), delta)
			if _step_clock >= TAP_SECONDS * 0.6:
				if lane.request(self):
					_gate_phase = "wachten"
				else:
					_gate_phase = "naar"
		"wachten":
			if lane.is_open():
				_gate_phase = "door"
		"door":
			var walked := _walk_to(lane.exit_point(), delta)
			if _at(lane.exit_point()):
				lane.release(self)
				_gate_phase = ""
				_next()
			return walked
	return 0.0


func _leave_lane() -> void:
	if steps.is_empty() or String(steps[0].type) != "gate":
		return
	var lane: StationGates.Lane = steps[0].lane
	if lane and is_instance_valid(lane):
		lane.queue.erase(self)
		lane.release(self)


func _next() -> void:
	if not steps.is_empty():
		steps.pop_front()
	_step_clock = 0.0
	_gate_phase = ""


func _follow(delta: float) -> float:
	if not is_instance_valid(follow):
		follow = null
		steps = [{"type": "leave"}]
		return 0.0
	var leader_basis := Basis(Vector3.UP, follow.rotation.y)
	var target := follow.position + leader_basis * follow_offset
	if position.distance_to(target) < 0.25:
		_face(leader_basis * Vector3.BACK, delta)
		return 0.0
	return _walk_to(target, delta)


## Walks towards `target` (turning to face the way); the distance walked. `with_height`: also
## up or down to its height (getting into a train). Else along the floor: up or down a step of
## at most MAX_STEP; a higher or lower edge stops it (but for a stumble now and then:
## station.stumbles), round the others close by. `walk_speed` (0: its own), `chasing`: after
## the player (does not wait for them).
func _walk_to(target: Vector3, delta: float, with_height := false, walk_speed := 0.0, chasing := false) -> float:
	var flat := Vector3(target.x - position.x, 0.0, target.z - position.z)
	var distance := flat.length()
	if distance < 0.001:
		return 0.0
	var direction := flat / distance
	if not chasing and _player_in_the_way(direction):
		_blocked_clock += delta
		if _blocked_clock < PLAYER_PATIENCE:
			return 0.0
	else:
		_blocked_clock = 0.0
	var pace := walk_speed if walk_speed > 0.0 else speed
	var step := minf(distance, pace * delta)
	var motion := direction * step
	if not with_height:
		var push := _avoidance(direction)
		if push.length_squared() > 0.0001 and distance > 0.4:
			motion = (direction + push).normalized() * step * clampf(1.0 - push.length() * 0.5, 0.35, 1.0)
	# a step aside that would go over an edge: straight on instead
	if not with_height and motion != direction * step and absf(_floor_at(position + motion) - position.y) > MAX_STEP:
		motion = direction * step
	var next := position + motion
	if with_height:
		position = Vector3(next.x, move_toward(position.y, target.y, delta * 1.2), next.z)
	else:
		var floor_y := _floor_at(next)
		if floor_y < position.y - MAX_STEP:
			# an edge down: stop, but for the rare stumble over it
			if _edge_rolled or station == null or not station.has_method("stumbles") or not station.call("stumbles", self, chasing):
				_edge_rolled = true
				_face(direction, delta)
				return 0.0
			position = next
			_falling = true
			_fall_speed = 0.0
			return step
		if floor_y > position.y + MAX_STEP:
			_face(direction, delta)
			return 0.0   # too high to step up (a platform from the rails): only by climbing
		_edge_rolled = false
		position = Vector3(next.x, move_toward(position.y, floor_y, delta * 3.0), next.z)
	_face(direction, delta)
	return motion.length()


## Runs at the player (not stopping for them: they are who it wants), to just before them,
## along the floor (an edge stops it, but for a stumble); the distance run.
func _chase(chase_speed: float, delta: float) -> float:
	var player: Node3D = station.call("player") if station and station.has_method("player") else null
	if player == null or not player.is_inside_tree():
		return 0.0
	var target := station.to_local(player.global_position)
	var flat := Vector3(target.x - position.x, 0.0, target.z - position.z)
	if flat.length() < 0.5:
		_face(flat, delta)
		return 0.0
	return _walk_to(position + flat.normalized() * minf(flat.length() - 0.5, chase_speed * delta * 2.0), delta, false, chase_speed, true)


## Up the platform edge from the rails: the arms up, a hop over the edge onto `to`.
func _climb(step: Dictionary, delta: float) -> float:
	if _step_clock <= delta:
		_climb_from = position
		_arm = "klimmen"
		_arm_clock = CLIMB_SECONDS
	var share := clampf(_step_clock / CLIMB_SECONDS, 0.0, 1.0)
	var to: Vector3 = step.to
	var flat := _climb_from.lerp(to, share)
	position = Vector3(flat.x, lerpf(_climb_from.y, to.y, share) + sin(share * PI) * CLIMB_HOP, flat.z)
	_face(Vector3(to.x - _climb_from.x, 0.0, to.z - _climb_from.z), delta)
	if share >= 1.0:
		position = to
		_edge_rolled = false
		_next()
	return 0.001


## The floor under `at` (the station's, else level where it is).
func _floor_at(at: Vector3) -> float:
	if station and station.has_method("floor_height"):
		return float(station.call("floor_height", at))
	return 0.0


## Steering away from the others close by: a push sideways (and how much slower, 0..1,
## behind someone close in front).
func _avoidance(direction: Vector3) -> Vector3:
	var others: Array = station.call("station_people") if station and station.has_method("station_people") else []
	var push := Vector3.ZERO
	for other in others:
		if other == self or not is_instance_valid(other):
			continue
		var away: Vector3 = position - (other as Node3D).position
		away.y = 0.0
		var gap := away.length()
		if gap < 0.01 or gap > AVOID_RADIUS:
			continue
		var closeness := (AVOID_RADIUS - gap) / AVOID_RADIUS
		if away.dot(direction) < 0.0:
			# in front: step aside, to the side it already is on (or its own side)
			var side := Vector3(-direction.z, 0.0, direction.x)
			var side_sign := signf(away.dot(side))
			if side_sign == 0.0:
				side_sign = 1.0 if get_instance_id() % 2 == 0 else -1.0
			push += side * side_sign * closeness
		else:
			push += away / gap * closeness * 0.5
	return push * AVOID_STRENGTH


func _at(target: Vector3) -> bool:
	return Vector2(position.x - target.x, position.z - target.z).length() < ARRIVED


func _face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	var wanted := atan2(direction.x, direction.z)
	rotation.y = rotation.y + angle_difference(rotation.y, wanted) * minf(1.0, TURN_SPEED * delta)


func _player_in_the_way(direction: Vector3) -> bool:
	var player: Node3D = station.call("player") if station and station.has_method("player") else null
	if player == null or not is_inside_tree() or not player.is_inside_tree():
		return false
	var offset := player.global_position - global_position
	offset.y = 0.0
	return offset.length() < PLAYER_GAP and offset.dot(direction) > 0.2


## Standing still and straight at once, as when the player starts talking to them
## (PlayerController.talk_to): the conversation pauses the game, so mid-stride a leg would
## stay in the air.
func stand_neutral() -> void:
	_walk_amount = 0.0
	_phase = 0.0
	if figure == null:
		return
	figure.walk(0.0, 0.0)
	for kind in carries:
		CarriedItems.pose(figure, kind)


func _animate(delta: float, moved: float) -> void:
	if figure == null:
		return
	if moved > 0.0:
		_phase += moved / TownsfolkFigure.STRIDE * PI
		_walk_amount = move_toward(_walk_amount, 1.0, delta * 5.0)
	else:
		_walk_amount = move_toward(_walk_amount, 0.0, delta * 5.0)
	figure.walk(_phase, _walk_amount)
	for kind in carries:
		CarriedItems.pose(figure, kind)
	if _arm != "":
		_arm_clock -= delta
		if _arm_clock <= 0.0:
			_arm = ""
		elif _arm == "tikken":
			var shoulder := figure.rest_joint("arm_right")
			figure.aim_arm("right", Vector3(shoulder.x + 0.1, shoulder.y - 0.25, 0.45))
		elif _arm == "klimmen":
			# both arms up onto the platform edge
			for side: String in ["left", "right"]:
				var shoulder := figure.rest_joint("arm_" + side)
				figure.aim_arm(side, Vector3(shoulder.x, shoulder.y + 0.55, 0.3))
		elif _arm == "fluiten":
			var shoulder := figure.rest_joint("arm_left")
			figure.aim_arm("left", Vector3(shoulder.x, shoulder.y + 0.6, 0.15))
			var other := figure.rest_joint("arm_right")
			figure.aim_arm("right", Vector3(other.x * 0.3, other.y + 0.25, 0.25))
