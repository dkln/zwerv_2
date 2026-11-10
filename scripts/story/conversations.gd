extends RefCounted
## Talking to a passer-by (Pedestrian; PlayerController.talk_to): a little conversation tree in
## the story box (scripts/ui/story_box.gd, pages of kind "gesprek" with "choices"). Who you
## talk to sets the tone (`persona`, from how they look: Pedestrian `mobility` and the
## TownsfolkFigure look): the wheelchair user, the one on the mobility scooter, the old
## Hagenaar (bald), the man in the cap, the lady (a skirt), the student (long hair), the civil
## servant (a dark or grey coat: Den Haag), the tourist (a beige coat) and the commuter.
## Each has its greetings, its own topic, an answer when you ask for some change (now and
## then they give some: once per person, GENEROSITY, counted for mission 1 as found money)
## and directions to Jan Blammage. Asked topics are not offered again; "Laat maar" ends it.
## Every line has a mood (MOODS, a persona's own in MOODS_OF): they babble in it, in their
## voice (Pedestrian.voice; Babble, the story box) and their body moves with it (Emote: angry
## shakes, happy hops, sad leans forward); `finish` puts them back as they were.
##   var talk := Conversations.new(person, player, hud)
##   hud.show_story(talk.opening())

const PERSONAS := {
	"rolstoel": {
		"speaker": "MAN IN ROLSTOEL",
		"greetings": ["Hé, kijk uit voor m'n wielen, maat. Wat kan ik voor je doen?", "Ja? Ik rij net een rondje. Zeg het maar."],
		"topic": ["Hoe gaat het met de stoepen hier?", "Stoepen? Half Den Haag is een hindernisbaan. Elke stoeprand is een berg, en de klinkers rammelen m'n tanden los.",
			["En toch rij je rond?", "Natuurlijk! Ik laat me niet binnenhouden door een stoeprand. Ik doe gewoon een wheelie, kijk maar uit."]],
		"money_yes": "Hier, een paar centen. Wij moeten elkaar een beetje helpen, hè?",
		"money_no": "Sorry jong, m'n uitkering is ook op. Volgende maand misschien.",
		"blammage": "Jan Blammage? Daar ga ik ook altijd heen. Kijk maar op je kaart, die zitten overal in de stad.",
		"bye": "Rij voorzichtig, hè. O nee, jij loopt. Nou, loop voorzichtig dan.",
	},
	"scootmobiel": {
		"speaker": "MEVROUW OP SCOOTMOBIEL",
		"greetings": ["Ja ja, wat is er? Ik heb haast, de markt gaat zo dicht.", "Goedemiddag! Pas op m'n mandje, daar zitten de eieren in."],
		"topic": ["Mooie scootmobiel, mevrouw.", "Hè, dank je! Vijftien kilometer per uur. M'n kleinzoon heeft hem een beetje opgevoerd.",
			["Opgevoerd? Mag dat wel?", "Mag dat wel, mag dat wel... Ik ben zevenentachtig, jongen. Ik mag alles."]],
		"money_yes": "Ach jongen, hier. Koop er wat warms van. En niet aan de drank, hè!",
		"money_no": "Kleingeld? Dat zit allemaal in de parkeermeter van m'n zoon. Sorry hoor.",
		"blammage": "Jan Blammage! Die kroketten zijn nog net zo lekker als in 1962. Op je kaartje staan ze, kijk maar.",
		"bye": "Dag jongen! En ga eens naar de kapper.",
	},
	"oude_hagenaar": {
		"speaker": "OUDE HAGENAAR",
		"greetings": ["Ollah. Wat mot je?", "Zo, jij ziet er ook uit alsof je een lange nacht had."],
		"topic": ["Hoe was Den Haag vroeger?", "Vroeger? Toen reed de tram nog met een conducteur en kostte een kroket een kwartje. Nu is alles glas en kantoor.",
			["Was het beter toen?", "Beter? Nee hoor. Wel goedkoper. En de mensen groetten je nog. Ollah, zeg ik altijd. Ollah!"]],
		"money_yes": "Hier, een paar centen. Niet zeuren, gewoon pakken.",
		"money_no": "Kleingeld? Ik ben zelf ook een zwerver geweest, jong. Je mot het zelf bij elkaar scharrelen.",
		"blammage": "Jan Blammage, da's de beste. Kijk op je kaart, dan zie je waar ze zitten. Neem een frikandel speciaal erbij.",
		"bye": "Hou je haaks, jonguh.",
	},
	"pet": {
		"speaker": "MAN MET PET",
		"greetings": ["Hé maat! Ook goeiemorgen. Of is het al middag?", "Wat is er, makker? Ik sta op het punt aan het werk te gaan."],
		"topic": ["Wat voor werk doe je?", "Ik sta op de markt. Groente en fruit. Drie kilo appels voor een tientje, geen mens die dat nog doet.",
			["Kan ik niet bij je komen werken?", "Bij mij? Hahaha. Kom eerst maar eens wakker, dan praten we verder. Maar je hebt lef, dat mag ik wel."]],
		"money_yes": "Hier, een paar muntjes. Gewoon tussen ons, hè?",
		"money_no": "Kleingeld? Op de markt is alles cash, maar dat is voor m'n vrouw. Sorry, makker.",
		"blammage": "Jan Blammage? Elke dag na de markt. Ze zitten op je kaart, maat. Zeg maar dat je van mij komt.",
		"bye": "Zie je, makker. Kop op!",
	},
	"dame": {
		"speaker": "NETTE DAME",
		"greetings": ["Oh! U laat me schrikken. Kan ik u ergens mee helpen?", "Goedendag. U ziet er... vermoeid uit."],
		"topic": ["Waar gaat u zo netjes heen?", "Naar de Koninklijke Schouwburg. Een toneelstuk over een man die alles kwijtraakt. Heel ontroerend, zeggen ze.",
			["Dat klinkt als mijn leven.", "Oh. Oh lieverd. Nou, dan weet u alvast hoe het afloopt. Er komt een pauze met bitterballen."]],
		"money_yes": "Hier, alstublieft. Gebruik het verstandig, beloofd?",
		"money_no": "Ik betaal tegenwoordig alles met mijn telefoon, het spijt me werkelijk.",
		"blammage": "Een snackbar? Dat ik u dat moet vertellen... Op uw kaart staan ze. Ik ga er zelf wel eens heen. Niet verder vertellen.",
		"bye": "Een fijne dag nog. En draag een jas, het wordt koud.",
	},
	"student": {
		"speaker": "STUDENT",
		"greetings": ["Hé! Sorry, ik heb over tien minuten tentamen. Wat is er?", "Yo. Jij bent toch die van het Plein? Wat is er?"],
		"topic": ["Wat studeer je?", "Internationaal recht. In Den Haag, hè, de stad van vrede en recht. Ik word later rechter in het Vredespaleis.",
			["En dan kun je mij vrijspreken?", "Haha, dat hangt ervan af wat je gedaan hebt. Maar ik reken alleen in kroketten, hoor."]],
		"money_yes": "Hier, een paar centen. Ik leef zelf van studieschuld, dus wat maakt het uit.",
		"money_no": "Kleingeld? Ik heb nog geen tien cent voor de koffieautomaat. Sorry!",
		"blammage": "Jan Blammage! Daar eten we altijd na het stappen. Op je kaart, kijk maar, die met het ruitje.",
		"bye": "Ik moet rennen! Succes, hè!",
	},
	"ambtenaar": {
		"speaker": "AMBTENAAR",
		"greetings": ["Ja? Ik heb om negen uur een overleg op het ministerie. Kort graag.", "Goedemorgen. Heeft u een afspraak? O nee, dit is de straat."],
		"topic": ["Wat doet u op het ministerie?", "Ik schrijf beleid over het schrijven van beleid. Het is een belangrijke notitie. Volgend jaar is hij af.",
			["Wat staat erin?", "Dat valt nog onder embargo. Maar tussen ons: er komt een werkgroep. Die gaat een advies schrijven. Over de notitie."]],
		"money_yes": "Hier. Ik zet het wel op de declaratie onder 'maatschappelijke betrokkenheid'.",
		"money_no": "Daar is geen budget voor, vrees ik. Probeert u het volgend kwartaal nog eens.",
		"blammage": "Jan Blammage? Ik ken het niet. Dat wil zeggen: officieel niet. Kijkt u op uw kaart, daar staan ze.",
		"bye": "Ik moet door. Fijne dag nog, en vergeet uw formulieren niet.",
	},
	"toerist": {
		"speaker": "TOERIST",
		"greetings": ["Oh, hello! Eh, hallo! Is this the way to the beach? Het strand?", "Hallo! Ik kom uit Groningen. Waar is hier dat Binnenhof?"],
		"topic": ["Waar komt u vandaan?", "Uit Groningen! Ik ben hier voor het Binnenhof, maar dat zit helemaal in de steigers. Ik zie alleen maar bouwdoek.",
			["Dat is al jaren zo.", "Jaren? Nou, dan kom ik wel terug als ik met pensioen ben. Of mijn kleinkinderen."]],
		"money_yes": "Ach, natuurlijk! Hier, en nog een fijne dag in uw mooie stad.",
		"money_no": "Oh, alles is op aan de parkeergarage. Twintig euro! Voor twee uur!",
		"blammage": "Jan Blammage? Daar wil ik ook heen! Op uw kaart? Kijk, die. Dan gaan we samen. Nee, grapje.",
		"bye": "Dag! Doei! Bye!",
	},
	"forens": {
		"speaker": "VOORBIJGANGER",
		"greetings": ["Hm? Sorry, ik moet m'n tram halen. Wat is er?", "Hé. Gaat het wel met je?"],
		"topic": ["Waar moet u heen?", "Naar Zoetermeer, met de RandstadRail. Elke dag. Al twaalf jaar. Ik ken alle haltes uit m'n hoofd.",
			["Noem ze dan eens op.", "Centraal, Laan van NOI, Voorburg 't Loo, Leidschendam-Voorburg... ach, daar gaat m'n tram. Bedankt, hoor."]],
		"money_yes": "Hier. Een paar muntjes. Sterkte, hè.",
		"money_no": "Ik heb alleen m'n ov-kaart bij me. Sorry.",
		"blammage": "Jan Blammage? Die zitten overal, kijk maar op je kaart. Lekkere kroketten, trouwens.",
		"bye": "Ik moet gaan. Pas goed op jezelf.",
	},
}
## The mood of each kind of line (Babble, Emote), and where a persona differs.
const MOODS := {"greeting": "neutraal", "topic": "neutraal", "follow_up": "blij", "money_yes": "blij",
	"money_no": "verdrietig", "blammage": "opgewonden", "bye": "blij"}
