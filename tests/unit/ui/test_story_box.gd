extends RefCounted
## Unit tests of the story box (scripts/ui/story_box.gd) on its own, without the HUD or the
## town: opening and closing (the pause, `done`, `finished`), a page typing out and Space
## going on, the kinds of pages (who speaks, the banner, the mission badge), the choices of
## a conversation (arrows, digits, what follows, what was said before), someone on duty,
## holding (on_hold) and the pure calculations (the default speaker, the scroll that follows).
##   tests/run_unit_tests.sh story_box

const StoryBox = preload("res://scripts/ui/story_box.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Counts what the box tells: `done`, `finished`, the choices said, the pages shown.
class Listener:
	var done_calls := 0
	var finished_calls := 0
	var chosen: Array = []
	var shown := 0
	var follow_up: Array = []

	func on_done() -> void:
		done_calls += 1

	func on_finished() -> void:
		finished_calls += 1

	func on_show() -> void:
		shown += 1

	func on_choice(choice_index: int) -> Array:
		chosen.append(choice_index)
		return follow_up


func _box(listener: Listener, player_name := "Sjaan") -> StoryBox:
	var box := StoryBox.new()
	box.player_name = player_name
	box.font_title = UiStyle.font(UiStyle.FONT_TITLE)
	box.font_pixel = UiStyle.font(UiStyle.FONT_PIXEL)
	box.font_body = UiStyle.font(UiStyle.FONT_BODY)
	box.finished.connect(listener.on_finished)
	tree.root.add_child(box)
	return box


static func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


static func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


## Types the page out by stepping the box's own _process.
static func _type_out(box: StoryBox) -> void:
	for step in 400:
		if box._typewriter.is_done():
			return
		# the sound of the word before is over (no frames pass here for it to end by itself)
		if is_instance_valid(box._babble):
			box._babble.stop()
		box._process(0.1)


func test_default_speaker_per_kind(test) -> void:
	test.check(StoryBox.default_speaker("verhaal", "Sjaan") == "VERTELLER", "een verhaal: de verteller")
	test.check(StoryBox.default_speaker("missie", "Sjaan") == "NIEUWE MISSIE", "een missie: NIEUWE MISSIE")
	test.check(StoryBox.default_speaker("gedachte", "Sjaan") == "Sjaan", "een gedachte: de speler zelf")
	test.check(StoryBox.default_speaker("gesprek", "Sjaan") == "Sjaan", "een gesprek zonder naam: de speler")


func test_shown_text_quotes_a_thought(test) -> void:
	test.check(StoryBox.shown_text("gedachte", "Honger.") == "“Honger.”", "een gedachte tussen aanhalingstekens")
	test.check(StoryBox.shown_text("verhaal", "Honger.") == "Honger.", "een verhaal zoals het is")
	test.check(StoryBox.shown_text("gesprek", "") == "", "leeg blijft leeg")


func test_next_scroll_eases_and_always_arrives(test) -> void:
	test.check(StoryBox.next_scroll(0.0, 100.0, 0.1) > 0 and StoryBox.next_scroll(0.0, 100.0, 0.1) < 100, "een stap naar het doel, niet in een keer")
	test.check(StoryBox.next_scroll(0.0, 100.0, 10.0) == 100, "na lang genoeg: er")
	test.check(StoryBox.next_scroll(98.0, 100.0, 0.0001) == 99, "een heel kort beeldje: toch minstens een pixel")
	test.check(StoryBox.next_scroll(100.0, 98.0, 0.0001) == 99, "ook terug omhoog")
	test.check(StoryBox.next_scroll(50.0, 50.4, 0.0001) == 50, "minder dan een pixel te gaan: blijft staan")
	var position := 0.0
	for step in 600:
		position = float(StoryBox.next_scroll(position, 37.0, 1.0 / 240.0))
	test.check(position == 37.0, "bij 240 beelden per seconde komt hij aan (%s)" % position)


func test_escaped_and_choice_style(test) -> void:
	test.check(StoryBox._escaped("Kijk [b]hier[/b]") == "Kijk [lb]b]hier[lb]/b]", "blokhaken zijn geen opmaak")
	var chosen := StoryBox._choice_style(true)
	var other := StoryBox._choice_style(false)
	test.check(chosen.border_width_left == StoryBox.CHOICE_STRIP and other.border_width_left == 2, "de gekozene heeft de strook links")
	test.check(chosen.border_color == UiStyle.ACCENT and other.border_color == UiStyle.BORDER, "en de rand in de accentkleur")
	test.check(chosen.bg_color == UiStyle.RAISED and other.bg_color == UiStyle.PANEL, "en ligt hoger")


func test_no_pages_calls_done_at_once(test) -> void:
	var listener := Listener.new()
	var box := _box(listener)
	var was_paused := tree.paused
	test.check(not box.is_showing(), "eerst dicht")
	box.show_pages([], listener.on_done)
	test.check(listener.done_calls == 1 and not box.is_showing(), "geen bladzijden: meteen klaar, niets te zien")
	test.check(tree.paused == was_paused and listener.finished_calls == 0, "geen pauze, geen finished")
	box.show_pages([])
	test.check(not box.is_showing(), "zonder done: ook niets")
	box.free()


func test_a_page_types_out_and_space_goes_on(test) -> void:
	var listener := Listener.new()
	var box := _box(listener)
	var was_paused := tree.paused
	test.check(not box.handle_input(_key(KEY_SPACE)), "dicht: toetsen zijn niet voor het kader")
	box.show_pages([{"text": "Het regent in Den Haag."}, {"text": "Je hebt honger."}], listener.on_done)
	test.check(box.is_showing() and tree.paused, "open, het spel staat stil")
	test.check(box.modulate.a == 0.0, "het komt op vanuit niets")
	test.check(not box._typewriter.is_done() and box._typewriter.text == "Het regent in Den Haag.", "de eerste bladzijde begint te typen")
	box._process(0.3)
	test.check(box._typewriter.shown_share() > 0.0 and not box._more.visible, "woord voor woord, nog geen pijltje")
	test.check(box.handle_input(_key(KEY_SPACE)), "Spatie is voor het kader")
	test.check(box._typewriter.is_done() and box._page_index == 0, "eerste Spatie: de rest van de bladzijde ineens")
	box._process(0.01)
	test.check(box._more.visible, "alles staat er: het pijltje")
	box._process(0.3)
	test.check(not box._more.visible, "het knippert")
	box.handle_input(_key(KEY_SPACE))
	test.check(box._page_index == 1 and box._typewriter.text == "Je hebt honger.", "tweede Spatie: de volgende bladzijde")
	box.handle_input(_click())
	box.handle_input(_click())
	test.check(not box.is_showing() and listener.done_calls == 1 and listener.finished_calls == 1, "na de laatste: dicht, done en finished een keer")
	test.check(tree.paused == was_paused, "de pauze terug zoals hij was")
	test.check(box._portrait == null, "het portret is weg")
	tree.paused = was_paused
	box.free()


func test_which_events_are_used(test) -> void:
	var listener := Listener.new()
	var box := _box(listener)
	var was_paused := tree.paused
	box.show_pages([{"text": "Een. Twee. Drie."}])
	test.check(box.handle_input(_key(KEY_Q)) and not box._typewriter.is_done(), "een andere toets: van het kader, maar doet niets")
	var released := _key(KEY_SPACE)
	released.pressed = false
	test.check(box.handle_input(released) and not box._typewriter.is_done(), "een losgelaten Spatie doet niets")
	var echo := _key(KEY_SPACE)
	echo.echo = true
	box.handle_input(echo)
	test.check(not box._typewriter.is_done(), "een ingehouden Spatie (echo) ook niet")
	var right_click := _click()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	test.check(box.handle_input(right_click) and not box._typewriter.is_done(), "de rechtermuisknop doet niets")
	test.check(not box.handle_input(InputEventMouseMotion.new()), "de muis bewegen is niet voor het kader")
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	box.handle_input(accept)
	test.check(box._typewriter.is_done(), "ui_accept (de controller) gaat ook verder")
	box.handle_input(_key(KEY_ENTER))
	test.check(not box.is_showing(), "Enter (ui_accept) na de laatste: dicht")
	tree.paused = was_paused
	box.free()


func test_kinds_of_pages(test) -> void:
	var listener := Listener.new()
	var box := _box(listener)
	var was_paused := tree.paused
	box.show_pages([
		{"kind": "verhaal", "text": "Lang geleden.", "banner": "De stad", "banner_kind": "PROLOOG"},
		{"kind": "gedachte", "text": "Ik heb honger."},
		{"kind": "missie", "text": "Zoek eten.", "banner": "Eerst eten", "banner_kind": "MISSIE 1"},
		{"kind": "gesprek", "text": "Hé jij.", "speaker": "TOERIST"},
	])
	test.check(box._name_label.text == "VERTELLER" and not box.is_conversation(), "een verhaal: de verteller")
	test.check(box._banner.visible and box._banner_title.text == "De stad" and box._banner_kind.text == "PROLOOG", "de banner erbij")
	test.check(box._portrait.archetype_id == StoryBox.NARRATOR_FIGURE and box._portrait.silhouette == StoryBox.NARRATOR_SILHOUETTE, "het silhouet van de verteller")
	test.check(box._portrait.visible and not box._mission_badge.visible, "het portret, geen missie-embleem")
	box.handle_input(_key(KEY_SPACE))
	box.handle_input(_key(KEY_SPACE))
	test.check(box._name_label.text == "Sjaan" and box._typewriter.text == "“Ik heb honger.”", "een gedachte: de speler, tussen aanhalingstekens (%s)" % box._typewriter.text)
	test.check(box._banner_title.text == "De stad", "de banner blijft van de bladzijde ervoor")
	test.check(box._typewriter.cursor_colour == UiStyle.SIDE_ACCENT and box._portrait.silhouette.a == 0.0, "in de kleur van een gedachte, de speler in kleur")
	box.handle_input(_key(KEY_SPACE))
	box.handle_input(_key(KEY_SPACE))
	test.check(box._name_label.text == "NIEUWE MISSIE" and box._mission_badge.visible and not box._portrait.visible, "een missie: het embleem in plaats van het portret")
	test.check(box._banner_title.text == "Eerst eten" and box._banner_kind.text == "MISSIE 1", "met zijn eigen banner")
	box.handle_input(_key(KEY_SPACE))
	box.handle_input(_key(KEY_SPACE))
	test.check(box.is_conversation() and box._name_label.text == "TOERIST", "een gesprek: wie er praat")
	test.check(box._portrait.archetype_id == StoryBox.NPC_FIGURE and box._portrait.silhouette == StoryBox.NPC_SILHOUETTE, "het silhouet van iemand anders")
	test.check(not box._choices_scroll.visible and box._scroll.anchor_right == 1.0, "zonder keuzes: de tekst over de hele breedte")
	box.handle_input(_key(KEY_SPACE))
	box.handle_input(_key(KEY_SPACE))
	test.check(not box.is_showing() and not box.is_conversation(), "dicht: geen gesprek meer")
	tree.paused = was_paused
	box.free()


func test_no_banner_hides_it(test) -> void:
	var listener := Listener.new()
	var box := _box(listener)
	var was_paused := tree.paused
	box.show_pages([{"text": "Zonder banner."}])
	test.check(not box._banner.visible, "geen banner: niet te zien")
	box.handle_input(_key(KEY_SPACE))
	box.handle_input(_key(KEY_SPACE))
	tree.paused = was_paused
	box.free()


func test_choices_are_chosen_with_the_keys(test) -> void:
	var listener := Listener.new()
	var box := _box(listener)
	var was_paused := tree.paused
	listener.follow_up = [{"kind": "gesprek", "text": "Mooi zo.", "speaker": "TOERIST"}]
	box.show_pages([{"kind": "gesprek", "text": "Weet jij de weg?", "speaker": "TOERIST",
		"choices": ["Ja hoor.", "Nee.", "Ga [weg]."], "on_choice": listener.on_choice, "on_show": listener.on_show}])
	test.check(listener.shown == 1, "on_show bij het openen van de bladzijde")
	test.check(box._choice_labels.size() == 3 and box._choices_scroll.visible, "drie keuzes, rechts van het gesprek")
	test.check(is_equal_approx(box._scroll.anchor_right, StoryBox.TALK_SPLIT), "de tekst op het linkerdeel")
	box.handle_input(_key(KEY_DOWN))
	test.check(box._chosen == 0, "nog aan het typen: de pijlen kiezen niet")
	box._process(0.05)
	test.check(not box._choices_box.visible, "de keuzes pas als de tekst er staat")
	box.handle_input(_key(KEY_SPACE))
	box._process(0.05)
	test.check(box._choices_box.visible and not box._more.visible, "de tekst staat er: de keuzes, geen pijltje")
	test.check(box.handle_input(_key(KEY_DOWN)) and box._chosen == 1, "omlaag: de tweede")
	box.handle_input(_key(KEY_S))
	box.handle_input(_key(KEY_S))
	test.check(box._chosen == 0, "onderaan omlaag: weer de eerste")
	box.handle_input(_key(KEY_W))
	test.check(box._chosen == 2, "bovenaan omhoog (W): de laatste")
	box.handle_input(_key(KEY_UP))
	test.check(box._chosen == 1, "pijl omhoog: de tweede")
	test.check(box._choice_labels[1].get_theme_color("font_color") == UiStyle.TEXT
		and box._choice_labels[0].get_theme_color("font_color") == UiStyle.MUTED, "de gekozene licht op")
	box.handle_input(_key(KEY_4))
	test.check(listener.chosen.is_empty(), "een cijfer boven het aantal keuzes doet niets")
	box.handle_input(_key(KEY_3))
	test.check(listener.chosen == [2], "3 kiest en zegt de derde (%s)" % [listener.chosen])
	test.check(box.is_showing() and box._typewriter.text == "Mooi zo." and box._choice_labels.is_empty(), "de bladzijden die erop volgen")
	test.check(box._history.size() == 2 and box._history[0].contains("TOERIST: Weet jij de weg?")
		and box._history[1].contains("→ Ga [lb]weg]."), "wat er gezegd is blijft staan (%s)" % [box._history])
	test.check(box._history_text.visible and box._history_text.text.contains("Weet jij de weg?"), "gedimd boven de nieuwe regel")
	box.handle_input(_key(KEY_SPACE))
	box.handle_input(_key(KEY_SPACE))
	test.check(not box.is_showing() and listener.finished_calls == 1, "na het antwoord: dicht")
	tree.paused = was_paused
	box.free()


func test_enter_says_the_chosen_and_nothing_after_closes(test) -> void:
	var listener := Listener.new()
	var box := _box(listener)
	var was_paused := tree.paused
	box.show_pages([{"kind": "gesprek", "text": "Kies maar.", "speaker": "TOERIST",
		"choices": ["Een.", "Twee."], "on_choice": listener.on_choice},
		{"kind": "gesprek", "text": "Dit komt nooit."}], listener.on_done)
	box.handle_input(_key(KEY_SPACE))
	box.handle_input(_key(KEY_DOWN))
	box.handle_input(_key(KEY_ENTER))
	test.check(listener.chosen == [1], "Enter zegt de gekozene (%s)" % [listener.chosen])
	test.check(not box.is_showing() and listener.done_calls == 1, "er volgt niets: het kader dicht, ook met bladzijden erna")
	box.show_pages([{"kind": "gesprek", "text": "Zonder vervolg.", "choices": ["Goed."]}])
	test.check(box._history.is_empty(), "opnieuw geopend: een leeg gesprek")
	box.handle_input(_click())
	box.handle_input(_click())
	test.check(not box.is_showing(), "een keuze zonder on_choice: een klik zegt hem en het kader sluit")
	tree.paused = was_paused
	box.free()


func test_a_story_page_clears_the_conversation(test) -> void:
	var listener := Listener.new()
	var box := _box(listener)
	var was_paused := tree.paused
	listener.follow_up = [{"kind": "verhaal", "text": "En toen."}]
	box.show_pages([{"kind": "gesprek", "text": "Hoi.", "speaker": "TOERIST", "choices": ["Hoi."], "on_choice": listener.on_choice}])
	box.handle_input(_key(KEY_SPACE))
	box.handle_input(_key(KEY_1))
	test.check(box._history.is_empty() and not box._history_text.visible, "een verhaal na een gesprek: wat er gezegd is weg")
	box.handle_input(_key(KEY_SPACE))
	box.handle_input(_key(KEY_SPACE))
	tree.paused = was_paused
	box.free()


func test_someone_on_duty_has_a_plate_and_an_emblem(test) -> void:
	var listener := Listener.new()
	var box := _box(listener)
	var was_paused := tree.paused
	var official := {"colour": Color("#FFD23A"), "plate": Color("#003082"), "plate_text": Color.WHITE, "emblem": "NS", "pitch": 0.8}
	box.show_pages([{"kind": "gesprek", "text": "Uw kaartje?", "speaker": "CONDUCTEUR", "official": official},
		{"kind": "gesprek", "text": "Zonder embleem.", "official": {"colour": Color("#FFD23A")}},
		{"kind": "gesprek", "text": "Gewoon iemand."}])
	var tag_style := box._name_tag.get_theme_stylebox("panel") as StyleBoxFlat
	test.check(box._emblem.visible and box._emblem_label.text == "NS", "het embleem op het portret")
	test.check(tag_style.bg_color == Color("#003082") and tag_style.border_color == Color("#FFD23A") and tag_style.border_width_left == 2, "het naamplaatje in hun kleuren")
	test.check(box._name_label.get_theme_color("font_color") == Color.WHITE, "de naam in de kleur van het plaatje")
	test.check(box._typewriter.cursor_colour == Color("#FFD23A"), "de cursor in hun kleur")
	box.handle_input(_key(KEY_SPACE))
	box.handle_input(_key(KEY_SPACE))
	test.check(not box._emblem.visible, "zonder embleem: geen")
	box.handle_input(_key(KEY_SPACE))
	box.handle_input(_key(KEY_SPACE))
	tag_style = box._name_tag.get_theme_stylebox("panel") as StyleBoxFlat
	test.check(not box._emblem.visible and tag_style.bg_color == UiStyle.ACCENT and tag_style.border_width_left == 0, "gewoon iemand: het gewone plaatje")
	box.handle_input(_key(KEY_SPACE))
	box.handle_input(_key(KEY_SPACE))
	tree.paused = was_paused
	box.free()


func test_someone_with_a_voice_babbles_instead_of_the_blip(test) -> void:
	var listener := Listener.new()
	var box := _box(listener)
	var was_paused := tree.paused
	box.show_pages([{"kind": "gesprek", "text": "Weet jij hoe laat het is?", "speaker": "TOERIST", "voice": "man", "mood": "neutraal"},
		{"text": "De verteller weer."}])
	test.check(not box._typewriter.sound and box._portrait.speech == "Weet jij hoe laat het is?", "geen tekstpiepje, de mond beweegt met de regel")
	box._process(0.05)
	test.check(box._portrait.speaking, "terwijl de regel typt: de mond beweegt")
	test.check(not box._asked_aloud, "het begin van de vraag: nog gewoon")
	_type_out(box)
	box._process(0.05)
	test.check(not box._portrait.speaking, "uitgetypt: de mond stil")
	test.check(box._asked_aloud, "een vraag gaat aan het eind omhoog")
	box.handle_input(_key(KEY_SPACE))
	test.check(box._typewriter.sound and box._portrait.speech == "", "de verteller: weer het piepje, geen mond")
	box._process(0.05)
	test.check(not box._portrait.speaking, "en zijn mond beweegt niet")
	box.handle_input(_key(KEY_SPACE))
	box.handle_input(_key(KEY_SPACE))
	tree.paused = was_paused
	box.free()


func test_on_hold_stops_everything(test) -> void:
	var listener := Listener.new()
	var box := _box(listener)
	var was_paused := tree.paused
	var holding := [true]
	box.on_hold = func() -> bool: return holding[0]
	box.show_pages([{"text": "Een hele lange regel tekst om te typen."}])
	test.check(not box.handle_input(_key(KEY_SPACE)) and not box._typewriter.is_done(), "wachtend: toetsen zijn niet voor het kader")
	var share_before := box._typewriter.shown_share()
	box._process(1.0)
	test.check(box._typewriter.shown_share() == share_before and not box._more.visible, "wachtend: de tekst typt niet door")
	holding[0] = false
	box._process(1.0)
	test.check(box._typewriter.shown_share() > share_before, "niet meer wachtend: hij typt weer")
	test.check(box.handle_input(_key(KEY_SPACE)), "en de toetsen zijn weer van het kader")
	box.handle_input(_key(KEY_SPACE))
	tree.paused = was_paused
	box.free()


func test_keep_paused_decides_the_pause_after_closing(test) -> void:
	var listener := Listener.new()
	var box := _box(listener)
	var was_paused := tree.paused
	box.keep_paused = func() -> bool: return true
	box.show_pages([{"text": "Nog een scherm open."}])
	box.handle_input(_key(KEY_SPACE))
	box.handle_input(_key(KEY_SPACE))
	test.check(not box.is_showing() and tree.paused, "een ander scherm staat nog open: het spel blijft stil")
	box.keep_paused = func() -> bool: return false
	box.show_pages([{"text": "Niets meer open."}])
	box.handle_input(_key(KEY_SPACE))
	box.handle_input(_key(KEY_SPACE))
	test.check(not tree.paused, "niets meer open: het spel gaat door")
	tree.paused = was_paused
	box.free()


func test_new_pages_while_open_replace_the_old(test) -> void:
	var listener := Listener.new()
	var box := _box(listener)
	var was_paused := tree.paused
	box.show_pages([{"text": "Eerst dit."}, {"text": "Dan dat."}])
	var portrait: Node = box._portrait
	box.show_pages([{"text": "Iets anders."}], listener.on_done)
	test.check(box._typewriter.text == "Iets anders." and box._page_index == 0, "nieuwe bladzijden in het open kader")
	test.check(box._portrait == portrait, "hetzelfde portret: het kader ging niet opnieuw open")
	box.handle_input(_key(KEY_SPACE))
	box.handle_input(_key(KEY_SPACE))
	test.check(not box.is_showing() and listener.done_calls == 1 and tree.paused == was_paused, "dicht, de pauze zoals voor het eerste openen")
	tree.paused = was_paused
	box.free()
