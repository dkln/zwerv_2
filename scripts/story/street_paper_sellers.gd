extends Node
## Sellers of Straatnieuws (the street paper sold by homeless people) by the supermarkets
## (Characters makes it, a child named Straatnieuws): they have no fixed place. Now and then,
## when the player comes near a supermarket (within NEAR_SUPERMARKET of its way in: Interiors
## .supermarkets()), one of SELLERS turns up there and shuffles about before its door (a round
## of a few points, Characters.wander_round), calling out to sell the paper (CALLS, in a speech
## balloon: DriverShout.shout_line) while the player is near; after a while (STAYS seconds) they
## are gone again, as soon as the player is not close by (Characters.dismiss). Talking to them:
## personages.json ("straatnieuws_ans", "straatnieuws_henk"), a free old copy now and then.
## Not while the player is inside.

const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")

const SELLERS := ["straatnieuws_ans", "straatnieuws_henk"]
## Seconds between two looks, the chance a seller turns up at a look (near a supermarket), how
## near (metres) that is, how long one stays (seconds, from .. to) and how near the player may
## be when they go (they do not vanish under its eyes).
const LOOK_EVERY := 15.0
const CHANCE := 0.45
const NEAR_SUPERMARKET := 90.0
const STAYS := Vector2(90.0, 240.0)
const LEAVE_UNSEEN_BEYOND := 30.0
## The round before the door (metres from the way in, outwards and along the front).
const ROUND := [Vector2(0.0, 0.0), Vector2(3.0, 0.0), Vector2(3.0, 2.0), Vector2(-3.0, 2.0), Vector2(-3.0, 0.0)]
## What they call out, how often (seconds, from .. to) and within how many metres of the player.
const CALLS := ["Straatnieuws! Nieuwe editie!", "Straatnieuws, steun de verkoper!", "Straatnieuws! Met puzzel!",
	"Twee vijftig, en de helft is voor mij!", "Straatnieuws! Lees wat de krant niet schrijft!", "Goedemiddag! Straatnieuws?"]
const CALL_EVERY := Vector2(7.0, 14.0)
const CALL_WITHIN := 22.0

var characters: Node
var _clock := 5.0
var _active := ""             # the seller about now ("" none)
var _left := 0.0              # seconds it stays still
var _call_clock := 3.0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	if characters == null:
		characters = get_parent()


## The seller about now ("" for none).
func active_seller() -> String:
	return _active


func _process(delta: float) -> void:
	if characters == null or get_tree().paused:
		return
	var player := _player()
	if player == null:
		return
	if _active != "":
		_stay(player, delta)
		return
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = LOOK_EVERY
	if _inside() or _random.randf() >= CHANCE:
		return
	var door := _nearest_supermarket(player)
	if not door.is_empty():
		turn_up(door)


## A seller turns up before the way in `door` (an Interiors way in: "door", "outward").
func turn_up(door: Dictionary) -> void:
	var outward: Vector3 = door.get("outward", Vector3.BACK)
	var at: Vector3 = door.door + outward * 3.0
	var across := Vector2(-outward.z, outward.x)
	var round_points: Array = []
	for point: Vector2 in ROUND:
		round_points.append(across * point.x + Vector2(outward.x, outward.z) * point.y)
	var who: String = SELLERS[_random.randi() % SELLERS.size()]
	if characters.call("wander_round", who, Vector2(at.x, at.z), round_points) == null:
		return
	_active = who
	_left = _random.randf_range(STAYS.x, STAYS.y)
	_call_clock = _random.randf_range(1.0, 4.0)


func _stay(player: Node3D, delta: float) -> void:
	var seller := characters.call("person_of", _active) as Node3D
	if seller == null:
		_active = ""
		return
	var gap := seller.global_position.distance_to(player.global_position)
	_left -= delta
	if _left <= 0.0 and (gap > LEAVE_UNSEEN_BEYOND or _inside()):
		characters.call("dismiss", _active)
		_active = ""
		_clock = LOOK_EVERY * 2.0
		return
	_call_clock -= delta
	if _call_clock <= 0.0:
		_call_clock = _random.randf_range(CALL_EVERY.x, CALL_EVERY.y)
		if gap <= CALL_WITHIN:
			DriverShout.shout_line(seller, CALLS[_random.randi() % CALLS.size()], 2.3, "opgewonden")


func _nearest_supermarket(player: Node3D) -> Dictionary:
	var interiors := get_tree().get_first_node_in_group("binnenruimtes")
	if interiors == null or not interiors.has_method("supermarkets"):
		return {}
	var best := {}
	var best_gap := NEAR_SUPERMARKET
	for way_in: Dictionary in interiors.supermarkets():
		var gap := (way_in.door as Vector3).distance_to(player.global_position)
		if gap < best_gap:
			best_gap = gap
			best = way_in
	return best


func _inside() -> bool:
	var interiors := get_tree().get_first_node_in_group("binnenruimtes")
	return interiors != null and interiors.has_method("is_inside") and bool(interiors.is_inside())


func _player() -> Node3D:
	var path: Variant = characters.get("player_path") if characters else null
	return characters.get_node_or_null(path) as Node3D if path is NodePath else null