const MOODS_OF := {
	"rolstoel": {"greeting": "blij", "topic": "boos", "follow_up": "opgewonden"},
	"scootmobiel": {"greeting": "boos", "follow_up": "boos"},
	"oude_hagenaar": {"greeting": "boos", "topic": "verdrietig", "money_no": "boos", "bye": "neutraal"},
	"pet": {"greeting": "blij", "follow_up": "opgewonden"},
	"dame": {"greeting": "verdrietig", "follow_up": "verdrietig", "blammage": "neutraal"},
	"student": {"greeting": "opgewonden", "topic": "opgewonden"},
	"ambtenaar": {"greeting": "neutraal", "money_no": "neutraal", "blammage": "neutraal", "bye": "neutraal"},
	"toerist": {"greeting": "opgewonden", "topic": "verdrietig", "follow_up": "blij"},
	"forens": {"follow_up": "verdrietig", "bye": "neutraal"},
}
const Emote = preload("res://scripts/world/emote.gd")

## Chance in 100 that someone of a persona gives some change, and how much (euros).
const GENEROSITY := {"rolstoel": [50, 0.2], "scootmobiel": [60, 0.5], "oude_hagenaar": [40, 0.2], "pet": [50, 0.5],
	"dame": [60, 0.5], "student": [30, 0.1], "ambtenaar": [45, 0.2], "toerist": [70, 1.0], "forens": [30, 0.2]}
