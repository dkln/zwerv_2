extends Node
## No longer welcome in an interior: someone of the place comes to put the player out, the
## same in every interior (Interiors makes one when an offence reaches its "na": Interiors.
## offence). Only someone of the place can put you out, and only once they are at you:
## - first the conversation or the shop screen is out of the way (the shop closes at once);
## - then who comes (uitzetten.json "uitzetter" "wie" of the place: the interior's
##   evictor_for, the nearest of that role, or one brought in) shouts why (the offence's
##   "roep", else the place's "kreten") and comes after the player (EVICTOR_SPEED: the player
##   walks 3, runs 6.5 m/s), shouting again now and then (SHOUT_EVERY, "kreten");
## - the rules of the chase are those of the conductor in Den Haag Centraal (Pursuit): at
##   CATCH_REACH they have the player (one more of the "kreten"), and `caught` fires
##   (Interiors then throws them out at once: the swipe, the door, Interiors.throw_out). They do not give up: you get away only by going out yourself;
## - how they walk is the interior's (walk_evictor: over its floor, round its counters and
##   shelves; the station along its own routes), and after it is over the interior puts
##   them back (evictor_done). An interior whose evictor leaves the player's sight (the
##   city hall, the player gone up in the lift) gets another one: the interior's
##   evictor_for again (the guard comes up with the next lift). While evicting_held()
##   (the lift riding) everything waits.
## Someone of the place who is at the player already (the conductor who fined them) needs
## no chase: `already_there`, and it is caught at once.
##   var eviction := Eviction.new()
##   add_child(eviction)
##   eviction.caught.connect(_on_caught)
##   eviction.start(interior, "bedelen", place_rules, player, hud)

signal caught

const Pursuit = preload("res://scripts/world/interiors/pursuit.gd")
const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")
## How fast who comes walks (m/s), how close they must be to have the player (m: along the
## floor), how high their shout hangs over them (m), and how often they shout again (s).
const EVICTOR_SPEED := 3.6
const CATCH_REACH := 1.0
const SHOUT_HEIGHT := 2.1
const SHOUT_EVERY := 5.0
## The group of who can be talked to: who is coming for you is not (until it is over).
const TALKABLE_GROUP := "aanspreekbaar"

var offence := ""
var interior: Node3D
var person: Node3D                   # who is coming for the player now (null: no one yet)
var pursuit: Pursuit
var _player: Node3D
var _hud: Node
var _role := ""
var _shout_lines: Array = []         # the first shout (the offence's "roep")
var _chase_lines: Array = []         # again now and then ("kreten")
var _shout_clock := 0.0
var _started := false                # the boxes out of the way, the chase begun
var _done := false
var _was_talkable := false
var _random := RandomNumberGenerator.new()


## Begins: for `offence_name` in `evicting_from` (an Interior), by the rules of the place
## (`place_rules`: uitzetten.json "plekken" of that place), after `player`. `already_there`:
## someone of the place who is at the player already (caught at once).
func start(evicting_from: Node3D, offence_name: String, place_rules: Dictionary, player: Node3D, hud: Node,
		already_there: Node3D = null) -> void:
	interior = evicting_from
	offence = offence_name
	_player = player
	_hud = hud
	_random.randomize()
	var evictor: Dictionary = place_rules.get("uitzetter", {})
	_role = String(evictor.get("wie", "beveiliger"))
	var rule: Dictionary = (place_rules.get("overtredingen", {}) as Dictionary).get(offence_name, {})
	_chase_lines = evictor.get("kreten", [])
	_shout_lines = rule.get("roep", _chase_lines)
	if already_there != null and is_instance_valid(already_there):
		_take(already_there)
		_started = true
		_finish_caught()
		return
	# the shop closes at once (the conversation is let finish: it pauses the game anyway)
	if _hud and _hud.has_method("is_showing_shop") and _hud.is_showing_shop():
		var shop: Node = _hud.get("_shop_screen")
		if shop and shop.has_method("leave"):
			shop.call("leave")


## Whether it is over (caught, or ended by Interiors).
func is_done() -> bool:
	return _done


func _process(delta: float) -> void:
	if _done or interior == null or not is_instance_valid(interior) or _player == null or not _player.is_inside_tree():
		return
	if not _started:
		if _boxes_open():
			return
		_started = true
	if interior.has_method("evicting_held") and bool(interior.call("evicting_held")):
		return
	if person != null and (not is_instance_valid(person) or not person.is_inside_tree() or not person.is_visible_in_tree()):
		# out of the player's sight (another floor): back where it came from, another one comes
		_release()
	if person == null:
		var found: Node3D = interior.call("evictor_for", _role, _player) if interior.has_method("evictor_for") else null
		if found == null:
			return
		_take(found)
		_shout(_shout_lines, "boos")
	var verdict := pursuit.update(delta, _player.global_position)
	if verdict == Pursuit.CAUGHT:
		_finish_caught()
		return
	if verdict == Pursuit.GAVE_UP:
		_release()
		return
	if interior.has_method("walk_evictor"):
		interior.call("walk_evictor", person, _player.global_position, EVICTOR_SPEED, delta)
	_shout_clock -= delta
	if _shout_clock <= 0.0:
		_shout(_chase_lines, "boos")


## Over without the player caught (they went out themselves, Interiors): who came is put
## back by the interior.
func end() -> void:
	if not _done:
		_done = true
	_release()


## `who` is the one coming for the player now.
func _take(who: Node3D) -> void:
	person = who
	pursuit = Pursuit.new(who, CATCH_REACH)
	_was_talkable = who.is_in_group(TALKABLE_GROUP)
	if _was_talkable:
		who.remove_from_group(TALKABLE_GROUP)
	_shout_clock = SHOUT_EVERY


## Caught: they stop where they are, and `caught` (Interiors throws the player out; who
## caught them is put back once the player is out: end).
func _finish_caught() -> void:
	_done = true
	if person and is_instance_valid(person) and interior and interior.has_method("evictor_stops"):
		interior.call("evictor_stops", person)
	# got them: one more cry as they take them by the collar
	_shout(_chase_lines, "boos")
	caught.emit()


## Who was coming handed back to the interior (evictor_done: back to where they were).
func _release() -> void:
	if person != null and is_instance_valid(person):
		if _was_talkable and not person.is_in_group(TALKABLE_GROUP):
			person.add_to_group(TALKABLE_GROUP)
		if interior and is_instance_valid(interior) and interior.has_method("evictor_done"):
			interior.call("evictor_done", person)
	person = null
	pursuit = null
	_was_talkable = false


func _shout(lines: Array, mood: String) -> void:
	_shout_clock = SHOUT_EVERY
	if person == null or lines.is_empty():
		return
	DriverShout.shout_line(person, String(lines[_random.randi() % lines.size()]), SHOUT_HEIGHT, mood)


func _boxes_open() -> bool:
	if _hud == null:
		return false
	return (_hud.has_method("is_showing_story") and _hud.is_showing_story()) \
		or (_hud.has_method("is_showing_shop") and _hud.is_showing_shop())
