extends RefCounted
## Unit tests of the logic of the intro (scripts/ui/intro/intro_rules.gd): the moments in
## their order, which key breaks it off, the opening line fading in and out, the logo
## shrinking and flying off, the story rolling between its cues and fading at the end, the
## twinkle and the stars.
##   tests/run_unit_tests.sh intro_rules

const IntroRules = preload("res://scripts/ui/intro/intro_rules.gd")


static func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func test_the_moments_are_in_order(test) -> void:
	test.check(IntroRules.LINE_IN_AT < IntroRules.LINE_OUT_AT and IntroRules.LINE_OUT_AT + IntroRules.LINE_FADE <= IntroRules.LOGO_FADE_IN_AT,
		"de openingszin is weg voordat het logo opkomt")
	test.check(IntroRules.LOGO_FADE_IN_AT < IntroRules.LOGO_AT and IntroRules.LOGO_AT < IntroRules.CRAWL_AT, "het logo, dan het verhaal")
	test.check(IntroRules.CRAWL_AT < IntroRules.REST_AT and IntroRules.REST_AT < IntroRules.END_AT, "het verhaal komt tot rust voor het eind")
	test.check(is_equal_approx(IntroRules.LOGO_HOLD, IntroRules.CRAWL_AT - IntroRules.LOGO_AT), "het logo staat tot het verhaal begint")
	var cue_paragraphs: Array = IntroRules.CRAWL_CUES.keys()
	cue_paragraphs.sort()
	var earlier: float = IntroRules.CRAWL_AT
	for paragraph_index: int in cue_paragraphs:
		var cue: float = IntroRules.CRAWL_CUES[paragraph_index]
		test.check(paragraph_index > 0 and paragraph_index < IntroRules.STORY.size(), "alinea %d van het verhaal bestaat" % paragraph_index)
		test.check(cue > earlier and cue < IntroRules.REST_AT, "alinea %d komt na de vorige en voor de rust (%.1f s)" % [paragraph_index, cue])
		earlier = cue
	for paragraph: String in IntroRules.STORY:
		test.check(paragraph.strip_edges() != "", "geen lege alinea")


func test_only_space_and_enter_break_it_off(test) -> void:
	test.check(IntroRules.is_skip_key(_key(KEY_SPACE)) and IntroRules.is_skip_key(_key(KEY_ENTER)) and IntroRules.is_skip_key(_key(KEY_KP_ENTER)), "Spatie en Enter slaan over")
	test.check(not IntroRules.is_skip_key(_key(KEY_ESCAPE)) and not IntroRules.is_skip_key(_key(KEY_VOLUMEUP)) and not IntroRules.is_skip_key(_key(KEY_DOWN)),
		"andere toetsen (ook de volumetoetsen) niet")
	var released := _key(KEY_SPACE)
	released.pressed = false
	var echo := _key(KEY_SPACE)
	echo.echo = true
	test.check(not IntroRules.is_skip_key(released) and not IntroRules.is_skip_key(echo), "loslaten of ingehouden houden ook niet")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	test.check(not IntroRules.is_skip_key(click), "de muis niet")
	test.check(KEY_ENTER in IntroRules.FAST_KEYS and KEY_DOWN in IntroRules.FAST_KEYS and not KEY_SPACE in IntroRules.FAST_KEYS, "sneller rollen: Enter of pijl omlaag, niet Spatie")


func test_the_opening_line_fades_in_and_out(test) -> void:
	test.check(IntroRules.line_alpha(0.0) == 0.0 and IntroRules.line_alpha(IntroRules.LINE_IN_AT) == 0.0, "eerst zwart")
	test.check(is_equal_approx(IntroRules.line_alpha(IntroRules.LINE_IN_AT + IntroRules.LINE_FADE * 0.5), 0.5), "halverwege het opkomen: half")
	test.check(IntroRules.line_alpha(IntroRules.LINE_IN_AT + IntroRules.LINE_FADE) == 1.0 and IntroRules.line_alpha(IntroRules.LINE_OUT_AT) == 1.0, "dan staat hij er")
	test.check(is_equal_approx(IntroRules.line_alpha(IntroRules.LINE_OUT_AT + IntroRules.LINE_FADE * 0.25), 0.75), "hij gaat weer weg")
	test.check(IntroRules.line_alpha(IntroRules.LINE_OUT_AT + IntroRules.LINE_FADE) < 0.0001 and IntroRules.line_alpha(IntroRules.END_AT) == 0.0, "en blijft weg")


