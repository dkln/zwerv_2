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
## This is the node (behaviour, docs/CODE_LAGEN.md): who is in town and what each is doing.
## When they wait, where they stand and what they say is character_rules.gd (logic), the
## places of their things characters_layout.gd, what you see of them beyond their figure
## (the marker, the trolley, the smoke, the balloons) characters_view.gd (the child "Beeld").
##   const Characters = preload("res://scripts/story/characters.gd")

signal arrived(who: String)
signal got_past(who: String)
## Someone chasing the player (chase) has come within CHASE_SHOW of it the first time.
signal chase_near(who: String)

const PedestrianScript = preload("res://scripts/world/people/pedestrian.gd")
const Conversations = preload("res://scripts/story/conversations.gd")
const CharacterRules = preload("res://scripts/story/character_rules.gd")
const CharactersLayout = preload("res://scripts/story/characters_layout.gd")
const CharactersView = preload("res://scripts/story/characters_view.gd")
const StreetPitches = preload("res://scripts/story/street_pitches.gd")
const StreetPaperSellers = preload("res://scripts/story/street_paper_sellers.gd")
const WAIT_DISTANCE := CharacterRules.WAIT_DISTANCE
const CALL_SECONDS := CharacterRules.CALL_SECONDS
const CALLS := CharacterRules.CALLS
const TALK_EVERY := CharacterRules.TALK_EVERY
const ARRIVED_NEAR := CharacterRules.ARRIVED_NEAR
const CHASE_DELAY := CharacterRules.CHASE_DELAY
const CHASE_FROM := CharacterRules.CHASE_FROM
const CHASE_SHOW := CharacterRules.CHASE_SHOW
const CHASE_REACH := CharacterRules.CHASE_REACH
const CHASE_GROUP_REACH := CharacterRules.CHASE_GROUP_REACH
const CHASE_AGAIN := CharacterRules.CHASE_AGAIN
const CHASE_RETARGET := CharacterRules.CHASE_RETARGET
const CHASE_PACE := CharacterRules.CHASE_PACE
const CHASE_LOST := CharacterRules.CHASE_LOST
const STOP_FOR_PLAYER := CharacterRules.STOP_FOR_PLAYER
const MUTTER_WITHIN := CharacterRules.MUTTER_WITHIN
const MUTTER_EVERY := CharacterRules.MUTTER_EVERY

@export var pedestrians_path := NodePath("../Voetgangers")
@export var player_path := NodePath("../Speler")
@export var hud_path := NodePath("../HUD")

## What is seen of them beyond their figure.
var view: CharactersView

var _people := {}           # who -> Pedestrian
var _leading := {}          # who -> CharacterRules.lead_state
var _blocking := {}         # who -> {"past": Vector2, "reach": float, "near": bool}
var _chasing := {}          # who -> CharacterRules.chase_state
var _wandering := {}        # who -> CharacterRules.wander_state (wander)
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	view = CharactersView.new()
	add_child(view)
	# who comes up to you in the street once the second mission is done (street_pitches.gd)
	var pitches: Node = StreetPitches.new()
	pitches.name = "Straatwerving"
	pitches.set("characters", self)
	add_child(pitches)
	# sellers of Straatnieuws by the supermarkets, coming and going (street_paper_sellers.gd)
	var paper_sellers: Node = StreetPaperSellers.new()
	paper_sellers.name = "Straatnieuws"
	paper_sellers.set("characters", self)
	add_child(paper_sellers)
	var player := get_node_or_null(player_path)
	if player and player.has_signal("talked"):
		player.talked.connect(_on_talked)


func _process(delta: float) -> void:
	var player := get_node_or_null(player_path) as Node3D
	if player == null:
		return
	var feet := CharacterRules.flat(player.global_position)
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
	var person := person_of(who)
	if person:
		return CharacterRules.flat(person.global_position)
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
	walker.wanted_look = CharactersView.look_of(entry.get("uiterlijk", {}))
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
func lead(who: String, points: Array, waits := true) -> void:
	var person := appear(who) as Pedestrian
	if person == null or points.is_empty():
		arrived.emit.call_deferred(who)
		return
	var entry: Dictionary = data().get(who, {})
	var first_talk := _random.randf_range(CharacterRules.FIRST_TALK.x, CharacterRules.FIRST_TALK.y)
	_leading[who] = CharacterRules.lead_state(points, waits, person.get("_pace"), first_talk)
	if entry.has("tempo_meelopen"):
		person.set("_pace", float(entry.tempo_meelopen))
	view.show_lead_marker(person, _head_height(person))
	_send(person, points[0])


## The top of `person`'s figure over its feet (its "lengte" counted).
func _head_height(person: Node3D) -> float:
	return CharacterRules.head_height(data().get(str(person.get_meta(Conversations.CHARACTER_META, "")), {}))


