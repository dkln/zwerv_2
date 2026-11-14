extends "res://tests/integration/support/town_test.gd"
## The game menu (scripts/ui/game_menu.gd) under a real HUD in a small world of its own
## (scene metadata "places" and "wijken", a map picture, a stand-in player "Speler" with the
## player API), without the town: each tab, the keys, an item used and one dropped, the
## marker on the map, the empty quest list, no opening while dead or paused, the menu
## without a player.
##   tests/run_integration_tests.sh game_menu

const HUD_SCRIPT = preload("res://scripts/ui/hud.gd")
const MENU_SCRIPT = preload("res://scripts/ui/game_menu.gd")
const Items = preload("res://scripts/player/items.gd")

## A player with the API of scripts/player/player_controller.gd, as far as the menu uses it.
const STAND_IN_PLAYER := """extends Node3D
const Items = preload("res://scripts/player/items.gd")
signal inventory_changed
signal stats_changed
var archetype_id := "willem"
var level := 3
var money := 12.0
var inventory := {"brood": 2, "bier": 1, "hoed": 1, "statiegeld": 6}
var stats := {"gezondheid": Vector2(60, 80), "uithoudingsvermogen": Vector2(80, 80),
		"honger": Vector2(10, 80), "overprikkeldheid": Vector2(30, 100)}
var dead := false

func stat(stat_name: String) -> Vector2:
	return stats.get(stat_name, Vector2(0, 100))

func use_item(item_id: String) -> bool:
	if int(inventory.get(item_id, 0)) <= 0 or not Items.can_use(item_id):
		return false
	var effect: Dictionary = Items.item(item_id).effect
	for stat_name: String in effect:
		var value: Vector2 = stats[stat_name]
		stats[stat_name] = Vector2(clampf(value.x + effect[stat_name], 0.0, value.y), value.y)
	drop_item(item_id)
	stats_changed.emit()
	return true

func drop_item(item_id: String) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) - 1
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	inventory_changed.emit()

func is_dead() -> bool:
	return dead

func teleport(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation.y = yaw
"""

## The HUD, the stand-in player and the menu of the small world built by _build_world.
var small_hud: Node
var stand_in: Node3D
var menu: Node


static func world_options() -> Dictionary:
	return {"town": false}


## Builds the small world (four places, three districts of which Centrum visited, a map
## picture of 50 x 50 cells of 4 m, two quests) with the menu under its HUD, closed.
func _build_world() -> void:
	var world := Node3D.new()
	world.name = "Wereld"
	world.set_meta("places", {"hoftoren": Vector2(100, 100), "het_plein": Vector2(140, 60),
			"verkeerslichten_test": Vector2(20, 20), "derrek_2": Vector2(150, 170)})
	world.set_meta("wijken", [["Centrum", 0, 0, 29, 49], ["Laak", 30, 0, 49, 49], ["Den Haag", 0, 0, 49, 49]])
	small_hud = CanvasLayer.new()
	small_hud.name = "HUD"
	small_hud.set_script(HUD_SCRIPT)
	world.add_child(small_hud)
	stand_in = Node3D.new()
	stand_in.name = "Speler"
	var player_script := GDScript.new()
	player_script.source_code = STAND_IN_PLAYER
	player_script.reload()
	stand_in.set_script(player_script)
	stand_in.position = Vector3(100, 0, 100)
	world.add_child(stand_in)
	add_to_root(world)
	tree.current_scene = world
	await frames(3)
	# a map picture as the HUD builds it from the Grond GridMap
	var image := Image.create(50, 50, false, Image.FORMAT_RGB8)
	image.fill(Color("#3A4A6E"))
	small_hud._minimap_map.texture = ImageTexture.create_from_image(image)
	small_hud._minimap_origin = Vector2.ZERO
	small_hud._minimap_cell = 4.0
	small_hud._visited_wijken = {"Centrum": true}
	small_hud.set_quests([
		{"kind": "verhaal", "label": "VERHAAL", "title": "Een dak boven je hoofd", "distance": "240M",
			"description": "Willem weet een portiek waar het droog blijft.",
			"steps": [{"text": "Praat met Willem", "done": true}, {"text": "Vind de portiek", "done": false}],
			"rewards": ["€ 5", "Slaapzak"]},
		{"kind": "zij", "label": "ZIJMISSIE", "title": "Statiegeld — 2/5"},
	])
	menu = MENU_SCRIPT.new()
	small_hud.add_child(menu)
	await frames(2)


