extends Node
## People who come up to you in the street to sell you something (Characters makes it, a child
## named Straatwerving): once the second mission is done (AFTER_MISSION), in the daytime
## (HOURS), now and then a little group comes after the player (Characters.chase), one of
## PITCHES: the telephone sellers of Lebaarmoeder, the fundraisers of the Stichting Rotonde in
## Nood, two Jehovah's Witnesses with the Wachttoren. Their conversation holds on ("klampt_vast",
## data/gesprekken/personages.json): only the right answer (a hidden check, "los") lets you go,
## and then they walk off; they give up on their own after GIVE_UP seconds.
## Where: mostly round the stations, the squares and the shopping streets of the centre (the
## places of HOT_SPOTS, within their metres), seldom elsewhere (CHANCE_ELSEWHERE); never while
## you are inside, in a conversation or a screen, or when someone else of the story is after
## you; never two within QUIET_AFTER seconds.
## While they are after you they call out what fits them ("kreten" of PITCHES, in a speech
## balloon: DriverShout.shout_line), every CALL_EVERY seconds when the player is near.

const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")

const AFTER_MISSION := "missie_2_bekend_gezicht"
const HOURS := Vector2(9.0, 19.0)
## Seconds between two looks, the chance at a look near a hot spot and elsewhere, the quiet
## after one (seconds), and how long a group keeps after you before it gives up.
const LOOK_EVERY := 12.0
const CHANCE_AT_HOT_SPOT := 0.3
const CHANCE_ELSEWHERE := 0.03
const QUIET_AFTER := 150.0
const GIVE_UP := 150.0
## How often they call out (seconds, from .. to) and within how many metres of the player.
const CALL_EVERY := Vector2(5.0, 10.0)
const CALL_WITHIN := 24.0
## The busy places (the "places" of the town) and how far round them (metres) counts as there.
const HOT_SPOTS := {"centraal": 70.0, "frietkar_centraal": 40.0, "station_laan_van_noi": 40.0, "station_voorburg": 40.0,
	"plein": 45.0, "buitenhof": 35.0, "grote_markt": 40.0, "grote_marktstraat": 55.0, "spui": 45.0, "spui_straat": 45.0,
	"dirigentplein": 30.0, "noordeinde": 45.0}
## Who comes ("wie" talks, "groep" comes along), their conversation then ("gesprek") and after
## ("klaar"), and the hidden check that lets you go ("los").
const PITCHES := [
	{"wie": "telefoonverkoper", "groep": ["telefoonverkoper_kevin", "telefoonverkoper_sanne"], "gesprek": "verkopen",
		"klaar": "klaar", "los": "verkopers_af", "stemming": "opgewonden",
		"kreten": ["Hé! Heb jij al 5G?", "Eén vraagje maar! Niet weglopen!", "Lebaarmoeder! Nu met gratis hoesje!", "Hé, jij daar! Telefoonabonnement?"]},
	{"wie": "werver_rotonde", "groep": ["werver_rotonde_2"], "gesprek": "werven", "klaar": "klaar", "los": "rotonde_af",
		"stemming": "opgewonden",
		"kreten": ["Heb jij een hart voor rotondes?", "Rotonde in Nood! Eén minuutje!", "Adopteer een rotonde!", "Hoi! Hé! Jij lijkt me een rotondemens!"]},
	{"wie": "getuige", "groep": ["getuige_2"], "gesprek": "bekeren", "klaar": "klaar", "los": "getuigen_af", "stemming": "blij",
		"kreten": ["Goedemiddag! Mogen wij u iets geven?", "De Wachttoren, gratis!", "Denkt u wel eens na over de toekomst?", "Een mooie dag, hè? Heeft u even?"]},
]

var characters: Node          # Characters (the parent)
var _clock := LOOK_EVERY
var _quiet := 30.0
var _active := {}             # the pitch under way (one of PITCHES), empty when none
var _active_left := 0.0
var _call_clock := 2.0
var _last_index := -1
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	if characters == null:
		characters = get_parent()


## Whether a group is after the player now, and which (its "wie"; "" for none).
func active_pitch() -> String:
	return String(_active.get("wie", ""))


