extends RefCounted
## Unit tests of Conversations (scripts/story/conversations.gd): who you talk to (from how
## they look) and the mood of each kind of line.

const Conversations = preload("res://scripts/story/conversations.gd")


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


func test_every_persona_has_everything(test) -> void:
	for persona: String in Conversations.PERSONAS:
		var data: Dictionary = Conversations.PERSONAS[persona]
		for key in ["speaker", "greetings", "topic", "money_yes", "money_no", "blammage", "bye"]:
			test.check(data.has(key), "%s heeft %s" % [persona, key])
		test.check(Conversations.GENEROSITY.has(persona), "%s heeft een gulheid" % persona)


func test_nobody_is_a_commuter(test) -> void:
	test.check(Conversations.persona_of(null) == "forens", "zonder persoon: de forens")


func test_moods_of_a_persona(test) -> void:
	var talk := Conversations.new(null, null, null)
	talk.persona = "oude_hagenaar"
	test.check(talk.mood_of("greeting") == "boos", "de oude Hagenaar groet boos")
	test.check(talk.mood_of("money_yes") == "blij", "geven is blij (de standaard)")
	talk.persona = "forens"
	test.check(talk.mood_of("blammage") == "opgewonden", "over de snackbar: opgewonden")
