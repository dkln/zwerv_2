extends RefCounted
## The layout of a supermarket branch (DERREK or ALFRED STEYHN), worked out from the chain,
## the seed of the branch and the width of its shop front on the map: one source for the
## game (scripts/world/interiors/supermarket.gd builds it into its GridMaps) and the checks
## (tests/integration/interiors/test_supermarket.gd). No two branches are the same:
## - size: wider than its shop front (4 m a cell: the shop runs on behind its neighbours,
##   EXTRA_CELLS more, FEWEST_CELLS..MOST_CELLS in all), 24 to 36 m deep (DEPTHS; both from
##   the seed);
## - the entrance: DERREK somewhere along the front, ALFRED STEYHN near a corner (which one
##   from the seed); the checkouts on the wider side of it, the trolleys, baskets and the
##   first things to see (DERREK its promotion pallets, ALFRED STEYHN flowers and the fruit
##   and vegetables) on the other;
## - the aisles: DERREK's gondolas always run from the front to the back, ALFRED STEYHN's
##   either way (from the seed); a cross aisle when they are long; one row of chest freezers
##   in some branches; the order of the categories from the seed;
## - the checkouts: DERREK only staffed ones (up to MOST_CHECKOUTS.derrek), ALFRED STEYHN one
##   or two staffed and a row of self-scan pillars;
## - along the left wall shelves (ALFRED STEYHN its bakery among them), along the back the
##   fridge wall (dairy) with the staff door in it.
## The room: x from -width/2 (the high left wall) to +width/2 (the low right one), z from
## -depth/2 (the low front with the entrance, where the camera looks in from) to +depth/2
## (the high back wall). Every tile at a point of the 0.5 m grid of the GridMaps, turned by
## `turn` (its front then faces (sin turn, 0, cos turn)).
##   var plan := SupermarketLayout.plan("derrek", 1234, 6)

const RandomPick = preload("res://scripts/common/random_pick.gd")
const CELL := 4.0
const FEWEST_CELLS := 5
const MOST_CELLS := 10
const EXTRA_CELLS := Vector2i(1, 3)
const DEPTHS := [24.0, 28.0, 32.0, 36.0]
## The front zone (entrance and checkouts) is this deep, metres from the front wall.
const FRONT_ZONE := 6.5
## The way in: from the door straight into the shop this wide and this deep stays free (no
## furniture, trolleys or baskets; no shopper stops in it: no shelf spot, till or queue).
const ENTRANCE_LANE_WIDTH := 1.6
const ENTRANCE_LANE_DEPTH := 4.0
## From the back wall: the fridge wall and the aisle before it; from the left wall: the wall
## shelves and the aisle before them; at the right (the low wall): an aisle.
const BACK_ZONE := 3.25
const LEFT_ZONE := 3.25
const RIGHT_AISLE := 2.0
## A gondola is 1 m deep with an aisle of 2.5 m between two of them; 4 m a module.
const GONDOLA_PITCH := 3.5
const MODULE := 4.0
const CROSS_AISLE := 2.0
## The checkouts: one each CHECKOUT_PITCH m (a counter of 1.5 m with its stool, a lane of 1
## m), the self-scan pillars SELF_SCAN_PITCH m apart.
const CHECKOUT_PITCH := 2.5
const SELF_SCAN_PITCH := 1.5
const MOST_CHECKOUTS := {"derrek": 5, "alfred_steyhn": 2}
const MOST_SELF_SCANS := 4
## How far before a shelf the player stands to take something (metres from its middle line).
const PICK_DISTANCE := 1.0
## Someone looking at a shelf stands this far along it from the spot where you take things.
const BESIDE_SPOT := 0.9
## The cashier sits on the stool of the checkout tile (binnen/supermarkt/kassa_<brand>):
## its place in the tile's space (x along the counter, z across) and the height of the seat.
const CASHIER_IN_TILE := Vector3(-0.25, 0.0, -0.31)
const CASHIER_SEAT := 0.75
## The gondola categories (tiles schap_<category>_<brand>), the wall shelves (wandschap_).
const GONDOLA_CATEGORIES := ["droog", "ontbijt", "snoep", "drank", "verzorging", "conserven"]
const WALL_CATEGORIES := {"derrek": ["drank", "snoep", "verzorging"], "alfred_steyhn": ["brood", "drank", "verzorging"]}
## What the signs over the aisles say, per category.
const SIGN_TEXTS := {
	"droog": "PASTA & RIJST", "ontbijt": "ONTBIJT", "snoep": "CHIPS & SNOEP", "drank": "DRANKEN",
	"verzorging": "VERZORGING", "conserven": "CONSERVEN", "diepvries": "DIEPVRIES", "zuivel": "ZUIVEL",
	"brood": "BROOD", "bakkerij": "BAKKERIJ", "groente": "GROENTE & FRUIT", "bloemen": "BLOEMEN",
	"actie": "ACTIE",
	"statiegeld": "STATIEGELD",
}
## The deposit machine (statiegeld, scripts/world/things/machine_models.gd): its size (across, up,
## deep) and where you stand to use it (metres from the back wall, before it). It stands at
## the back of the shop against the back wall, in the cell beside the staff door.
const DEPOSIT_MACHINE_SIZE := Vector3(0.875, 1.875, 0.625)
const DEPOSIT_USE_FROM_BACK := 1.45
## The props colour of each chain's trolleys (props/winkel/winkelwagen_<colour>).
const CART_COLOURS := {"derrek": "rood", "alfred_steyhn": "blauw"}


