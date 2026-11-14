extends RefCounted
## Unit tests of the logic the story box and the shop share (scripts/ui/screens/dialogue_rules.gd):
## the babble of a line that types out and the blinking arrows of a list that scrolls.
##   tests/run_unit_tests.sh dialogue_rules

const DialogueRules = preload("res://scripts/ui/screens/dialogue_rules.gd")


func test_is_question(test) -> void:
	test.check(DialogueRules.is_question("Weet jij de weg?"), "een vraagteken aan het eind: een vraag")
	test.check(DialogueRules.is_question("Echt?  \n"), "ook met wit erachter")
	test.check(not DialogueRules.is_question("Wat? Nee."), "een vraagteken middenin: geen vraag")
	test.check(not DialogueRules.is_question("") and not DialogueRules.is_question("Hoi."), "leeg of een gewone zin: geen vraag")


func test_typing_mood(test) -> void:
	test.check(DialogueRules.typing_mood(false, 0, "boos") == "boos", "geen vraag: de stemming van de regel")
	test.check(DialogueRules.typing_mood(true, 5, "boos") == "boos", "het begin van een vraag: nog gewoon")
	test.check(DialogueRules.typing_mood(true, 3, "boos") == "boos", "drie woorden te gaan: nog gewoon")
	test.check(DialogueRules.typing_mood(true, 2, "boos") == DialogueRules.QUESTION_MOOD, "de laatste twee woorden: omhoog")
	test.check(DialogueRules.typing_mood(true, 0, "boos") == DialogueRules.QUESTION_MOOD, "het laatste woord: omhoog")
	test.check(DialogueRules.DEFAULT_MOOD == "neutraal" and DialogueRules.QUESTION_MOOD == "vraag", "de stemmingen zoals het gebabbel ze kent")


func test_asks_after_typing(test) -> void:
	test.check(DialogueRules.asks_after_typing(true, false), "een vraag die nog niet omhoog ging: alsnog")
	test.check(not DialogueRules.asks_after_typing(true, true), "al omhoog gegaan: niet nog eens")
	test.check(not DialogueRules.asks_after_typing(false, false), "geen vraag: niets")


func test_blink_on(test) -> void:
	test.check(DialogueRules.blink_on(0.0) and DialogueRules.blink_on(0.49), "het begin van een tel: aan")
	test.check(not DialogueRules.blink_on(0.5) and not DialogueRules.blink_on(0.79), "het eind van een tel: uit")
	test.check(DialogueRules.blink_on(0.81) and not DialogueRules.blink_on(1.4), "en zo door")


func test_scroll_room_and_arrows(test) -> void:
	test.check(DialogueRules.scroll_room(300.0, 200.0) == 100.0 and DialogueRules.scroll_room(150.0, 200.0) == -50.0, "wat er te scrollen is; negatief als het past")
	test.check(not DialogueRules.more_below(-50.0, 0.0, true) and not DialogueRules.more_above(-50.0, 0.0, true), "het past: geen pijlen")
	test.check(not DialogueRules.more_below(1.0, 0.0, true), "een pixel te hoog: nog geen pijl")
	test.check(DialogueRules.more_below(100.0, 0.0, true) and not DialogueRules.more_above(100.0, 0.0, true), "bovenaan: alleen omlaag")
	test.check(DialogueRules.more_below(100.0, 50.0, true) and DialogueRules.more_above(100.0, 50.0, true), "middenin: allebei")
	test.check(not DialogueRules.more_below(100.0, 100.0, true) and DialogueRules.more_above(100.0, 100.0, true), "onderaan: alleen omhoog")
	test.check(not DialogueRules.more_below(100.0, 99.5, true) and not DialogueRules.more_above(100.0, 0.5, true), "een halve pixel van het eind: geen pijl")
	test.check(not DialogueRules.more_below(100.0, 50.0, false) and not DialogueRules.more_above(100.0, 50.0, false), "de knipper uit: geen pijlen")
