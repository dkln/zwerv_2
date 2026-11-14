extends RefCounted
## Unit tests of the intro (scripts/ui/intro.gd, the behaviour) without playing it (in the
## tree it starts the music and loads the menu's 3D map): built on its own, it is set to a
## moment of the music and the picture shows what belongs there; its own clock runs
## without music; on its way to the menu nothing starts again.
##   tests/run_unit_tests.sh test_intro.gd

const IntroScript = preload("res://scripts/ui/intro.gd")
const IntroRules = preload("res://scripts/ui/intro/intro_rules.gd")
const IntroLayout = preload("res://scripts/ui/intro/intro_layout.gd")


## The intro built but not in the tree (no music, nothing loading).
static func _intro() -> IntroScript:
	var intro := IntroScript.new()
	intro._build()
	return intro


func test_it_builds_its_picture_and_texts(test) -> void:
	var intro := _intro()
	test.check(intro.view() != null and intro.view().get_parent() == intro, "het beeld als kind")
	test.check(intro.view().line().text == IntroRules.OPENING_LINE and intro.view().story_text().get_child_count() == IntroRules.STORY.size(), "de openingszin en het verhaal")
	test.check(intro.view().stars().get_child_count() == IntroLayout.STAR_COUNT, "de sterren")
	test.check(intro.view().prompts().actions() == [IntroRules.SKIP_ACTION], "de contextactie: overslaan")
	test.check(intro.drifter() != null and intro.drifter().get_parent() == intro.view().design(), "wat er zweeft staat in het beeld")
	test.check(is_equal_approx(intro.drifter().first_at, IntroRules.LOGO_FADE_IN_AT + IntroScript.DrifterRules.FIRST) and intro.drifter().last_at < IntroRules.END_AT,
		"en zweeft pas na de sterren, niet meer vlak voor het eind")
	intro.free()


func test_play_sets_the_picture_to_a_moment(test) -> void:
	var intro := _intro()
	var view := intro.view()
	intro.play(IntroRules.LINE_IN_AT + IntroRules.LINE_FADE)
	test.check(view.line().modulate.a == 1.0 and not view.stars_visible() and not view.logo().visible and not view.story_screen().visible, "eerst alleen de openingszin")
	intro.play(IntroRules.LOGO_AT)
	test.check(view.line().modulate.a == 0.0 and view.stars_visible() and view.logo().visible and view.logo().modulate.a == 1.0, "dan de sterren en het logo")
	test.check(is_equal_approx(view.logo().scale.x, IntroRules.logo_scale(IntroRules.LOGO_AT)) and not view.fast_footer().visible, "het logo op de maat van dat moment")
	intro.play(IntroRules.CRAWL_AT + 1.0)
	test.check(view.story_screen().visible and view.fast_footer().visible, "het verhaal rolt, sneller wordt aangeboden")
	intro.play(IntroRules.SPARKLE_AT + IntroRules.SPARKLE_SECONDS * 0.5)
	test.check(view.sparkle().visible, "waar het logo verdwijnt twinkelt een ster")
	intro.play(IntroRules.REST_AT)
	test.check(not view.logo().visible and not view.sparkle().visible and view.story_screen().visible and not intro.is_leaving(), "aan het eind alleen nog het verhaal")
	test.check(view.story_text().position.y < IntroLayout.CRAWL_PICTURE.y, "de tekst is omhoog gerold")
	intro.free()


func test_its_own_clock_without_music(test) -> void:
	var intro := _intro()
	test.check(intro.music_time() == 0.0, "zonder muziek: de eigen klok, op nul")
	intro._process(IntroRules.LINE_IN_AT + IntroRules.LINE_FADE)
	test.check(is_equal_approx(intro.music_time(), IntroRules.LINE_IN_AT + IntroRules.LINE_FADE) and intro.view().line().modulate.a == 1.0, "de klok loopt en het beeld gaat mee")
	test.check(intro.crawl_ahead() == 0.0, "zonder Enter loopt het verhaal niet voor")
	intro._process(IntroRules.LOGO_AT)
	test.check(intro.view().stars_visible() and not intro.drifter().is_flying(), "sterren; er zweeft nog niets")
	intro.free()


func test_on_its_way_to_the_menu_nothing_starts_again(test) -> void:
	var intro := _intro()
	intro.play(IntroRules.LOGO_AT)
	intro._leaving = true
	intro.to_menu()
	test.check(intro.is_leaving(), "al onderweg: nog eens vragen doet niets")
	intro._process(IntroRules.CRAWL_AT)
	test.check(not intro.view().story_screen().visible and intro.view().logo().visible, "het beeld blijft staan zoals het was")
	intro.play(IntroRules.END_AT + 1.0)
	test.check(intro.is_leaving() and not intro.view().story_screen().visible, "het eind van het verhaal: naar het menu (al onderweg)")
	intro.free()