## The plan of a branch of `brand` with `seed`, its shop front `front_cells` cells wide:
## {"brand", "width", "depth", "tiles": [[tile, at, turn]] (the library binnen without its
##  "supermarkt/" prefix), "wall_tiles": [[tile, at (on the wall's grid line), turn]]
##  (the name and the emblem of the chain, hung by WallMount), "floor": [[tile, at]],
##  "props": [[props item, at, turn]],
##  "door": Transform3D (inside the entrance, facing into the shop), "door_gap": Vector3
##  (the middle of the opening in the front wall),
##  "entrance_lane": Rect2 (x, z: the way in from the door, kept free; ENTRANCE_LANE_*),
##  "shelves": [{"at", "facing" (towards the shelf), "category"}] (where you take something),
##  "checkouts": [{"number", "pay_at", "self_scan", "cashier" (Transform3D, staffed ones)}],
##  "cart_at", "basket_at": where you take a trolley or a basket,
##  "deposit": {"at", "turn", "use_at", "size"} the deposit machine (statiegeld) and where you
##  stand to use it,
##  "signs": [{"at", "turn", "text"}] (hung over the aisles), "promotions": [{"at", "turn"}]
##  (the price boards of DERREK's pallets), "lamps": [Vector3],
##  "people": [Transform3D] (shoppers standing at a shelf), "staff": [Transform3D],
##  "aisles": "lengte" or "breedte", "self_scans": int, "freezers": bool}.
static func plan(brand: String, seed: int, front_cells: int) -> Dictionary:
	var random := RandomPick.seeded(hash([brand, seed]))
	var cells := clampi(front_cells + random.randi_range(EXTRA_CELLS.x, EXTRA_CELLS.y), FEWEST_CELLS, MOST_CELLS)
	var width := cells * CELL
	var depth: float = DEPTHS[random.randi() % DEPTHS.size()]
	var result := {"brand": brand, "width": width, "depth": depth, "tiles": [], "wall_tiles": [], "floor": [], "props": [],
		"shelves": [], "checkouts": [], "signs": [], "promotions": [], "lamps": [], "people": [], "staff": []}
	var left := -width * 0.5
	var right := width * 0.5
	var front := -depth * 0.5
	var back := depth * 0.5
	# the floor and the walls
	for column in cells:
		for row in int(depth / CELL):
			result.floor.append(["vloer_" + brand, Vector3(left + CELL * 0.5 + column * CELL, 0.0, front + CELL * 0.5 + row * CELL)])
	# the entrance: DERREK anywhere but the corners, ALFRED STEYHN beside one of them
	var door_cell: int
	if brand == "alfred_steyhn":
		door_cell = 1 if random.randf() < 0.5 else cells - 2
	else:
		door_cell = random.randi_range(1, cells - 2)
	var door_x := left + CELL * 0.5 + door_cell * CELL
	for column in cells:
		var x := left + CELL * 0.5 + column * CELL
		_tile(result, "muur_" + brand, Vector3(x, 0.0, back), PI)
		if column == door_cell:
			for side in [-1.0, 1.0]:
				_tile(result, "muur_laag_kort_" + brand, Vector3(x + side * 1.5, 0.0, front), 0.0)
		else:
			_tile(result, "muur_laag_" + brand, Vector3(x, 0.0, front), 0.0)
	for row in int(depth / CELL):
		var z := front + CELL * 0.5 + row * CELL
		_tile(result, "muur_" + brand, Vector3(left, 0.0, z), PI * 0.5)
		_tile(result, "muur_laag_" + brand, Vector3(right, 0.0, z), -PI * 0.5)
	result["door"] = Transform3D(Basis(), Vector3(door_x, 0.0, front + 0.9))
	result["door_gap"] = Vector3(door_x, 0.0, front)
	result["entrance_lane"] = Rect2(door_x - ENTRANCE_LANE_WIDTH * 0.5, front, ENTRANCE_LANE_WIDTH, ENTRANCE_LANE_DEPTH)
	# the checkouts on the wider side of the entrance, the rest on the other
	var room_left := door_x - 1.0 - left
	var room_right := right - (door_x + 1.0)
	var checkout_side := 1.0 if room_right >= room_left else -1.0
	var entrance_side := -checkout_side
	_checkouts(result, brand, random, door_x, checkout_side, maxf(room_left, room_right), front)
	_entrance(result, brand, random, door_x, entrance_side, minf(room_left, room_right), front)
	# the back wall: the fridge wall, the staff door in one cell and beside it the deposit
	# machine (statiegeld) in a cell of its own, against the back wall facing the entrance: seen
	# at once from the door and by the camera, which looks in from the front
	var staff_cell := 0 if random.randf() < 0.5 else cells - 1
	var deposit_cell := 1 if staff_cell == 0 else cells - 2
	var deposit_x := left + CELL * 0.5 + deposit_cell * CELL
	result["deposit"] = {"at": Vector3(deposit_x, 0.0, back - 0.125 - DEPOSIT_MACHINE_SIZE.z * 0.5), "turn": PI,
		"use_at": Vector3(deposit_x, 0.0, back - DEPOSIT_USE_FROM_BACK), "size": DEPOSIT_MACHINE_SIZE}
	result.signs.append({"at": Vector3(deposit_x, 2.6, back - 0.4), "turn": PI, "text": SIGN_TEXTS.statiegeld})
	for column in cells:
		var x := left + CELL * 0.5 + column * CELL
		if column == staff_cell:
			_tile(result, "deur_personeel", Vector3(x, 0.0, back - 0.25), PI)
			result.staff.append(Transform3D(Basis(Vector3.UP, PI), Vector3(x + 1.0, 0.0, back - 1.2)))
		elif column == deposit_cell:
			pass   # the deposit machine (Supermarket._make_deposit_machine)
		else:
			_tile(result, "koelwand_" + brand, Vector3(x, 0.0, back - 0.5), PI)
			_shelf_spots(result, Vector3(x, 0.0, back - 0.5), Vector3(0.0, 0.0, -1.0), "zuivel", 0.4)
	# the name of the chain over the fridges, its emblem towards the right
	_wall_tile(result, "naambord_" + brand, Vector3(snappedf(left + width * 0.5, 0.5), 2.0, back), PI)
	_wall_tile(result, "logo_" + brand, Vector3(right - 2.0, 2.0, back), PI)
	# the left wall: shelves, at ALFRED STEYHN the bakery among them
	var wall_categories: Array = WALL_CATEGORIES[brand].duplicate()
	RandomPick.shuffle(random, wall_categories)
	var bakery_row := -1
	var wall_rows: Array[float] = []
	for row in int(depth / CELL):
		var z := front + CELL * 0.5 + row * CELL
		if z - CELL * 0.5 >= front + FRONT_ZONE - 0.5 and z + CELL * 0.5 <= back - 0.75:
			wall_rows.append(z)
	if brand == "alfred_steyhn" and not wall_rows.is_empty():
		bakery_row = random.randi() % wall_rows.size()
	for index in wall_rows.size():
		var z: float = wall_rows[index]
		if index == bakery_row:
			_tile(result, "bakkerij_alfred_steyhn", Vector3(left + 0.75, 0.0, z), PI * 0.5)
			_shelf_spots(result, Vector3(left + 0.75, 0.0, z), Vector3(1.0, 0.0, 0.0), "bakkerij", 0.6)
			result.signs.append({"at": Vector3(left + 0.4, 2.85, z), "turn": PI * 0.5, "text": SIGN_TEXTS.bakkerij})
		else:
			var category: String = wall_categories[index % wall_categories.size()]
			_tile(result, "wandschap_%s_%s" % [category, brand], Vector3(left + 0.5, 0.0, z), PI * 0.5)
			_shelf_spots(result, Vector3(left + 0.5, 0.0, z), Vector3(1.0, 0.0, 0.0), category, 0.4)
			result.signs.append({"at": Vector3(left + 0.4, 2.6, z), "turn": PI * 0.5, "text": SIGN_TEXTS[category]})
	_gondolas(result, brand, random, left + LEFT_ZONE, right - RIGHT_AISLE, front + FRONT_ZONE, back - BACK_ZONE)
	# lamps over the shop, one each 8 m or so
	var lamps_across := maxi(2, roundi(width / 8.0))
	var lamps_deep := maxi(2, roundi(depth / 8.0))
	for column in lamps_across:
		for row in lamps_deep:
			result.lamps.append(Vector3(left + width * (column + 0.5) / lamps_across, 3.2, front + depth * (row + 0.5) / lamps_deep))
	# shoppers at a few of the shelves, someone of the staff at one
	var spots: Array = result.shelves.duplicate()
	RandomPick.shuffle(random, spots)
	var shoppers := mini(random.randi_range(2, 3 + cells / 2), spots.size())
	# beside the spot where you take something (not on it: there [E] is for the shelf)
	for index in shoppers:
		var spot: Dictionary = spots[index]
		result.people.append(_standing(beside(spot), spot.facing))
	if spots.size() > shoppers:
		var spot: Dictionary = spots[shoppers]
		result.staff.append(_standing(beside(spot), spot.facing))
	return result


