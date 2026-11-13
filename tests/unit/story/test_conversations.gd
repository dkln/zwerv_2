extends RefCounted
## Unit tests of Conversations (scripts/story/conversations.gd): who you talk to (from how
## they look) and the mood of each kind of line.

const Conversations = preload("res://scripts/story/conversations.gd")
const Items = preload("res://scripts/player/items.gd")


## A stand-in for a passer-by: its mobility and the look of its figure.
class Someone:
	extends Node3D
	var mobility := ""
	var figure: Node3D


func _someone(mobility: String, look: Dictionary) -> Someone:
	var person := Someone.new()
	person.mobility = mobility
	person.figure = FigureWithLook.new(look)
	return person


## A stand-in for its figure (TownsfolkFigure): only its look.
class FigureWithLook:
	extends Node3D
	var look := {}

	func _init(with_look: Dictionary) -> void:
		look = with_look


## The persona you talk to follows from how someone looks: a wheelchair, the hair, a
## skirt, the colour of the coat.
func test_persona_from_the_look(test) -> void:
	var cases := [
		["rolstoel", {}, "rolstoel"],
		["", {"hair_style": "kaal"}, "oude_hagenaar"],
		["", {"hair_style": "pet"}, "pet"],
		["", {"hair_style": "lang", "skirt": true}, "dame"],
		["", {"hair_style": "lang", "skirt": false}, "student"],
		["", {"hair_style": "kort", "coat": Color("#22242A")}, "ambtenaar"],
		["", {"hair_style": "kort", "coat": Color("#C8B48A")}, "toerist"],
		["", {"hair_style": "kort", "coat": Color("#8A2A2A")}, "forens"],
	]
	for case: Array in cases:
		var person := _someone(case[0], case[1])
		var persona := Conversations.persona_of(person)
		test.check(persona == case[2], "%s %s: %s (verwacht %s)" % [case[0], case[1], persona, case[2]])
		person.figure.free()
		person.free()


## Every kind of person in the data has a persona with all its lines, and a topic of its
## own with a question and answer (and the answer to a follow-up, if any).
func test_every_persona_has_everything(test) -> void:
	var personas := Conversations.personas()
	test.check(personas.size() >= 9, "alle soorten mensen uit de data (%d)" % personas.size())
	for persona: String in personas:
		var data: Dictionary = personas[persona]
		for key in ["spreker", "begroetingen", "onderwerp", "kleingeld_ja", "kleingeld_nee", "dag", "gulheid"]:
			test.check(data.has(key), "%s heeft %s" % [persona, key])
		# its own topic: a question and the answer, and with a follow-up question its answer too
		var topic: Dictionary = data.get("onderwerp", {})
		test.check(str(topic.get("vraag", "")) != "" and str(topic.get("antwoord", "")) != "",
				"%s: een onderwerp met vraag en antwoord" % persona)
		if topic.has("doorvraag"):
			test.check(str(topic.get("doorantwoord", "")) != "", "%s: de doorvraag heeft een antwoord" % persona)


## The snack bar's counter has a menu to sell from, with a kroket on it.
func test_the_counter_has_a_menu(test) -> void:
	var menu: Array = Conversations.counter().get("menu", [])
	test.check(menu.size() >= 3, "de snackbar verkoopt iets (%d)" % menu.size())
	test.check(menu.any(func(entry: Dictionary) -> bool: return entry.get("item") == "kroket"), "een kroket")
	for entry: Dictionary in menu:
		test.check(Items.ITEMS.has(str(entry.get("item", ""))), "%s is een item" % entry.get("item"))


## Without a person to read the look from, the persona is the commuter.
func test_nobody_is_a_commuter(test) -> void:
	test.check(Conversations.persona_of(null) == "forens", "zonder persoon: de forens")


## Each kind of line has its mood: the persona's own where it sets one, the default
## otherwise, also for the answer to a follow-up question.
func test_moods_of_a_persona(test) -> void:
	var talk := Conversations.new(null, null, null)
	talk.persona = "oude_hagenaar"
	test.check(talk.mood_of("begroeting") == "boos", "de oude Hagenaar groet boos")
	test.check(talk.mood_of("kleingeld_ja") == "blij", "geven is blij (de standaard)")
	test.check(talk.mood_of("onderwerp") == "verdrietig", "zijn eigen onderwerp: verdrietig (eigen stemming)")
	# (a conversation keeps the lines of who it began with: another one for the next person)
	talk = Conversations.new(null, null, null)
	talk.persona = "forens"
	test.check(talk.mood_of("onderwerp") == "neutraal", "de forens over zijn onderwerp: neutraal (de standaard)")
	test.check(talk.mood_of("doorvraag") == "verdrietig", "en op de doorvraag (zijn tram gaat): verdrietig")