## The small world with the menu open on `tab`.
func _open_on(tab: String) -> void:
	await _build_world()
	menu.open(tab)
	await frames(2)


## The small world with the map open and the marker set on the supermarket (Enter).
func _marker_on_the_supermarket() -> void:
	await _open_on("kaart")
	menu._choose_place("derrek_2")
	await _press(KEY_ENTER)


## A key pressed and let go, as from the keyboard.
func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	tree.root.push_input(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	tree.root.push_input(release)
	await frames(2)


## Tab opens the menu on the inventory and pauses the game; it shows the things in the
## grid, the character (name, level, money) and its figure.
func test_tab_opens_the_inventory_and_pauses(test) -> void:
	await _build_world()
	await _press(KEY_TAB)
	test.check(menu.is_open() and tree.paused, "Tab opent het menu en pauzeert")
	test.check(menu.current_tab() == "inventaris", "op de inventaris")
	test.check(menu._shown_items.size() == 5 and menu._shown_items[0] == "id_kaart", "het lege vakje van de ID-kaart en vier soorten spullen in het raster (%d)" % menu._shown_items.size())
	test.check(menu._character_name.text == "Willem", "naam van het karakter: " + menu._character_name.text)
	test.check(menu._character_line.text.begins_with("LV 3"), "niveau: " + menu._character_line.text)
	test.check(menu._money_label.text == "12,00", "geld: " + menu._money_label.text)
	test.check(menu._portrait != null, "figuur in 3D")


## Enter uses the chosen item: one bread less, its effect on the hunger, shown in the bar.
func test_enter_uses_the_chosen_item(test) -> void:
	await _open_on("inventaris")
	menu._selected_item = "brood"
	menu._refresh()
	await _press(KEY_ENTER)
	test.check(int(stand_in.inventory.get("brood", 0)) == 1, "brood gegeten (nog %d)" % int(stand_in.inventory.get("brood", 0)))
	test.check(stand_in.stats.honger.x == 35.0, "honger 10 + 25 = %d" % stand_in.stats.honger.x)
	test.check((menu._stat_texts["honger"] as Label).text == "35/80", "honger in de balk: " + (menu._stat_texts["honger"] as Label).text)


## X drops the chosen item, but never a key item.
func test_x_drops_an_item_but_not_a_key_item(test) -> void:
	await _open_on("inventaris")
	menu._selected_item = "hoed"
	menu._refresh()
	await _press(KEY_X)
	test.check(stand_in.inventory.has("hoed"), "sleutelvoorwerp niet weg te gooien")
	menu._selected_item = "bier"
	menu._refresh()
	await _press(KEY_X)
	test.check(not stand_in.inventory.has("bier"), "bier weggegooid")


## The number keys choose a category of the inventory, the arrows the next slot.
func test_categories_and_arrows_in_the_inventory(test) -> void:
	await _open_on("inventaris")
	await _press(KEY_2)
	test.check(menu._category == "eten" and menu._shown_items == ["brood"], "categorie ETEN: %s" % [menu._shown_items])
	await _press(KEY_1)
	var before: String = menu._selected_item
	await _press(KEY_RIGHT)
	test.check(menu._selected_item != before, "pijl rechts kiest het volgende vakje (%s -> %s)" % [before, menu._selected_item])


## E goes on to the quests: the story quest in the list, the arrow to the side quests.
func test_quests_tab_lists_story_and_side_quests(test) -> void:
	await _open_on("inventaris")
	await _press(KEY_E)
	test.check(menu.current_tab() == "quests", "E gaat naar de quests")
	test.check(menu._quest_rows.get_child_count() == 1, "één verhaalopdracht in de lijst (%d)" % menu._quest_rows.get_child_count())
	test.check(not menu._quest_empty.visible, "geen lege toestand")
	await _press(KEY_RIGHT)
	test.check(menu._quest_kind == "zij", "pijl rechts: zijmissies")


## E from the quests goes to the map: the places (not the test places), the nearest one
## chosen, the fog over the districts not visited, the arrow to the next place; Q goes back.
func test_map_tab_shows_places_and_fog(test) -> void:
	await _open_on("quests")
	await _press(KEY_E)
	test.check(menu.current_tab() == "kaart", "E gaat naar de kaart")
	test.check(menu._places.size() == 3, "drie plekken (verkeerslichten niet): %d" % menu._places.size())
	test.check(menu._selected_place == "hoftoren", "dichtstbijzijnde plek gekozen: " + menu._selected_place)
	test.check(menu._map_picture.texture != null and menu._map_fog.texture != null, "kaart en mist")
	test.check(menu._place_distance.text == "0 M", "afstand: " + menu._place_distance.text)
	test.check(menu._header_info.text.contains("1 / 2"), "wijken ontdekt: " + menu._header_info.text)
	var fog: Image = menu._map_fog.texture.get_image()
	test.check(fog.get_pixel(5, 5).a == 0.0 and fog.get_pixel(40, 5).a > 0.5, "mist alleen over de niet bezochte wijk")
	await _press(KEY_RIGHT)
	test.check(menu._selected_place == "het_plein", "pijl rechts kiest de plek rechtsboven: " + menu._selected_place)
	test.check(menu._place_name.text == "Het Plein", "naam van de plek: " + menu._place_name.text)
	await _press(KEY_Q)
	test.check(menu.current_tab() == "quests", "Q gaat terug")


## A supermarket on the map: known by its place, its own kind and the chain's name, the
## distance to it.
func test_supermarket_on_the_map(test) -> void:
	await _open_on("kaart")
	test.check(menu.supermarket_chain("derrek_2") == "derrek" and menu.supermarket_chain("alfred_steyhn") == "alfred_steyhn"
		and menu.supermarket_chain("hoftoren") == "", "supermarkten herkend aan hun plek (derrek_2, alfred_steyhn)")
	menu._choose_place("derrek_2")
	test.check(menu._place_kind.text == "◆ SUPERMARKT" and menu._place_name.text == "DERREK", "een supermarkt gekozen: %s %s" % [menu._place_kind.text, menu._place_name.text])
	test.check(menu._place_distance.text == "86 M", "afstand tot de supermarkt: " + menu._place_distance.text)


## Enter on a place sets the marker (the HUD's waypoint, the beacon in the town, the chip
## under the minimap), Enter again takes it off.
func test_enter_sets_and_removes_the_marker(test) -> void:
	await _open_on("kaart")
	menu._choose_place("derrek_2")
	test.check(menu._place_marker.text == "[ENTER] MARKER ZETTEN", "zonder marker: " + menu._place_marker.text)
	await _press(KEY_ENTER)
	test.check(small_hud.has_waypoint() and small_hud.waypoint() == Vector2(150, 170) and small_hud.waypoint_name() == "DERREK", "Enter: marker op de supermarkt (%s)" % small_hud.waypoint_name())
	test.check(menu._place_marker.text.begins_with("◆ MARKER STAAT HIER"), "het vak zegt het: " + menu._place_marker.text)
	test.check(small_hud._beacon != null and small_hud._beacon.is_inside_tree(), "een lichtbaken in de stad")
	test.check(small_hud._waypoint_chip.visible, "de marker onder het kaartje")
	await _press(KEY_ENTER)
	test.check(not small_hud.has_waypoint() and not small_hud._waypoint_chip.visible, "nog eens Enter: marker weg")


## Escape closes the menu and the game goes on; Tab then opens it on the tab it was left on.
func test_escape_closes_and_tab_reopens_on_the_last_tab(test) -> void:
	await _open_on("quests")
	await _press(KEY_ESCAPE)
	test.check(not menu.is_open() and not tree.paused, "Escape sluit en gaat verder")
	test.check(not small_hud._pause_layer.visible, "pauzemenu niet ook open")
	await _press(KEY_TAB)
	test.check(menu.is_open() and menu.current_tab() == "quests", "Tab opent op het laatste tabblad (%s)" % menu.current_tab())
	await _press(KEY_ESCAPE)


## The marker stays after the menu closes: on the minimap with its distance under it, and
## gone once the player is there.
func test_marker_shows_on_the_minimap_until_arrival(test) -> void:
	await _marker_on_the_supermarket()
	await _press(KEY_ESCAPE)
	test.check(small_hud.has_waypoint(), "de marker staat nog")
	small_hud._update_waypoint(Vector3(150, 0, 100), 1.0)
	test.check(small_hud._waypoint_label.text == "DERREK · 70 M", "onder het kaartje: " + small_hud._waypoint_label.text)
	test.check(small_hud._minimap_waypoint.points.size() == 1, "op het kaartje")
	small_hud._update_waypoint(Vector3(150, 0, 165), 1.0)
	test.check(not small_hud.has_waypoint(), "aangekomen: de marker is weg")


## M opens the menu on the map, M again closes it.
func test_m_opens_and_closes_the_map(test) -> void:
	await _build_world()
	await _press(KEY_M)
	test.check(menu.is_open() and menu.current_tab() == "kaart", "M opent de kaart")
	await _press(KEY_M)
	test.check(not menu.is_open(), "M nog eens sluit")


## Without quests the quests tab shows its empty state.
func test_no_quests_shows_the_empty_state(test) -> void:
	await _build_world()
	small_hud.set_quests([])
	menu.open("quests")
	await frames(2)
	test.check(menu._quest_empty.visible and not menu._quest_detail.visible, "lege toestand")
	menu.close()


## The menu does not open under the pause menu, nor when the player is dead.
func test_does_not_open_while_paused_or_dead(test) -> void:
	await _build_world()
	small_hud.set_paused(true)
	await _press(KEY_I)
	test.check(not menu.is_open(), "niet open tijdens het pauzemenu")
	small_hud.set_paused(false)
	stand_in.dead = true
	await _press(KEY_J)
	test.check(not menu.is_open() and not tree.paused, "niet open als de speler dood is")


## Without a player in the scene the menu shows the starting things of the chosen
## character, and using one works.
func test_menu_without_a_player(test) -> void:
	await _build_world()
	stand_in.free()
	menu.open("inventaris")
	await frames(2)
	test.check(menu.is_open() and not menu._shown_items.is_empty(), "startspullen van het gekozen karakter: %s" % [menu._shown_items])
	var first_item: String = menu._shown_items[0]
	var count_before := int(menu._inventory().get(first_item, 0))
	menu._selected_item = first_item
	menu._use_selected()
	test.check(int(menu._inventory().get(first_item, 0)) == count_before - 1 or not Items.can_use(first_item), "gebruikt zonder speler")
	menu.close()
	await frames(2)


## A key pressed until `done` holds (a story box: first the rest of the page, then on), at
## most `tries` times, with game time between the presses.
func _press_until(keycode: Key, done: Callable, tries := 8) -> void:
	for attempt in tries:
		if done.call():
			return
		await tree.create_timer(0.6, true, false, true).timeout
		await _press(keycode)


## A thought (the story box) while the inventory is open lies over the menu: the menu goes
## under the HUD, the rest of the HUD hides, the keys go to the story box; after it all is back
## and the game stays paused while the menu is open.
func test_story_box_lies_over_the_open_menu(test) -> void:
	await _build_world()
	var game_menu: CanvasLayer = small_hud.get_node("Spelmenu")
	game_menu.open("inventaris")
	await frames(2)
	var menu_layer := game_menu.layer
	small_hud.show_story([{"kind": "gedachte", "text": "Wat zit er allemaal in mijn zakken?"}])
	await frames(3)
	test.check(small_hud.is_showing_story(), "het gedachtevak staat open")
	test.check(game_menu.layer < small_hud.layer, "het menu ligt onder de HUD (%d < %d)" % [game_menu.layer, small_hud.layer])
	test.check(not small_hud._hidden_for_modal.is_empty(), "de rest van de HUD is weg (%d delen)" % small_hud._hidden_for_modal.size())
	await _press_until(KEY_SPACE, func() -> bool: return not small_hud.is_showing_story())
	await frames(2)
	test.check(not small_hud.is_showing_story(), "Spatie sluit het gedachtevak, niet het menu")
	test.check(game_menu.is_open() and tree.paused, "het menu staat nog open en het spel blijft gepauzeerd")
	test.check(game_menu.layer == menu_layer and small_hud._hidden_for_modal.is_empty(), "menu weer boven, HUD terug")
	game_menu.close()


## A level up shows the level-up screen (also over the open menu): S chooses the next stat,
## Enter takes it (once the keys count), the choice goes to the player, then it closes.
func test_level_up_screen_chooses_a_stat(test) -> void:
	await _build_world()
	var game_menu: CanvasLayer = small_hud.get_node("Spelmenu")
	game_menu.open("inventaris")
	await frames(2)
	var chosen: Array[String] = []
	small_hud.show_level_up(4, func(stat_name: String) -> void: chosen.append(stat_name), stand_in.stat)
	await frames(3)
	test.check(small_hud.is_showing_level_up() and tree.paused, "het level-up-scherm staat open, het spel gepauzeerd")
	test.check(game_menu.layer < small_hud.layer, "ook over het open menu")
	test.check(small_hud._level_up_screen._row_values[0].text == "80 → %d" % roundi(80.0 + PlayerController.LEVEL_UP_RAISE["gezondheid"]),
			"maximum nu → straks: " + small_hud._level_up_screen._row_values[0].text)
	await _press(KEY_S)
	test.check(small_hud._level_up_screen.selected_stat() == "uithoudingsvermogen", "S kiest de volgende")
	await _press_until(KEY_ENTER, func() -> bool: return not small_hud.is_showing_level_up())
	test.check(chosen.size() == 1 and chosen[0] == "uithoudingsvermogen", "Enter neemt hem (%s)" % [chosen])
	test.check(not small_hud.is_showing_level_up() and game_menu.is_open() and tree.paused, "dicht; het menu staat nog open")
	game_menu.close()
	await frames(2)
	test.check(not tree.paused, "menu dicht: het spel loopt weer")


## A Story with the API the mission picker uses (scripts/story/story.gd): two missions, the
## first under way at its second step.
const STAND_IN_STORY := """extends Node
var missions: Array[Dictionary] = [
	{"id": "missie_1", "label": "MISSIE 1", "titel": "Lege maag",
		"stappen": [{"id": "blikjes", "tekst": "Zoek blikjes"}, {"id": "kroket", "tekst": "Koop een kroket"}]},
	{"id": "missie_2", "label": "MISSIE 2", "titel": "Bekend gezicht",
		"stappen": [{"id": "praten", "tekst": "Praat met Ome Wim"}]},
]
func is_started(id: String) -> bool:
	return id == "missie_1"
func is_finished(_id: String) -> bool:
	return false
func step_done(id: String, step_id: String) -> bool:
	return id == "missie_1" and step_id == "blikjes"
"""


## F8 opens the mission picker (debug builds) on the step under way, also over the open menu;
## S and Page Down choose, Escape closes it and the menu stays open.
func test_mission_picker(test) -> void:
	await _build_world()
	var picker: CanvasLayer = small_hud.get_node_or_null("Missiekiezer")
	test.check(picker != null, "de missiekiezer hangt onder de HUD (debug)")
	if picker == null:
		return
	var stand_in_story := Node.new()
	var story_script := GDScript.new()
	story_script.source_code = STAND_IN_STORY
	story_script.reload()
	stand_in_story.set_script(story_script)
	small_hud.add_child(stand_in_story)
	picker.story = stand_in_story
	var game_menu: CanvasLayer = small_hud.get_node("Spelmenu")
	game_menu.open("quests")
	await frames(2)
	await _press(KEY_F8)
	test.check(picker.is_open() and tree.paused, "F8 opent de kiezer, het spel gepauzeerd")
	test.check(picker._rows.size() == 5, "twee missies en drie taken (%d rijen)" % picker._rows.size())
	test.check(picker.selected_entry() == {"mission": "missie_1", "step": "kroket"}, "op de taak die loopt: %s" % picker.selected_entry())
	await _press(KEY_PAGEDOWN)
	test.check(picker.selected_entry() == {"mission": "missie_2", "step": ""}, "Page Down: de volgende missie (%s)" % picker.selected_entry())
	await _press(KEY_S)
	test.check(picker.selected_entry() == {"mission": "missie_2", "step": "praten"}, "S: zijn eerste taak (%s)" % picker.selected_entry())
	await _press(KEY_ESCAPE)
	test.check(not picker.is_open() and game_menu.is_open() and tree.paused, "Escape sluit de kiezer, het menu blijft open")
	game_menu.close()
	stand_in_story.queue_free()


## A player with what the debug keys use (scripts/debug/debug_keys.gd).
const DEBUG_PLAYER := """extends Node3D
var money := 5.0
var earned := []
var xp := 0.0
var xp_for_level := 300.0
var level := 1
var stats := {"gezondheid": Vector2(30, 80), "honger": Vector2(50, 140),
		"uithoudingsvermogen": Vector2(10, 60), "overprikkeldheid": Vector2(70, 100)}
func add_money(euros: float, counts := true) -> void:
	money += euros
	earned.append(counts)
func add_xp(points: float) -> void:
	xp += points
	while xp >= xp_for_level:
		xp -= xp_for_level
		level += 1
func stat(stat_name: String) -> Vector2:
	return stats[stat_name]
func change_stat(stat_name: String, amount: float) -> void:
	var value: Vector2 = stats[stat_name]
	stats[stat_name] = Vector2(clampf(value.x + amount, 0.0, value.y), value.y)
"""


## A debug key pressed, with Shift or without.
func _press_debug(keycode: Key, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.shift_pressed = shift
	tree.root.push_input(event)
	await frames(2)


## F7 gives €10 (Shift: €100), also with the menu open; it does not count as earned. F9 gives
## 100 XP, Shift+F9 just enough for a level; F5 / F6 / F2 fill health, hunger and stamina, with
## Shift 20 off; F4 empties overstimulation, with Shift 20 more.
func test_debug_keys(test) -> void:
	await _build_world()
	var money_key: Node = small_hud.get_node_or_null("Debugtoetsen")
	test.check(money_key != null, "de debugtoetsen hangen onder de HUD (debug)")
	if money_key == null:
		return
	var player_script := GDScript.new()
	player_script.source_code = DEBUG_PLAYER
	player_script.reload()
	var wallet := Node3D.new()
	wallet.set_script(player_script)
	small_hud.add_child(wallet)
	money_key.player = wallet
	menu.open("inventaris")
	await frames(2)
	await _press(KEY_F7)
	test.check(is_equal_approx(wallet.money, 15.0), "F7: €10 erbij (%.2f)" % wallet.money)
	await _press_debug(KEY_F7, true)
	test.check(is_equal_approx(wallet.money, 115.0), "Shift+F7: €100 erbij (%.2f)" % wallet.money)
	test.check(not wallet.earned.has(true), "telt niet als verdiend")
	await _press_debug(KEY_F9)
	test.check(is_equal_approx(wallet.xp, 100.0), "F9: 100 XP (%.0f)" % wallet.xp)
	await _press_debug(KEY_F9, true)
	test.check(wallet.level == 2 and is_equal_approx(wallet.xp, 0.0), "Shift+F9: precies een level (level %d, %.0f XP)" % [wallet.level, wallet.xp])
	# the rest with the mission picker open, which lists these keys
	var picker: CanvasLayer = small_hud.get_node("Missiekiezer")
	var stand_in_story := Node.new()
	var story_script := GDScript.new()
	story_script.source_code = STAND_IN_STORY
	story_script.reload()
	stand_in_story.set_script(story_script)
	small_hud.add_child(stand_in_story)
	picker.story = stand_in_story
	await _press(KEY_F8)
	test.check(picker.is_open(), "missiekiezer open")
	var help_lines := picker.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.text.begins_with("F5"))
	test.check(help_lines.size() == 1, "de kiezer toont de debugtoetsen (F5: %d regel)" % help_lines.size())
	await _press_debug(KEY_F5)
	test.check(wallet.stats.gezondheid == Vector2(80, 80), "F5 (kiezer open): gezondheid vol (%s)" % wallet.stats.gezondheid)
	await _press_debug(KEY_F5, true)
	test.check(wallet.stats.gezondheid == Vector2(60, 80), "Shift+F5: 20 eraf (%s)" % wallet.stats.gezondheid)
	await _press_debug(KEY_F6)
	test.check(wallet.stats.honger == Vector2(140, 140), "F6: honger vol (%s)" % wallet.stats.honger)
	await _press_debug(KEY_F6, true)
	test.check(wallet.stats.honger == Vector2(120, 140), "Shift+F6: 20 eraf (%s)" % wallet.stats.honger)
	await _press_debug(KEY_F2)
	test.check(wallet.stats.uithoudingsvermogen == Vector2(60, 60), "F2: uithoudingsvermogen vol (%s)" % wallet.stats.uithoudingsvermogen)
	await _press_debug(KEY_F2, true)
	test.check(wallet.stats.uithoudingsvermogen == Vector2(40, 60), "Shift+F2: 20 eraf (%s)" % wallet.stats.uithoudingsvermogen)
	await _press_debug(KEY_F4)
	test.check(wallet.stats.overprikkeldheid == Vector2(0, 100), "F4: overprikkeldheid leeg (%s)" % wallet.stats.overprikkeldheid)
	await _press_debug(KEY_F4, true)
	test.check(wallet.stats.overprikkeldheid == Vector2(20, 100), "Shift+F4: 20 erbij (%s)" % wallet.stats.overprikkeldheid)
	await _press(KEY_ESCAPE)
	menu.close()
	wallet.queue_free()
	stand_in_story.queue_free()


## A controller button pressed and let go (as from a Steam Deck), through the Controller
## autoload (scripts/ui/pad_keys.gd), which makes it the key the screens know.
func _press_pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		tree.root.push_input(event)
	# the key made of it goes through Input.parse_input_event: it arrives a few frames later
	await frames(6)


## With a controller: Back (Select) opens the game menu in the town, RB goes to the next tab,
## B closes it; Godot's ui_accept has no controller button left (it comes as Enter).
func test_game_menu_with_a_controller(test) -> void:
	await _build_world()
	test.check(tree.root.has_node("Controller"), "de controller-vertaler draait (autoload)")
	var accept_has_pad := InputMap.action_get_events("ui_accept").any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton)
	test.check(not accept_has_pad, "ui_accept zonder controllerknop (die komt als Enter)")
	var game_menu: Node = menu   # the menu of this small world (it takes the keys first)
	await _press_pad(JOY_BUTTON_BACK)
	test.check(game_menu.is_open() and game_menu.current_tab() == "inventaris", "Select opent het menu op de inventaris")
	await _press_pad(JOY_BUTTON_RIGHT_SHOULDER)
	test.check(game_menu.current_tab() == "quests", "RB: het volgende tabblad (%s)" % game_menu.current_tab())
	await _press_pad(JOY_BUTTON_LEFT_SHOULDER)
	test.check(game_menu.current_tab() == "inventaris", "LB: terug (%s)" % game_menu.current_tab())
	await _press_pad(JOY_BUTTON_B)
	test.check(not game_menu.is_open() and not tree.paused, "B sluit het menu")


