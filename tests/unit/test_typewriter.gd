extends RefCounted
## Unit tests of Typewriter (scripts/ui/widgets/typewriter.gd): word by word, how much has
## appeared, finish() all at once.

const Typewriter = preload("res://scripts/ui/widgets/typewriter.gd")


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
