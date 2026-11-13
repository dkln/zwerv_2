extends RefCounted
## Unit tests of the layouts of the supermarket branches (scripts/world/interiors/supermarket_layout.gd,
## the boxes and the floor grid of scripts/world/interiors/supermarket.gd): for both chains, many seeds
## and every width of shop front the plan is made and looked over once (_survey), and the
## tests each check one thing of it: the tiles exist, nothing stands in something else,
## everything can be walked to, the branches differ, and each chain has its own checkouts.

const Layout = preload("res://scripts/world/interiors/supermarket_layout.gd")
const Supermarket = preload("res://scripts/world/interiors/supermarket.gd")

const BRANDS := ["derrek", "alfred_steyhn"]
const SEEDS := 30
const WIDTHS := [5, 6, 7]
## Branches looked over per chain.
const BRANCHES := 90
## Furniture boxes may touch: they are shrunk by this much before checking overlap (metres).
const TOUCH := 0.06
## Half the width of someone standing at a spot (metres).
const PERSON_RADIUS := 0.22

## brand -> what _survey found (made once for all the tests).
static var _surveys := {}


## Every branch of `brand` (SEEDS seeds for each of WIDTHS) planned and looked over:
## "kinds" (the different layouts), "sizes" (per front width: [width, depth] of the first
## branch), "missing" (tiles and props not in the libraries), "overlaps" / "first_overlap",
## "inside" (spots in furniture), "unreachable" / "first_unreachable",
## "fewest_checkouts" (staffed), and how many branches have "self_scans", a "bakery",
## "freezers", and their aisles running "lengte" or "breedte".
static func _survey(brand: String) -> Dictionary:
	if _surveys.has(brand):
		return _surveys[brand]
	var library: MeshLibrary = load(Supermarket.LIBRARY)
	var props_library: MeshLibrary = load(Supermarket.PROPS_LIBRARY)
	var found := {"kinds": {}, "sizes": {}, "missing": {}, "overlaps": 0, "first_overlap": "", "inside": 0,
		"unreachable": 0, "first_unreachable": "", "fewest_checkouts": 99,
		"self_scans": 0, "bakery": 0, "freezers": 0, "lengte": 0, "breedte": 0}
	for width: int in WIDTHS:
		for seed in SEEDS:
			var plan := Layout.plan(brand, seed * 7919 + width, width)
			found.kinds["%dx%d deur %.0f %s kassa's %d" % [int(plan.width), int(plan.depth), (plan.door as Transform3D).origin.x,
				plan.aisles, plan.checkouts.size()]] = true
			if seed == 0:
				found.sizes[width] = [float(plan.width), float(plan.depth)]
			for entry: Array in plan.tiles:
				if library.find_item_by_name(Supermarket.PREFIX + String(entry[0])) < 0:
					found.missing[String(entry[0])] = true
			for entry: Array in plan.props:
				if props_library.find_item_by_name(String(entry[0])) < 0:
					found.missing[String(entry[0])] = true
			var boxes := Supermarket.footprints(plan, library, props_library)
			# walls meet in the corners: only the furniture inside the walls counts
			var inner := boxes.filter(func(box: AABB) -> bool:
				return box.position.x > -float(plan.width) * 0.5 + 0.2 and box.end.x < float(plan.width) * 0.5 - 0.2 \
					and box.position.z > -float(plan.depth) * 0.5 + 0.2 and box.end.z < float(plan.depth) * 0.5 - 0.2)
			# the deposit machine stands against a wall: checked against all the furniture
			var deposit_box: AABB = Supermarket.deposit_footprint(plan)[0]
			for box: AABB in inner:
				if box != deposit_box and box.grow(-TOUCH).intersects(deposit_box.grow(-TOUCH)):
					found.overlaps += 1
					if found.first_overlap == "":
						found.first_overlap = "seed %d breedte %d: statiegeldautomaat %s in %s" % [seed, width, deposit_box, box]
			for first in inner.size():
				for second in range(first + 1, inner.size()):
					if (inner[first] as AABB).grow(-TOUCH).intersects((inner[second] as AABB).grow(-TOUCH)):
						found.overlaps += 1
						if found.first_overlap == "":
							found.first_overlap = "seed %d breedte %d: %s en %s" % [seed, width, inner[first], inner[second]]
			var grid := Supermarket.make_floor_grid(plan, library, props_library)
			var door: Vector3 = (plan.door as Transform3D).origin
			var spots: Array = [["karretjes", plan.cart_at], ["mandjes", plan.basket_at], ["statiegeld", plan.deposit.use_at]]
			for shelf: Dictionary in plan.shelves:
				spots.append(["schap " + String(shelf.category), shelf.at])
			for checkout: Dictionary in plan.checkouts:
				spots.append(["kassa %d" % int(checkout.number), checkout.pay_at])
			for named: Array in spots:
				var spot: Vector3 = named[1]
				# where you stand: a person (PERSON_RADIUS) there must be clear of every box
				var standing := AABB(spot - Vector3(PERSON_RADIUS, 0.0, PERSON_RADIUS) + Vector3(0.0, 0.3, 0.0),
					Vector3(PERSON_RADIUS * 2.0, 1.0, PERSON_RADIUS * 2.0))
				var hit := boxes.filter(func(box: AABB) -> bool: return box.intersects(standing))
				if not hit.is_empty():
					found.inside += 1
					if found.first_unreachable == "":
						found.first_unreachable = "seed %d breedte %d: %s op %s in %s" % [seed, width, named[0], spot, hit[0]]
				elif not Supermarket.reachable_on(grid, plan, door, spot):
					found.unreachable += 1
					if found.first_unreachable == "":
						found.first_unreachable = "seed %d breedte %d: %s niet te bereiken" % [seed, width, spot]
			var staffed: int = plan.checkouts.filter(func(checkout: Dictionary) -> bool: return not checkout.self_scan).size()
			found.fewest_checkouts = mini(found.fewest_checkouts, staffed)
			if int(plan.self_scans) > 0:
				found.self_scans += 1
			if plan.tiles.any(func(entry: Array) -> bool: return String(entry[0]) == "bakkerij_alfred_steyhn"):
				found.bakery += 1
			if bool(plan.get("freezers", false)):
				found.freezers += 1
			found[String(plan.aisles)] += 1
	_surveys[brand] = found
	return found


