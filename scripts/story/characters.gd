extends Node3D
## The people of the story (the node "Personages" of scenes/stad.tscn): Ome Wim and the others
## of data/gesprekken/personages.json. Each is a Pedestrian of the town (Voetgangers) that is
## always the same: its own look ("uiterlijk"), its own conversations (Conversations: the
## meta "personage", and "gesprek" for which one now), standing still at its place ("plek")
## until the story needs it (scripts/story/story.gd asks):
## - appear(who): it stands at its place (made the first time);
## - lead(who, points): it walks along the points (world x, z), over the pavements by the
##   route finder (Pedestrians.route_to); it waits for the player while the player is more
##   than WAIT_DISTANCE away and behind it; at the last point it stands still: arrived(who).
##   Meanwhile it walks at its "tempo_meelopen" (m/s), has a marker over its head (LEAD_MARKER:
##   who you walk with) and now and then says a line of its "onderweg" (TALK_EVERY);
## - in_the_way(who, reach, at, past): it stands at `at` in the way; the player talks to it
##   or gets past it (nearer to `past` than it is): got_past(who); then it walks off;
## - chase(who, group): it (and the others of `group` with it) comes up to the player a little
##   after (CHASE_DELAY), keeps following and starts its conversation itself when it gets
##   there (again after CHASE_AGAIN when that is over); stop_chasing(who): they walk off;
## - set_talk(who, key): which of its "gesprekken" it has now.
## It is no part of the crowd round the player (Pedestrians does not move it elsewhere).

signal arrived(who: String)
signal got_past(who: String)

const PedestrianScript = preload("res://scripts/world/people/pedestrian.gd")
const MachineModels = preload("res://scripts/world/things/machine_models.gd")
const CigaretteSmokeScript = preload("res://scripts/effects/cigarette_smoke.gd")
const PROPS_LIBRARY := "res://assets/libraries/props.res"
const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")
const Conversations = preload("res://scripts/story/conversations.gd")
## Metres the player may be behind the one it walks with before that one waits.
const WAIT_DISTANCE := 9.0
## Seconds between two calls of the one waiting ("Kom je nog?").
const CALL_SECONDS := 9.0
const CALLS := ["Kom je nog?", "Hé, deze kant op!", "Niet treuzelen, jong."]
const LOOK_COLOURS := ["skin", "hair", "coat", "trim", "trousers", "shoes", "cap", "helmet"]
## The marker over the one you walk with: an amber diamond (the colour of the quest places on
## the map), this high over its head, this big, bobbing and turning.
const LEAD_MARKER_COLOUR := Color("#FFB830")
const LEAD_MARKER_ABOVE := 0.55
const LEAD_MARKER_SIZE := 0.22
const LEAD_MARKER_BOB := 0.08
const LEAD_MARKER_TURN := 2.0
## Seconds between two lines of its "onderweg" while you walk along (not while it waits), and
## how high over its feet the balloon stands (times its "lengte").
const TALK_EVERY := Vector2(9.0, 16.0)
const TALK_HEIGHT := 2.3

@export var pedestrians_path := NodePath("../Voetgangers")
@export var player_path := NodePath("../Speler")
@export var hud_path := NodePath("../HUD")

var _people := {}           # who -> Pedestrian
var _leading := {}          # who -> {"points": Array[Vector2], "index": int, "call": float}
var _blocking := {}         # who -> {"past": Vector2, "reach": float, "near": bool}
var _chasing := {}          # who -> {"group": Array[String], "wait": float, "retarget": float}
var _wandering := {}        # who -> {"points": Array[Vector2], "index", "pause", "phase", "puff", "smoke", "trolley"} (wander)
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	var player := get_node_or_null(player_path)
	if player and player.has_signal("talked"):
		player.talked.connect(_on_talked)


func _process(delta: float) -> void:
	var player := get_node_or_null(player_path) as Node3D
	if player == null:
		return
	var feet := Vector2(player.global_position.x, player.global_position.z)
	for who: String in _leading.keys():
		_lead_step(who, feet, delta)
	for who: String in _blocking.keys():
		_block_step(who, feet)
	for who: String in _wandering.keys():
		_wander_step(who, feet, delta)
	for who: String in _chasing.keys():
		_chase_step(who, player, feet, delta)