## The staffed checkouts, then (ALFRED STEYHN) the self-scan pillars, from beside the
## entrance towards the wall on `side` (room: metres between the entrance and that wall).
static func _checkouts(result: Dictionary, brand: String, random: RandomNumberGenerator, door_x: float,
		side: float, room: float, front: float) -> void:
	var lane_z := front + 3.0
	var first := door_x + side * (1.0 + 1.75)
	# a counter k stands 2.75 + k * CHECKOUT_PITCH from the entrance, its stool 0.75 further
	var room_for := maxi(1, int(floor((room - 2.75) / CHECKOUT_PITCH)) + 1)
	var staffed := mini(MOST_CHECKOUTS[brand], room_for)
	var self_scans := 0
	if brand == "alfred_steyhn":
		staffed = mini(1 + random.randi() % 2, room_for)
		self_scans = clampi(int(floor((room - 2.6 - staffed * CHECKOUT_PITCH) / SELF_SCAN_PITCH)) + 1, 0, MOST_SELF_SCANS)
	else:
		staffed = mini(maxi(2, staffed - random.randi() % 2), room_for)
	var number := 1
	# the counter turned so its length runs front to back, its front (the lane) towards the
	# entrance side; the cashier on the far side of it
	var turn := -PI * 0.5 if side > 0.0 else PI * 0.5
	for index in staffed:
		var x := first + side * index * CHECKOUT_PITCH
		var at := Vector3(x, 0.0, lane_z)
		_tile(result, "kassa_" + brand, at, turn)
		var basis := Basis(Vector3.UP, turn)
		var cashier := Transform3D(basis, at + basis * CASHIER_IN_TILE)
		cashier.origin.y = 0.0
		# you pay at the till, in the lane before the counter (its front), by the till end
		var pay_at := at + basis * Vector3(-0.9, 0.0, 1.25)
		# the lane number in the box on the pole at the other end, towards the camera
		var sign_at := at + basis * Vector3(1.375, 0.0, 0.62) + Vector3(0.0, 2.0, -0.2)
		result.checkouts.append({"number": number, "pay_at": pay_at, "self_scan": false, "cashier": cashier,
			"seat": CASHIER_SEAT, "sign_at": sign_at})
		number += 1
	if self_scans > 0:
		var start := first + side * (staffed * CHECKOUT_PITCH + 0.25)
		for index in self_scans:
			var at := Vector3(start + side * index * SELF_SCAN_PITCH, 0.0, lane_z + 0.5)
			_tile(result, "zelfscan_alfred_steyhn", at, 0.0)
			result.checkouts.append({"number": number, "pay_at": at + Vector3(0.0, 0.0, 0.9), "self_scan": true})
			number += 1
		result.signs.append({"at": Vector3(start + side * (self_scans - 1) * SELF_SCAN_PITCH * 0.5, 2.6, lane_z + 0.5),
			"turn": PI, "text": "ZELFSCAN"})
	result["self_scans"] = self_scans