func test_the_logo_settles_then_flies_off(test) -> void:
	test.check(is_equal_approx(IntroRules.logo_scale(IntroRules.LOGO_FADE_IN_AT), IntroRules.LOGO_HUGE_SCALE), "het komt enorm op")
	var at_entry := IntroRules.logo_scale(IntroRules.LOGO_AT)
	test.check(at_entry < IntroRules.LOGO_HUGE_SCALE and at_entry > IntroRules.LOGO_START_SCALE, "en krimpt langzaam (%.2f)" % at_entry)
	var leaves_at: float = IntroRules.LOGO_AT + IntroRules.LOGO_HOLD
	test.check(is_equal_approx(IntroRules.logo_scale(leaves_at), IntroRules.LOGO_START_SCALE), "tot zijn gewone maat als het gaat")
	test.check(IntroRules.logo_going(IntroRules.LOGO_AT) == 0.0 and IntroRules.logo_going(leaves_at) == 0.0, "tot dan staat het")
	test.check(is_equal_approx(IntroRules.logo_going(leaves_at + IntroRules.LOGO_SECONDS * 0.5), 0.5), "halverwege het weggaan: half")
	var early := IntroRules.logo_scale(leaves_at + IntroRules.LOGO_SECONDS * 0.1)
	var late := IntroRules.logo_scale(leaves_at + IntroRules.LOGO_SECONDS * 0.9)
	test.check(early < IntroRules.LOGO_START_SCALE and late < early, "het wordt steeds kleiner (%.3f, %.3f)" % [early, late])
	test.check(is_equal_approx(IntroRules.logo_scale(leaves_at + IntroRules.LOGO_SECONDS), IntroRules.LOGO_END_SCALE)
		and IntroRules.logo_going(IntroRules.END_AT) == 1.0, "tot een stipje in de verte")
	var previous := IntroRules.logo_scale(IntroRules.LOGO_FADE_IN_AT)
	var shrinking := true
	for step in range(1, 200):
		var size := IntroRules.logo_scale(lerpf(IntroRules.LOGO_FADE_IN_AT, leaves_at + IntroRules.LOGO_SECONDS, step / 200.0))
		shrinking = shrinking and size <= previous + 0.00001
		previous = size
	test.check(shrinking, "nergens wordt het weer groter")
	test.check(IntroRules.SPARKLE_AT > leaves_at and IntroRules.SPARKLE_AT < leaves_at + IntroRules.LOGO_SECONDS, "de ster twinkelt waar het verdwijnt")


func test_the_story_fades_out_at_the_end(test) -> void:
	test.check(IntroRules.crawl_alpha(IntroRules.CRAWL_AT) == 1.0 and IntroRules.crawl_alpha(IntroRules.REST_AT) == 1.0, "tot de rust helemaal te zien")
	test.check(is_equal_approx(IntroRules.crawl_alpha((IntroRules.REST_AT + IntroRules.END_AT) * 0.5), 0.5), "halverwege het uitklinken: half")
	test.check(IntroRules.crawl_alpha(IntroRules.END_AT) == 0.0 and IntroRules.crawl_alpha(IntroRules.END_AT + 5.0) == 0.0, "aan het eind weg")


func test_the_twinkle_flares_up_and_dies_out(test) -> void:
	test.check(IntroRules.sparkle_flare(0.0) == 0.0, "het begint uit het niets")
	test.check(is_equal_approx(IntroRules.sparkle_flare(IntroRules.SPARKLE_FLARE), 1.0), "op zijn felst na het opvlammen")
	test.check(is_equal_approx(IntroRules.sparkle_flare(IntroRules.SPARKLE_FLARE * 0.5), 0.5), "halverwege het opvlammen: half")
	test.check(is_equal_approx(IntroRules.sparkle_flare((1.0 + IntroRules.SPARKLE_FLARE) * 0.5), 0.5), "halverwege het doven: half")
	test.check(absf(IntroRules.sparkle_flare(0.9999)) < 0.001, "aan het eind gedoofd")