# ------------------------------------------------------------------ the data

static func data() -> Dictionary:
	return Conversations.characters()


func has_character(who: String) -> bool:
	return data().has(who)


## Where `who` stands now (world x, z): the person when it is in town, else its place; INF
## when it has neither.
func spot_of(who: String) -> Vector2:
	var person := _people.get(who) as Node3D
	if person and is_instance_valid(person):
		return Vector2(person.global_position.x, person.global_position.z)
	return _place(str(data().get(who, {}).get("plek", "")))


## The person of `who` in town (null when it is not there yet).
func person_of(who: String) -> Node3D:
	var person := _people.get(who) as Node3D
	return person if person and is_instance_valid(person) else null


# ------------------------------------------------------------------ what the story asks

## `who` in town, standing still at its place (or where it is, when it is there already).
func appear(who: String, at := Vector2.INF) -> Node3D:
	var person := person_of(who)
	if person:
		return person
	var pedestrians := get_node_or_null(pedestrians_path)
	var entry: Dictionary = data().get(who, {})
	if pedestrians == null or entry.is_empty() or not pedestrians.has_method("cell_of"):
		return null
	var spot := at if at != Vector2.INF else _place(str(entry.get("plek", "")))
	if spot == Vector2.INF:
		push_error("characters: %s has no place on the map" % who)
		return null
	var walker: Pedestrian = PedestrianScript.new()
	walker.name = "Personage_" + who
	walker.town = pedestrians
	walker.walker_seed = hash(who)
	walker.wanted_look = _look(entry.get("uiterlijk", {}))
	walker.pace_factor = float(entry.get("tempo", 1.0))
	walker.figure_scale = float(entry.get("lengte", 1.0))
	walker.start_cell = pedestrians.nearest_walkable(pedestrians.cell_of(Vector3(spot.x, 0.0, spot.y)))
	walker.story_held = true
	walker.set_meta(Conversations.CHARACTER_META, who)
	walker.set_meta(Conversations.TALK_META, str(entry.get("standaard", "")))
	if entry.has("stem"):
		walker.set_meta("stem", str(entry.stem))   # Person.VOICE_META: a voice of its own
	pedestrians.add_child(walker)
	walker.story_arrived.connect(func() -> void: _on_arrived(who))
	_people[who] = walker
	return walker


## Which of its conversations `who` has now ("gesprekken" of personages.json).
func set_talk(who: String, key: String) -> void:
	var person := appear(who)
	if person:
		person.set_meta(Conversations.TALK_META, key)


## `who` walks along `points` (world x, z) with the player; at the last: arrived(who).
## `waits` false: it walks there in one go without waiting for the player, and arrived(who)
## comes once the player is within ARRIVED_NEAR of it there (you only follow it a bit).
const ARRIVED_NEAR := 12.0


func lead(who: String, points: Array, waits := true) -> void:
	var person := appear(who) as Pedestrian
	if person == null or points.is_empty():
		arrived.emit.call_deferred(who)
		return
	var entry: Dictionary = data().get(who, {})
	_leading[who] = {"points": points, "index": 0, "call": CALL_SECONDS * 0.5,
		"talk": _random.randf_range(3.0, 6.0), "said": "", "pace": person.get("_pace"), "waits": waits,
		"there": false}
	if entry.has("tempo_meelopen"):
		person.set("_pace", float(entry.tempo_meelopen))
	_mark(person, true)
	_send(person, points[0])