## Beside the entrance on `side`: the trolleys along the front wall, the baskets by the
## door, and what you see first: DERREK its promotion pallets, ALFRED STEYHN flowers and a
## stand of fruit and vegetables.
static func _entrance(result: Dictionary, brand: String, random: RandomNumberGenerator, door_x: float,
		side: float, room: float, front: float) -> void:
	var cart_colour: String = CART_COLOURS[brand]
	var cart_x := door_x + side * 3.75
	result.props.append(["winkel/winkelwagens_rij_" + cart_colour, Vector3(cart_x, 0.0, front + 0.75), side * PI * 0.5])
	result["cart_at"] = Vector3(cart_x, 0.0, front + 1.8)
	_tile(result, "mandjes_" + brand, Vector3(door_x + side * 1.5, 0.0, front + 0.5), 0.0)
	_tile(result, "mandjes_" + brand, Vector3(door_x + side * 1.5, 0.0, front + 1.0), 0.0)
	result["basket_at"] = Vector3(door_x + side * 1.5, 0.0, front + 1.6)
	var far := door_x + side * (room + 1.0)    # the wall on that side
	var zone_z := front + 4.75
	if brand == "derrek":
		var pallets := clampi(int((room - 4.3) / 2.0) + 1, 1, 3)
		for index in pallets:
			var at := Vector3(door_x + side * (2.5 + index * 2.0), 0.0, zone_z)
			# turned so the price board faces the entrance (and the camera)
			_tile(result, "pallet_derrek", at, PI)
			result.promotions.append({"at": at + Vector3(0.0, 2.1, -0.3), "turn": PI})
			_shelf_spots(result, at, Vector3(0.0, 0.0, -1.0), "actie", 0.6, true)
		result.signs.append({"at": Vector3(door_x + side * (2.5 + (pallets - 1) * 1.0), 2.9, zone_z), "turn": PI,
			"text": "LAAGSTE PRIJS"})
	else:
		var stand_x := snappedf(door_x + side * (room * 0.5 + 1.0), 0.5)
		_tile(result, "groentebak", Vector3(stand_x, 0.0, zone_z), 0.0)
		_shelf_spots(result, Vector3(stand_x, 0.0, zone_z), Vector3(0.0, 0.0, 1.0), "groente", 0.5, true)
		result.signs.append({"at": Vector3(stand_x, 2.6, zone_z), "turn": PI, "text": SIGN_TEXTS.groente})
		var flowers_x := snappedf(far - side * 1.25, 0.5)
		_tile(result, "bloemen", Vector3(flowers_x, 0.0, front + 2.75), -side * PI * 0.5)
		_shelf_spots(result, Vector3(flowers_x, 0.0, front + 2.75), Vector3(-side, 0.0, 0.0), "bloemen", 0.5, true)


