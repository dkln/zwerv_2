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
