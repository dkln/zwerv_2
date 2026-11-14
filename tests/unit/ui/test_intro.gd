extends RefCounted
## Unit tests of the intro (scripts/ui/intro.gd) without playing it (played it starts the
## music and loads the menu's 3D map): the moments in their order, which key breaks it off,
## the opening line fading in and out, the logo shrinking and flying off, the story rolling
## between its cues and fading at the end, the twinkle, and what drifts by.
##   tests/run_unit_tests.sh intro

const IntroScript = preload("res://scripts/ui/intro.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")


static func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func test_the_moments_are_in_order(test) -> void:
	test.check(IntroScript.LINE_IN_AT < IntroScript.LINE_OUT_AT and IntroScript.LINE_OUT_AT + IntroScript.LINE_FADE <= IntroScript.LOGO_FADE_IN_AT,
		"de openingszin is weg voordat het logo opkomt")
	test.check(IntroScript.LOGO_FADE_IN_AT < IntroScript.LOGO_AT and IntroScript.LOGO_AT < IntroScript.CRAWL_AT, "het logo, dan het verhaal")
	test.check(IntroScript.CRAWL_AT < IntroScript.REST_AT and IntroScript.REST_AT < IntroScript.END_AT, "het verhaal komt tot rust voor het eind")
	test.check(is_equal_approx(IntroScript.LOGO_HOLD, IntroScript.CRAWL_AT - IntroScript.LOGO_AT), "het logo staat tot het verhaal begint")
	var cue_paragraphs: Array = IntroScript.CRAWL_CUES.keys()
	cue_paragraphs.sort()
	var earlier: float = IntroScript.CRAWL_AT
	for paragraph_index: int in cue_paragraphs:
		var cue: float = IntroScript.CRAWL_CUES[paragraph_index]
		test.check(paragraph_index > 0 and paragraph_index < IntroScript.STORY.size(), "alinea %d van het verhaal bestaat" % paragraph_index)
		test.check(cue > earlier and cue < IntroScript.REST_AT, "alinea %d komt na de vorige en voor de rust (%.1f s)" % [paragraph_index, cue])
		earlier = cue
	for paragraph: String in IntroScript.STORY:
		test.check(paragraph.strip_edges() != "", "geen lege alinea")


func test_only_space_and_enter_break_it_off(test) -> void:
	test.check(IntroScript.is_skip_key(_key(KEY_SPACE)) and IntroScript.is_skip_key(_key(KEY_ENTER)) and IntroScript.is_skip_key(_key(KEY_KP_ENTER)), "Spatie en Enter slaan over")
	test.check(not IntroScript.is_skip_key(_key(KEY_ESCAPE)) and not IntroScript.is_skip_key(_key(KEY_VOLUMEUP)) and not IntroScript.is_skip_key(_key(KEY_DOWN)),
		"andere toetsen (ook de volumetoetsen) niet")
	var released := _key(KEY_SPACE)
	released.pressed = false
	var echo := _key(KEY_SPACE)
	echo.echo = true
	test.check(not IntroScript.is_skip_key(released) and not IntroScript.is_skip_key(echo), "loslaten of ingehouden houden ook niet")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	test.check(not IntroScript.is_skip_key(click), "de muis niet")
	test.check(KEY_ENTER in IntroScript.FAST_KEYS and KEY_DOWN in IntroScript.FAST_KEYS and not KEY_SPACE in IntroScript.FAST_KEYS, "sneller rollen: Enter of pijl omlaag, niet Spatie")


func test_the_opening_line_fades_in_and_out(test) -> void:
	test.check(IntroScript.line_alpha(0.0) == 0.0 and IntroScript.line_alpha(IntroScript.LINE_IN_AT) == 0.0, "eerst zwart")
	test.check(is_equal_approx(IntroScript.line_alpha(IntroScript.LINE_IN_AT + IntroScript.LINE_FADE * 0.5), 0.5), "halverwege het opkomen: half")
	test.check(IntroScript.line_alpha(IntroScript.LINE_IN_AT + IntroScript.LINE_FADE) == 1.0 and IntroScript.line_alpha(IntroScript.LINE_OUT_AT) == 1.0, "dan staat hij er")
	test.check(is_equal_approx(IntroScript.line_alpha(IntroScript.LINE_OUT_AT + IntroScript.LINE_FADE * 0.25), 0.75), "hij gaat weer weg")
	test.check(IntroScript.line_alpha(IntroScript.LINE_OUT_AT + IntroScript.LINE_FADE) < 0.0001 and IntroScript.line_alpha(IntroScript.END_AT) == 0.0, "en blijft weg")