## The one you walk with stops leading: its own pace again, no marker.
func _stop_leading(who: String) -> void:
	var lead_state: Dictionary = _leading.get(who, {})
	_leading.erase(who)
	var person := person_of(who) as Pedestrian
	if person == null:
		return
	if lead_state.get("pace") != null:
		person.set("_pace", float(lead_state.pace))
	view.hide_lead_marker(person)


## Now and then a line of its "onderweg" while walking ahead of the player (not while it waits
## or the game stands still), never the same line twice in a row.
func _talk_on_the_way(who: String, person: Pedestrian, lead_state: Dictionary, delta: float) -> void:
	var entry: Dictionary = data().get(who, {})
	var lines: Array = entry.get("onderweg", [])
	if lines.is_empty() or get_tree().paused:
		return
	lead_state.talk = float(lead_state.talk) - delta
	if float(lead_state.talk) > 0.0:
		return
	lead_state.talk = _random.randf_range(TALK_EVERY.x, TALK_EVERY.y)
	var line := CharacterRules.other_line(lines, _random.randi(), str(lead_state.said))
	if view.show_line(person, line, CharactersLayout.TALK_HEIGHT * float(entry.get("lengte", 1.0)), "neutraal"):
		lead_state.said = line


## The last line `who` said on the way (_talk_on_the_way), "" none yet.
func last_said_on_the_way(who: String) -> String:
	return str((_leading.get(who, {}) as Dictionary).get("said", ""))


## `who` stands in the way at `at` (world x, z; INF: a few metres before the player, on the
## way to `past`) until the player talks to it or is nearer to `past` than it: got_past(who).
func in_the_way(who: String, reach: float, at := Vector2.INF, past := Vector2.INF) -> void:
	var player := get_node_or_null(player_path) as Node3D
	var feet: Variant = CharacterRules.flat(player.global_position) if player else null
	var person := appear(who, CharacterRules.blocking_spot(at, feet, past)) as Pedestrian
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
	var lead_state: Dictionary = _leading[who]
	view.move_lead_marker(person, _head_height(person), Time.get_ticks_msec() / 1000.0)
	var points: Array = lead_state.points
	var goal: Vector2 = points[lead_state.index]
	var at := CharacterRules.flat(person.global_position)
	if lead_state.there:
		# there, without waiting on the way: done once the player has come up too
		if CharacterRules.has_come_along(feet, at):
			_stop_leading(who)
			arrived.emit(who)
		return
	# the player far behind: it waits (and calls now and then); ahead of it: on it goes
	if CharacterRules.is_behind(lead_state.waits, feet, at, goal):
		person.story_held = true
		lead_state.call = float(lead_state.call) - delta
		if float(lead_state.call) <= 0.0:
			lead_state.call = CALL_SECONDS
			view.show_call(get_node_or_null(hud_path), person, CALLS[_random.randi() % CALLS.size()])
		return
	_talk_on_the_way(who, person, lead_state, delta)
	if person.story_held and person.story_goal == Pedestrian.NO_STORY_GOAL and not CharacterRules.is_at(at, goal):
		_send(person, goal)
	elif person.story_held and person.story_goal != Pedestrian.NO_STORY_GOAL:
		person.story_held = false


func _on_arrived(who: String) -> void:
	if not _leading.has(who):
		return
	var lead_state: Dictionary = _leading[who]
	var count := (lead_state.points as Array).size()
	lead_state.index = int(lead_state.index) + 1
	if CharacterRules.is_route_done(int(lead_state.index), count):
		if not lead_state.waits:
			lead_state.index = count - 1
			lead_state.there = true   # it stands there; arrived once the player is near (_lead_step)
			return
		_stop_leading(who)
		arrived.emit(who)
		return
	var person := person_of(who) as Pedestrian
	if person:
		_send(person, lead_state.points[lead_state.index])


func _send(person: Pedestrian, goal: Vector2) -> void:
	var pedestrians := person.town
	person.story_goal = pedestrians.nearest_walkable(pedestrians.cell_of(Vector3(goal.x, person.global_position.y, goal.y)))
	person.set("_way", [] as Array[Vector3i])
	person.story_held = false


# ------------------------------------------------------------------ after the player

## `who` (and `group`) come up to the player and keep after it; at it, `who` talks (see the top).
## `first_pages`: shown (GameHud.show_story) once, when it reaches the player the first time,
## before its conversation (the narrator warning you).
func chase(who: String, group: Array = [], first_pages: Array = []) -> void:
	_chasing[who] = CharacterRules.chase_state(group, first_pages)


func is_chasing(who: String) -> bool:
	return _chasing.has(who)


## Whether anyone of the story is after the player now.
func is_anyone_chasing() -> bool:
	return not _chasing.is_empty()


