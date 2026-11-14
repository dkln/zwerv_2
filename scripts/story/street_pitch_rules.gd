extends RefCounted
## The rules of the people who come up to you in the street to sell you something (logic;
## docs/CODE_LAGEN.md): who they are (PITCHES), where and when they come (HOT_SPOTS, HOURS,
## the chances), which group is next and what lets you go. street_pitches.gd is the node
## that keeps the clocks and sends them after the player.
##   const StreetPitchRules = preload("res://scripts/story/street_pitch_rules.gd")

const AFTER_MISSION := "missie_2_bekend_gezicht"
const HOURS := Vector2(9.0, 19.0)
## Seconds between two looks, the chance at a look near a hot spot and elsewhere, the quiet
## after one (seconds), and how long a group keeps after you before it gives up.
const LOOK_EVERY := 12.0
const CHANCE_AT_HOT_SPOT := 0.3
const CHANCE_ELSEWHERE := 0.03
const QUIET_AFTER := 150.0
const GIVE_UP := 150.0
## How often they call out (seconds, from .. to) and within how many metres of the player.
const CALL_EVERY := Vector2(5.0, 10.0)
const CALL_WITHIN := 24.0
## The busy places (the "places" of the town) and how far round them (metres) counts as there.
const HOT_SPOTS := {"centraal": 70.0, "frietkar_centraal": 40.0, "station_laan_van_noi": 40.0, "station_voorburg": 40.0,
	"plein": 45.0, "buitenhof": 35.0, "grote_markt": 40.0, "grote_marktstraat": 55.0, "spui": 45.0, "spui_straat": 45.0,
	"dirigentplein": 30.0, "noordeinde": 45.0}
## Who comes ("wie" talks, "groep" comes along), their conversation then ("gesprek") and after
## ("klaar"), and the hidden check that lets you go ("los").
const PITCHES := [
	{"wie": "telefoonverkoper", "groep": ["telefoonverkoper_kevin", "telefoonverkoper_sanne"], "gesprek": "verkopen",
		"klaar": "klaar", "los": "verkopers_af", "stemming": "opgewonden",
		"kreten": ["Hé! Heb jij al 5G?", "Eén vraagje maar! Niet weglopen!", "Lebaarmoeder! Nu met gratis hoesje!", "Hé, jij daar! Telefoonabonnement?"]},
	{"wie": "werver_rotonde", "groep": ["werver_rotonde_2"], "gesprek": "werven", "klaar": "klaar", "los": "rotonde_af",
		"stemming": "opgewonden",
		"kreten": ["Heb jij een hart voor rotondes?", "Rotonde in Nood! Eén minuutje!", "Adopteer een rotonde!", "Hoi! Hé! Jij lijkt me een rotondemens!"]},
	{"wie": "getuige", "groep": ["getuige_2"], "gesprek": "bekeren", "klaar": "klaar", "los": "getuigen_af", "stemming": "blij",
		"kreten": ["Goedemiddag! Mogen wij u iets geven?", "De Wachttoren, gratis!", "Denkt u wel eens na over de toekomst?", "Een mooie dag, hè? Heeft u even?"]},
]


## Whether they come at this hour of the day (HOURS).
static func is_daytime(hour: float) -> bool:
	return hour >= HOURS.x and hour <= HOURS.y


## Whether `feet` (world x, z) is round one of HOT_SPOTS (`places`: the places of the town).
static func at_hot_spot(feet: Vector2, places: Dictionary) -> bool:
	for place: String in HOT_SPOTS:
		if places.has(place) and feet.distance_to(places[place]) <= float(HOT_SPOTS[place]):
			return true
	return false


## The chance a group comes at one look.
static func chance(near_hot_spot: bool) -> float:
	return CHANCE_AT_HOT_SPOT if near_hot_spot else CHANCE_ELSEWHERE


## Which of PITCHES comes when `drawn_index` was drawn: never the same as the last one
## (`last_index`), the next one instead.
static func pitch_index(drawn_index: int, last_index: int) -> int:
	return (drawn_index + 1) % PITCHES.size() if drawn_index == last_index else drawn_index


## Everyone of a pitch: who talks first, then the group that comes along.
static func names_of(pitch: Dictionary) -> Array:
	return [String(pitch.get("wie", ""))] + Array(pitch.get("groep", []))


## Whether a group is over: it gave up (no seconds left) or no longer chases the player.
static func is_over(seconds_left: float, still_chasing: bool) -> bool:
	return seconds_left <= 0.0 or not still_chasing


## Whether the check `check_id` lets you go from `pitch`: passed, and its hidden check "los".
static func lets_go(pitch: Dictionary, check_id: String, passed: bool) -> bool:
	return passed and not pitch.is_empty() and check_id == String(pitch.get("los", ""))


## Whether the one calling is near enough to the player to be heard (CALL_WITHIN).
static func within_call(gap: float) -> bool:
	return gap <= CALL_WITHIN
