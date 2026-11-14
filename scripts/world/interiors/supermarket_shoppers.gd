extends Node
## Who shops in a branch of a supermarket (behaviour, docs/CODE_LAGEN.md; the supermarket,
## supermarket.gd, makes one and steps it: advance). Shoppers walk in through the door, go
## along a few shelves (stopping, their basket or trolley filling up), queue at a checkout,
## pay and walk out again; some only look and leave; new ones come in now and then, as many
## as the branch is big. They walk on the grid of the free floor round the shelves, and
## wait for the player when they stand in the way. What they do and when:
## supermarket_shopper_rules.gd; their trolley or basket: supermarket_carrier_view.gd.
##   const SupermarketShoppers = preload("res://scripts/world/interiors/supermarket_shoppers.gd")

const SupermarketShopperRules = preload("res://scripts/world/interiors/supermarket_shopper_rules.gd")
const SupermarketFloorRules = preload("res://scripts/world/interiors/supermarket_floor_rules.gd")
const SupermarketCarrierView = preload("res://scripts/world/interiors/supermarket_carrier_view.gd")
const SupermarketLayout = preload("res://scripts/world/interiors/supermarket_layout.gd")
const NODE_NAME := "Winkelend"

## The one at the front of a queue pays: the till at `at` (the shop's space) beeps `count` times.
signal paying(at: Vector3, count: int)

## What the shoppers did since the branch was laid out: came in, paid at a checkout, went out.
var stats := {"binnen": 0, "betaald": 0, "weg": 0}
## The player (null: no one to wait for).
var player: Node3D

var _plan := {}
var _brand := ""
var _grid: AStarGrid2D
var _random: RandomNumberGenerator
var _holder: Node3D                     # the people stand in it (the shop's space)
var _people: Array[InteriorPerson] = [] # the people of the interior: the shoppers are among them
var _shoppers: Array[Dictionary] = []   # see SupermarketShopperRules.new_shopper, and "person"
var _queues := {}                       # checkout number -> Array of shoppers (Dictionaries)
var _spawn_clock := 0.0
var _next_look := {}                    # the look of the next shopper, built on a thread first
var _next_seed := 0


func _init() -> void:
	name = NODE_NAME


## Starts anew in the branch of `plan` (of the chain `brand`): the people go into `holder`
## (the shop's space) and into `people` (the interior's list), walk on `grid`, and every
## draw comes from `random` (the branch's own). A few are in the shop already, mid-way
## through their round (their looks from `already_seeds`, at the plan's "people"); the
## next ones get `next_seed` and on.
func begin(plan: Dictionary, brand: String, grid: AStarGrid2D, holder: Node3D, people: Array[InteriorPerson],
		random: RandomNumberGenerator, already_seeds: Array[int], next_seed: int) -> void:
	_plan = plan
	_brand = brand
	_grid = grid
	_holder = holder
	_people = people
	_random = random
	_shoppers.clear()
	_queues.clear()
	stats = {"binnen": 0, "betaald": 0, "weg": 0}
	_spawn_clock = SupermarketShopperRules.spawn_seconds(_random, true)
	for index in already_seeds.size():
		var spot: Transform3D = plan.people[index]
		add_shopper(already_seeds[index], spot.origin, true)
	_next_seed = next_seed
	_prepare_next_look()


## The shoppers in the shop now: {"person", "steps", "path", "speed", "phase", "walking",
## "clock", "waited", "cart", ...} each.
func shoppers() -> Array[Dictionary]:
	return _shoppers


## The seconds until the next one comes in.
func seconds_to_next() -> float:
	return _spawn_clock


## `delta` seconds on: a new one in when it is time, and everyone a step further.
func advance(delta: float) -> void:
	if _plan.is_empty():
		return
	_spawn_clock -= delta
	if _spawn_clock <= 0.0:
		_spawn_clock = SupermarketShopperRules.spawn_seconds(_random)
		if SupermarketShopperRules.comes_in(_shoppers.size(), _plan, TownsfolkFigure.is_prepared(_next_look)):
			add_shopper(_next_seed, Vector3.ZERO)
			stats.binnen += 1
			_next_seed += 1
			_prepare_next_look()
	for shopper in _shoppers.duplicate():
		_update_shopper(shopper, delta)


## Someone shopping, from `look_seed`: coming in at the door (or, `already`, standing at
## `at` mid-way through their round).
func add_shopper(look_seed: int, at: Vector3, already := false) -> void:
	var person := InteriorPerson.create("klant", look_seed, false)
	person.name = "Klant"
	_holder.add_child(person)
	_people.append(person)
	var shopper := SupermarketShopperRules.new_shopper(_random)
	shopper["person"] = person
	# a basket on the arm or a trolley before them, in the chain's colour
	person.add_child(SupermarketCarrierView.shopper_model(bool(shopper.cart), _brand))
	person.fit_collider()   # the trolley or basket is part of what bumps
	if already:
		person.position = at
	else:
		person.position = SupermarketShopperRules.entry_position(_plan)
		person.rotation.y = 0.0
	shopper["steps"] = SupermarketShopperRules.plan_round(_plan, _grid, already, SupermarketLayout.beside, _random)
	_shoppers.append(shopper)


func _prepare_next_look() -> void:
	_next_look = TownsfolkFigure.look_for(_next_seed)
	TownsfolkFigure.prepare(_next_look)


