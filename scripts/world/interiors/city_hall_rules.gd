extends RefCounted
## The logic of the city hall (docs/CODE_LAGEN.md): what its floors are called in the lift
## and on the notice, what its people wear and how they are made, whether the lift may ride,
## and the round of the caretaker. The queue of Burgerzaken has its own:
## city_hall_queue_rules.gd. Behaviour: city_hall.gd (and city_hall_caretaker.gd); where
## things stand: city_hall_layout.gd; what you see: city_hall_view.gd.
##   const CityHallRules = preload("res://scripts/world/interiors/city_hall_rules.gd")

const NOTICE_HEADING := "— ETAGE %d —"
const LIFT_QUESTION := "Ding. De liftdeuren gaan open. Naar welke etage?"
## The roles behind a counter: talked to across it, from before it.
const COUNTER_ROLES := ["loketmedewerker", "receptioniste"]
## The caretaker of the basement: his role, his pace (m/s), how long he stops to mop at a
## point of his round (s, from .. to), and how near a point counts as there (m).
const CARETAKER_ROLE := "concierge"
const CARETAKER_PACE := 0.9
const CARETAKER_MOP := Vector2(2.0, 6.0)
const CARETAKER_AT_POINT := 0.3
## The seed of the people of the building (person_seed).
const PEOPLE_SEED := 7000


## What who works here wears: the receptionists in the city's green, the guard in black
## with yellow, the mayor in dark blue; civil servants and visitors their own clothes.
static func outfit(role: String) -> Dictionary:
	match role:
		"receptioniste":
			return {"jas": "#2E7D32", "rand": "#F2C200", "broek": "#22242A"}
		"beveiliger":
			return {"jas": "#1E2024", "rand": "#F2C200", "broek": "#1E2024", "pet": "#1E2024"}
		"burgemeester":
			return {"jas": "#1A2440", "rand": "#C9A23A", "broek": "#1A2440"}
		"raadslid":
			return {"jas": "#3A3E48", "rand": "#E8E6E0", "broek": "#2A2C32"}
		"concierge":
			return {"jas": "#2A3E5C", "rand": "#C8CCD2", "broek": "#2A3E5C"}
	return {}


## The seed of the look of person `index` of floor `floor_number`.
static func person_seed(floor_number: int, index: int) -> int:
	return PEOPLE_SEED + floor_number * 100 + index


## The name of the node of someone with `role` ("loketmedewerker" -> "Loketmedewerker").
static func person_name(role: String) -> String:
	return role.capitalize().replace(" ", "")


## Whether someone with `role` sits behind a counter (talked to across it).
static func talks_across_counter(role: String) -> bool:
	return role in COUNTER_ROLES


## The text of a level on the displays: "K" for the basement, else its number.
static func level_text(level: int) -> String:
	return "K" if level < 0 else str(level)


## Where a level is, in words: "Begane grond", "Kelder", "2e etage".
static func level_words(level: int) -> String:
	return "Begane grond" if level == 0 else ("Kelder" if level < 0 else "%de etage" % level)


## The choices of the lift called on floor `from`: one per floor (`levels` and `names` by
## floor number), "<where> · <name>", the floor you are on marked "(hier)".
static func floor_choices(levels: Array, names: Array, from: int) -> Array:
	var choices: Array = []
	for index in levels.size():
		var label := level_words(int(levels[index])) + " · " + String(names[index] if index < names.size() else "")
		choices.append(label + ("  (hier)" if index == from else ""))
	return choices


## The page of the story box the lift asks its question with.
static func lift_page(choices: Array) -> Dictionary:
	return {"kind": "verhaal", "speaker": "LIFT", "text": LIFT_QUESTION, "choices": choices}


## The heading of the notice on arriving at `level`.
static func arrival_heading(level: int) -> String:
	return NOTICE_HEADING % level if level > 0 else ("— BEGANE GROND —" if level == 0 else "— KELDER —")


## Whether the lift may ride to floor `to` now: not riding already, another floor, one that exists.
static func may_ride(riding: bool, current_floor: int, to: int, floor_count: int) -> bool:
	return not riding and to != current_floor and to >= 0 and to < floor_count


## The floor the lift goes to from `from` when nothing can ask which (no HUD): the next one up, round.
static func next_floor(from: int, floor_count: int) -> int:
	return (from + 1) % maxi(floor_count, 1)


## Whether the floor chosen in the story box is one to ride to (-1: none chosen).
static func is_ride_chosen(chosen: int, current_floor: int) -> bool:
	return chosen >= 0 and chosen != current_floor


## The point of his round the caretaker goes to after `point` (of `point_count`).
static func next_round_point(point: int, point_count: int) -> int:
	return (point + 1) % point_count


## Whether the caretaker at `at` is at the point `target` of his round (along the floor).
static func is_at_round_point(at: Vector3, target: Vector3) -> bool:
	return Vector2(at.x - target.x, at.z - target.z).length() < CARETAKER_AT_POINT
