extends RefCounted
## Unit tests of the character creation screen (scripts/ui/character_creation.gd) on its own
## (it needs no town): the list sharing the height of the detail panel, the difficulty
## blocks and the numbers beside the stats, and the screen itself: which character it opens
## on, choosing with the keys and the mouse, what the detail panel shows of each, and that
## nothing can be begun twice. Beginning for real (the town opens) and going back to the
## menu change the scene and are left to the integration tests.
##   tests/run_unit_tests.sh character_creation

const CharacterCreation = preload("res://scripts/ui/character_creation.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## The screen in the tree, opened with `chosen` as the character chosen before ("" for none).
func _screen(chosen := "") -> CharacterCreation:
	PlayerCharacter.chosen_id = chosen
	var screen := CharacterCreation.new()
	tree.root.add_child(screen)
	return screen


static func _action(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


static func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


static func _selected_id(screen: CharacterCreation) -> String:
	return PlayerCharacter.ORDER[screen._selected]


func test_entry_heights_share_the_height_exactly(test) -> void:
	for count in [1, 2, 3, 5, 6]:
		var heights := CharacterCreation.entry_heights(count)
		var total := 0.0
		for height in heights:
			total += height
		test.check(heights.size() == count and is_equal_approx(total + CharacterCreation.ENTRY_GAP * (count - 1), CharacterCreation.HEIGHT),
			"%d in de lijst: samen met de tussenruimtes precies de hoogte van het paneel (%s)" % [count, heights])
		test.check(not CharacterCreation.list_scrolls(count), "%d passen: de lijst schuift niet" % count)
		test.check(heights.max() - heights.min() <= 1.0 and heights[0] == heights.max(), "hooguit een pixel verschil, de eerste het hoogst")
	var many := CharacterCreation.entry_heights(12)
	test.check(CharacterCreation.list_scrolls(12) and many.size() == 12 and many.min() == CharacterCreation.ENTRY_LOWEST and many.max() == CharacterCreation.ENTRY_LOWEST,
		"te veel om te passen: allemaal de laagste hoogte, de lijst schuift")
	test.check(not CharacterCreation.list_scrolls(PlayerCharacter.ORDER.size()), "de personages van nu passen allemaal")


func test_difficulty_block_colour(test) -> void:
	var colours: Array = CharacterCreation.DIFFICULTY_COLOURS
	test.check(CharacterCreation.difficulty_block_colour(0, 1) == colours[0] and CharacterCreation.difficulty_block_colour(1, 1) == CharacterCreation.DIFFICULTY_EMPTY,
		"makkelijk: één groen blok, de rest leeg")
	test.check(CharacterCreation.difficulty_block_colour(0, 3) == colours[2] and CharacterCreation.difficulty_block_colour(2, 3) == colours[2]
		and CharacterCreation.difficulty_block_colour(3, 3) == CharacterCreation.DIFFICULTY_EMPTY, "gemiddeld: drie blokken in dezelfde kleur")
	test.check(CharacterCreation.difficulty_block_colour(4, 5) == colours[4], "zwaar: alle vijf rood")
	test.check(CharacterCreation.difficulty_block_colour(4, 9) == colours[4], "boven de schaal: de laatste kleur")
	test.check(CharacterCreation.difficulty_block_colour(0, 0) == CharacterCreation.DIFFICULTY_EMPTY, "geen moeilijkheid: alles leeg")
	test.check(colours.size() == PlayerCharacter.DIFFICULTY_CEILING, "een kleur per stap")


func test_stat_number_text(test) -> void:
	test.check(CharacterCreation.stat_number_text(100.0) == "100", "gewoon: alleen het getal")
	test.check(CharacterCreation.stat_number_text(120.0) == "120+", "erboven: een plus")
	test.check(CharacterCreation.stat_number_text(80.0) == "80-", "eronder: een min")
	test.check(CharacterCreation.stat_number_text(99.6) == "100-", "afgerond, maar nog net eronder")


func test_it_opens_on_the_first_or_the_one_chosen_before(test) -> void:
	var chosen_before := PlayerCharacter.chosen_id
	var screen := _screen("")
	test.check(_selected_id(screen) == PlayerCharacter.ORDER[0], "niets gekozen: de eerste")
	test.check(screen._entries.size() == PlayerCharacter.ORDER.size() and screen._entry_panels.size() == screen._entries.size(), "een regel per personage")
	screen.free()
	var third: String = PlayerCharacter.ORDER[2]
	var again := _screen(third)
	test.check(_selected_id(again) == third, "eerder gekozen: die weer (%s)" % _selected_id(again))
	test.check(again._begin_button.text == "→  BEGIN ALS %s" % String(PlayerCharacter.ARCHETYPES[third].name).to_upper(), "de knop zegt als wie je begint")
	again.free()
	PlayerCharacter.chosen_id = chosen_before


func test_the_keys_choose(test) -> void:
	var chosen_before := PlayerCharacter.chosen_id
	var screen := _screen("")
	var last := PlayerCharacter.ORDER.size() - 1
	screen._unhandled_input(_action("ui_down"))
	test.check(screen._selected == 1, "omlaag: de tweede")
	screen._unhandled_input(_action("ui_right"))
	test.check(screen._selected == 2, "rechts: ook de volgende")
	screen._unhandled_input(_action("ui_left"))
	screen._unhandled_input(_action("ui_up"))
	screen._unhandled_input(_action("ui_up"))
	test.check(screen._selected == last, "bovenaan omhoog: de laatste")
	screen._unhandled_input(_action("ui_down"))
	test.check(screen._selected == 0, "onderaan omlaag: weer de eerste")
	screen._unhandled_input(_key(KEY_4))
	test.check(screen._selected == 3, "4: meteen de vierde")
	screen._unhandled_input(_key(KEY_1 + PlayerCharacter.ORDER.size()))
	test.check(screen._selected == 3, "een cijfer voorbij de lijst doet niets")
	screen._unhandled_input(_key(KEY_Q))
	test.check(screen._selected == 3, "een andere toets ook niet")
	test.check(screen._entry_panels[3].get_theme_stylebox("panel").border_color == UiStyle.ACCENT
		and screen._entry_panels[0].get_theme_stylebox("panel").border_color == UiStyle.BORDER, "de gekozen regel in amber")
	test.check(screen._entries[3].modulate == Color.WHITE and screen._entries[0].modulate != Color.WHITE, "de andere gedimd")
	test.check(PlayerCharacter.chosen_id == "", "kiezen in de lijst legt nog niets vast")
	screen.free()
	PlayerCharacter.chosen_id = chosen_before


func test_a_click_on_another_entry_chooses_it(test) -> void:
	var chosen_before := PlayerCharacter.chosen_id
	var screen := _screen("")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen._entries[2].gui_input.emit(click)
	test.check(screen._selected == 2 and not screen._leaving, "een klik op een andere regel kiest hem (en begint nog niet)")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	screen._entries[4].gui_input.emit(wheel)
	test.check(screen._selected == 2, "het wieltje kiest niet")
	screen.free()
	PlayerCharacter.chosen_id = chosen_before


func test_the_detail_panel_shows_each_character(test) -> void:
	var chosen_before := PlayerCharacter.chosen_id
	var screen := _screen("")
	for index in PlayerCharacter.ORDER.size():
		var archetype_id: String = PlayerCharacter.ORDER[index]
		var archetype: Dictionary = PlayerCharacter.ARCHETYPES[archetype_id]
		screen._select(index, false)
		test.check(screen._detail_name.text == String(archetype.name) and screen._detail_subtitle.text == String(archetype.subtitle)
			and screen._detail_figure.archetype_id == archetype_id, "%s: de naam, waar die goed in is en het figuur" % archetype_id)
		test.check(screen._story_typewriter.text == String(archetype.story) and not screen._story_typewriter.is_done(), "%s: het verhaal begint te typen" % archetype_id)
		test.check((screen._detail_level.get_child(0) as Label).text == "LEVEL %d" % int(archetype.level), "%s: het level" % archetype_id)
		test.check(screen._detail_perk.visible == archetype.has("perk")
			and (not archetype.has("perk") or screen._detail_perk.text == "EXTRA: " + String(archetype.perk).to_upper()), "%s: het extraatje (als die er een heeft)" % archetype_id)
		var difficulty := int(archetype.get("difficulty", 1))
		test.check(screen._difficulty_name.text == PlayerCharacter.DIFFICULTY_NAMES[clampi(difficulty, 1, PlayerCharacter.DIFFICULTY_CEILING)],
			"%s: de moeilijkheid (%s)" % [archetype_id, screen._difficulty_name.text])
		var lit := screen._difficulty_blocks.filter(func(block: ColorRect) -> bool: return block.color != CharacterCreation.DIFFICULTY_EMPTY).size()
		test.check(lit == mini(difficulty, screen._difficulty_blocks.size()), "%s: zoveel blokken als hij moeilijk is (%d)" % [archetype_id, lit])
		for stat_name: String in PlayerCharacter.STAT_LABELS:
			var value := float(archetype.stats[stat_name])
			test.check((screen._detail_numbers[stat_name] as Label).text == CharacterCreation.stat_number_text(value)
				and is_equal_approx(screen._detail_bars[stat_name].fill, value / PlayerCharacter.STAT_CEILING), "%s: %s als balk en getal" % [archetype_id, stat_name])
	screen._process(5.0)
	test.check(screen._story_typewriter.shown_share() > 0.0, "het verhaal typt zich uit")
	screen.free()
	PlayerCharacter.chosen_id = chosen_before


func test_the_shout_of_the_one_shown(test) -> void:
	var chosen_before := PlayerCharacter.chosen_id
	var screen := _screen("")
	screen._select(1, false)
	screen._on_gesture_cue()
	var archetype_id: String = PlayerCharacter.ORDER[1]
	var has_shout := ResourceLoader.exists(CharacterCreation.SHOUT_FOLDER + "kreet_%s.ogg" % archetype_id)
	test.check((screen._shout != null) == has_shout, "de kreet van wie er staat (als het bestand er is)")
	test.check(String(PlayerCharacter.ARCHETYPES[archetype_id].get("shout", "")) != "" and screen._balloon.visible, "zijn woorden in een ballon boven zijn hoofd")
	screen._select(2, false)
	test.check(not screen._balloon.visible and (screen._shout == null or not screen._shout.playing), "een ander gekozen: de ballon weg, de kreet afgebroken")
	screen._play_shout("bestaat_niet")
	test.check(screen._shout == null or not screen._shout.playing, "iemand zonder kreet: stil")
	screen.free()
	PlayerCharacter.chosen_id = chosen_before


func test_nothing_happens_while_leaving(test) -> void:
	var chosen_before := PlayerCharacter.chosen_id
	var screen := _screen("")
	var button_text := screen._begin_button.text
	screen._leaving = true
	screen.begin()
	test.check(PlayerCharacter.chosen_id == "" and screen._begin_button.text == button_text, "al aan het weggaan: begin doet niets meer")
	screen._unhandled_input(_action("ui_down"))
	screen._unhandled_input(_key(KEY_3))
	test.check(screen._selected == 0, "en de toetsen kiezen niet meer")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen._entries[2].gui_input.emit(click)
	test.check(screen._selected == 0, "een klik ook niet")
	screen.free()
	PlayerCharacter.chosen_id = chosen_before