## The gondolas between x0..x1 and z0..z1 (their middle lines inside): rows of modules, a
## cross aisle in long rows, a row of freezers in some branches, a sign over each row.
static func _gondolas(result: Dictionary, brand: String, random: RandomNumberGenerator, x0: float, x1: float,
		z0: float, z1: float) -> void:
	var along_depth := brand == "derrek" or random.randf() < 0.5
	result["aisles"] = "lengte" if along_depth else "breedte"
	# rows across the other way: their middle lines, GONDOLA_PITCH apart
	var row_from := (x0 + 0.5) if along_depth else (z0 + 0.5)
	var row_to := (x1 - 0.5) if along_depth else (z1 - 0.5)
	var length_from := z0 if along_depth else x0 - 0.5
	var length_to := z1 if along_depth else x1
	var rows: Array[float] = []
	var row_line := row_from
	while row_line <= row_to + 0.01:
		rows.append(snappedf(row_line, 0.5))
		row_line += GONDOLA_PITCH
	var modules := int(floor((length_to - length_from) / MODULE))
	if modules >= 3 and modules * MODULE + CROSS_AISLE > length_to - length_from:
		modules -= 1
	if rows.is_empty() or modules < 1:
		result["freezers"] = false
		return
	var cross := modules >= 3
	var run := modules * MODULE + (CROSS_AISLE if cross else 0.0)
	var start := snappedf(length_from + (length_to - length_from - run) * 0.5, 0.5)
	var categories: Array = GONDOLA_CATEGORIES.duplicate()
	RandomPick.shuffle(random, categories)
	var freezer_row := random.randi() % rows.size() if random.randf() < 0.6 else -1
	result["freezers"] = freezer_row >= 0
	var turn := PI * 0.5 if along_depth else 0.0
	for row_index in rows.size():
		var line: float = rows[row_index]
		var category: String = "diepvries" if row_index == freezer_row else categories[row_index % categories.size()]
		var tile: String = ("diepvries_" + brand) if category == "diepvries" else "schap_%s_%s" % [category, brand]
		var along := start
		for module_index in modules:
			if cross and module_index == modules / 2:
				along += CROSS_AISLE
			var middle := along + MODULE * 0.5
			var at := Vector3(line, 0.0, middle) if along_depth else Vector3(middle, 0.0, line)
			_tile(result, tile, at, turn)
			var across := Vector3(1.0, 0.0, 0.0) if along_depth else Vector3(0.0, 0.0, 1.0)
			# a gondola: from both sides; a freezer too
			_shelf_spots(result, at, across, category, 0.5)
			_shelf_spots(result, at, -across, category, 0.5)
			along += MODULE
		var sign_middle := start + run * 0.5
		var sign_at := Vector3(line, 2.7, sign_middle) if along_depth else Vector3(sign_middle, 2.7, line)
		# facing the camera (it looks in from the front and the right): +x or -z
		result.signs.append({"at": sign_at, "turn": PI * 0.5 if along_depth else PI, "text": SIGN_TEXTS[category]})


