extends RefCounted
## The rules of who shops in a supermarket (logic, docs/CODE_LAGEN.md): how many at once,
## when the next one comes in, the round each makes (a few shelves, then a checkout and out,
## or only looking), where they stand in a queue, how long they wait for the player in
## their way, and how they turn and step. Every draw comes from the generator handed in,
## in a fixed order, so a seed gives the same shoppers. The node: supermarket_shoppers.gd.
##   const SupermarketShopperRules = preload("res://scripts/world/interiors/supermarket_shopper_rules.gd")

const SupermarketFloorRules = preload("res://scripts/world/interiors/supermarket_floor_rules.gd")

## How fast they walk (m/s), how long at a shelf, at the till (s), how far apart in a queue (m).
const WALK_SPEED := Vector2(1.0, 1.35)
const LOOK_SECONDS := Vector2(1.5, 4.0)
const PAY_SECONDS := Vector2(4.0, 7.0)
const QUEUE_GAP := 0.9
## A new one comes in every so many seconds; the share that only looks, and that has a trolley.
const SHOPPER_EVERY := Vector2(6.0, 15.0)
const ONLY_LOOKING := 0.25
const WITH_CART := 0.35
## They wait this long (s) for a player this near (m) before them.
const PLAYER_GAP := 0.75
const PLAYER_PATIENCE := 2.0
## In the way in from the door (the plan's "entrance_lane") they wait for the player only this
## long: they do not stand about in the entrance, with or without a trolley.
const PLAYER_PATIENCE_IN_ENTRANCE := 0.5
const TURN_SPEED := 8.0
## A point of the way is reached within this (m); in a queue they walk the floor grid to
## their place from further than QUEUE_WALK, and stand still within QUEUE_AT of it.
const AT_POINT := 0.08
const QUEUE_WALK := 1.2
const QUEUE_AT := 0.12
## How fast the legs go from standing to walking and back (per second).
const GAIT_CHANGE := 5.0


## As many shoppers at once as the branch is big.
static func most_shoppers(plan: Dictionary) -> int:
	return 3 + int(float(plan.width) / 4.0)


## How many are in the shop already when it is laid out.
static func already_inside(plan: Dictionary) -> int:
	return mini(int(plan.people.size()), 2 + int(plan.width / 8.0))


## The seconds until the next one comes in (the first one in half the time).
static func spawn_seconds(random: RandomNumberGenerator, first := false) -> float:
	return random.randf_range(SHOPPER_EVERY.x, SHOPPER_EVERY.y) * (0.5 if first else 1.0)


## Whether one more comes in now: fewer than the most, and their look is ready.
static func comes_in(inside: int, plan: Dictionary, look_ready: bool) -> bool:
	return inside < most_shoppers(plan) and look_ready


## A new shopper, without its person and its round: its speed and whether it has a trolley
## (two draws, in that order). {"steps", "path", "speed", "phase", "walking", "clock",
## "waited", "queue", "goods", "cart"}.
static func new_shopper(random: RandomNumberGenerator) -> Dictionary:
	var shopper := {"steps": [], "path": PackedVector3Array(), "speed": random.randf_range(WALK_SPEED.x, WALK_SPEED.y),
		"phase": 0.0, "walking": 0.0, "clock": 0.0, "waited": 0.0, "queue": -1, "goods": 0}
	shopper["cart"] = random.randf() < WITH_CART
	return shopper


## Where one comes in: in the door of the plan, just inside the front wall.
static func entry_position(plan: Dictionary) -> Vector3:
	var door_place: Transform3D = plan.door
	return Vector3(door_place.origin.x, 0.0, float(plan.depth) * -0.5 + 0.2)