const GAVE_META := "gaf_kleingeld"
const MONEY_COLOUR := Color("#E8B83A")

## The questions you can ask (in this order), and what ends it.
const ASK_MONEY := "Heeft u misschien wat kleingeld voor me?"
const ASK_BLAMMAGE := "Weet u waar Jan Blammage zit?"
const ASK_BYE := "Laat maar. Fijne dag nog."
const AGAIN := ["Nog iets?", "Was er nog wat?", "Verder nog iets?"]

var persona := "forens"
var person: Node3D
var player: Node
var hud: Node
var _asked := {}
var _random := RandomNumberGenerator.new()


func _init(talking_to: Node3D, the_player: Node, the_hud: Node) -> void:
	person = talking_to
	player = the_player
	hud = the_hud
	persona = persona_of(talking_to)
	_random.randomize()


## Who `someone` (a Pedestrian) is to talk to: the key of PERSONAS.
static func persona_of(someone: Node) -> String:
	if someone == null:
		return "forens"
	var mobility := str(someone.get("mobility")) if someone.get("mobility") != null else ""
	if mobility == "rolstoel" or mobility == "scootmobiel":
		return mobility
	var figure: Node = someone.get("figure")
	var look: Dictionary = figure.get("look") if figure and figure.get("look") is Dictionary else {}
	match str(look.get("hair_style", "kort")):
		"kaal":
			return "oude_hagenaar"
		"pet":
			return "pet"
		"lang":
			return "dame" if look.get("skirt", false) else "student"
	var coat: Color = look.get("coat", Color.WHITE)
	if coat.is_equal_approx(Color("#22242A")) or coat.is_equal_approx(Color("#6A6E74")):
		return "ambtenaar"
	if coat.is_equal_approx(Color("#C8B48A")):
		return "toerist"
	return "forens"