## The spot before a shelf whose middle is `at`: `outward` the way from the shelf to where
## you stand (its front), `depth_half` half the depth of the shelf; `single`: one spot, no
## two along a 4 m module.
static func _shelf_spots(result: Dictionary, at: Vector3, outward: Vector3, category: String, depth_half: float,
		single := false) -> void:
	var stand := at + outward * (depth_half + PICK_DISTANCE * (0.6 if single else 0.75))
	result.shelves.append({"at": stand, "facing": -outward, "category": category})


## A place beside a shelf spot, along the shelf (BESIDE_SPOT m), where someone can stand
## looking at it without being in the way of whoever takes something there.
static func beside(spot: Dictionary, side := 1.0) -> Vector3:
	var facing: Vector3 = spot.facing
	return (spot.at as Vector3) + Vector3(facing.z, 0.0, -facing.x) * BESIDE_SPOT * side


static func _standing(at: Vector3, facing: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, atan2(facing.x, facing.z)), at)


static func _tile(result: Dictionary, tile_name: String, at: Vector3, turn: float) -> void:
	result.tiles.append([tile_name, at, turn])


## A tile that hangs on the wall whose grid line runs through `at` (WallMount: just before
## its inner surface, not half in it).
static func _wall_tile(result: Dictionary, tile_name: String, at: Vector3, turn: float) -> void:
	result.wall_tiles.append([tile_name, at, turn])


# ------------------------------------------------------------------ a trolley or a basket

## How the player pushes a trolley (its handle this far before the feet) and carries a
## basket (in the right hand: beside the body, at hip height).
const CART_AHEAD := 0.75
const BASKET_AT := Vector3(-0.3, 0.42, 0.08)
## Where a shopper has theirs: the trolley before them, the basket on the arm.
const SHOPPER_CART_AT := Vector3(0.0, 0.0, 0.8)
const SHOPPER_BASKET_AT := Vector3(-0.32, 0.5, 0.05)
## The packs in a trolley and in a basket: the side of a pack (m).
const CART_PACK := 0.16
const BASKET_PACK := 0.1


## Where the trolley (`in_cart`) or the basket hangs on the player.
static func carried_at(in_cart: bool) -> Vector3:
	return Vector3(0.0, 0.0, CART_AHEAD) if in_cart else BASKET_AT


## The side of a pack (m) in a trolley or a basket.
static func pack_size(in_cart: bool) -> float:
	return CART_PACK if in_cart else BASKET_PACK


## Where pack `index` lies in the trolley (`in_cart`) or the basket: in rows of 3 (2 in a
## basket), 4 rows (3) to a layer, layer on layer.
static func pack_at(index: int, in_cart: bool) -> Vector3:
	var per_row := 3 if in_cart else 2
	var rows := 4 if in_cart else 3
	var column := index % per_row
	var row := (index / per_row) % rows
	var layer := index / (per_row * rows)
	if in_cart:
		return Vector3(-0.2 + column * 0.2, 0.5 + layer * 0.17, -0.2 + row * 0.18)
	return Vector3(-0.08 + column * 0.13, 0.14 + layer * 0.1, -0.06 + row * 0.08)