func test_the_logo_settles_then_flies_off(test) -> void:
	test.check(is_equal_approx(IntroScript.logo_scale(IntroScript.LOGO_FADE_IN_AT), IntroScript.LOGO_HUGE_SCALE), "het komt enorm op")
	var at_entry := IntroScript.logo_scale(IntroScript.LOGO_AT)
	test.check(at_entry < IntroScript.LOGO_HUGE_SCALE and at_entry > IntroScript.LOGO_START_SCALE, "en krimpt langzaam (%.2f)" % at_entry)
	var leaves_at: float = IntroScript.LOGO_AT + IntroScript.LOGO_HOLD
	test.check(is_equal_approx(IntroScript.logo_scale(leaves_at), IntroScript.LOGO_START_SCALE), "tot zijn gewone maat als het gaat")
	test.check(IntroScript.logo_going(IntroScript.LOGO_AT) == 0.0 and IntroScript.logo_going(leaves_at) == 0.0, "tot dan staat het")
	test.check(is_equal_approx(IntroScript.logo_going(leaves_at + IntroScript.LOGO_SECONDS * 0.5), 0.5), "halverwege het weggaan: half")
	var early := IntroScript.logo_scale(leaves_at + IntroScript.LOGO_SECONDS * 0.1)
	var late := IntroScript.logo_scale(leaves_at + IntroScript.LOGO_SECONDS * 0.9)
	test.check(early < IntroScript.LOGO_START_SCALE and late < early, "het wordt steeds kleiner (%.3f, %.3f)" % [early, late])
	test.check(is_equal_approx(IntroScript.logo_scale(leaves_at + IntroScript.LOGO_SECONDS), IntroScript.LOGO_END_SCALE)
		and IntroScript.logo_going(IntroScript.END_AT) == 1.0, "tot een stipje in de verte")
	var previous := IntroScript.logo_scale(IntroScript.LOGO_FADE_IN_AT)
	var shrinking := true
	for step in range(1, 200):
		var size := IntroScript.logo_scale(lerpf(IntroScript.LOGO_FADE_IN_AT, leaves_at + IntroScript.LOGO_SECONDS, step / 200.0))
		shrinking = shrinking and size <= previous + 0.00001
		previous = size
	test.check(shrinking, "nergens wordt het weer groter")
	test.check(IntroScript.SPARKLE_AT > leaves_at and IntroScript.SPARKLE_AT < leaves_at + IntroScript.LOGO_SECONDS, "de ster twinkelt waar het verdwijnt")


func test_the_story_fades_out_at_the_end(test) -> void:
	test.check(IntroScript.crawl_alpha(IntroScript.CRAWL_AT) == 1.0 and IntroScript.crawl_alpha(IntroScript.REST_AT) == 1.0, "tot de rust helemaal te zien")
	test.check(is_equal_approx(IntroScript.crawl_alpha((IntroScript.REST_AT + IntroScript.END_AT) * 0.5), 0.5), "halverwege het uitklinken: half")
	test.check(IntroScript.crawl_alpha(IntroScript.END_AT) == 0.0 and IntroScript.crawl_alpha(IntroScript.END_AT + 5.0) == 0.0, "aan het eind weg")


func test_the_twinkle_flares_up_and_dies_out(test) -> void:
	test.check(IntroScript.sparkle_flare(0.0) == 0.0, "het begint uit het niets")
	test.check(is_equal_approx(IntroScript.sparkle_flare(IntroScript.SPARKLE_FLARE), 1.0), "op zijn felst na het opvlammen")
	test.check(is_equal_approx(IntroScript.sparkle_flare(IntroScript.SPARKLE_FLARE * 0.5), 0.5), "halverwege het opvlammen: half")
	test.check(is_equal_approx(IntroScript.sparkle_flare((1.0 + IntroScript.SPARKLE_FLARE) * 0.5), 0.5), "halverwege het doven: half")
	test.check(absf(IntroScript.sparkle_flare(0.9999)) < 0.001, "aan het eind gedoofd")


func test_value_between_the_stops(test) -> void:
	var stops := [[10.0, 100.0], [20.0, 0.0], [40.0, -50.0]]
	test.check(IntroScript.value_between(stops, 0.0) == 100.0 and IntroScript.value_between(stops, 10.0) == 100.0, "voor de eerste: de eerste waarde")
	test.check(is_equal_approx(IntroScript.value_between(stops, 15.0), 50.0), "halverwege twee stops: het midden")
	test.check(IntroScript.value_between(stops, 20.0) == 0.0, "op een stop: zijn waarde")
	test.check(is_equal_approx(IntroScript.value_between(stops, 25.0), -12.5), "elk stuk gaat in zijn eigen tempo")
	test.check(IntroScript.value_between(stops, 40.0) == -50.0 and IntroScript.value_between(stops, 99.0) == -50.0, "na de laatste: daar blijft het")
	test.check(IntroScript.value_between([[5.0, 7.0]], 0.0) == 7.0, "één stop: altijd die waarde")


func test_what_drifts_by_is_never_twice_the_same(test) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 1992
	var last := ""
	var characters := 0
	var tractors := 0
	var repeated := false
	var unknown := false
	for flight in 400:
		var picked := IntroScript.pick_drifter(random, last)
		repeated = repeated or picked == last
		if picked in PlayerCharacter.ORDER:
			characters += 1
		elif picked in IntroScript.TRACTOR_MODELS:
			tractors += 1
		else:
			unknown = true
		last = picked
	test.check(not repeated, "nooit twee keer achter elkaar dezelfde")
	test.check(not unknown and characters > 0 and tractors > 0, "zwervers en trekkers (%d, %d)" % [characters, tractors])
	test.check(characters > tractors, "vaker een zwerver dan een trekker")
	var again := RandomNumberGenerator.new()
	again.seed = 7
	var same := RandomNumberGenerator.new()
	same.seed = 7
	test.check(IntroScript.pick_drifter(again, "jos") == IntroScript.pick_drifter(same, "jos"), "met hetzelfde toeval dezelfde keuze")


func test_font_with_a_weight(test) -> void:
	var font := IntroScript._font(IntroScript.UiStyle.FONT_TITLE, 700)
	test.check(font != null and font is Font, "een lettertype op gewicht")