## XP that makes a level up and the reward it came with: one screen, the level up with the
## XP on it ("+150 XP"); a reward of only XP is not shown on its own.
func test_xp_and_level_up_in_one_screen(test) -> void:
	await _build_world()
	var chosen: Array[String] = []
	small_hud.show_level_up(2, func(stat_name: String) -> void: chosen.append(stat_name), stand_in.stat)
	small_hud.show_reward({"heading": "TAAK VOLBRACHT", "title": "Blikjes", "xp": 150})
	await frames(3)
	test.check(not small_hud.is_showing_reward() and small_hud.rewards_waiting().is_empty(), "geen los XP-scherm")
	test.check(small_hud.is_showing_level_up(), "het level-up-scherm")
	var xp_label: Label = small_hud._level_up_screen._xp_label
	test.check(xp_label.visible and xp_label.text == "+150 XP", "met de XP erop (%s)" % xp_label.text)
	small_hud._level_up_screen._since = 1.0
	small_hud._level_up_screen.take()
	await frames(2)
	small_hud.show_level_up(3, func(stat_name: String) -> void: chosen.append(stat_name), stand_in.stat)
	small_hud.show_reward({"heading": "TAAK VOLBRACHT", "title": "Statiegeld", "xp": 40, "items": [{"item": "brood", "count": 1}]})
	await frames(3)
	var page: Dictionary = small_hud._reward_screen.current_page() if small_hud.is_showing_reward() else {}
	test.check(String(page.get("item", "")) == "brood" and int(page.get("xp", -1)) == 0, "met spullen: eerst de spullen, zonder XP (%s)" % [page])
	small_hud._reward_screen.next_page()
	await frames(3)
	test.check(small_hud.is_showing_level_up() and small_hud._level_up_screen._xp_label.text == "+40 XP", "dan het level up met de XP")
	small_hud._level_up_screen._since = 1.0
	small_hud._level_up_screen.take()
	await frames(2)