## The marker over the head of the one you walk with (LEAD_MARKER_*), on or off.
func _mark(person: Pedestrian, on: bool) -> void:
	var marker := person.get_node_or_null("Meeloopmarkering") as MeshInstance3D
	if not on:
		if marker:
			marker.queue_free()
		return
	if marker:
		return
	var diamond := SphereMesh.new()   # four sides, one ring: a diamond
	diamond.radial_segments = 4
	diamond.rings = 1
	diamond.radius = LEAD_MARKER_SIZE * 0.6
	diamond.height = LEAD_MARKER_SIZE * 1.6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = LEAD_MARKER_COLOUR
	material.no_depth_test = true   # seen through roofs and trees too
	material.render_priority = 1
	diamond.material = material
	marker = MeshInstance3D.new()
	marker.name = "Meeloopmarkering"
	marker.mesh = diamond
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	person.add_child(marker)
	marker.position.y = _head_height(person) + LEAD_MARKER_ABOVE


## The top of `person`'s figure over its feet (its "lengte" counted).
func _head_height(person: Pedestrian) -> float:
	var who := str(person.get_meta(Conversations.CHARACTER_META, ""))
	return 1.8 * float(data().get(who, {}).get("lengte", 1.0))


func _bob_marker(person: Pedestrian) -> void:
	var marker := person.get_node_or_null("Meeloopmarkering") as Node3D
	if marker == null:
		return
	var clock := Time.get_ticks_msec() / 1000.0
	marker.position.y = _head_height(person) + LEAD_MARKER_ABOVE + sin(clock * 3.0) * LEAD_MARKER_BOB
	marker.rotation.y = clock * LEAD_MARKER_TURN


## The one you walk with stops leading: its own pace again, no marker.
func _stop_leading(who: String) -> void:
	var lead: Dictionary = _leading.get(who, {})
	_leading.erase(who)
	var person := person_of(who) as Pedestrian
	if person == null:
		return
	if lead.get("pace") != null:
		person.set("_pace", float(lead.pace))
	_mark(person, false)


## Now and then a line of its "onderweg" while walking ahead of the player (not while it waits
## or the game stands still), never the same line twice in a row.
func _talk_on_the_way(who: String, person: Pedestrian, lead: Dictionary, delta: float) -> void:
	var lines: Array = data().get(who, {}).get("onderweg", [])
	if lines.is_empty() or get_tree().paused:
		return
	lead.talk = float(lead.talk) - delta
	if float(lead.talk) > 0.0:
		return
	lead.talk = _random.randf_range(TALK_EVERY.x, TALK_EVERY.y)
	var line := str(lines[_random.randi() % lines.size()])
	if line == str(lead.said) and lines.size() > 1:
		line = str(lines[(lines.find(line) + 1) % lines.size()])
	if DriverShout.shout_line(person, line, TALK_HEIGHT * float(data().get(who, {}).get("lengte", 1.0)), "neutraal"):
		lead.said = line


## The last line `who` said on the way (_talk_on_the_way), "" none yet.
func last_said_on_the_way(who: String) -> String:
	return str((_leading.get(who, {}) as Dictionary).get("said", ""))


## `who` stands in the way at `at` (world x, z; INF: a few metres before the player, on the
## way to `past`) until the player talks to it or is nearer to `past` than it: got_past(who).
func in_the_way(who: String, reach: float, at := Vector2.INF, past := Vector2.INF) -> void:
	var player := get_node_or_null(player_path) as Node3D
	var spot := at
	if spot == Vector2.INF and player and past != Vector2.INF:
		var feet := Vector2(player.global_position.x, player.global_position.z)
		spot = feet + (past - feet).normalized() * minf(12.0, feet.distance_to(past) * 0.5)
	var person := appear(who, spot) as Pedestrian
	if person == null:
		got_past.emit.call_deferred(who)
		return
	person.story_held = true
	_blocking[who] = {"past": past, "reach": reach}


# ------------------------------------------------------------------ walking with the player