func _process(delta: float) -> void:
	if characters == null:
		return
	if not _active.is_empty():
		_active_left -= delta
		if _active_left <= 0.0 or not bool(characters.call("is_chasing", String(_active.wie))):
			end_pitch()
			return
		_call_out(delta)
		return
	_quiet -= delta
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = LOOK_EVERY
	if _quiet > 0.0 or not may_start():
		return
	var chance := CHANCE_AT_HOT_SPOT if at_hot_spot() else CHANCE_ELSEWHERE
	if _random.randf() < chance:
		start_pitch(_pick())


## The group under way calls out now and then (one of its "kreten", the leader or one of the
## others), while the player is near and nothing holds the game.
func _call_out(delta: float) -> void:
	_call_clock -= delta
	if _call_clock > 0.0 or get_tree().paused:
		return
	_call_clock = _random.randf_range(CALL_EVERY.x, CALL_EVERY.y)
	var player := _player()
	var names: Array = [String(_active.wie)] + Array(_active.groep)
	var caller := characters.call("person_of", String(names[_random.randi() % names.size()])) as Node3D
	if player == null or caller == null or caller.global_position.distance_to(player.global_position) > CALL_WITHIN:
		return
	var calls: Array = _active.get("kreten", [])
	if not calls.is_empty():
		DriverShout.shout_line(caller, String(calls[_random.randi() % calls.size()]), 2.3, String(_active.get("stemming", "opgewonden")))


## Whether one may come now (see the top): the mission done, daytime, the player outside, free.
func may_start() -> bool:
	var tree := get_tree()
	if tree.paused:
		return false
	var story := tree.get_first_node_in_group("verhaal")
	if story == null or not story.has_method("is_finished") or not bool(story.is_finished(AFTER_MISSION)):
		return false
	var scene := tree.current_scene
	var day := scene.get_node_or_null("Dagcyclus") if scene else null
	if day and "time_of_day" in day:
		var hour := float(day.time_of_day)
		if hour < HOURS.x or hour > HOURS.y:
			return false
	var interiors := tree.get_first_node_in_group("binnenruimtes")
	if interiors and interiors.has_method("is_inside") and bool(interiors.is_inside()):
		return false
	var chasing: Dictionary = characters.get("_chasing")
	return chasing == null or chasing.is_empty()


## Whether the player is round one of HOT_SPOTS.
func at_hot_spot() -> bool:
	var player := _player()
	var scene := get_tree().current_scene
	if player == null or scene == null:
		return false
	var places: Dictionary = scene.get_meta("places", {})
	var feet := Vector2(player.global_position.x, player.global_position.z)
	for place: String in HOT_SPOTS:
		if places.has(place) and feet.distance_to(places[place]) <= float(HOT_SPOTS[place]):
			return true
	return false


func _pick() -> Dictionary:
	var index := _random.randi() % PITCHES.size()
	if index == _last_index:
		index = (index + 1) % PITCHES.size()
	_last_index = index
	return PITCHES[index]


## A group comes after the player (Characters.chase), in its conversation that holds on.
func start_pitch(pitch: Dictionary) -> void:
	if pitch.is_empty() or characters == null:
		return
	var leader := String(pitch.wie)
	characters.call("set_talk", leader, String(pitch.gesprek))
	characters.call("chase", leader, pitch.groep)
	_active = pitch
	_active_left = GIVE_UP
	var player := _player()
	if player and player.has_signal("checked") and not player.is_connected("checked", _on_checked):
		player.connect("checked", _on_checked)


## Over (let go by the right answer, or they gave up): they walk off, their conversation the
## one of after.
func end_pitch() -> void:
	if _active.is_empty():
		return
	var leader := String(_active.wie)
	if bool(characters.call("is_chasing", leader)):
		characters.call("stop_chasing", leader)
	characters.call("set_talk", leader, String(_active.klaar))
	_active = {}
	_quiet = QUIET_AFTER


func _on_checked(check_id: String, passed: bool) -> void:
	if passed and not _active.is_empty() and check_id == String(_active.los):
		end_pitch()


func _player() -> Node3D:
	var path: Variant = characters.get("player_path") if characters else null
	return characters.get_node_or_null(path) as Node3D if path is NodePath else null