## The first page: a greeting and what you can say.
func opening() -> Array:
	var lines: Array = PERSONAS[persona].greetings
	return [_page(lines[_random.randi() % lines.size()], "greeting")]


## The conversation is over: the body as it was.
func finish() -> void:
	Emote.stop(person)


func mood_of(line_kind: String) -> String:
	return str((MOODS_OF.get(persona, {}) as Dictionary).get(line_kind, MOODS.get(line_kind, "neutraal")))


func _voice() -> String:
	return str(person.call("voice")) if person and person.has_method("voice") else "man"


## Their mood shown and heard on a page (babble, Emote).
func _with_mood(page: Dictionary, line_kind: String) -> Dictionary:
	var mood := mood_of(line_kind)
	page["voice"] = _voice()
	page["mood"] = mood
	var look: Variant = person.get("figure").get("look") if person and person.get("figure") else null
	if look is Dictionary:
		page["portrait_look"] = look
	var figure: Node3D = person.get("figure") if person else null
	page["on_show"] = func() -> void: Emote.start(person, figure, mood)
	return page


## The page of the person saying `text` (a line of `line_kind`, MOODS), with the questions
## not asked yet.
func _page(text: String, line_kind: String, follow_up := []) -> Dictionary:
	var data: Dictionary = PERSONAS[persona]
	var options: Array = []
	if not follow_up.is_empty():
		options.append(["follow_up", follow_up[0]])
	if not _asked.has("topic"):
		options.append(["topic", data.topic[0]])
	if not _asked.has("money"):
		options.append(["money", ASK_MONEY])
	if not _asked.has("blammage"):
		options.append(["blammage", ASK_BLAMMAGE])
	options.append(["bye", ASK_BYE])
	var texts: Array = options.map(func(option: Array) -> String: return option[1])
	return _with_mood({"kind": "gesprek", "speaker": data.speaker, "text": text, "choices": texts,
		"on_choice": func(index: int) -> Array: return _answer(options[index], follow_up)}, line_kind)


func _answer(option: Array, follow_up: Array) -> Array:
	var data: Dictionary = PERSONAS[persona]
	var again: String = AGAIN[_random.randi() % AGAIN.size()]
	match str(option[0]):
		"topic":
			_asked["topic"] = true
			return [_page(data.topic[1], "topic", data.topic[2])]
		"follow_up":
			return [_page(str(follow_up[1]) + " " + again, "follow_up")]
		"money":
			_asked["money"] = true
			var gave := _ask_for_money()
			return [_page(str(data.money_yes if gave else data.money_no) + " " + again, "money_yes" if gave else "money_no")]
		"blammage":
			_asked["blammage"] = true
			return [_page(str(data.blammage) + " " + again, "blammage")]
	# goodbye: their last word, then the box closes
	return [_with_mood({"kind": "gesprek", "speaker": data.speaker, "text": data.bye}, "bye")]


## Asked for change: once per person maybe some (GENEROSITY), counted as found money; true
## if they gave.
func _ask_for_money() -> bool:
	var generosity: Array = GENEROSITY[persona]
	if person.has_meta(GAVE_META) or _random.randi_range(1, 100) > int(generosity[0]):
		person.set_meta(GAVE_META, true)
		return false
	person.set_meta(GAVE_META, true)
	var euros: float = generosity[1]
	if player and player.has_method("add_money"):
		player.add_money(euros)
	if hud and hud.has_method("show_floating_number"):
		hud.show_floating_number(person.global_position + Vector3.UP * 2.0, "+€ " + ("%.2f" % euros).replace(".", ","), MONEY_COLOUR)
	return true