func _lead_step(who: String, feet: Vector2, delta: float) -> void:
	var person := person_of(who) as Pedestrian
	if person == null:
		_leading.erase(who)
		return
	var lead: Dictionary = _leading[who]
	_bob_marker(person)
	var points: Array = lead.points
	var goal: Vector2 = points[lead.index]
	var at := Vector2(person.global_position.x, person.global_position.z)
	if lead.there:
		# there, without waiting on the way: done once the player has come up too
		if feet.distance_to(at) <= ARRIVED_NEAR:
			_stop_leading(who)
			arrived.emit(who)
		return
	# the player far behind: it waits (and calls now and then); ahead of it: on it goes
	var behind: bool = lead.waits and feet.distance_to(at) > WAIT_DISTANCE and feet.distance_to(goal) > at.distance_to(goal)
	if behind:
		person.story_held = true
		lead.call = float(lead.call) - delta
		if float(lead.call) <= 0.0:
			lead.call = CALL_SECONDS
			_say(person, CALLS[_random.randi() % CALLS.size()])
		return
	_talk_on_the_way(who, person, lead, delta)
	if person.story_held and person.story_goal == Pedestrian.NO_STORY_GOAL and not _at(person, goal):
		_send(person, goal)
	elif person.story_held and person.story_goal != Pedestrian.NO_STORY_GOAL:
		person.story_held = false


func _on_arrived(who: String) -> void:
	if not _leading.has(who):
		return
	var lead: Dictionary = _leading[who]
	lead.index = int(lead.index) + 1
	if int(lead.index) >= (lead.points as Array).size():
		if not lead.waits:
			lead.index = (lead.points as Array).size() - 1
			lead.there = true   # it stands there; arrived once the player is near (_lead_step)
			return
		_stop_leading(who)
		arrived.emit(who)
		return
	var person := person_of(who) as Pedestrian
	if person:
		_send(person, lead.points[lead.index])


func _send(person: Pedestrian, goal: Vector2) -> void:
	var pedestrians := person.town
	person.story_goal = pedestrians.nearest_walkable(pedestrians.cell_of(Vector3(goal.x, person.global_position.y, goal.y)))
	person.set("_way", [] as Array[Vector3i])
	person.story_held = false


func _at(person: Pedestrian, goal: Vector2) -> bool:
	return Vector2(person.global_position.x, person.global_position.z).distance_to(goal) < 6.0


# ------------------------------------------------------------------ after the player

## Seconds after the step begins before they come; how far off (m) they appear, behind the
## player; how near they come (the one who talks, the others round it); seconds between two
## conversations; how often (s) they look again where the player is.
const CHASE_DELAY := 4.0
const CHASE_FROM := 22.0
const CHASE_REACH := 2.2
const CHASE_GROUP_REACH := 3.4
const CHASE_AGAIN := 6.0
const CHASE_RETARGET := 0.5
## How fast (m/s) they come after you: about as fast as you walk, so you cannot simply walk
## away; and how far behind (m) they may lose you before they turn up behind you again (round
## a corner, out of a building).
const CHASE_PACE := 3.2
const CHASE_LOST := 40.0


## `who` (and `group`) come up to the player and keep after it; at it, `who` talks (see the top).
## `first_pages`: shown (GameHud.show_story) once, when it reaches the player the first time,
## before its conversation (the narrator warning you).
func chase(who: String, group: Array = [], first_pages: Array = []) -> void:
	_chasing[who] = {"group": group.duplicate(), "wait": CHASE_DELAY, "retarget": 0.0, "came": false,
		"first_pages": first_pages.duplicate()}


func is_chasing(who: String) -> bool:
	return _chasing.has(who)


## They give up: they walk off into the crowd, the marker of the chase gone.
func stop_chasing(who: String) -> void:
	var chase_state: Dictionary = _chasing.get(who, {})
	_chasing.erase(who)
	for name: String in [who] + Array(chase_state.get("group", [])):
		var person := person_of(name) as Pedestrian
		if person:
			person.story_held = false
			person.story_goal = Pedestrian.NO_STORY_GOAL
			person.set("_pace", 1.3)   # an ordinary walk again


