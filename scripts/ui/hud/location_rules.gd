extends RefCounted
## The rules of where the player is, as the HUD shows it over the minimap (logic;
## docs/CODE_LAGEN.md): the neighbourhood, the street and the nearest named place of a
## spot, from the plain tables the city builder leaves in the scene metadata ("wijken",
## "straten", "places"); the name a neighbourhood or a place is shown by; which font size
## fits. Used by location.gd (and the map of the game menu).
##   const LocationRules = preload("res://scripts/ui/hud/location_rules.gd")

## Neighbourhoods shown under another name than their key in the "wijken" metadata (the key
## stays what the crowds (data/drukte.json) and the visited list go by).
const AREA_DISPLAY_NAMES := {"Centraal Station": "Station Den Haag Centraal"}
## The neighbourhood of a spot in none of the "wijken".
const WHOLE_CITY := "Den Haag"
## The neighbourhood's name: this size, smaller (down to the smallest) for a long name, so
## it fits the box whole.
const AREA_FONT_SIZE := 11
const AREA_SMALLEST_FONT_SIZE := 8
## Map cells are 4 m (the "wijken" and "straten" tables count in cells).
const CELL_METRES := 4.0
## Cells beside a street that still count as on it (the pavement).
const STREET_MARGIN_CELLS := 1.0
## Places whose key starts so are test spots of the builder, not places.
const TEST_PLACE_PREFIX := "verkeerslichten"
## Words of a place name that keep their small letter ("Ministerie van Financien").
const SMALL_WORDS := ["van", "de", "het", "en", "der", "den", "op"]


## The map cell (fractional) of the world point (x, z).
static func cell_of(world: Vector2) -> Vector2:
	return world / CELL_METRES


## The neighbourhood of a map cell: the first of `areas` ("wijken": [name, x from, y from,
## x to, y to] each, in cells) it lies in; WHOLE_CITY when in none.
static func area_at(areas: Array, cell: Vector2) -> String:
	for area: Array in areas:
		if cell.x >= area[1] and cell.y >= area[2] and cell.x < area[3] + 1 and cell.y < area[4] + 1:
			return area[0]
	return WHOLE_CITY


## The name a neighbourhood (a key of the "wijken" metadata) is shown by.
static func area_display_name(wijk: String) -> String:
	return String(AREA_DISPLAY_NAMES.get(wijk, wijk))


## The name of the street at this map cell (fractional), from `streets` ("straten": [name,
## axis, across from, across to, along from, along to] each); on the lanes before the
## pavement beside them; "" if none.
static func street_at(streets: Array, cell: Vector2) -> String:
	var beside := ""
	for street: Array in streets:
		var across := cell.x if street[1] == "x" else cell.y
		var along := cell.y if street[1] == "x" else cell.x
		if along < street[4] or along >= street[5] + 1:
			continue
		if across >= street[2] and across < street[3] + 1:
			return street[0]
		if beside == "" and across >= street[2] - STREET_MARGIN_CELLS and across < street[3] + 1 + STREET_MARGIN_CELLS:
			beside = street[0]
	return beside


## A key of "places" as a name: "ministerie_van_financien" -> "Ministerie van Financien",
## "a12_koningskade" -> "A12 Koningskade".
static func place_name(place_key: String) -> String:
	var words := place_key.split("_", false)
	# a second one of the same (a supermarket chain: "derrek_3") is just its name
	if words.size() > 1 and words[-1].is_valid_int():
		words.resize(words.size() - 1)
	for index in words.size():
		var word := words[index]
		if index > 0 and word in SMALL_WORDS:
			continue
		words[index] = word.substr(0, 1).to_upper() + word.substr(1)
	return " ".join(words)


## The name of the place of `places` ("places": key -> world x, z) nearest to `from`,
## nearer than `within` metres; "" when none is.
static func nearest_place(places: Dictionary, from: Vector2, within: float) -> String:
	var nearest := ""
	var nearest_distance := within
	for place_key: String in places:
		if place_key.begins_with(TEST_PLACE_PREFIX):
			continue
		var distance := (places[place_key] as Vector2).distance_to(from)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = place_name(place_key)
	return nearest


## Where the player is: {"wijk": the key of the neighbourhood, "shown_name": the name it
## is shown by, "street", "place": the nearest named place within `place_near` metres}
## ("" none) at the world point `at`. Inside a building (`indoor_wijk` not ""): its
## neighbourhood, no street or place (the spot itself is far off the map).
static func where(areas: Array, streets: Array, places: Dictionary, at: Vector2, place_near: float, indoor_wijk := "") -> Dictionary:
	var cell := cell_of(at)
	var wijk := area_at(areas, cell)
	var street := street_at(streets, cell)
	var place := nearest_place(places, at, place_near)
	if indoor_wijk != "":
		wijk = indoor_wijk
		street = ""
		place = ""
	return {"wijk": wijk, "shown_name": area_display_name(wijk), "street": street, "place": place}


## Whether the place line shows: there is a place and it does not say what the
## neighbourhood or the street line says already.
static func is_place_shown(place: String, wijk: String, shown_name: String, street: String) -> bool:
	var lower := place.to_lower()
	return place != "" and lower != wijk.to_lower() and lower != shown_name.to_lower() and lower != street.to_lower()


## Whether a neighbourhood is announced as a new area: entered for the first time, and not
## the one the game starts in (`current`: "" at the start).
static func is_new_area(wijk: String, current: String, visited: Array) -> bool:
	return wijk != current and current != "" and not visited.has(wijk)


## The font size of the neighbourhood line: the usual one, or the biggest smaller one at
## which the text is no wider than `room` (`width_at`: font size -> width of the text);
## the smallest when none fits.
static func fitting_font_size(room: float, width_at: Callable) -> int:
	var font_size := AREA_FONT_SIZE
	while font_size > AREA_SMALLEST_FONT_SIZE and width_at.call(font_size) > room:
		font_size -= 1
	return font_size