## The round of a shopper: a few shelves (walk there, look), then a checkout and out; or,
## only looking, straight out after the shelves. Steps: {"walk": Vector3}, {"look": seconds,
## "face": Vector3}, {"queue": checkout number}, {"leave": true}. `already`: standing at a
## shelf mid-way (no walk to the first one). `beside`: a Callable (shelf, side) -> Vector3,
## the place beside the spot of a shelf (SupermarketLayout.beside); `grid`: the free floor
## (null: none).
static func plan_round(plan: Dictionary, grid: AStarGrid2D, already: bool, beside: Callable, random: RandomNumberGenerator) -> Array:
	var steps: Array = []
	var shelves: Array = plan.shelves
	var stops := random.randi_range(1 if already else 2, 4)
	for index in stops:
		var shelf: Dictionary = shelves[random.randi() % shelves.size()]
		if not (already and index == 0):
			# beside the spot of the shelf (on it the player would talk to them, not take)
			var place: Vector3 = beside.call(shelf, -1.0 if random.randf() < 0.5 else 1.0)
			if grid and grid.is_point_solid(SupermarketFloorRules.cell_of(plan, place)):
				place = shelf.at
			steps.append({"walk": place})
		steps.append({"look": random.randf_range(LOOK_SECONDS.x, LOOK_SECONDS.y), "face": shelf.facing})
	if random.randf() >= ONLY_LOOKING and not plan.checkouts.is_empty():
		var checkout: Dictionary = plan.checkouts[random.randi() % plan.checkouts.size()]
		steps.append({"queue": int(checkout.number)})
	steps.append({"walk": (plan.door as Transform3D).origin})
	steps.append({"leave": true})
	return steps


## The checkout `number` of the plan (the first one when it has no such number).
static func checkout(plan: Dictionary, number: int) -> Dictionary:
	for found: Dictionary in plan.checkouts:
		if int(found.number) == number:
			return found
	return plan.checkouts[0]


## Where number `place` of the queue of `a_checkout` stands: the queue goes back into the
## shop along the lane (+z).
static func queue_spot(a_checkout: Dictionary, place: int) -> Vector3:
	return a_checkout.pay_at + Vector3(0.0, 0.0, QUEUE_GAP * place)


## How long the one at the front of a queue takes to pay (s).
static func pay_seconds(random: RandomNumberGenerator) -> float:
	return random.randf_range(PAY_SECONDS.x, PAY_SECONDS.y)


## Whether `point` (in the shop's space) lies in the way in from the door (plan "entrance_lane").
static func in_entrance_lane(plan: Dictionary, point: Vector3) -> bool:
	var lane: Rect2 = plan.get("entrance_lane", Rect2())
	return lane.has_point(Vector2(point.x, point.z))


## How long a shopper at `point` waits for the player in their way (s).
static func patience(plan: Dictionary, point: Vector3) -> float:
	return PLAYER_PATIENCE_IN_ENTRANCE if in_entrance_lane(plan, point) else PLAYER_PATIENCE


## Whether the player, `towards` away (in the shop's space), is in the way of one walking
## in `direction`: near and before them.
static func player_in_the_way(towards: Vector3, direction: Vector3) -> bool:
	var flat := Vector3(towards.x, 0.0, towards.z)
	return flat.length() < PLAYER_GAP + 0.4 and flat.normalized().dot(direction) > 0.6


## The facing (radians round y) of one at `facing` turning towards `direction` for `delta`
## seconds; unchanged when the direction has no length along the floor.
static func turned(facing: float, direction: Vector3, delta: float) -> float:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return facing
	return lerp_angle(facing, atan2(direction.x, direction.z), 1.0 - exp(-TURN_SPEED * delta))


## The step phase and the walking share (x, y) of one who moved `moved` metres in `delta`
## seconds, with a stride of `stride` metres.
static func gait(phase: float, walking: float, moved: float, delta: float, stride: float) -> Vector2:
	if moved > 0.0:
		return Vector2(phase + moved / stride * PI, move_toward(walking, 1.0, delta * GAIT_CHANGE))
	return Vector2(phase, move_toward(walking, 0.0, delta * GAIT_CHANGE))