func _chase_step(who: String, player: Node3D, feet: Vector2, delta: float) -> void:
	var chase_state: Dictionary = _chasing[who]
	var hud := get_node_or_null(hud_path)
	var busy: bool = get_tree().paused or (hud and hud.has_method("is_showing_story") and (hud.is_showing_story() \
			or hud.is_showing_shop() or hud.is_showing_reward()))
	if busy:
		return
	chase_state.wait = float(chase_state.wait) - delta
	if not chase_state.came:
		if float(chase_state.wait) > 0.0:
			return
		_come_after(who, chase_state, player)
		chase_state.came = true
		chase_state.wait = 0.0
	chase_state.retarget = float(chase_state.retarget) - delta
	var leader := person_of(who) as Pedestrian
	if leader == null:
		_chasing.erase(who)
		return
	var leader_at := Vector2(leader.global_position.x, leader.global_position.z)
	if leader_at.distance_to(feet) > CHASE_LOST:
		# lost you: they turn up behind you again
		_come_after(who, chase_state, player)
		chase_state.retarget = 0.0
		return
	if leader_at.distance_to(feet) <= CHASE_REACH:
		leader.story_held = true
		leader.story_goal = Pedestrian.NO_STORY_GOAL
		if float(chase_state.wait) <= 0.0 and player.has_method("talk_to"):
			chase_state.wait = CHASE_AGAIN
			var first_pages: Array = chase_state.first_pages
			if not first_pages.is_empty() and hud and hud.has_method("show_story"):
				chase_state.first_pages = []
				hud.show_story(first_pages, func() -> void:
					if is_instance_valid(leader) and _chasing.has(who):
						player.talk_to.call_deferred(leader))
			else:
				player.talk_to(leader)
		return
	if float(chase_state.retarget) > 0.0:
		return
	chase_state.retarget = CHASE_RETARGET
	_send(leader, feet)
	var round_index := 0
	for name: String in chase_state.group:
		var follower := person_of(name) as Pedestrian
		if follower == null:
			continue
		round_index += 1
		var follower_at := Vector2(follower.global_position.x, follower.global_position.z)
		if follower_at.distance_to(feet) <= CHASE_GROUP_REACH:
			follower.story_held = true
			follower.story_goal = Pedestrian.NO_STORY_GOAL
		else:
			# round the player, each on its own side
			_send(follower, feet + Vector2.from_angle(TAU * round_index / 3.0) * 1.5)


## They appear CHASE_FROM behind the player (away from where it looks), side by side.
func _come_after(who: String, chase_state: Dictionary, player: Node3D) -> void:
	var back := Vector2(player.global_basis.z.x, player.global_basis.z.z).normalized()
	if back == Vector2.ZERO:
		back = Vector2.DOWN
	var from := Vector2(player.global_position.x, player.global_position.z) + back * CHASE_FROM
	var side := back.orthogonal()
	var names: Array = [who] + Array(chase_state.group)
	for index in names.size():
		var spot := from + side * (index - (names.size() - 1) * 0.5) * 1.4
		var already := person_of(str(names[index])) as Pedestrian
		var person := appear(str(names[index]), spot) as Pedestrian
		if person == null:
			continue
		if already and person.town and person.town.has_method("cell_of"):
			# there already, far off: brought back behind you
			person.restart_at(person.town.nearest_walkable(person.town.cell_of(Vector3(spot.x, player.global_position.y, spot.y))))
		person.story_held = true
		person.set("_pace", CHASE_PACE)


# ------------------------------------------------------------------ in the way

func _block_step(who: String, feet: Vector2) -> void:
	var person := person_of(who)
	if person == null:
		_blocking.erase(who)
		return
	var block: Dictionary = _blocking[who]
	var past: Vector2 = block.past
	if past == Vector2.INF:
		return
	var at := Vector2(person.global_position.x, person.global_position.z)
	# by it and then on the far side (walked round it): past it
	if feet.distance_to(at) < float(block.reach):
		block["near"] = true
	if block.get("near", false) and feet.distance_to(past) + 2.0 < at.distance_to(past) and feet.distance_to(at) > 3.0:
		_let_go(who)


func _on_talked(persona: String) -> void:
	if _blocking.has(persona):
		# talked yourself out of it: it goes once the conversation is over
		_let_go.call_deferred(persona)