## The pause menu has INSTELLINGEN: the settings in its panel (anti-aliasing, render scale,
## CRT, the camera); the camera setting changes at once, Escape goes back to the pause menu.
func test_settings_in_the_pause_menu(test) -> void:
	await _build_world()
	var CameraTurning: GDScript = load("res://scripts/camera/camera_turning.gd")
	var was_manual: bool = CameraTurning.is_manual()
	small_hud.set_paused(true)
	var actions: Array = small_hud.PAUSE_ITEMS.map(func(item: Array) -> String: return item[1])
	small_hud._choose_pause_item(actions.find("settings"))
	await frames(2)
	var labels: Array = small_hud._pause_buttons.map(func(button: Button) -> String: return button.text.strip_edges().trim_prefix("→").strip_edges())
	test.check(small_hud._pause_in_settings and labels.any(func(text: String) -> bool: return text.begins_with("CAMERA")), "instellingen in het pauzemenu (%s)" % [labels])
	var camera_index: int = labels.map(func(text: String) -> bool: return text.begins_with("CAMERA")).find(true)
	small_hud._choose_pause_item(camera_index)
	await frames(1)
	test.check(CameraTurning.is_manual() != was_manual, "camera omgezet (%s)" % CameraTurning.label())
	test.check(small_hud._pause_buttons[camera_index].text.contains(CameraTurning.label()), "het knopje zegt het meteen")
	var back := InputEventKey.new()
	back.keycode = KEY_ESCAPE
	back.physical_keycode = KEY_ESCAPE
	back.pressed = true
	tree.root.push_input(back)
	await frames(2)
	test.check(not small_hud._pause_in_settings and tree.paused, "Escape: terug naar het pauzemenu, nog gepauzeerd")
	CameraTurning.set_manual(was_manual)
	small_hud.set_paused(false)


