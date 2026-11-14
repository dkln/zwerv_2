class_name GameMenu
extends CanvasLayer
## The in-game menu over the city (a child of the HUD, scripts/ui/hud.gd), in the pixel
## style of the designs "Inventory & character", "Questlog" and "Wereldkaart" (1280 x 720,
## scales with the window like the HUD). Built entirely in code. Three tabs in a bar at the
## top ("[Q] INVENTARIS QUESTS KAART [E]", the open one filled amber):
## - INVENTARIS: the character on the left (name, level, subtitle of the archetype, the
##   figure in 3D, the four stats as segment bars), category buttons and a 6 x 5 grid of
##   the items in the middle (border in the colour of the rarity, count bottom right), the
##   chosen item on the right (rarity, name, kind, effects, text, use and drop buttons);
## - QUESTS: the quests of the HUD (hud.quests(), the format of set_quests) in two lists,
##   VERHAAL and ZIJMISSIES, the chosen one on the right with its steps and rewards;
##   Enter (or VOLGEN) follows the chosen quest (hud.track_quest): its places on the minimap
##   and the map, on top of the tracker;
## - KAART: the whole map of the HUD's minimap (hud.minimap_texture()) with the player as a
##   white triangle, the named places ("places" scene metadata) as markers that can be
##   chosen, the neighbourhoods not visited yet (hud.visited_areas()) under a fog, and the
##   places the followed quest sends you to (hud.quest_targets()) as amber diamonds; the
##   supermarkets in the colour and shape of their chain (SUPERMARKETS: DERREK a red
##   square, ALFRED STEYHN a light blue disc, as their emblems), also in neighbourhoods not
##   visited yet, so you can always find the nearest; the legend has them too; and so the
##   cash machines (Straatautomaten: CASH_MACHINE_COLOUR, PINPUNT yellow). Enter (or a
##   right click) sets the marker on the chosen place (GameHud.set_waypoint: a pink diamond
##   on the minimap and the map, a beam of light in the town, gone once you are there);
##   again: off.
## Keys: Tab opens the menu on the tab it was left on (the inventory the first time), I the
## inventory, J the quests, M the map; Q / E change tab; Tab or
## Escape closes; arrows / WASD and Enter choose; the mouse works too. While open the game
## stands still (the tree paused). It does not open while the pause menu has the game paused
## or while the player is dead.
## The player is the "Speler" node of the current scene (scripts/player/player_controller.gd:
## archetype_id, level, money, stat(name) -> Vector2(value, maximum), inventory,
## use_item(id), drop_item(id), is_dead(), signals inventory_changed and stats_changed);
## without it the menu shows the chosen archetype (PlayerCharacter) and its START_ITEMS.
## This script is the behaviour of the menu as a whole (docs/CODE_LAGEN.md): open and
## closed, the tab that is shown, the keys; it ties together the parts in
## scripts/ui/game_menu/: menu_rules.gd (its logic), menu_frame_view.gd (the frame and the
## tab bar, sizes in menu_frame_layout.gd), menu_player.gd (the player as the menu sees
## it) and the three tabs, each a behaviour with its own rules, layout and view:
## inventory_tab.gd, quest_tab.gd and map_tab.gd.