## The one in the way gives up: it walks off as anyone in the crowd; got_past(who).
func _let_go(who: String) -> void:
	if not _blocking.has(who):
		return
	_blocking.erase(who)
	var person := person_of(who) as Pedestrian
	if person:
		person.story_held = false
		person.story_goal = Pedestrian.NO_STORY_GOAL
	got_past.emit(who)


# ------------------------------------------------------------------ wandering about

## `who` wanders about for good along the points of its "zwerft" (personages.json: "punten",
## [x, z] metres from its "plek", in a round; "tempo" m/s; "rookpauze" [from, to] seconds it
## stands still at a point to smoke; "karretje": a shopping trolley before it, full of cans,
## that it pushes; "rookt": a roll-up's smoke at its mouth, CigaretteSmoke). It stops and turns
## to the player who comes near (STOP_FOR_PLAYER), to be talked to. Made the first time.
func wander(who: String) -> Node3D:
	if _wandering.has(who):
		return person_of(who)
	var entry: Dictionary = data().get(who, {})
	var roam: Dictionary = entry.get("zwerft", {})
	var home := _place(str(entry.get("plek", "")))
	if roam.is_empty() or home == Vector2.INF:
		return appear(who)
	var points: Array[Vector2] = []
	for point: Array in roam.get("punten", []):
		points.append(home + Vector2(float(point[0]), float(point[1])))
	if points.is_empty():
		points.append(home)
	var person := appear(who, points[0]) as Pedestrian
	if person == null:
		return null
	person.story_held = true   # it does not walk the pavements as the crowd: we move it
	person.global_position = Vector3(points[0].x, person.global_position.y, points[0].y)
	var state := {"points": points, "index": 0, "pause": 1.0, "phase": 0.0, "puff": 2.0,
		"speed": float(roam.get("tempo", 0.6)), "rest": roam.get("rookpauze", [4.0, 8.0]),
		"smoke": null, "trolley": null}
	if bool(roam.get("karretje", false)):
		state.trolley = _trolley_full_of_cans(person)
	if bool(roam.get("rookt", false)):
		var smoke: Node3D = CigaretteSmokeScript.new()
		smoke.name = "Rook"
		state.smoke = smoke
		_put_smoke_at_mouth.call_deferred(person, smoke)
	_wandering[who] = state
	return person


## Whether `who` wanders about (wander).
func is_wandering(who: String) -> bool:
	return _wandering.has(who)


## Metres from the player at which the one wandering stops and turns to them.
const STOP_FOR_PLAYER := 3.5
## The arm of the one smoking goes to the mouth for this long (s), every SMOKE_EVERY s.
const DRAG_SECONDS := 1.4
const SMOKE_EVERY := Vector2(3.0, 6.0)
## Where the trolley stands before the one pushing it, and its handle (in the person's space).
const TROLLEY_AHEAD := 0.8
const HANDLE := Vector3(0.0, 0.9, 0.36)


func _wander_step(who: String, feet: Vector2, delta: float) -> void:
	var person := person_of(who) as Pedestrian
	var state: Dictionary = _wandering[who]
	if person == null:
		_wandering.erase(who)
		return
	var at := Vector2(person.global_position.x, person.global_position.z)
	var walking := 0.0
	if at.distance_to(feet) < STOP_FOR_PLAYER:
		# someone to talk to: stand and look at them
		var to_player := feet - at
		person.rotation.y = lerp_angle(person.rotation.y, atan2(to_player.x, to_player.y), 1.0 - exp(-delta * 6.0))
	elif float(state.pause) > 0.0:
		state.pause = float(state.pause) - delta
	else:
		var points: Array = state.points
		var goal: Vector2 = points[int(state.index)]
		var to_goal := goal - at
		if to_goal.length() < 0.3:
			state.index = (int(state.index) + 1) % points.size()
			var rest: Array = state.rest
			state.pause = _random.randf_range(float(rest[0]), float(rest[1]))
		else:
			var step := minf(float(state.speed) * delta, to_goal.length())
			var direction := to_goal.normalized()
			person.global_position += Vector3(direction.x, 0.0, direction.y) * step
			person.rotation.y = lerp_angle(person.rotation.y, atan2(direction.x, direction.y), 1.0 - exp(-delta * 4.0))
			walking = 1.0
	_pose_wanderer(person, state, walking, delta)
	_mutter(who, person, state, at.distance_to(feet), delta)