func test_value_between_the_stops(test) -> void:
	var stops := [[10.0, 100.0], [20.0, 0.0], [40.0, -50.0]]
	test.check(IntroRules.value_between(stops, 0.0) == 100.0 and IntroRules.value_between(stops, 10.0) == 100.0, "voor de eerste: de eerste waarde")
	test.check(is_equal_approx(IntroRules.value_between(stops, 15.0), 50.0), "halverwege twee stops: het midden")
	test.check(IntroRules.value_between(stops, 20.0) == 0.0, "op een stop: zijn waarde")
	test.check(is_equal_approx(IntroRules.value_between(stops, 25.0), -12.5), "elk stuk gaat in zijn eigen tempo")
	test.check(IntroRules.value_between(stops, 40.0) == -50.0 and IntroRules.value_between(stops, 99.0) == -50.0, "na de laatste: daar blijft het")
	test.check(IntroRules.value_between([[5.0, 7.0]], 0.0) == 7.0, "één stop: altijd die waarde")


func test_the_stars_and_the_logo_come_up_together(test) -> void:
	test.check(not IntroRules.stars_shown(IntroRules.LOGO_FADE_IN_AT - 0.01) and IntroRules.stars_shown(IntroRules.LOGO_FADE_IN_AT), "de sterren vanaf het opkomen")
	test.check(IntroRules.fade_in(0.0) == 0.0 and IntroRules.fade_in(IntroRules.LOGO_AT) == 1.0 and IntroRules.fade_in(IntroRules.END_AT) == 1.0, "van niets tot helemaal, en dat blijft")
	test.check(is_equal_approx(IntroRules.fade_in((IntroRules.LOGO_FADE_IN_AT + IntroRules.LOGO_AT) * 0.5), 0.5), "halverwege: half")
	var gone_at: float = IntroRules.LOGO_AT + IntroRules.LOGO_HOLD + IntroRules.LOGO_SECONDS
	test.check(not IntroRules.logo_shown(0.0) and IntroRules.logo_shown(IntroRules.LOGO_FADE_IN_AT) and IntroRules.logo_shown(gone_at - 0.01), "het logo: van het opkomen tot het weg is")
	test.check(not IntroRules.logo_shown(gone_at), "daarna niet meer")
	test.check(IntroRules.logo_alpha(IntroRules.LOGO_FADE_IN_AT) == 0.0 and IntroRules.logo_alpha(IntroRules.LOGO_AT) == 1.0, "het komt op met de sterren")
	test.check(is_equal_approx(IntroRules.logo_alpha(IntroRules.LOGO_AT + IntroRules.LOGO_HOLD + IntroRules.LOGO_SECONDS * 0.5), 0.5) and IntroRules.logo_alpha(gone_at) == 0.0,
		"en vervaagt terwijl het weggaat")


func test_the_story_starts_ends_and_goes_faster(test) -> void:
	test.check(not IntroRules.crawl_started(IntroRules.CRAWL_AT - 0.01) and IntroRules.crawl_started(IntroRules.CRAWL_AT), "het verhaal rolt vanaf zijn moment")
	test.check(not IntroRules.crawl_ended(IntroRules.END_AT - 0.01) and IntroRules.crawl_ended(IntroRules.END_AT), "en is aan het eind voorbij")
	test.check(is_equal_approx(IntroRules.crawl_gain(0.5), 0.5 * (IntroRules.CRAWL_FAST - 1.0)) and IntroRules.crawl_gain(0.0) == 0.0, "met Enter ingehouden loopt het voor op de muziek")
	test.check(not IntroRules.fast_offered(IntroRules.CRAWL_AT - 0.01) and IntroRules.fast_offered(IntroRules.CRAWL_AT) and not IntroRules.fast_offered(IntroRules.END_AT),
		"sneller wordt alleen aangeboden terwijl het rolt")