const MoneyText = preload("res://scripts/common/money_text.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const ItemLook = preload("res://scripts/ui/game_menu/item_look.gd")
const MenuRules = preload("res://scripts/ui/game_menu/menu_rules.gd")
const MenuPlayer = preload("res://scripts/ui/game_menu/menu_player.gd")
const MenuFrameLayout = preload("res://scripts/ui/game_menu/menu_frame_layout.gd")
const MenuFrameView = preload("res://scripts/ui/game_menu/menu_frame_view.gd")
const InventoryTab = preload("res://scripts/ui/game_menu/inventory_tab.gd")
const InventoryTabRules = preload("res://scripts/ui/game_menu/inventory_tab_rules.gd")
const QuestTab = preload("res://scripts/ui/game_menu/quest_tab.gd")
const MapTab = preload("res://scripts/ui/game_menu/map_tab.gd")
const MapTabRules = preload("res://scripts/ui/game_menu/map_tab_rules.gd")

## Size of the design; the menu is laid out at this size and scaled to the window.
const DESIGN_SIZE := MenuFrameLayout.DESIGN_SIZE
const TABS := MenuRules.TABS
## The pixel icons of the items, the icon of an item without one (by its kind) and the
## colours of the HUD's own icons: read by the shop screen and the station's shops.
const ITEM_ICONS := ItemLook.ITEM_ICONS
const KIND_ICONS := InventoryTabRules.KIND_ICONS
const HUD_ICON_COLOURS := ItemLook.HUD_ICON_COLOURS
## The layer of the menu: over the HUD (which puts it under itself for a story box).
const LAYER := 20

## Shut by the story until a mission opens it (Story "ontgrendelt": ["menu"], GameHud.set_menu_locked):
## then Tab, I, J and M do nothing.
var locked := false
## Its picture: the frame, the tab bar and the room for the tabs.
var view: MenuFrameView
## The player as the menu sees it (the "Speler" node, else the chosen archetype).
var player: MenuPlayer
## The three tabs.
var inventory_tab: InventoryTab
var quest_tab: QuestTab
var map_tab: MapTab

var _hud: Node
var _is_open := false
var _current_tab: String = MenuRules.FIRST_TAB
var _tabs := {}              # tab name -> its behaviour (inventory_tab, quest_tab, map_tab)


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	player = MenuPlayer.new()
	view = MenuFrameView.new()
	add_child(view)
	inventory_tab = InventoryTab.new()
	quest_tab = QuestTab.new()
	map_tab = MapTab.new()
	_tabs = {"inventaris": inventory_tab, "quests": quest_tab, "kaart": map_tab}
	for tab_name: String in TABS:
		view.add_tab(tab_name, MenuRules.TAB_TITLES[tab_name])
		view.add_page(_tabs[tab_name])
	inventory_tab.player = player
	map_tab.player = player
	view.tab_pressed.connect(_show_tab)
	view.close_pressed.connect(close)
	inventory_tab.changed.connect(_refresh)
	map_tab.teleported.connect(close)


func _ready() -> void:
	if get_parent() and get_parent().has_method("quests"):
		_hud = get_parent()
	player.hud = _hud
	quest_tab.hud = _hud
	map_tab.hud = _hud
	_show_bend()
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()


func _exit_tree() -> void:
	# the menu leaving the tree while open (a scene change) must not leave the game paused
	if _is_open and is_inside_tree():
		get_tree().paused = false
	_is_open = false


# ------------------------------------------------------------------ API

## Opens the menu on this tab ("inventaris", "quests" or "kaart"); when open already, goes
## to that tab. Does nothing while the game is paused by something else (the pause menu)
## or the player is dead.
func open(tab_name: String = MenuRules.FIRST_TAB) -> void:
	tab_name = MenuRules.valid_tab(tab_name)
	if not _is_open:
		if locked or get_tree().paused:
			return
		player.find_in(get_tree().current_scene, _refresh)
		if player.is_dead():
			return
		_is_open = true
		visible = true
		get_tree().paused = true
		UiSounds.play(self, "doe")
		inventory_tab.show_figure()
		_show_tab(tab_name, false)
		return
	_show_tab(tab_name)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	get_tree().paused = false
	UiSounds.play(self, "terug")
	# the 3D figure renders every frame: only while the menu is open
	inventory_tab.hide_figure()


func is_open() -> bool:
	return _is_open


## The tab shown (or shown last).
func current_tab() -> String:
	return _current_tab


## The marker on the chosen place of the map (GameHud.set_waypoint), or off again when it
## is there already (MapTab.toggle_marker).
func toggle_marker() -> void:
	map_tab.toggle_marker()


## Debug: the player to `spot` (world x, z) and the menu closed (MapTab.teleport_to).
func teleport_to(spot: Vector2) -> void:
	map_tab.teleport_to(spot)


## The chain of a supermarket place ("derrek_3" -> "derrek"), "" for any other place.
static func supermarket_chain(place_key: String) -> String:
	return MapTabRules.supermarket_chain(place_key)


## Whether a place of the map is a cash machine ("pinautomaat_3").
static func is_cash_machine(place_key: String) -> bool:
	return MapTabRules.is_cash_machine(place_key)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = (event as InputEventKey).keycode
	if not _is_open:
		if key == KEY_TAB:
			# where you left it (the tab shown last), the inventory the first time
			open(_current_tab)
		elif MenuRules.tab_for_key(key) != "":
			open(MenuRules.tab_for_key(key))
		else:
			return
		if _is_open:
			get_viewport().set_input_as_handled()
		return
	if MenuRules.is_close_key(key):
		close()
	elif MenuRules.tab_for_key(key) != "":
		_open_or_close(MenuRules.tab_for_key(key))
	elif MenuRules.tab_step(key) != 0:
		_show_tab(MenuRules.neighbour_tab(_current_tab, MenuRules.tab_step(key)))
	else:
		_tabs[_current_tab].handle_key(key)
	# while open no key reaches the game (nor the HUD's pause menu)
	if is_inside_tree():
		get_viewport().set_input_as_handled()


## The key of a tab while on it closes the menu, else goes there.
func _open_or_close(tab_name: String) -> void:
	if _current_tab == tab_name:
		close()
	else:
		_show_tab(tab_name)


# ------------------------------------------------------------------ tabs

func _show_tab(tab_name: String, with_sound := true) -> void:
	if with_sound and tab_name != _current_tab:
		UiSounds.play(self, "kies")
	_current_tab = tab_name
	for name_of_tab: String in TABS:
		(_tabs[name_of_tab] as Control).visible = name_of_tab == tab_name
	view.show_tab(tab_name)
	_refresh()
	if _is_open and _hud and _hud.has_signal("menu_opened"):
		_hud.menu_opened.emit(tab_name)


## Fills the open tab and the header from the player, the HUD and the scene.
func _refresh() -> void:
	if not _is_open:
		return
	view.show_money(MoneyText.amount(player.money()))
	var tab: Control = _tabs[_current_tab]
	tab.refresh()
	view.show_header(tab.header_text())


# ------------------------------------------------------------------ CRT and layout

## A slight bend over the menu, with the HUD's settings (the menu bends as little as the
## HUD itself does).
func _show_bend() -> void:
	var bend := Vector2(MenuRules.CURVATURE, MenuRules.CORNER)
	if _hud and "crt_ui_curvature" in _hud:
		bend = MenuRules.bend(_hud.crt_ui_curvature, _hud.crt_curvature, _hud.crt_corner)
	view.show_bend(bend.x, bend.y)


## Scales the design to the window (the smaller of the two ratios); the layout fills the
## window at that scale.
func _fit_to_window() -> void:
	view.fit(get_viewport().get_visible_rect().size)
