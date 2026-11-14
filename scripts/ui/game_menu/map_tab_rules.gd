extends RefCounted
## The rules of the KAART tab of the game menu (logic; docs/CODE_LAGEN.md): which places
## the map has (the named places of the scene, the supermarkets by their chain, the cash
## machines), which neighbourhoods are visited and fogged, which place is the nearest, the
## next one in a direction or under a click, what the marks and the panel of the chosen
## place say, and whether the marker stands on it. Names and neighbourhoods:
## scripts/ui/hud/location_rules.gd. The behaviour is map_tab.gd, the picture map_tab_view.gd.
##   const MapTabRules = preload("res://scripts/ui/game_menu/map_tab_rules.gd")

const LocationRules = preload("res://scripts/ui/hud/location_rules.gd")

## The name of the whole city (the "wijken" entry that covers everything; never fogged).
const WHOLE_CITY := LocationRules.WHOLE_CITY
## Map cells are 4 m (the "wijken" table counts in cells).
const CELL_METRES := LocationRules.CELL_METRES
## The supermarket chains on the map and their name in the place panel. Their places are
## "derrek", "derrek_2", ... (tools/build/city/map.gd _supermarket).
const SUPERMARKET_NAMES := {"derrek": "DERREK", "alfred_steyhn": "ALFRED STEYHN"}
## The cash machines in the streets (the markers Geldautomaat_<n> under Straatautomaten,
## scripts/world/things/street_machines.gd) on the map, as places: also in neighbourhoods
## not visited yet (so you can always find the nearest one to get money).
const CASH_MACHINE_NODE := "Straatautomaten"
const CASH_MACHINE_MARKER := "Geldautomaat"
const CASH_MACHINE_KEY := "pinautomaat_"
const CASH_MACHINE_NAME := "Pinautomaat"
## A test spot of the builder among the places, not a place.
const TEST_PLACE_PREFIX := LocationRules.TEST_PLACE_PREFIX
## Debug (debug builds only): on the map T takes the player to the chosen place.
const KEY_TELEPORT := KEY_T
## How far over the ground the player is put down by the debug teleport (m).
const TELEPORT_DROP := 2.0
## A place this near (map pixels) to the chosen one is the same spot, not a next one.
const SAME_SPOT := 0.5
## A next place lies within 60 degrees of the arrow pressed (the cosine of it).
const LEAST_STRAIGHTNESS := 0.5
## The looks of a place: a place in a visited neighbourhood, one in another, a supermarket
## (with its chain), a cash machine.
const LOOK_PLACE := "plek"
const LOOK_UNKNOWN := "onbekend"
const LOOK_SUPERMARKET := "supermarkt"
const LOOK_CASH_MACHINE := "pinautomaat"


## The chain of a supermarket place ("derrek_3" -> "derrek"), "" for any other place.
static func supermarket_chain(place_key: String) -> String:
	var words := place_key.split("_", false)
	if words.size() > 1 and words[-1].is_valid_int():
		words.resize(words.size() - 1)
	var chain := "_".join(words)
	return chain if SUPERMARKET_NAMES.has(chain) else ""


## Whether a place of the map is a cash machine ("pinautomaat_3").
static func is_cash_machine(place_key: String) -> bool:
	return place_key.begins_with(CASH_MACHINE_KEY)


## Whether a node under Straatautomaten with this name is a cash machine.
static func is_cash_machine_marker(node_name: String) -> bool:
	return node_name.begins_with(CASH_MACHINE_MARKER)


## The neighbourhood at world x, z (the first of `areas`, the "wijken", it lies in).
static func area_at(areas: Array, world_position: Vector2) -> String:
	return LocationRules.area_at(areas, LocationRules.cell_of(world_position))


## The places of the map, each {"key", "name", "position": world x, z, "wijk"}: the `named`
## places of the scene ("places": key -> world x, z; not the test spots) and the cash
## machines (`machines`: their spots in order, numbered from 1), without what
## `is_shrouded` (world x, z -> bool) says the story has not opened yet.
static func places(named: Dictionary, machines: Array, areas: Array, is_shrouded: Callable) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for place_key: String in named:
		if place_key.begins_with(TEST_PLACE_PREFIX):
			continue
		var place_position: Vector2 = named[place_key]
		if is_shrouded.call(place_position):
			continue
		found.append({"key": place_key, "name": LocationRules.place_name(place_key),
				"position": place_position, "wijk": area_at(areas, place_position)})
	for machine_index in machines.size():
		var machine_position: Vector2 = machines[machine_index]
		if is_shrouded.call(machine_position):
			continue
		found.append({"key": CASH_MACHINE_KEY + str(machine_index + 1), "name": CASH_MACHINE_NAME,
				"position": machine_position, "wijk": area_at(areas, machine_position)})
	return found