## Metres from the player within which the one wandering mutters to itself, the seconds
## between two lines, and how high over its feet the balloon stands.
const MUTTER_WITHIN := 30.0
const MUTTER_EVERY := Vector2(8.0, 25.0)
const MUTTER_HEIGHT := 2.3


## Now and then a line of its "mompelt" (personages.json) in a speech balloon over its head
## (DriverShout.shout_line, its own babble): only with the player near and not talking (the
## game going on), never the same line twice in a row.
func _mutter(who: String, person: Node3D, state: Dictionary, player_distance: float, delta: float) -> void:
	var lines: Array = data().get(who, {}).get("mompelt", [])
	if lines.is_empty() or get_tree().paused or player_distance > MUTTER_WITHIN:
		return
	state.mutter = float(state.get("mutter", _random.randf_range(2.0, 6.0))) - delta
	if float(state.mutter) > 0.0:
		return
	state.mutter = _random.randf_range(MUTTER_EVERY.x, MUTTER_EVERY.y)
	var line := str(lines[_random.randi() % lines.size()])
	if line == str(state.get("said", "")) and lines.size() > 1:
		line = str(lines[(lines.find(line) + 1) % lines.size()])
	if DriverShout.shout_line(person, line, MUTTER_HEIGHT, "neutraal"):
		state.said = line


## The last line `who` muttered (_mutter), "" none yet.
func last_muttered(who: String) -> String:
	return str((_wandering.get(who, {}) as Dictionary).get("said", ""))


## The walk (slow, pushing), both hands on the trolley's handle; standing, now and then the right
## hand to the mouth for a drag, and a cloud blown out after it (CigaretteSmoke.exhale).
func _pose_wanderer(person: Pedestrian, state: Dictionary, walking: float, delta: float) -> void:
	var figure := person.figure
	if figure == null:
		return
	state.phase = fmod(float(state.phase) + float(state.speed) * delta / TownsfolkFigure.STRIDE * PI * walking, TAU)
	figure.walk(float(state.phase), walking)
	var dragging := false
	if walking == 0.0 and state.smoke != null:
		state.puff = float(state.puff) - delta
		if float(state.puff) <= 0.0:
			state.puff = _random.randf_range(SMOKE_EVERY.x, SMOKE_EVERY.y) + DRAG_SECONDS
			state.drag_left = DRAG_SECONDS
		if float(state.get("drag_left", 0.0)) > 0.0:
			state.drag_left = float(state.drag_left) - delta
			dragging = true
			if float(state.drag_left) <= 0.0:
				(state.smoke as Node).call("exhale")
	var handle := person.to_global(Vector3(0.0, HANDLE.y, HANDLE.z))
	var right := Vector3(0.17, 0.0, 0.0)
	if state.trolley != null:
		figure.aim_arm("left", figure.to_local(handle) - right)
		if not dragging:
			figure.aim_arm("right", figure.to_local(handle) + right)
	if dragging:
		figure.aim_arm("right", TownsfolkFigure.cell_point(Vector3(7.0, 27.0, -3.0)))


## The roll-up's smoke at the mouth of `person`'s figure (once the figure is built).
func _put_smoke_at_mouth(person: Pedestrian, smoke: Node3D) -> void:
	if not is_instance_valid(person) or not is_instance_valid(smoke):
		return
	if person.figure == null:
		get_tree().create_timer(0.3).timeout.connect(_put_smoke_at_mouth.bind(person, smoke))
		return
	person.figure.add_child(smoke)
	smoke.position = TownsfolkFigure.cell_point(Vector3(7.0, 28.5, -4.5))


