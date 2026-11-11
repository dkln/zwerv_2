extends SceneTree
## The layouts of the supermarket branches (scripts/world/supermarket_layout.gd), headless and
## without the town (fast): for both chains, many seeds and every width of shop front:
## - every tile it uses is in the library binnen (and every prop in props);
## - no two pieces of furniture stand in each other (their boxes, a little shrunk);
## - the shop is as wide as its front, 16-24 m deep;
## - DERREK has at least two staffed checkouts and no self-scan, ALFRED STEYHN at least one
##   staffed and (in most branches) self-scan pillars, its bakery, flowers and fruit;
## - from the entrance you can walk to every shelf spot, every checkout, the trolleys and the
##   baskets (the floor grid the shoppers walk on), and none of those spots is inside furniture;
## - the branches differ: many different sizes, entrances, aisle directions, checkout counts.
## usage: tools/godot.sh --headless --script tools/check/supermarket_layout_test.gd

const Common = preload("res://tools/tool_common.gd")
const Layout = preload("res://scripts/world/supermarket_layout.gd")
const Supermarket = preload("res://scripts/world/supermarket.gd")

const SEEDS := 30
const WIDTHS := [5, 6, 7]
## Furniture boxes may touch: they are shrunk by this much before checking overlap (metres).
const TOUCH := 0.06
## Half the width of someone standing at a spot (metres).
const PERSON_RADIUS := 0.22

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 120)
	var library: MeshLibrary = load(Supermarket.LIBRARY)
	var props_library: MeshLibrary = load(Supermarket.PROPS_LIBRARY)
	for brand: String in ["derrek", "alfred_steyhn"]:
		var kinds := {}
		var missing := {}
		var overlaps := 0
		var unreachable := 0
		var inside := 0
		var counts := {"self_scans": 0, "bakery": 0, "freezers": 0, "lengte": 0, "breedte": 0}
		var fewest_checkouts := 99
		var first_overlap := ""
		var first_unreachable := ""
		for width: int in WIDTHS:
			for seed in SEEDS:
				var plan := Layout.plan(brand, seed * 7919 + width, width)
				kinds["%dx%d deur %.0f %s kassa's %d" % [int(plan.width), int(plan.depth), (plan.door as Transform3D).origin.x,
					plan.aisles, plan.checkouts.size()]] = true
				if seed == 0:
					_check(is_equal_approx(float(plan.width), width * 4.0) and float(plan.depth) in Layout.DEPTHS,
						"%s, gevel van %d cellen: %d x %d m" % [brand, width, int(plan.width), int(plan.depth)])
				for entry: Array in plan.tiles:
					if library.find_item_by_name(Supermarket.PREFIX + String(entry[0])) < 0:
						missing[String(entry[0])] = true
				for entry: Array in plan.props:
					if props_library.find_item_by_name(String(entry[0])) < 0:
						missing[String(entry[0])] = true
				var boxes := Supermarket.footprints(plan, library, props_library)
				# walls meet in the corners: only the furniture inside the walls counts
				var inner := boxes.filter(func(box: AABB) -> bool:
					return box.position.x > -float(plan.width) * 0.5 + 0.2 and box.end.x < float(plan.width) * 0.5 - 0.2 \
						and box.position.z > -float(plan.depth) * 0.5 + 0.2 and box.end.z < float(plan.depth) * 0.5 - 0.2)
				for first in inner.size():
					for second in range(first + 1, inner.size()):
						if (inner[first] as AABB).grow(-TOUCH).intersects((inner[second] as AABB).grow(-TOUCH)):
							overlaps += 1
							if first_overlap == "":
								first_overlap = "seed %d breedte %d: %s en %s" % [seed, width, inner[first], inner[second]]
				var grid := Supermarket.make_floor_grid(plan, library, props_library)
				var door: Vector3 = (plan.door as Transform3D).origin
				var spots: Array = [["karretjes", plan.cart_at], ["mandjes", plan.basket_at]]
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
						inside += 1
						if first_unreachable == "":
							first_unreachable = "seed %d breedte %d: %s op %s in %s" % [seed, width, named[0], spot, hit[0]]
					elif not Supermarket.reachable_on(grid, plan, door, spot):
						unreachable += 1
						if first_unreachable == "":
							first_unreachable = "seed %d breedte %d: %s niet te bereiken" % [seed, width, spot]
				var staffed: int = plan.checkouts.filter(func(checkout: Dictionary) -> bool: return not checkout.self_scan).size()
				fewest_checkouts = mini(fewest_checkouts, staffed)
				if int(plan.self_scans) > 0:
					counts.self_scans += 1
				if plan.tiles.any(func(entry: Array) -> bool: return String(entry[0]) == "bakkerij_alfred_steyhn"):
					counts.bakery += 1
				if bool(plan.get("freezers", false)):
					counts.freezers += 1
				counts[String(plan.aisles)] += 1
		var branches: int = SEEDS * WIDTHS.size()
		print("%s: %d filialen, %d verschillende indelingen; %s" % [brand, branches, kinds.size(), counts])
		_check(missing.is_empty(), "%s: alle tiles in de bibliotheek %s" % [brand, missing.keys()])
		_check(overlaps == 0, "%s: geen meubels in elkaar (%d) %s" % [brand, overlaps, first_overlap])
		_check(inside == 0 and unreachable == 0, "%s: alle schappen, kassa's, karretjes en mandjes bereikbaar (%d in meubels, %d onbereikbaar) %s" % [brand, inside, unreachable, first_unreachable])
		_check(kinds.size() >= branches / 3, "%s: de filialen verschillen (%d van %d)" % [brand, kinds.size(), branches])
		_check(counts.freezers > 0 and counts.freezers < branches, "%s: sommige filialen met een diepvriesrij (%d)" % [brand, counts.freezers])
		if brand == "derrek":
			_check(fewest_checkouts >= 2, "derrek: overal minstens twee bemande kassa's (%d)" % fewest_checkouts)
			_check(counts.self_scans == 0, "derrek: geen zelfscan")
			_check(counts.breedte == 0, "derrek: de schappen altijd van voor naar achter")
		else:
			_check(fewest_checkouts >= 1, "alfred_steyhn: overal een bemande kassa (%d)" % fewest_checkouts)
			_check(counts.self_scans > branches / 2, "alfred_steyhn: meestal zelfscan (%d van %d)" % [counts.self_scans, branches])
			_check(counts.bakery == branches, "alfred_steyhn: overal een bakkerij (%d)" % counts.bakery)
			_check(counts.lengte > 0 and counts.breedte > 0, "alfred_steyhn: schappen beide kanten op (%d / %d)" % [counts.lengte, counts.breedte])
	print("indelingen ok" if _problems.is_empty() else "indelingen problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