## Whether who chases the player has been near it (CHASE_SHOW) yet.
func is_chase_near(who: String) -> bool:
	return bool(_chasing.get(who, {}).get("near", false))


## They give up: they walk off into the crowd, the marker of the chase gone.
func stop_chasing(who: String) -> void:
	var chase_state: Dictionary = _chasing.get(who, {})
	_chasing.erase(who)
	for name: String in CharacterRules.chase_names(who, chase_state):
		var person := person_of(name) as Pedestrian
		if person:
			person.story_held = false
			person.story_goal = Pedestrian.NO_STORY_GOAL
			person.set("_pace", CharacterRules.WALK_PACE)   # an ordinary walk again


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
	var gap := CharacterRules.flat(leader.global_position).distance_to(feet)
	if not chase_state.get("near", false) and CharacterRules.chase_shows(gap):
		chase_state["near"] = true
		chase_near.emit(who)
	if CharacterRules.chase_lost(gap):
		# lost you: they turn up behind you again
		_come_after(who, chase_state, player)
		chase_state.retarget = 0.0
		return
	if CharacterRules.chase_reached(gap):
		_talk_to_the_player(who, leader, chase_state, player, hud)
		return
	if float(chase_state.retarget) > 0.0:
		return
	chase_state.retarget = CHASE_RETARGET
	_send(leader, feet)
	_send_followers(chase_state.group, feet)


## The one who chases has reached the player: it stands, and starts its conversation (again
## after CHASE_AGAIN), the first time after the pages that warn you.
func _talk_to_the_player(who: String, leader: Pedestrian, chase_state: Dictionary, player: Node3D, hud: Node) -> void:
	leader.story_held = true
	leader.story_goal = Pedestrian.NO_STORY_GOAL
	if float(chase_state.wait) > 0.0 or not player.has_method("talk_to"):
		return
	chase_state.wait = CHASE_AGAIN
	var first_pages: Array = chase_state.first_pages
	if not first_pages.is_empty() and hud and hud.has_method("show_story"):
		chase_state.first_pages = []
		hud.show_story(first_pages, func() -> void:
			if is_instance_valid(leader) and _chasing.has(who):
				player.talk_to.call_deferred(leader))
	else:
		player.talk_to(leader)


## The others of a chase: round the player, each on its own side; standing once they are there.
func _send_followers(group: Array, feet: Vector2) -> void:
	var round_index := 0
	for name: String in group:
		var follower := person_of(name) as Pedestrian
		if follower == null:
			continue
		round_index += 1
		if CharacterRules.follower_reached(CharacterRules.flat(follower.global_position).distance_to(feet)):
			follower.story_held = true
			follower.story_goal = Pedestrian.NO_STORY_GOAL
		else:
			_send(follower, CharacterRules.follower_spot(feet, round_index))


## They appear CHASE_FROM behind the player (away from where it looks), side by side.
func _come_after(who: String, chase_state: Dictionary, player: Node3D) -> void:
	var names := CharacterRules.chase_names(who, chase_state)
	var spots := CharacterRules.chase_spots(CharacterRules.flat(player.global_position),
		CharacterRules.flat(player.global_basis.z), names.size())
	for index in names.size():
		var spot: Vector2 = spots[index]
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
	var at := CharacterRules.flat(person.global_position)
	# by it and then on the far side (walked round it): past it
	if CharacterRules.is_by(feet, at, float(block.reach)):
		block["near"] = true
	if CharacterRules.is_past(block.get("near", false), feet, at, past):
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
	var state := CharacterRules.wander_state(CharacterRules.round_points(home, roam.get("punten", [])), roam, [4.0, 8.0])
	var person := _put_on_round(who, state)
	if person == null:
		return null
	if bool(roam.get("karretje", false)):
		state.trolley = view.show_trolley(person)
	if bool(roam.get("rookt", false)):
		state.smoke = view.show_smoke(person)
	_wandering[who] = state
	return person


## Whether `who` wanders about (wander).
func is_wandering(who: String) -> bool:
	return _wandering.has(who)


## `who` wanders about `home` (world x, z) along `points` (offsets from it, metres) instead of
## round its "plek": someone without a fixed place (a seller of Straatnieuws by a supermarket,
## street_paper_sellers.gd). Made now, as wander does it otherwise.
func wander_round(who: String, home: Vector2, points: Array) -> Node3D:
	if _wandering.has(who):
		return person_of(who)
	var roam: Dictionary = data().get(who, {}).get("zwerft", {})
	var state := CharacterRules.wander_state(CharacterRules.round_points(home, points), roam, [3.0, 7.0])
	var person := _put_on_round(who, state)
	if person == null:
		return null
	_wandering[who] = state
	return person