## The shop is at least as wide as its front (it may run on behind the neighbours, up to
## MOST_CELLS) and as deep as one of Layout.DEPTHS.
func test_shop_is_as_wide_as_its_front_or_wider(test) -> void:
	for brand: String in BRANDS:
		var sizes: Dictionary = _survey(brand).sizes
		for width: int in WIDTHS:
			var size: Array = sizes[width]
			test.check(size[0] >= width * 4.0 and size[0] <= Layout.MOST_CELLS * 4.0 and size[1] in Layout.DEPTHS,
				"%s, gevel van %d cellen: %d x %d m" % [brand, width, int(size[0]), int(size[1])])


## Every tile a plan uses is in the library binnen, every prop in the library props.
func test_every_tile_and_prop_is_in_its_library(test) -> void:
	for brand: String in BRANDS:
		var missing: Dictionary = _survey(brand).missing
		test.check(missing.is_empty(), "%s: alle tiles in de bibliotheek %s" % [brand, missing.keys()])


## No two pieces of furniture stand in each other (their boxes, a little shrunk), nor the
## deposit machine in any of them.
func test_no_furniture_stands_in_other_furniture(test) -> void:
	for brand: String in BRANDS:
		var found := _survey(brand)
		test.check(found.overlaps == 0, "%s: geen meubels in elkaar (%d) %s" % [brand, found.overlaps, found.first_overlap])


## From the entrance you can walk to every shelf spot, every checkout, the trolleys, the
## baskets and the deposit machine, and none of those spots is inside furniture.
func test_every_spot_can_be_walked_to_from_the_door(test) -> void:
	for brand: String in BRANDS:
		var found := _survey(brand)
		test.check(found.inside == 0 and found.unreachable == 0,
			"%s: alle schappen, kassa's, karretjes en mandjes bereikbaar (%d in meubels, %d onbereikbaar) %s" % [brand, found.inside, found.unreachable, found.first_unreachable])


## The branches differ: many different sizes, entrances, aisle directions and checkout
## counts, and only some have a row of freezers.
func test_branches_differ(test) -> void:
	for brand: String in BRANDS:
		var found := _survey(brand)
		test.check(found.kinds.size() >= BRANCHES / 3, "%s: de filialen verschillen (%d van %d)" % [brand, found.kinds.size(), BRANCHES])
		test.check(found.freezers > 0 and found.freezers < BRANCHES, "%s: sommige filialen met een diepvriesrij (%d)" % [brand, found.freezers])


## DERREK: at least two staffed checkouts everywhere, never self-scan, the shelves always
## running from front to back.
func test_derrek_has_staffed_checkouts_and_no_self_scan(test) -> void:
	var found := _survey("derrek")
	test.check(found.fewest_checkouts >= 2, "derrek: overal minstens twee bemande kassa's (%d)" % found.fewest_checkouts)
	test.check(found.self_scans == 0, "derrek: geen zelfscan")
	test.check(found.breedte == 0, "derrek: de schappen altijd van voor naar achter")


## ALFRED STEYHN: a staffed checkout everywhere, self-scan in most branches, a bakery in
## all, and shelves running both ways over the branches.
func test_alfred_steyhn_has_self_scan_and_a_bakery(test) -> void:
	var found := _survey("alfred_steyhn")
	test.check(found.fewest_checkouts >= 1, "alfred_steyhn: overal een bemande kassa (%d)" % found.fewest_checkouts)
	test.check(found.self_scans > BRANCHES / 2, "alfred_steyhn: meestal zelfscan (%d van %d)" % [found.self_scans, BRANCHES])
	test.check(found.bakery == BRANCHES, "alfred_steyhn: overal een bakkerij (%d)" % found.bakery)
	test.check(found.lengte > 0 and found.breedte > 0, "alfred_steyhn: schappen beide kanten op (%d / %d)" % [found.lengte, found.breedte])