## Pockets full and a number from the machine of Burgerzaken: the slip gets a slot of its own on
## top (lit, not shut), and it does not count as room.
func test_a_slip_with_full_pockets(test) -> void:
	await _build_world()
	stand_in.inventory = {"brood": 1, "bier": 1, "hoed": 1, "statiegeld": 1, "appel": 1, "wachtnummer": 1}
	menu.open("inventaris")
	await frames(2)
	var at: int = menu._shown_items.find("wachtnummer")
	test.check(at >= 0, "het nummertje staat in de inventory")
	if at >= 0:
		test.check(menu._slots[at].modulate.a == 1.0, "in een gewoon vakje, niet op slot (vakje %d van %d)" % [at + 1, menu._slot_count()])
	test.check(menu._slots_used_label.text.begins_with("%d / " % menu._slot_count()) or menu._slots_used_label.text.begins_with("4 / "),
		"telt niet als ruimte (%s)" % menu._slots_used_label.text)
	menu.close()


## Debug: from the map to anywhere (GameMenu.teleport_to): the map's point and the town's agree
## both ways, and T on a chosen place puts the player there and closes the menu.
func test_teleport_from_the_map(test) -> void:
	await _open_on("kaart")
	var spot := Vector2(140, 60)
	var back: Vector2 = menu._map_to_world(menu._world_to_map(spot))
	test.check(back.distance_to(spot) < 0.01, "kaart en stad rekenen terug (%s)" % back)
	menu._choose_place("het_plein")
	await _press(KEY_T)
	test.check(Vector2(stand_in.global_position.x, stand_in.global_position.z).distance_to(Vector2(140, 60)) < 0.01,
		"T: de speler staat op Het Plein (%s)" % stand_in.global_position)
	test.check(not menu.is_open(), "en het menu is dicht")