func _update_shopper(shopper: Dictionary, delta: float) -> void:
	var person: InteriorPerson = shopper.person
	if not is_instance_valid(person):
		_shoppers.erase(shopper)
		return
	var steps: Array = shopper.steps
	if steps.is_empty():
		_remove_shopper(shopper)
		return
	var step: Dictionary = steps[0]
	var moved := 0.0
	if step.has("walk"):
		moved = _walk_along(shopper, step.walk, delta)
		if moved < 0.0:
			steps.pop_front()
			shopper.path = PackedVector3Array()
			moved = 0.0
	elif step.has("look"):
		shopper.clock = float(shopper.clock) + delta
		_turn_to(person, step.face, delta)
		# reaching into the shelf halfway, a pack into the basket or trolley
		if float(shopper.clock) >= float(step.look):
			shopper.clock = 0.0
			shopper.goods = int(shopper.goods) + 1
			steps.pop_front()
	elif step.has("queue"):
		moved = _queue_at(shopper, int(step.queue), delta)
	elif step.has("leave"):
		_remove_shopper(shopper)
		return
	_animate(shopper, moved, delta)


## Walks `shopper` towards `target` along the floor grid; returns how far it moved, or -1
## once it is there.
func _walk_along(shopper: Dictionary, target: Vector3, delta: float) -> float:
	var person: InteriorPerson = shopper.person
	var path: PackedVector3Array = shopper.path
	if path.is_empty():
		path = SupermarketFloorRules.path(_grid, _plan, person.position, target)
		shopper.path = path
	if path.is_empty():
		return -1.0
	var next := path[0]
	var offset := next - person.position
	offset.y = 0.0
	if offset.length() < SupermarketShopperRules.AT_POINT:
		path.remove_at(0)
		shopper.path = path
		return -1.0 if path.is_empty() else 0.0
	var direction := offset.normalized()
	if _player_in_the_way(person.position, direction):
		shopper.waited = float(shopper.waited) + delta
		if float(shopper.waited) < SupermarketShopperRules.patience(_plan, person.position):
			return 0.0
	else:
		shopper.waited = 0.0
	return _step_towards(shopper, offset, delta)


## A step of `shopper` along `offset` (no further than its end), turning that way.
func _step_towards(shopper: Dictionary, offset: Vector3, delta: float) -> float:
	var person: InteriorPerson = shopper.person
	var direction := offset.normalized()
	var step := minf(float(shopper.speed) * delta, offset.length())
	person.position += direction * step
	_turn_to(person, direction, delta)
	return step


## In the queue of checkout `number`: to the place in it, the first pays (beeps), then on.
func _queue_at(shopper: Dictionary, number: int, delta: float) -> float:
	var queue: Array = _queues.get(number, [])
	if not queue.has(shopper):
		queue.append(shopper)
		_queues[number] = queue
		shopper.path = PackedVector3Array()
	var checkout := SupermarketShopperRules.checkout(_plan, number)
	var place := queue.find(shopper)
	if int(shopper.get("place", -1)) != place:
		shopper["place"] = place
		shopper.path = PackedVector3Array()   # moved up: a new way to the new place
	var spot := SupermarketShopperRules.queue_spot(checkout, place)
	var person: InteriorPerson = shopper.person
	var offset := spot - person.position
	offset.y = 0.0
	if offset.length() > SupermarketShopperRules.QUEUE_WALK:
		return maxf(_walk_along(shopper, spot, delta), 0.0)
	if offset.length() > SupermarketShopperRules.QUEUE_AT:
		return _step_towards(shopper, offset, delta)
	_turn_to(person, Vector3(0.0, 0.0, -1.0), delta)
	if place != 0:
		return 0.0
	if float(shopper.clock) == 0.0:
		shopper.clock = 0.001
		shopper["pay_for"] = SupermarketShopperRules.pay_seconds(_random)
		paying.emit(checkout.pay_at, int(shopper.goods))
	shopper.clock = float(shopper.clock) + delta
	if float(shopper.clock) >= float(shopper.get("pay_for", 5.0)):
		shopper.clock = 0.0
		stats.betaald += 1
		queue.erase(shopper)
		(shopper.steps as Array).pop_front()
		shopper.path = PackedVector3Array()
	return 0.0


func _remove_shopper(shopper: Dictionary) -> void:
	if _shoppers.has(shopper):
		stats.weg += 1
	_shoppers.erase(shopper)
	for number in _queues:
		(_queues[number] as Array).erase(shopper)
	var person: InteriorPerson = shopper.person
	if is_instance_valid(person):
		_people.erase(person)
		person.queue_free()


func _animate(shopper: Dictionary, moved: float, delta: float) -> void:
	var person: InteriorPerson = shopper.person
	if person.figure == null:
		return
	var gait := SupermarketShopperRules.gait(float(shopper.phase), float(shopper.walking), moved, delta, TownsfolkFigure.STRIDE)
	shopper.phase = gait.x
	shopper.walking = gait.y
	person.figure.walk(float(shopper.phase), float(shopper.walking))
	if bool(shopper.cart):
		SupermarketCarrierView.hold_cart(person.figure)


func _turn_to(person: Node3D, direction: Vector3, delta: float) -> void:
	person.rotation.y = SupermarketShopperRules.turned(person.rotation.y, direction, delta)


func _player_in_the_way(from: Vector3, direction: Vector3) -> bool:
	if player == null or not is_instance_valid(player) or not player.is_visible_in_tree() or _holder == null:
		return false
	return SupermarketShopperRules.player_in_the_way(_holder.to_local(player.global_position) - from, direction)