## The neighbourhoods that count as visited (name -> true): those of the HUD, the one the
## player is in and the whole city.
static func visited(visited_areas: Array, player_wijk: String) -> Dictionary:
	var names := {}
	for wijk: String in visited_areas:
		names[wijk] = true
	names[player_wijk] = true
	names[WHOLE_CITY] = true
	return names


## The place with this key among `places`; {} when there is none.
static func place(places: Array, place_key: String) -> Dictionary:
	for candidate: Dictionary in places:
		if candidate.key == place_key:
			return candidate
	return {}


## The key of the place nearest to `world_position`; "" without places.
static func nearest_place(places: Array, world_position: Vector2) -> String:
	var nearest := ""
	var nearest_distance := INF
	for candidate: Dictionary in places:
		var distance := (candidate.position as Vector2).distance_to(world_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate.key
	return nearest


## The place that stays chosen when the places become `places`: `selected` while it is
## among them, else the one nearest to the player.
static func selected_after_change(places: Array, selected: String, player_at: Vector2) -> String:
	if selected == "" or place(places, selected).is_empty():
		return nearest_place(places, player_at)
	return selected


## The key of the place under a click at `point`: the nearest of `points` (key -> point of
## the map) within `radius`; "" when none is.
static func picked_place(points: Dictionary, point: Vector2, radius: float) -> String:
	var nearest := ""
	var nearest_distance := radius
	for place_key: String in points:
		var distance := (points[place_key] as Vector2).distance_to(point)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = place_key
	return nearest


## The key of the nearest place in `direction` (on screen) from the chosen one among
## `points` (key -> point of the map), within 60 degrees of it, the straightest preferred;
## "" when there is none that way.
static func place_towards(points: Dictionary, current_key: String, direction: Vector2) -> String:
	var from: Vector2 = points[current_key]
	var best := ""
	var best_score := INF
	for place_key: String in points:
		if place_key == current_key:
			continue
		var offset: Vector2 = points[place_key] - from
		var distance := offset.length()
		if distance < SAME_SPOT:
			continue
		var straightness := offset.dot(direction) / distance
		if straightness < LEAST_STRAIGHTNESS:
			continue
		var score := distance * (2.0 - straightness)
		if score < best_score:
			best_score = score
			best = place_key
	return best


## The line in the tab bar: "DEN HAAG · 1 / 2 WIJKEN ONTDEKT" (the whole city is no
## neighbourhood).
static func header_text(areas: Array, visited_names: Dictionary) -> String:
	var area_names := {}
	for area: Array in areas:
		if area[0] != WHOLE_CITY:
			area_names[area[0]] = true
	var visited_count := 0
	for wijk: String in area_names:
		if visited_names.has(wijk):
			visited_count += 1
	return "DEN HAAG · %d / %d WIJKEN ONTDEKT" % [visited_count, area_names.size()]


## Where the player is, as written on the map: "X 0100 · Y 0100".
static func coordinates_text(player_at: Vector2) -> String:
	return "X %04d · Y %04d" % [roundi(player_at.x), roundi(player_at.y)]


## The street the player is in as written beside the map; without one "Geen straat".
static func street_text(street: String) -> String:
	return street if street != "" else "Geen straat"


## The stretches of the town to paint for the fog, in the order to paint them (the "wijken"
## last to first: the first one a cell lies in wins, as in the HUD): {"from", "to": world
## x, z, "fogged": not visited yet}.
static func fog_areas(areas: Array, visited_names: Dictionary) -> Array:
	var stretches: Array = []
	for area_index in range(areas.size() - 1, -1, -1):
		var area: Array = areas[area_index]
		stretches.append({"from": Vector2(area[1], area[2]) * CELL_METRES,
				"to": Vector2(float(area[3]) + 1.0, float(area[4]) + 1.0) * CELL_METRES,
				"fogged": not visited_names.has(area[0])})
	return stretches


## The names of the visited neighbourhoods on the map: {"text", "at": the middle of the
## neighbourhood, world x, z}; not the whole city, nor what `is_shrouded` hides.
static func area_labels(areas: Array, visited_names: Dictionary, is_shrouded: Callable) -> Array:
	var labels: Array = []
	for area: Array in areas:
		if area[0] == WHOLE_CITY or not visited_names.has(area[0]):
			continue
		var centre := Vector2(float(area[1] + area[3]) + 1.0, float(area[2] + area[4]) + 1.0) * 0.5 * CELL_METRES
		if is_shrouded.call(centre):
			continue
		labels.append({"text": str(area[0]).to_upper(), "at": centre})
	return labels


## How a place looks on the map and in its panel: LOOK_SUPERMARKET, LOOK_CASH_MACHINE,
## LOOK_PLACE (its neighbourhood is visited) or LOOK_UNKNOWN.
static func look_of(a_place: Dictionary, visited_names: Dictionary) -> String:
	if supermarket_chain(a_place.key) != "":
		return LOOK_SUPERMARKET
	if is_cash_machine(a_place.key):
		return LOOK_CASH_MACHINE
	return LOOK_PLACE if visited_names.has(a_place.wijk) else LOOK_UNKNOWN


## The marks of the places on the map, in the order to draw them (the chosen one last, on
## top): {"at": world x, z, "look", "chain", "chosen"}; a place `is_shrouded` hides is
## left out, but never the chosen one.
static func marks(places: Array, selected: String, visited_names: Dictionary, is_shrouded: Callable) -> Array:
	var shown: Array = []
	var chosen := {}
	for a_place: Dictionary in places:
		var mark := {"at": a_place.position, "look": look_of(a_place, visited_names),
				"chain": supermarket_chain(a_place.key), "chosen": a_place.key == selected}
		if mark.chosen:
			chosen = mark
		elif not is_shrouded.call(a_place.position):
			shown.append(mark)
	if not chosen.is_empty():
		shown.append(chosen)
	return shown


## The name the marker gets on a place: the chain of a supermarket, else the place's name.
static func marker_name(a_place: Dictionary) -> String:
	var chain := supermarket_chain(a_place.key)
	return String(SUPERMARKET_NAMES[chain]) if chain != "" else String(a_place.name)


## Whether the marker (`has_waypoint`, at `waypoint`) stands on this place.
static func is_marker_on(a_place: Dictionary, has_waypoint: bool, waypoint: Vector2) -> bool:
	return has_waypoint and waypoint.is_equal_approx(a_place.position)


## The panel of the chosen place: {"look", "chain", "kind_text", "name", "wijk_text",
## "distance_text": how far from `player_at`, "state_text", "marker_text", "marked"}.
static func place_panel(a_place: Dictionary, visited_names: Dictionary, player_at: Vector2, marked: bool) -> Dictionary:
	var known := visited_names.has(a_place.wijk)
	var look := look_of(a_place, visited_names)
	var kind_text := "◆ PLEK" if known else "? NOG ONBEKEND"
	if look == LOOK_SUPERMARKET:
		kind_text = "◆ SUPERMARKT"
	elif look == LOOK_CASH_MACHINE:
		kind_text = "◆ PINAUTOMAAT"
	return {
		"look": look,
		"chain": supermarket_chain(a_place.key),
		"kind_text": kind_text,
		"name": marker_name(a_place),
		"wijk_text": "In %s" % a_place.wijk if a_place.wijk != WHOLE_CITY else "In Den Haag",
		"distance_text": "%d M" % roundi((a_place.position as Vector2).distance_to(player_at)),
		"state_text": "BEZOCHTE WIJK" if known else "ONONTDEKTE WIJK",
		"marker_text": "◆ MARKER STAAT HIER   [ENTER] WEG" if marked else "[ENTER] MARKER ZETTEN",
		"marked": marked,
	}


## Where the debug teleport puts the player down for `spot` (world x, z): on the ground it
## was given (`ground`, the middle of the nearest walkable cell) or, without one, at the
## height the player stood (`player_height`), a little above it.
static func teleport_point(spot: Vector2, player_height: float, ground: Variant = null) -> Vector3:
	if ground is Vector3:
		return Vector3(ground.x, ground.y + TELEPORT_DROP, ground.z)
	return Vector3(spot.x, player_height + TELEPORT_DROP, spot.y)