func test_where_the_story_stands(test) -> void:
	var tops := []
	for paragraph_index in IntroRules.STORY.size():
		tops.append(paragraph_index * 100.0)
	var picture := 1400.0
	var text_height := 1250.0
	test.check(IntroRules.crawl_position(0.0, tops, text_height, picture, 0.35) == picture and IntroRules.crawl_position(IntroRules.CRAWL_AT, tops, text_height, picture, 0.35) == picture,
		"aan het begin staat de hele tekst onder het beeld")
	for paragraph_index: int in IntroRules.CRAWL_CUES:
		var at_cue := IntroRules.crawl_position(IntroRules.CRAWL_CUES[paragraph_index], tops, text_height, picture, 0.35)
		test.check(is_equal_approx(at_cue + tops[paragraph_index], picture), "alinea %d komt op zijn moment onderaan binnen" % paragraph_index)
	var rest := picture * 0.35 - text_height
	test.check(is_equal_approx(IntroRules.crawl_position(IntroRules.REST_AT, tops, text_height, picture, 0.35), rest)
		and is_equal_approx(IntroRules.crawl_position(IntroRules.END_AT, tops, text_height, picture, 0.35), rest), "de laatste alinea komt ver weg tot rust en blijft daar")
	var previous := picture
	var rolling_up := true
	for step in range(1, 100):
		var position := IntroRules.crawl_position(lerpf(IntroRules.CRAWL_AT, IntroRules.REST_AT, step / 100.0), tops, text_height, picture, 0.35)
		rolling_up = rolling_up and position < previous
		previous = position
	test.check(rolling_up, "het rolt steeds omhoog")
	test.check(is_equal_approx(IntroRules.crawl_position(IntroRules.REST_AT, [], text_height, picture, 0.35), rest), "zonder alinea's: recht naar de rust")
	var halfway := IntroRules.crawl_position((IntroRules.CRAWL_AT + IntroRules.REST_AT) * 0.5, [], text_height, picture, 0.35)
	test.check(is_equal_approx(halfway, (picture + rest) * 0.5), "dan gelijkmatig (%.1f)" % halfway)


func test_the_twinkle_has_its_time(test) -> void:
	test.check(is_equal_approx(IntroRules.sparkle_share(IntroRules.SPARKLE_AT), 0.0) and is_equal_approx(IntroRules.sparkle_share(IntroRules.SPARKLE_AT + IntroRules.SPARKLE_SECONDS), 1.0),
		"van 0 tot 1 over zijn tijd")
	test.check(IntroRules.sparkle_share(0.0) < 0.0, "ervoor: onder nul")
	test.check(IntroRules.sparkle_shown(0.0) and IntroRules.sparkle_shown(0.99) and not IntroRules.sparkle_shown(-0.01) and not IntroRules.sparkle_shown(1.0), "alleen in zijn tijd te zien")


func test_a_star_twinkles(test) -> void:
	test.check(is_equal_approx(IntroRules.twinkle_alpha(0.0, 2.0, PI * 0.5, 0.6), 0.4), "op de top van de golf: zo diep gedimd als hij gaat")
	test.check(is_equal_approx(IntroRules.twinkle_alpha(0.0, 2.0, -PI * 0.5, 0.6), 1.0), "in het dal: helemaal helder")
	test.check(IntroRules.twinkle_alpha(0.0, 2.0, 0.0, 0.6) > 0.98, "meestal helder: halverwege de golf nog bijna vol")
	test.check(is_equal_approx(IntroRules.twinkle_alpha(1.0, PI, 0.0, 0.5), IntroRules.twinkle_alpha(3.0, PI, 0.0, 0.5)), "in zijn eigen tempo, steeds opnieuw")
	test.check(IntroRules.twinkle_alpha(0.3, 2.0, 1.0, 0.0) == 1.0, "een ster die niet dimt blijft helder")


func test_the_texts(test) -> void:
	test.check(IntroRules.OPENING_LINE.strip_edges() != "" and IntroRules.STORY.size() == 12, "een openingszin en twaalf alinea's")
	test.check(IntroRules.SKIP_ACTION == ["SPATIE", "Overslaan"] and IntroRules.FAST_TEXT.contains("ENTER"), "de acties in de hoeken")
