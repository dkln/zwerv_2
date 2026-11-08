extends SceneTree
## Opens the main menu (scenes/hoofdmenu.tscn), checks it is built (the menu, the 3D map
## behind it), chooses NIEUW SPEL, begins on the character creation screen
## (scenes/karakter.tscn) as soon as it is there and waits until the town (scenes/stad.tscn) is the
## current scene, then pauses it (the HUD's pause menu) and goes back to the main menu.
## Prints "menu ok" for each step that went well.
## usage: Godot --headless --script tools/check/menu_test.gd

const Common = preload("res://tools/tool_common.gd")


func _init() -> void:
	Common.watchdog(self, 300)
	var menu_scene: Node = load("res://scenes/hoofdmenu.tscn").instantiate()
	get_root().add_child(menu_scene)
	current_scene = menu_scene
	await process_frame
	await process_frame
	var menu := menu_scene.get_node("Menu") as MainMenu
	print("menukaart: ", menu_scene.has_node("Menukaart"), ", knoppen: ", menu._buttons.size())
	menu._choose(1)
	var waited := 0.0
	var began := false
	while waited < 200.0:
		await process_frame
		waited += 0.05
		if not began and current_scene != null and current_scene.name == "Karakterkeuze":
			print("menu ok: karakterkeuze geopend")
			began = true
			await process_frame
			current_scene.get_node("Scherm").begin()
		if current_scene != null and current_scene.name == "Stad":
			print("menu ok: stad geopend")
			await _back_to_menu()
			quit()
			return
	print("FOUT: de stad ging niet open")
	quit()


func _back_to_menu() -> void:
	await process_frame
	var hud := current_scene.get_node("HUD") as GameHud
	hud.set_paused(true)
	print("gepauzeerd: ", paused)
	hud._choose_pause_item(1)
	for frame_index in 200:
		await process_frame
		if current_scene != null and current_scene.name == "Hoofdmenu":
			print("menu ok: terug in het hoofdmenu (gepauzeerd: %s)" % paused)
			return
	print("FOUT: niet terug in het hoofdmenu")