## `who` in town at the first point of the round of `state`, held by the story (it does not
## walk the pavements as the crowd: we move it); null when it cannot appear.
func _put_on_round(who: String, state: Dictionary) -> Pedestrian:
	var first: Vector2 = state.points[0]
	var person := appear(who, first) as Pedestrian
	if person == null:
		return null
	person.story_held = true
	person.global_position = Vector3(first.x, person.global_position.y, first.y)
	return person


## `who` gone from the town (someone who comes and goes: a seller of Straatnieuws); made
## again the next time it appears.
func dismiss(who: String) -> void:
	_wandering.erase(who)
	_chasing.erase(who)
	var person := person_of(who)
	_people.erase(who)
	if person and is_instance_valid(person):
		person.queue_free()


func _wander_step(who: String, feet: Vector2, delta: float) -> void:
	var person := person_of(who) as Pedestrian
	var state: Dictionary = _wandering[who]
	if person == null:
		_wandering.erase(who)
		return
	var at := CharacterRules.flat(person.global_position)
	var walking := 0.0
	if CharacterRules.stops_for(at.distance_to(feet)):
		# someone to talk to: stand and look at them
		_turn(person, feet - at, CharacterRules.TURN_TO_PLAYER, delta)
	elif float(state.pause) > 0.0:
		state.pause = float(state.pause) - delta
	else:
		var points: Array = state.points
		var to_goal: Vector2 = points[int(state.index)] - at
		if CharacterRules.round_point_reached(to_goal):
			state.index = (int(state.index) + 1) % points.size()
			var rest: Array = state.rest
			state.pause = _random.randf_range(float(rest[0]), float(rest[1]))
		else:
			var direction := to_goal.normalized()
			person.global_position += Vector3(direction.x, 0.0, direction.y) * CharacterRules.step_length(float(state.speed), delta, to_goal)
			_turn(person, direction, CharacterRules.TURN_TO_WAY, delta)
			walking = 1.0
	_pose_wanderer(person, state, walking, delta)
	_mutter(who, person, state, at.distance_to(feet), delta)


## `person` turns a little more to look along `way` (x, z).
func _turn(person: Node3D, way: Vector2, rate: float, delta: float) -> void:
	person.rotation.y = lerp_angle(person.rotation.y, CharacterRules.facing(way), CharacterRules.turn_share(delta, rate))


## Now and then a line of its "mompelt" (personages.json) in a speech balloon over its head
## (its own babble): only with the player near and not talking (the game going on), never
## the same line twice in a row.
func _mutter(who: String, person: Node3D, state: Dictionary, player_distance: float, delta: float) -> void:
	var lines: Array = data().get(who, {}).get("mompelt", [])
	if lines.is_empty() or get_tree().paused or not CharacterRules.mutters(player_distance):
		return
	if not state.has("mutter"):
		state.mutter = _random.randf_range(CharacterRules.FIRST_MUTTER.x, CharacterRules.FIRST_MUTTER.y)
	state.mutter = float(state.mutter) - delta
	if float(state.mutter) > 0.0:
		return
	state.mutter = _random.randf_range(MUTTER_EVERY.x, MUTTER_EVERY.y)
	var line := CharacterRules.other_line(lines, _random.randi(), str(state.get("said", "")))
	if view.show_line(person, line, CharactersLayout.MUTTER_HEIGHT, "neutraal"):
		state.said = line


## The last line `who` muttered (_mutter), "" none yet.
func last_muttered(who: String) -> String:
	return str((_wandering.get(who, {}) as Dictionary).get("said", ""))


## The walk (slow, pushing), both hands on the trolley's handle; standing, now and then the right
## hand to the mouth for a drag, and a cloud blown out after it (CigaretteSmoke.exhale).
func _pose_wanderer(person: Pedestrian, state: Dictionary, walking: float, delta: float) -> void:
	if person.figure == null:
		return
	state.phase = CharacterRules.walk_phase(float(state.phase), float(state.speed), delta, TownsfolkFigure.STRIDE, walking)
	view.show_walk(person, float(state.phase), walking)
	var dragging := walking == 0.0 and state.smoke != null and _takes_a_drag(state, delta)
	view.show_hands(person, state.trolley != null, dragging)


## The one smoking, standing: every SMOKE_EVERY seconds a drag of DRAG_SECONDS, a cloud blown
## out when it ends. True while the hand is at the mouth.
func _takes_a_drag(state: Dictionary, delta: float) -> bool:
	state.puff = float(state.puff) - delta
	if float(state.puff) <= 0.0:
		state.puff = _random.randf_range(CharacterRules.SMOKE_EVERY.x, CharacterRules.SMOKE_EVERY.y) + CharacterRules.DRAG_SECONDS
		state.drag_left = CharacterRules.DRAG_SECONDS
	if float(state.get("drag_left", 0.0)) <= 0.0:
		return false
	state.drag_left = float(state.drag_left) - delta
	if float(state.drag_left) <= 0.0:
		view.show_puff(state.smoke)
	return true


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
