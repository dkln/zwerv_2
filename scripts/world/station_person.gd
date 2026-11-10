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
## A handhaver walking as the second of a pair has `follow`: it keeps beside the first.
## It stops for the player when they stand right in its way (at most PLAYER_PATIENCE s).

const TALKABLE_GROUP := "aanspreekbaar"
const TURN_SPEED := 7.0
const ARRIVED := 0.15
const PLAYER_GAP := 0.75
const PLAYER_PATIENCE := 1.6
## Seconds with the card at the reader, and with the whistle at the lips.
const TAP_SECONDS := 0.55
const WHISTLE_SECONDS := 1.3
const QUEUE_GAP := 0.85

const UNIFORMS := {
	"conducteur": {"coat": Color("#1E2C55"), "trim": Color("#9FC4EC"), "trousers": Color("#1E2C55"), "cap": Color("#1E2C55")},
	"handhaver": {"coat": Color("#16181C"), "trim": Color("#E8C21A"), "trousers": Color("#16181C"), "cap": Color("#16181C")},
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
	var moved := 0.0
	if follow != null:
		moved = _follow(delta)
	elif not steps.is_empty():
		moved = _do_step(delta)
	_animate(delta, moved)


## Works on the first step; the distance walked.
func _do_step(delta: float) -> float:
	var step: Dictionary = steps[0]
	_step_clock += delta
	match String(step.type):
		"walk":
			var walked := _walk_to(step.to, delta)
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
				var walked := _walk_to(step.spot, delta)
				if _at(step.spot):
					step["at_door"] = true
				return walked
			var walked := _walk_to(step.inside, delta, true)
			if _at(step.inside):
				_next()
			return walked
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
## up or down to its height (getting into a train).
func _walk_to(target: Vector3, delta: float, with_height := false) -> float:
	var flat := Vector3(target.x - position.x, 0.0, target.z - position.z)
	var distance := flat.length()
	if distance < 0.001:
		return 0.0
	if _player_in_the_way(flat / distance):
		_blocked_clock += delta
		if _blocked_clock < PLAYER_PATIENCE:
			return 0.0
	else:
		_blocked_clock = 0.0
	var step := minf(distance, speed * delta)
	position += flat / distance * step
	if with_height:
		position.y = move_toward(position.y, target.y, delta * 1.2)
	_face(flat / distance, delta)
	return step


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
		elif _arm == "fluiten":
			var shoulder := figure.rest_joint("arm_left")
			figure.aim_arm("left", Vector3(shoulder.x, shoulder.y + 0.6, 0.15))
			var other := figure.rest_joint("arm_right")
			figure.aim_arm("right", Vector3(other.x * 0.3, other.y + 0.25, 0.25))
