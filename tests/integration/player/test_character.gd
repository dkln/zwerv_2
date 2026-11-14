extends "res://tests/integration/support/town_test.gd"
## The character creation screen (scenes/karakter.tscn, scripts/ui/character_creation.gd):
## the list and the detail panel with their 3D figures, choosing one (it walks, does its
## move, shouts and says it in a balloon), and beginning: the town opens with the one chosen
## in the HUD (name, portrait, the maximum of the stats). Without the shared town: the
## screen opens the town itself. The figures themselves (limbs, detail) are the unit test
## tests/unit/player/test_character_figures.gd.
##   tests/run_integration_tests.sh character

## Place in the list of the ufo pilot and of Willem.
const UFO_PILOT := 2
const WILLEM := 3
## Frames the town may take to open after "begin".
const TOWN_OPENS_WITHIN := 4000


static func world_options() -> Dictionary:
	return {"town": false}


## The character screen opened as the current scene; returns the screen ("Scherm").
func _open_screen() -> Node:
	var screen_scene: Node = load("res://scenes/karakter.tscn").instantiate()
	add_to_root(screen_scene)
	tree.current_scene = screen_scene
	await frames(5)
	return screen_scene.get_node("Scherm")


## Every character is in the list, which does not scroll: its entries are spread over the
## height of the detail panel.
func test_list_shows_every_character_without_scrolling(test) -> void:
	var screen := await _open_screen()
	print("in de lijst: ", screen._entries.size(), ", knop: ", screen._begin_button.text)
	test.check(screen._entries.size() == PlayerCharacter.ORDER.size(), "%d in de lijst" % PlayerCharacter.ORDER.size())
	var list_end: float = screen._entries[-1].position.y + screen._entries[-1].size.y
	print("lijst: eind ", list_end, " (detail ", screen.HEIGHT, ")")
	test.check(screen._scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "de lijst scrollt niet")
	test.check(absf(list_end - screen.HEIGHT) <= 1.0, "lijst over de hoogte van het detail verdeeld")


## The one chosen is shown in the detail panel (name, figure) and walks there.
func test_choice_is_shown_walking_in_the_detail_panel(test) -> void:
	var screen := await _open_screen()
	screen._select(UFO_PILOT)
	await frames(60)
	print("loopt: ", screen._detail_figure.walking, ", moeilijkheid: ", screen._difficulty_name.text)
	test.check(screen._detail_figure.walking >= 0.5, "loopt")
	print("gekozen: ", screen._begin_button.text, ", detail ", screen._detail_name.text, " / ", screen._detail_subtitle.text)
	test.check(screen._detail_name.text == "Ufo Piloot" and screen._detail_figure.archetype_id == "ufo_piloot", "detail toont de keuze")


## The one chosen does its move, shouts at its moment (its own sound) and says it in a balloon.
func test_choice_does_its_move_and_shouts_in_a_balloon(test) -> void:
	var screen := await _open_screen()
	var cued := [false]
	screen._detail_figure.gesture_cue.connect(func() -> void: cued[0] = true)
	screen._select(WILLEM)
	for frame_index in 300:
		await tree.process_frame
		if cued[0]:
			break
	await frames(1)
	test.check(cued[0], "een gebaar met kreet")
	print("ballon: ", screen._balloon.visible, " \"", screen._balloon._typewriter.text, "\"")
	test.check(screen._balloon.visible and screen._balloon._typewriter.text == String(PlayerCharacter.ARCHETYPES.willem.shout), "een tekstballon bij de kreet")
	var shout_path: String = screen._shout.stream.resource_path if screen._shout and screen._shout.stream else ""
	print("kreet: ", shout_path)
	test.check(shout_path.ends_with("kreet_willem.ogg"), "een kreet bij het kiezen")


## Every character has a shout sound of its own.
func test_every_character_has_a_shout(test) -> void:
	var screen := await _open_screen()
	for archetype_id: String in PlayerCharacter.ORDER:
		test.check(ResourceLoader.exists(screen.SHOUT_FOLDER + "kreet_%s.ogg" % archetype_id), "een kreet voor %s" % archetype_id)


## Beginning with the ufo pilot chosen opens the town, with the pilot in the HUD: the name,
## the portrait and the maximum of the stats.
func test_begin_opens_the_town_with_the_one_chosen(test) -> void:
	var screen := await _open_screen()
	screen._select(UFO_PILOT)
	await frames(2)
	screen.begin()
	for frame_index in TOWN_OPENS_WITHIN:
		await tree.process_frame
		if tree.current_scene != null and tree.current_scene.name == "Stad":
			break
	var opened := tree.current_scene != null and tree.current_scene.name == "Stad"
	test.check(opened, "de stad ging open")
	if opened:
		await frames(5)
		var town_hud := tree.current_scene.get_node("HUD")
		print("HUD: ", town_hud.player_name, ", leven ", town_hud.get_stat("gezondheid"), ", stamina ",
				town_hud.get_stat("uithoudingsvermogen"), ", honger ", town_hud.get_stat("honger"), ", portret ",
				town_hud.player_frame.portrait.archetype_id)
		test.check(town_hud.player_name == "Ufo Piloot" and town_hud.get_stat("gezondheid") == Vector2(150, 150)
				and town_hud.player_frame.portrait.archetype_id == "ufo_piloot", "HUD heeft de keuze")
	PlayerCharacter.choose("martin")
