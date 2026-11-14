extends RefCounted
## Unit tests of Typewriter (scripts/ui/widgets/typewriter.gd): word by word, how much has
## appeared, finish() all at once, where the words end (word_ends_of), the rests after a
## sentence and a comma, the cursor and what the label is given.
##   tests/run_unit_tests.sh typewriter

const Typewriter = preload("res://scripts/ui/widgets/typewriter.gd")


## The text appears word by word (nearly empty at first, more after a while) and
## finish() shows all of it at once.
func test_word_by_word_and_finish(test) -> void:
	var label := RichTextLabel.new()
	var owner := Node.new()
	var typewriter := Typewriter.new(label, owner)
	typewriter.sound = false
	typewriter.start("Een kroket kost twee euro.")
	test.check(typewriter.shown_share() < 0.5 and not typewriter.is_done(), "begint bijna leeg")
	test.check(typewriter.words_left() > 0, "woorden te gaan (%d)" % typewriter.words_left())
	typewriter.update(0.25)
	var halfway := typewriter.shown_share()
	test.check(halfway > 0.0, "na even zijn er woorden (%.2f)" % halfway)
	typewriter.finish()
	test.check(typewriter.is_done() and is_equal_approx(typewriter.shown_share(), 1.0) and typewriter.words_left() == 0, "finish: alles in een keer")
	label.free()
	owner.free()


## A silent typewriter on a label of its own (free both).
static func _typewriter(label: RichTextLabel, owner: Node) -> Typewriter:
	var typewriter := Typewriter.new(label, owner)
	typewriter.sound = false
	return typewriter


func test_word_ends_of(test) -> void:
	test.check(Typewriter.word_ends_of("Een kroket") == [3, 10], "het eind van elk woord, in tekens")
	test.check(Typewriter.word_ends_of("") == [] and Typewriter.word_ends_of("   ") == [], "geen woorden: niets")
	test.check(Typewriter.word_ends_of("Hoi") == [3], "één woord")
	test.check(Typewriter.word_ends_of("  Hoi  daar ") == [5, 11], "spaties ervoor, ertussen en erna tellen niet als woord")
	test.check(Typewriter.word_ends_of("een\ntwee\tdrie") == [3, 8, 13], "ook regeleinden en tabs scheiden woorden")
	test.check(Typewriter.word_ends_of("Hé, zwerver!") == [3, 12], "leestekens horen bij hun woord")


func test_shown_share_counts_characters(test) -> void:
	var label := RichTextLabel.new()
	var owner := Node.new()
	var typewriter := _typewriter(label, owner)
	test.check(typewriter.is_done() and typewriter.shown_share() == 1.0 and typewriter.words_left() == 0, "zonder tekst: klaar")
	typewriter.start("")
	test.check(typewriter.is_done() and typewriter.shown_share() == 1.0, "een lege tekst: ook klaar")
	typewriter.start("Een kroket")
	test.check(typewriter.shown_share() == 0.0 and typewriter.words_left() == 2 and typewriter.text == "Een kroket", "net begonnen: nog niets")
	typewriter.update(0.16)
	test.check(typewriter.words_left() == 1 and is_equal_approx(typewriter.shown_share(), 0.3), "na de aanloop het eerste woord: 3 van de 10 tekens (%s)" % typewriter.shown_share())
	typewriter.update(Typewriter.WORD_SECONDS)
	test.check(typewriter.is_done() and typewriter.shown_share() == 1.0, "een woord per WORD_SECONDS")
	typewriter.start("Opnieuw beginnen")
	test.check(not typewriter.is_done() and typewriter.words_left() == 2, "start() begint van voren")
	label.free()
	owner.free()


func test_a_rest_after_a_sentence_and_a_comma(test) -> void:
	var label := RichTextLabel.new()
	var owner := Node.new()
	var typewriter := _typewriter(label, owner)
	typewriter.start("Ja. Nee, toch niet")
	typewriter.update(0.16)
	test.check(typewriter.words_left() == 3, "het eerste woord (met zijn punt)")
	typewriter.update(Typewriter.WORD_SECONDS + Typewriter.SENTENCE_REST - 0.05)
	test.check(typewriter.words_left() == 3, "na een punt een langere rust")
	typewriter.update(0.06)
	test.check(typewriter.words_left() == 2, "dan het volgende woord (met zijn komma)")
	typewriter.update(Typewriter.WORD_SECONDS + Typewriter.COMMA_REST - 0.05)
	test.check(typewriter.words_left() == 2, "na een komma een korte rust")
	typewriter.update(0.06)
	test.check(typewriter.words_left() == 1, "dan verder")
	typewriter.update(Typewriter.WORD_SECONDS)
	test.check(typewriter.is_done(), "zonder leesteken: gewoon een woord per WORD_SECONDS")
	typewriter.start("Een lange zin van heel veel woorden achter elkaar")
	typewriter.update(60.0)
	test.check(typewriter.is_done(), "een lange stap haalt alles in")
	label.free()
	owner.free()


func test_what_the_label_is_given(test) -> void:
	var label := RichTextLabel.new()
	var owner := Node.new()
	var typewriter := _typewriter(label, owner)
	test.check(label.bbcode_enabled, "het label leest opmaak")
	typewriter.start("Kijk [hier] nou")
	typewriter.update(0.16)
	test.check(label.text.begins_with("Kijk" + Typewriter.CURSOR_GAP), "wat er staat, dan de cursor een eindje erachter")
	test.check(label.text.contains("[bgcolor=#%s]" % typewriter.cursor_colour.to_html(false)), "de cursor als blokje in zijn kleur")
	test.check(label.text.contains("[color=#00000000] [lb]hier] nou[/color]"), "de rest staat er al doorzichtig, haken als tekst (%s)" % label.text)
	typewriter.finish()
	test.check(label.text.begins_with("Kijk [lb]hier] nou") and not label.text.contains("[color=#00000000] "), "af: de hele tekst, niets doorzichtigs meer erachter")
	test.check(label.text.contains("[bgcolor="), "de cursor knippert aan het eind (eerst aan)")
	typewriter.update(Typewriter.BLINK_SECONDS * 0.7)
	test.check(not label.text.contains("[bgcolor="), "en uit")
	typewriter.blink_when_done = false
	typewriter.start("Hoi")
	typewriter.finish()
	test.check(not label.text.contains("[bgcolor="), "zonder knipperen: aan het eind geen cursor")
	typewriter.show_cursor = false
	typewriter.start("Hoi daar")
	typewriter.update(0.16)
	test.check(label.text == "Hoi[color=#00000000] daar[/color]", "zonder cursor: alleen de tekst (%s)" % label.text)
	label.free()
	owner.free()
