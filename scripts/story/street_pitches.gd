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
## This is the node (behaviour, docs/CODE_LAGEN.md): its clocks and what it asks of Characters;
## who, where, when and what lets you go are street_pitch_rules.gd.
##   const StreetPitches = preload("res://scripts/story/street_pitches.gd")

const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")

const StreetPitchRules = preload("res://scripts/story/street_pitch_rules.gd")
const AFTER_MISSION := StreetPitchRules.AFTER_MISSION
const HOURS := StreetPitchRules.HOURS
const LOOK_EVERY := StreetPitchRules.LOOK_EVERY
const QUIET_AFTER := StreetPitchRules.QUIET_AFTER
const GIVE_UP := StreetPitchRules.GIVE_UP
const HOT_SPOTS := StreetPitchRules.HOT_SPOTS
const PITCHES := StreetPitchRules.PITCHES
## How high over its feet the balloon of someone calling out stands (metres).
const CALL_HEIGHT := 2.3

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
		if StreetPitchRules.is_over(_active_left, bool(characters.call("is_chasing", String(_active.wie)))):
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
	if _random.randf() < StreetPitchRules.chance(at_hot_spot()):
		start_pitch(_pick())


## The group under way calls out now and then (one of its "kreten", the leader or one of the
## others), while the player is near and nothing holds the game.
func _call_out(delta: float) -> void:
	_call_clock -= delta
	if _call_clock > 0.0 or get_tree().paused:
		return
	_call_clock = _random.randf_range(StreetPitchRules.CALL_EVERY.x, StreetPitchRules.CALL_EVERY.y)
	var player := _player()
	var names := StreetPitchRules.names_of(_active)
	var caller := characters.call("person_of", String(names[_random.randi() % names.size()])) as Node3D
	if player == null or caller == null or not StreetPitchRules.within_call(caller.global_position.distance_to(player.global_position)):
		return
	var calls: Array = _active.get("kreten", [])
	if not calls.is_empty():
		DriverShout.shout_line(caller, String(calls[_random.randi() % calls.size()]), CALL_HEIGHT, String(_active.get("stemming", "opgewonden")))


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
		if not StreetPitchRules.is_daytime(float(day.time_of_day)):
			return false
	var interiors := tree.get_first_node_in_group("binnenruimtes")
	if interiors and interiors.has_method("is_inside") and bool(interiors.is_inside()):
		return false
	return not characters.has_method("is_anyone_chasing") or not bool(characters.call("is_anyone_chasing"))


## Whether the player is round one of HOT_SPOTS.
func at_hot_spot() -> bool:
	var player := _player()
	var scene := get_tree().current_scene
	if player == null or scene == null:
		return false
	return StreetPitchRules.at_hot_spot(Vector2(player.global_position.x, player.global_position.z), scene.get_meta("places", {}))


func _pick() -> Dictionary:
	var index := StreetPitchRules.pitch_index(_random.randi() % PITCHES.size(), _last_index)
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
	if StreetPitchRules.lets_go(_active, check_id, passed):
		end_pitch()


func _player() -> Node3D:
	var path: Variant = characters.get("player_path") if characters else null
	return characters.get_node_or_null(path) as Node3D if path is NodePath else null
