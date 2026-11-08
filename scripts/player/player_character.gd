extends RefCounted
## The three kinds of zwerver a new game can start as (the character creation screen,
## scenes/karakter.tscn) and which one was chosen. The choice lives in a static variable:
## it stays across the change to the town, where the HUD reads it (portrait, name, the
## maximum of the stats).
##   PlayerCharacter.choose("ufo_piloot")
##   var archetype := PlayerCharacter.chosen_archetype()
## "addiction" is for the game, not shown on the creation screen.
## The stats use the HUD's names (GameHud.STATS): "gezondheid" (hp), "uithoudingsvermogen"
## (stamina) and "honger" (how much the hunger meter holds); 100 is ordinary. The names
## are nicknames; "subtitle" says in a few words what they are good at, "level" the level
## they start on, "difficulty" how hard a game with them is (1 easy .. 5 hard; Willem has been on the street longest: level 3, lower stats); "perk" (if
## any) something only they have, "start_money" the euros they start with (Sjaan: what is in
## her cap).

const ARCHETYPES := {
	"jos": {
		"name": "Jos",
		"subtitle": "DE IJZEREN MAAG",
		"addiction": "alcohol",
		"difficulty": 4,
		"level": 1,
		"story": "Jos reed ooit rodeo op de kermis in het Zuiderpark, tot het paard er met het prijzengeld vandoor ging. Van die tijd is alleen zijn hoed nog over. Nu slaapt hij onder de Hoftoren, met die hoed als kussen. Hij eet alles wat los zit, maar na één trap staat hij te hijgen.",
		"stats": {"gezondheid": 70, "uithoudingsvermogen": 60, "honger": 140},
	},
	"martin": {
		"name": "Martin",
		"subtitle": "DE RENNER",
		"addiction": "speed",
		"difficulty": 2,
		"level": 1,
		"story": "Martin was de snelste fatbikekoerier van de Schilderswijk, tot hij zijn fiets en zijn kamer kwijtraakte. Stilstaan kan hij nog steeds niet. Zijn hele huis zit in zijn rugzak. Hij rent de stad door, praat tegen de meeuwen op het Plein en vergeet dagenlang te eten.",
		"stats": {"gezondheid": 100, "uithoudingsvermogen": 150, "honger": 70},
	},
	"ufo_piloot": {
		"name": "Ufo Piloot",
		"subtitle": "DE ONVERWOESTBARE",
		"addiction": "crack",
		"difficulty": 3,
		"level": 1,
		"story": "Ze noemen hem de Ufo Piloot, omdat hij zweert dat hij in '97 boven het Malieveld is meegenomen en zonder zijn naam is teruggezet. Verder is er niks vreemds aan hem: een oude vliegeniersjas, een stoppelbaard, broodmager. Niks doet hem nog pijn, maar hij is altijd moe en heeft altijd trek.",
		"stats": {"gezondheid": 150, "uithoudingsvermogen": 60, "honger": 70},
	},
	"willem": {
		"name": "Willem",
		"subtitle": "DE OUDE RAT",
		"addiction": "gokkasten",
		"difficulty": 3,
		"level": 3,
		"story": "Willem zwerft al sinds de jaren tachtig door Den Haag. Hij kent elke portiek, elk statiegeldapparaat en elke agent bij naam, en hij liep hier al rond toen de Hoftoren nog gebouwd moest worden. Hij is niet meer de sterkste, maar niemand weet de weg zo goed als hij.",
		"stats": {"gezondheid": 80, "uithoudingsvermogen": 80, "honger": 80},
	},
	"sjaan": {
		"name": "Sjaan",
		"subtitle": "DE STRAATMUZIKANT",
		"addiction": "sigaretten",
		"difficulty": 1,
		"level": 1,
		"perk": "Begint met € 25 in de pet en hond Bobbie bij zich.",
		"start_money": 25,
		"story": "Sjaan speelde dertig jaar accordeon op de Grote Markt, tot haar huisbaas het pand verkocht. Nu slaapt ze met haar hond Bobbie in een portiek in Chinatown, maar ze speelt nog elke dag. Er valt altijd wel wat in de pet, en Bobbie hoort de politie eerder aankomen dan zij.",
		"stats": {"gezondheid": 90, "uithoudingsvermogen": 110, "honger": 90},
	},
}
## The order on the screen.
const ORDER := ["jos", "martin", "ufo_piloot", "willem", "sjaan"]
## The highest difficulty and what each is called.
const DIFFICULTY_CEILING := 5
const DIFFICULTY_NAMES := ["", "MAKKELIJK", "MAKKELIJK", "GEMIDDELD", "MOEILIJK", "ZWAAR"]
## The highest value a stat can have: the bars on the creation screen are a share of it.
const STAT_CEILING := 150.0
## How the stats are called on the creation screen.
const STAT_LABELS := {"gezondheid": "LEVEN", "uithoudingsvermogen": "STAMINA", "honger": "HONGER"}

static var chosen_id := ""


static func choose(archetype_id: String) -> void:
	if ARCHETYPES.has(archetype_id):
		chosen_id = archetype_id


## The chosen archetype id, or the first one when none was chosen (the town opened
## straight from the editor).
static func current_id() -> String:
	return chosen_id if ARCHETYPES.has(chosen_id) else ORDER[0]


static func chosen_archetype() -> Dictionary:
	return ARCHETYPES[current_id()]
