extends RefCounted
## Unit tests of the speech balloon (scripts/ui/widgets/speech_balloon.gd): how high a line
## stands, what say() sets up, typing, holding and fading (is_talking, `finished`), and
## following someone in the world through a camera.
##   tests/run_unit_tests.sh speech_balloon

const SpeechBalloon = preload("res://scripts/ui/widgets/speech_balloon.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Counts how often a balloon is gone.
class Listener:
	var finishes := 0

	func on_finished() -> void:
		finishes += 1


func _balloon() -> SpeechBalloon:
	var balloon := SpeechBalloon.new()
	tree.root.add_child(balloon)
	return balloon


## Steps every running tween of the tree `seconds` on (a test has no frames of its own).
func _step_tweens(seconds: float) -> void:
	for tween: Tween in tree.get_processed_tweens():
		if tween.is_valid():
			tween.custom_step(seconds)


## Steps the balloon until its line is typed out.
static func _type_out(balloon: SpeechBalloon) -> void:
	for step in 400:
		if balloon._typewriter.is_done():
			return
		balloon._process(0.05)


func test_text_height_counts_the_wrapped_rows(test) -> void:
	var font := UiStyle.font(UiStyle.FONT_PIXEL_BOLD)
	var row := font.get_height(SpeechBalloon.TEXT_SIZE)
	var one_row := SpeechBalloon.text_height("Hoi!", SpeechBalloon.MAX_TEXT_WIDTH)
	test.check(is_equal_approx(one_row, ceilf(row)), "een korte regel: één rij hoog (%s)" % one_row)
	test.check(SpeechBalloon.text_height("", SpeechBalloon.MAX_TEXT_WIDTH) == one_row, "niets: ook één rij")
	var long_line := "Pas op waar je loopt, hier rijden trams en die stoppen niet voor jou!"
	var wrapped := SpeechBalloon.text_height(long_line, SpeechBalloon.MAX_TEXT_WIDTH)
	var rows := roundi((wrapped + SpeechBalloon.LINE_SEPARATION) / (row + SpeechBalloon.LINE_SEPARATION))
	test.check(rows >= 2, "een lange regel loopt over meer rijen (%d)" % rows)
	test.check(is_equal_approx(wrapped, ceilf(rows * row + (rows - 1) * SpeechBalloon.LINE_SEPARATION)), "rijen met de regelafstand ertussen (%s)" % wrapped)
	test.check(SpeechBalloon.text_height(long_line, 120.0) > wrapped, "smaller: meer rijen, hoger")
	test.check(SpeechBalloon.text_height("een\ntwee", SpeechBalloon.MAX_TEXT_WIDTH) > one_row, "een regeleinde telt ook")


func test_say_pops_up_a_balloon_as_big_as_its_line(test) -> void:
	var balloon := _balloon()
	test.check(not balloon.visible and not balloon.is_talking(), "eerst niet te zien")
	test.check(balloon.mouse_filter == Control.MOUSE_FILTER_IGNORE and balloon.process_mode == Node.PROCESS_MODE_ALWAYS, "klikken gaan erdoorheen, het loopt door in een gesprek")
	balloon.say("Hé, zwerver!")
	test.check(balloon.visible and balloon.is_talking(), "het praat")
	test.check(balloon.scale.is_equal_approx(Vector2.ONE * 0.6) and balloon.modulate.a == 1.0, "het springt op vanuit klein")
	var font := UiStyle.font(UiStyle.FONT_PIXEL_BOLD)
	var line_width := font.get_string_size("Hé, zwerver! ", HORIZONTAL_ALIGNMENT_LEFT, -1, SpeechBalloon.TEXT_SIZE).x
	var text := balloon._text
	test.check(is_equal_approx(text.custom_minimum_size.x, ceilf(line_width) + 2.0), "zo breed als de hele regel (%s)" % text.custom_minimum_size.x)
	test.check(is_equal_approx(text.custom_minimum_size.y, SpeechBalloon.text_height("Hé, zwerver!", text.custom_minimum_size.x)), "en zo hoog")
	var panel := balloon._panel
	test.check(is_equal_approx(panel.position.x, -roundf(panel.size.x * 0.5)), "het paneel midden boven de punt")
	test.check(is_equal_approx(panel.position.y, -panel.size.y - SpeechBalloon.TAIL_HEIGHT + SpeechBalloon.BORDER_WIDTH), "met de staart eronder")
	test.check(panel.size.x >= text.custom_minimum_size.x + 2.0 * SpeechBalloon.PADDING.x, "de tekst met ruimte eromheen")
	test.check((panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color == balloon.accent, "de rand in de kleur van wie het zegt")
	test.check(not balloon._typewriter.sound and not balloon._typewriter.show_cursor, "stil en zonder cursor")
	balloon.free()


func test_a_long_line_wraps_at_the_widest(test) -> void:
	var balloon := _balloon()
	var long_line := "Pas op waar je loopt, hier rijden trams en die stoppen niet voor jou!"
	balloon.say(long_line)
	test.check(balloon._text.custom_minimum_size.x == SpeechBalloon.MAX_TEXT_WIDTH, "niet breder dan MAX_TEXT_WIDTH")
	var whole_height := SpeechBalloon.text_height(long_line, SpeechBalloon.MAX_TEXT_WIDTH)
	test.check(balloon._text.custom_minimum_size.y == whole_height, "meteen zo hoog als de hele regel")
	_type_out(balloon)
# (the label itself counts the line separation under its last row as well)
	var around_text := balloon._panel.size.y - 2.0 * SpeechBalloon.PADDING.y
	test.check(around_text >= whole_height and around_text <= whole_height + SpeechBalloon.LINE_SEPARATION, "uitgetypt: het paneel past om de hele regel (%s om %s)" % [around_text, whole_height])
	test.check(is_equal_approx(balloon._panel.size.x, SpeechBalloon.MAX_TEXT_WIDTH + 2.0 * SpeechBalloon.PADDING.x), "en is niet breder geworden (%s)" % balloon._panel.size.x)
	balloon.free()


func test_the_accent_colours_the_border(test) -> void:
	var balloon := _balloon()
	balloon.accent = UiStyle.SIDE_ACCENT
	balloon.say("Goedemiddag.")
	test.check((balloon._panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color == UiStyle.SIDE_ACCENT, "een andere spreker: een andere rand")
	test.check((balloon._panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == UiStyle.PANEL, "op hetzelfde paneel")
	balloon.free()


func test_it_types_holds_and_fades(test) -> void:
	var balloon := _balloon()
	var listener := Listener.new()
	balloon.finished.connect(listener.on_finished)
	balloon.say("Hé, zwerver! Kom eens hier.", 1.0)
	balloon._process(0.05)
	test.check(not balloon._typewriter.is_done() and balloon.is_talking(), "het typt woord voor woord")
	_type_out(balloon)
	test.check(balloon._typewriter.is_done() and balloon.is_talking(), "uitgetypt: het blijft staan")
	balloon._process(0.6)
	test.check(balloon.is_talking(), "binnen de wachttijd: nog steeds")
	balloon._process(0.6)
	test.check(not balloon.is_talking() and balloon.visible, "daarna vervaagt het")
	_step_tweens(SpeechBalloon.FADE_SECONDS * 0.5)
	test.check(balloon.visible and balloon.modulate.a < 1.0 and listener.finishes == 0, "halverwege het vervagen: nog te zien")
	_step_tweens(SpeechBalloon.FADE_SECONDS)
	test.check(not balloon.visible and listener.finishes == 1, "weg, en dat laat het weten (%d)" % listener.finishes)
	balloon._process(1.0)
	test.check(not balloon.visible and listener.finishes == 1, "verborgen gebeurt er niets meer")
	balloon.free()


func test_a_new_line_replaces_the_one_under_way(test) -> void:
	var balloon := _balloon()
	balloon.say("Dit is de eerste regel die ik zeg.", 0.5)
	balloon._process(0.3)
	balloon.say("Nee.", 2.0)
	test.check(balloon._typewriter.text == "Nee." and not balloon._typewriter.is_done(), "de nieuwe regel begint van voren")
	_type_out(balloon)
	balloon._process(1.0)
	test.check(balloon.is_talking(), "met zijn eigen wachttijd")
	balloon._process(1.1)
	test.check(not balloon.is_talking(), "die daarna om is")
	balloon.free()


func test_follow_keeps_the_tip_over_the_head(test) -> void:
	var balloon := _balloon()
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.0, 6.0)
	tree.root.add_child(camera)
	camera.make_current()
	var speaker := Node3D.new()
	speaker.position = Vector3(1.0, 0.0, 0.0)
	tree.root.add_child(speaker)
	balloon.head_height = 2.0
	balloon.follow(speaker, camera)
	balloon.say("Hoi!")
	var over_head := camera.unproject_position(Vector3(1.0, 2.0, 0.0)).round()
	test.check(balloon.position == over_head, "de punt boven het hoofd (%s bij %s)" % [balloon.position, over_head])
	speaker.position = Vector3(-2.0, 0.0, -3.0)
	balloon._process(0.01)
	test.check(balloon.position == camera.unproject_position(Vector3(-2.0, 2.0, -3.0)).round(), "het loopt mee")
	test.check(balloon.modulate.a == 1.0, "en is te zien")
	speaker.position = Vector3(0.0, 0.0, 20.0)
	var before := balloon.position
	balloon._process(0.01)
	test.check(balloon.modulate.a == 0.0 and balloon.position == before, "achter de camera: niet te zien")
	speaker.free()
	balloon._process(0.01)
	test.check(balloon.position == before, "wie het zei is weg: de ballon gaat nergens meer heen")
	camera.free()
	balloon.free()
