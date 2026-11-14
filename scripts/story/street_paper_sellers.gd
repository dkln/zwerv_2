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
## This is the node (behaviour, docs/CODE_LAGEN.md): its clocks and what it asks of Characters;
## the round, the nearest supermarket and when one goes are street_paper_seller_rules.gd.
##   const StreetPaperSellers = preload("res://scripts/story/street_paper_sellers.gd")

const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")

const StreetPaperSellerRules = preload("res://scripts/story/street_paper_seller_rules.gd")
const SELLERS := StreetPaperSellerRules.SELLERS
const LOOK_EVERY := StreetPaperSellerRules.LOOK_EVERY
const CHANCE := StreetPaperSellerRules.CHANCE
const STAYS := StreetPaperSellerRules.STAYS
const CALLS := StreetPaperSellerRules.CALLS
const CALL_EVERY := StreetPaperSellerRules.CALL_EVERY
## How high over its feet the balloon of a seller calling out stands (metres).
const CALL_HEIGHT := 2.3

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
	var who: String = SELLERS[_random.randi() % SELLERS.size()]
	if characters.call("wander_round", who, StreetPaperSellerRules.spot_before(door.door, outward),
			StreetPaperSellerRules.round_points(outward)) == null:
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
	if StreetPaperSellerRules.may_leave(_left, gap, _inside()):
		characters.call("dismiss", _active)
		_active = ""
		_clock = LOOK_EVERY * 2.0
		return
	_call_clock -= delta
	if _call_clock <= 0.0:
		_call_clock = _random.randf_range(CALL_EVERY.x, CALL_EVERY.y)
		if StreetPaperSellerRules.within_call(gap):
			DriverShout.shout_line(seller, CALLS[_random.randi() % CALLS.size()], CALL_HEIGHT, "opgewonden")


func _nearest_supermarket(player: Node3D) -> Dictionary:
	var interiors := get_tree().get_first_node_in_group("binnenruimtes")
	if interiors == null or not interiors.has_method("supermarkets"):
		return {}
	return StreetPaperSellerRules.nearest_door(interiors.supermarkets(), player.global_position)


func _inside() -> bool:
	var interiors := get_tree().get_first_node_in_group("binnenruimtes")
	return interiors != null and interiors.has_method("is_inside") and bool(interiors.is_inside())


func _player() -> Node3D:
	var path: Variant = characters.get("player_path") if characters else null
	return characters.get_node_or_null(path) as Node3D if path is NodePath else null
