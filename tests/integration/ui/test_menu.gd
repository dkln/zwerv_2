extends "res://tests/integration/support/town_test.gd"
## From the main menu into the game and back: the main menu (scenes/hoofdmenu.tscn) is built
## (the menu, the 3D map behind it), NIEUW SPEL opens the character creation screen
## (scenes/karakter.tscn), beginning there loads the town (scenes/stad.tscn) as the current
## scene, and from its pause menu the main menu comes back.
## A run of its own: it changes the current scene and loads the whole town as the game does.
##   tests/run_integration_tests.sh menu

## Seconds of the clock one test may take (the town loads in full).
const TEST_SECONDS := 250.0


static func world_options() -> Dictionary:
	return {"town": false, "own_process": true}


## Waits until the current scene is the one named `scene_name`, at most `most_frames`
## frames; returns whether it is.
func _wait_for_scene(scene_name: String, most_frames: int) -> bool:
	for frame_index in most_frames:
		if tree.current_scene != null and tree.current_scene.name == scene_name:
			return true
		await tree.process_frame
	return tree.current_scene != null and tree.current_scene.name == scene_name


## The main menu as the current scene; returns its Menu node.
func _open_main_menu() -> MainMenu:
	var menu_scene: Node = load("res://scenes/hoofdmenu.tscn").instantiate()
	add_to_root(menu_scene)
	tree.current_scene = menu_scene
	await frames(2)
	return menu_scene.get_node("Menu") as MainMenu


## The main menu is built: its buttons are there.
func test_main_menu_is_built(test) -> void:
	var menu := await _open_main_menu()
	print("menukaart: ", tree.current_scene.has_node("Menukaart"), ", knoppen: ", menu._buttons.size())
	test.check(menu != null and menu._buttons.size() > 1, "het hoofdmenu heeft knoppen (%d)" % (menu._buttons.size() if menu else 0))


## NIEUW SPEL opens the character creation, beginning there opens the town, and from the
## town's pause menu the main menu comes back.
func test_new_game_goes_to_the_town_and_back_to_the_menu(test) -> void:
	var menu := await _open_main_menu()
	menu._choose(1)
	var at_characters := await _wait_for_scene("Karakterkeuze", 4000)
	test.check(at_characters, "karakterkeuze geopend")
	if not at_characters:
		return
	await frames(1)
	tree.current_scene.get_node("Scherm").begin()
	var in_town := await _wait_for_scene("Stad", 4000)
	test.check(in_town, "stad geopend")
	if not in_town:
		return
	await frames(1)
	var town_hud := tree.current_scene.get_node("HUD") as GameHud
	town_hud.set_paused(true)
	test.check(tree.paused, "gepauzeerd in de stad")
	town_hud.pause_menu.choose(town_hud.pause_menu.item_index("menu"))
	test.check(await _wait_for_scene("Hoofdmenu", 200), "terug in het hoofdmenu (gepauzeerd: %s)" % tree.paused)
