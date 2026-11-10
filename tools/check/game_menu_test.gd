extends SceneTree
## Opens the game menu (scripts/ui/game_menu.gd) headless under a real HUD in a small world
## of its own (scene metadata "places" and "wijken", a map picture, a stand-in player
## "Speler" with the player API): each tab, the keys, an item used and one dropped, the
## empty quest list, no opening while dead or paused, the menu without a player; closes
## without errors. Prints "spelmenu ok" or the problems.
## usage: tools/godot.sh --headless --script tools/check/game_menu_test.gd

const Common = preload("res://tools/tool_common.gd")
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

var _problems := []


func _init() -> void:
	Common.watchdog(self, 120)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok: ", what)
	else:
		print("  FOUT: ", what)
		_problems.append(what)


func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	get_root().push_input(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	get_root().push_input(release)
	await Common.wait_frames(self, 2)


func _run() -> void:
	var world := Node3D.new()
	world.name = "Wereld"
	world.set_meta("places", {"hoftoren": Vector2(100, 100), "het_plein": Vector2(140, 60),
			"verkeerslichten_test": Vector2(20, 20)})
	world.set_meta("wijken", [["Centrum", 0, 0, 29, 49], ["Laak", 30, 0, 49, 49], ["Den Haag", 0, 0, 49, 49]])
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(HUD_SCRIPT)
	world.add_child(hud)
	var player := Node3D.new()
	player.name = "Speler"
	var player_script := GDScript.new()
	player_script.source_code = STAND_IN_PLAYER
	player_script.reload()
	player.set_script(player_script)
	player.position = Vector3(100, 0, 100)
	world.add_child(player)
	get_root().add_child(world)
	current_scene = world
	await Common.wait_frames(self, 3)
	# a map picture of 50 x 50 cells of 4 m, as the HUD builds it from the Grond GridMap
	var image := Image.create(50, 50, false, Image.FORMAT_RGB8)
	image.fill(Color("#3A4A6E"))
	hud._minimap_map.texture = ImageTexture.create_from_image(image)
	hud._minimap_origin = Vector2.ZERO
	hud._minimap_cell = 4.0
	hud._visited_wijken = {"Centrum": true}
	hud.set_quests([
		{"kind": "verhaal", "label": "VERHAAL", "title": "Een dak boven je hoofd", "distance": "240M",
			"description": "Willem weet een portiek waar het droog blijft.",
			"steps": [{"text": "Praat met Willem", "done": true}, {"text": "Vind de portiek", "done": false}],
			"rewards": ["€ 5", "Slaapzak"]},
		{"kind": "zij", "label": "ZIJMISSIE", "title": "Statiegeld — 2/5"},
	])
	var menu: Node = MENU_SCRIPT.new()
	hud.add_child(menu)
	await Common.wait_frames(self, 2)

	print("inventaris")
	await _press(KEY_TAB)
	_check(menu.is_open() and paused, "Tab opent het menu en pauzeert")
	_check(menu.current_tab() == "inventaris", "op de inventaris")
	_check(menu._shown_items.size() == 4, "vier soorten spullen in het raster (%d)" % menu._shown_items.size())
	_check(menu._character_name.text == "Willem", "naam van het karakter: " + menu._character_name.text)
	_check(menu._character_line.text.begins_with("LV 3"), "niveau: " + menu._character_line.text)
	_check(menu._money_label.text == "12,00", "geld: " + menu._money_label.text)
	_check(menu._portrait != null, "figuur in 3D")
	menu._selected_item = "brood"
	menu._refresh()
	await _press(KEY_ENTER)
	_check(int(player.inventory.get("brood", 0)) == 1, "brood gegeten (nog %d)" % int(player.inventory.get("brood", 0)))
	_check(player.stats.honger.x == 35.0, "honger 10 + 25 = %d" % player.stats.honger.x)
	_check((menu._stat_texts["honger"] as Label).text == "35/80", "honger in de balk: " + (menu._stat_texts["honger"] as Label).text)
	menu._selected_item = "hoed"
	menu._refresh()
	await _press(KEY_X)
	_check(player.inventory.has("hoed"), "sleutelvoorwerp niet weg te gooien")
	menu._selected_item = "bier"
	menu._refresh()
	await _press(KEY_X)
	_check(not player.inventory.has("bier"), "bier weggegooid")
	await _press(KEY_2)
	_check(menu._category == "eten" and menu._shown_items == ["brood"], "categorie ETEN: %s" % [menu._shown_items])
	await _press(KEY_1)
	var before: String = menu._selected_item
	await _press(KEY_RIGHT)
	_check(menu._selected_item != before, "pijl rechts kiest het volgende vakje (%s -> %s)" % [before, menu._selected_item])

	print("quests")
	await _press(KEY_E)
	_check(menu.current_tab() == "quests", "E gaat naar de quests")
	_check(menu._quest_rows.get_child_count() == 1, "één verhaalopdracht in de lijst (%d)" % menu._quest_rows.get_child_count())
	_check(not menu._quest_empty.visible, "geen lege toestand")
	await _press(KEY_RIGHT)
	_check(menu._quest_kind == "zij", "pijl rechts: zijmissies")

	print("kaart")
	await _press(KEY_E)
	_check(menu.current_tab() == "kaart", "E gaat naar de kaart")
	_check(menu._places.size() == 2, "twee plekken (verkeerslichten niet): %d" % menu._places.size())
	_check(menu._selected_place == "hoftoren", "dichtstbijzijnde plek gekozen: " + menu._selected_place)
	_check(menu._map_picture.texture != null and menu._map_fog.texture != null, "kaart en mist")
	_check(menu._place_distance.text == "0 M", "afstand: " + menu._place_distance.text)
	_check(menu._header_info.text.contains("1 / 2"), "wijken ontdekt: " + menu._header_info.text)
	var fog: Image = menu._map_fog.texture.get_image()
	_check(fog.get_pixel(5, 5).a == 0.0 and fog.get_pixel(40, 5).a > 0.5, "mist alleen over de niet bezochte wijk")
	await _press(KEY_RIGHT)
	_check(menu._selected_place == "het_plein", "pijl rechts kiest de plek rechtsboven: " + menu._selected_place)
	_check(menu._place_name.text == "Het Plein", "naam van de plek: " + menu._place_name.text)
	await _press(KEY_Q)
	_check(menu.current_tab() == "quests", "Q gaat terug")

	print("sluiten")
	await _press(KEY_ESCAPE)
	_check(not menu.is_open() and not paused, "Escape sluit en gaat verder")
	_check(not hud._pause_layer.visible, "pauzemenu niet ook open")
	await _press(KEY_M)
	_check(menu.is_open() and menu.current_tab() == "kaart", "M opent de kaart")
	await _press(KEY_M)
	_check(not menu.is_open(), "M nog eens sluit")

	print("lege quests")
	hud.set_quests([])
	menu.open("quests")
	await Common.wait_frames(self, 2)
	_check(menu._quest_empty.visible and not menu._quest_detail.visible, "lege toestand")
	menu.close()

	print("niet openen")
	hud.set_paused(true)
	await _press(KEY_I)
	_check(not menu.is_open(), "niet open tijdens het pauzemenu")
	hud.set_paused(false)
	player.dead = true
	await _press(KEY_J)
	_check(not menu.is_open() and not paused, "niet open als de speler dood is")

	print("zonder speler")
	player.free()
	menu.open("inventaris")
	await Common.wait_frames(self, 2)
	_check(menu.is_open() and not menu._shown_items.is_empty(), "startspullen van het gekozen karakter: %s" % [menu._shown_items])
	var first_item: String = menu._shown_items[0]
	var count_before := int(menu._inventory().get(first_item, 0))
	menu._selected_item = first_item
	menu._use_selected()
	_check(int(menu._inventory().get(first_item, 0)) == count_before - 1 or not Items.can_use(first_item), "gebruikt zonder speler")
	menu.close()
	await Common.wait_frames(self, 2)
	world.queue_free()
	await Common.wait_frames(self, 2)
	print("spelmenu ok" if _problems.is_empty() else "spelmenu problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)