## A shopping trolley (the props' winkel/winkelwagen) before `person`, full of cans
## (MachineModels.can_mesh) and a few bulging bin bags.
func _trolley_full_of_cans(person: Node3D) -> Node3D:
	var trolley := Node3D.new()
	trolley.name = "Winkelkarretje"
	trolley.position = Vector3(0.0, 0.0, TROLLEY_AHEAD)
	person.add_child(trolley)
	var library := load(PROPS_LIBRARY) as MeshLibrary
	var item := library.find_item_by_name("winkel/winkelwagen") if library else -1
	var basket := AABB(Vector3(-0.3, 0.45, -0.4), Vector3(0.6, 0.45, 0.8))
	if item >= 0:
		var model := MeshInstance3D.new()
		model.name = "Model"
		model.mesh = library.get_item_mesh(item)
		model.transform = library.get_item_mesh_transform(item)
		trolley.add_child(model)
		var box := model.transform * model.mesh.get_aabb()
		basket = AABB(Vector3(box.position.x + 0.08, box.position.y + box.size.y * 0.5, box.position.z + 0.12),
				Vector3(box.size.x - 0.16, box.size.y * 0.45, box.size.z - 0.24))
	var random := RandomNumberGenerator.new()
	random.seed = 4711
	# the bags first, low in the basket; the cans heaped up over and round them
	for bag_index in 2:
		var bag := MeshInstance3D.new()
		bag.name = "Vuilniszak%d" % (bag_index + 1)
		var bag_mesh := BoxMesh.new()
		bag_mesh.size = Vector3(0.26, 0.24, 0.3)
		var bag_material := StandardMaterial3D.new()
		bag_material.albedo_color = Color("#2A2C30") if bag_index == 0 else Color("#3A5A8A")
		bag_material.roughness = 0.4
		bag_mesh.material = bag_material
		bag.mesh = bag_mesh
		bag.position = basket.position + Vector3(basket.size.x * (0.3 + 0.4 * bag_index), basket.size.y * 0.5, basket.size.z * (0.35 + 0.3 * bag_index))
		bag.rotation.y = random.randf_range(-0.4, 0.4)
		trolley.add_child(bag)
	for can_index in 12:
		var can := MeshInstance3D.new()
		can.name = "Blikje%d" % (can_index + 1)
		can.mesh = MachineModels.can_mesh()
		can.position = basket.position + Vector3(random.randf() * basket.size.x, basket.size.y * random.randf_range(0.5, 1.0), 0.15 + random.randf() * (basket.size.z - 0.15))
		can.scale = Vector3.ONE * 0.8
		can.rotation = Vector3(random.randf_range(-1.4, 1.4), random.randf() * TAU, random.randf_range(-1.4, 1.4))
		trolley.add_child(can)
	return trolley


## The trolley of `who` (wander, "karretje"), or null.
func trolley_of(who: String) -> Node3D:
	var state: Dictionary = _wandering.get(who, {})
	return state.get("trolley") as Node3D


## The smoke of `who` (wander, "rookt"), or null.
func smoke_of(who: String) -> Node3D:
	var state: Dictionary = _wandering.get(who, {})
	return state.get("smoke") as Node3D


# ------------------------------------------------------------------ helpers

func _place(key: String) -> Vector2:
	var root: Node = owner if owner else get_parent()
	var places: Dictionary = root.get_meta("places", {}) if root else {}
	return places.get(key, Vector2.INF)


## A look of personages.json ("uiterlijk": colours as #RRGGBB) as TownsfolkFigure has it.
static func _look(entry: Dictionary) -> Dictionary:
	var look := {}
	for key: String in entry:
		look[key] = Color(str(entry[key])) if key in LOOK_COLOURS else entry[key]
	return look


func _say(person: Node3D, text: String) -> void:
	var hud := get_node_or_null(hud_path)
	if hud and hud.has_method("show_floating_number"):
		hud.show_floating_number(person.global_position + Vector3.UP * 2.3, text, Color.WHITE, 13)


## The state to put back after a test (TownWorld.reset): everyone away.
func clear() -> void:
	for who: String in _people:
		var person := person_of(who)
		if person:
			person.queue_free()
	_people.clear()
	_leading.clear()
	_blocking.clear()
	_chasing.clear()
	_wandering.clear()
