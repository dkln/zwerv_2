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

const MoneyText = preload("res://scripts/common/money_text.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const QuestMarks = preload("res://scripts/ui/widgets/quest_marks.gd")
## The colour of the XP a step gives (as the XP bar of the HUD).
const XP_TEXT_COLOUR := Color("#47D6C2")
const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")
const SegmentBar = preload("res://scripts/ui/widgets/segment_bar.gd")
const PlayerArrow = preload("res://scripts/ui/widgets/player_arrow.gd")
const PlayerPortrait = preload("res://scripts/ui/widgets/player_portrait.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const Items = preload("res://scripts/player/items.gd")
const BankCards = preload("res://scripts/player/bank_cards.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")

## Size of the design; the menu is laid out at this size and scaled to the window.
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const TAB_BAR_HEIGHT := 64.0
## Space left and right of a tab title, inside its amber background when chosen.
const TAB_PADDING_X := 18
const PAGE_MARGIN_X := 28
const PAGE_MARGIN_Y := 22
const PLAYER_NODE := "Speler"

const TABS := ["inventaris", "quests", "kaart"]
## Debug (debug builds only): on the map T takes the player to the chosen place (teleport_to);
## Shift+click anywhere on the map does the same for that spot.
const KEY_TELEPORT := KEY_T
const TAB_TITLES := {"inventaris": "INVENTARIS", "quests": "QUESTS", "kaart": "KAART"}

## Colours of the designs beyond the shared palette (UiStyle).
const RAISED := UiStyle.RAISED          # a chosen button or row
const SELECTED_SLOT := Color("#232A55")
const EMPTY_SLOT := Color("#10132A")
const EMPTY_BORDER := Color("#232850")
const SOFT_TEXT := Color("#C9CCE6")
const GOOD := Color("#8BE36B")
const BAD := Color("#FF5D73")

## The rarities of Items.ITEMS: what they are called and their colour.
const RARITIES := {
	"gewoon": {"label": "GEWOON", "colour": Color("#9AA0C8")},
	"bijzonder": {"label": "BIJZONDER", "colour": Color("#8BE36B")},
	"zeldzaam": {"label": "ZELDZAAM", "colour": Color("#5B8CFF")},
	"episch": {"label": "EPISCH", "colour": Color("#C08BFF")},
	"legendarisch": {"label": "LEGENDARISCH", "colour": Color("#FFB547")},
}
## The kinds of Items.ITEMS as shown under an item's name, and their order in the grid.
const KIND_NAMES := {"eten": "Eten", "drinken": "Drinken", "spullen": "Spullen", "sleutel": "Sleutelvoorwerp · niet weg te gooien"}
const KIND_ORDER := ["eten", "drinken", "spullen", "sleutel"]
## The category buttons over the grid: label and kind ("" = all).
const CATEGORIES := [["ALLES", ""], ["ETEN", "eten"], ["DRINKEN", "drinken"], ["SPULLEN", "spullen"], ["SLEUTEL", "sleutel"]]
const GRID_COLUMNS := 6
const GRID_ROWS := 5
const SLOT_SIZE := 69.0
const SLOT_GAP := 6
## How much of a shut slot shows (beyond the room the player has).
const LOCKED_SLOT_ALPHA := 0.3

## How the stats are called in the menu (the HUD's STATS give icon and colours), and the
## stats where less is better (a negative effect shows green).
const STAT_LABELS := {"gezondheid": "LEVEN", "uithoudingsvermogen": "STAMINA", "honger": "HONGER", "overprikkeldheid": "PRIKKELS"}
const LOWER_IS_BETTER := ["overprikkeldheid"]
const STAT_SEGMENTS := 24

## Pixel icons of the items ("#" = coloured; Items.ITEMS "icon"), drawn at 3 x 3 screen pixels
## per pixel in the grid; an icon not here comes from the HUD's PIXEL_ICONS, an item without
## one gets the icon of its kind (KIND_ICONS).
const ITEM_ICONS := {
	"ov_chipkaart": {"colour": Color("#4FA3E8"), "rows": ["##########", "#........#", "#.##.....#", "#.##..##.#", "#.....##.#", "#........#", "##########"]},
	"pinpas": {"colour": Color("#F2C230"), "rows": ["##########", "#........#", "#.##.....#", "#.##.....#", "#........#", "#.######.#", "##########"]},
	"kaartje": {"colour": Color("#E8E6F0"), "rows": ["########", "#......#", "#.####.#", "#......#", "#.##.#.#", "#......#", "########"]},
	"brood": {"colour": Color("#D9A55B"), "rows": [".#######.", "#########", "##.##.###", "#########", "#########", ".#######."]},
	"kroket": {"colour": Color("#B8692E"), "rows": [".........", "..#####..", ".#######.", ".#######.", ".#######.", "..#####..", "........."]},
	"patat": {"colour": Color("#F2C440"), "rows": ["..#.#.#..", ".#.#.#.#.", "..#####..", "..#####..", "...###...", "...###...", "....#...."]},
	"frikandel": {"colour": Color("#C0703A"), "rows": ["......##.", ".....###.", "....###..", "...###...", "..###....", ".###.....", ".##......"]},
	"appel": {"colour": Color("#FF5D73"), "rows": ["....#....", "...#.##..", ".###.###.", "#########", "#########", "#########", ".#######.", "..##.##.."]},
	"vis": {"colour": Color("#9AD0F0"), "rows": ["..####...#", ".######.##", "##.#######", "##########", ".######.##", "..####...#"]},
	"fles": {"colour": Color("#6FC3FF"), "rows": ["...###...", "...#.#...", "..#####..", ".#######.", ".#.....#.", ".#.....#.", ".#######.", ".#######."]},
	"blik": {"colour": Color("#E8C547"), "rows": [".#####.", "#######", "##...##", "#######", "##...##", "#######", ".#####."]},
	"kruik": {"colour": Color("#C9A76A"), "rows": ["...###...", "....#....", "..#####..", ".#######.", "#########", "#########", ".#######.", "..#####.."]},
	"shag": {"colour": Color("#7FB0A0"), "rows": ["#########", "#.......#", "#########", "#########", "##.#.#.##", "#########"]},
	"slaapzak": {"colour": Color("#5B8CFF"), "rows": ["..#####..", ".##...##.", "##.###.##", "##.#.#.##", "##.###.##", ".##...##.", "..#####.."]},
	"emmer": {"colour": Color("#6FC3FF"), "rows": ["..#####..", ".#.....#.", "#########", ".#######.", ".##...##.", ".#######.", "..#####.."]},
	"hengel": {"colour": Color("#C9A76A"), "rows": ["........#", ".......#.", "......#.#", ".....#..#", "....#...#", "...#....#", "..#....##", ".#.....##", "#........"]},
	"flessen": {"colour": Color("#6FC3FF"), "rows": ["..#...#..", "..#...#..", ".###.###.", ".###.###.", ".###.###.", ".###.###.", ".###.###."]},
	"hoed": {"colour": Color("#B5823A"), "rows": ["...###...", "..#####..", "..#####..", "#########", ".#######."]},
	"foto": {"colour": Color("#E8E6F0"), "rows": ["#########", "#.......#", "#..##...#", "#.####..#", "#.......#", "#########"]},
	"tas": {"colour": Color("#9AA0C8"), "rows": ["..###..", ".#...#.", "#######", "#######", "#######", "#######"]},
	"sleutel": {"colour": Color("#FFB547"), "rows": [".###......", "#...######", "#...#..#.#", ".###......"]},
	# the goods of the shops of Den Haag Centraal (the shop screen, scripts/ui/shop_screen.gd)
	"beker": {"colour": Color("#C9A76A"), "rows": [".#.#.#...", "..#.#....", "#######..", "#######.#", ".#####.##", ".#####.#.", "..###....", "..###...."]},
	"koek": {"colour": Color("#D9A55B"), "rows": ["..#####..", ".#######.", "####.####", "###...###", "####.####", ".#######.", "..#####.."]},
	"broodje": {"colour": Color("#E0B070"), "rows": ["..#####..", ".#######.", "#########", ".........", "#########", ".#######."]},
	"krant": {"colour": Color("#E8E6F0"), "rows": ["#########", "#.##.##.#", "#.......#", "#.###.#.#", "#.......#", "#.###.#.#", "#########"]},
	"bloem": {"colour": Color("#FF5D73"), "rows": [".#.#.#.", "#######", ".#####.", "..###..", "...#...", "..##...", "...#..."]},
	"boek": {"colour": Color("#5B8CFF"), "rows": ["#######.", "#.....##", "#.###.##", "#.....##", "#.###.##", "#.....##", "########"]},
	"kaart": {"colour": Color("#8BE36B"), "rows": ["##.##.##", "#.#..#.#", "##.##.##", "#.#..#.#", "##.##.##"]},
	"wafel": {"colour": Color("#D9A55B"), "rows": ["..#####..", ".#.#.#.#.", "#.#.#.#.#", "##.#.#.##", "#.#.#.#.#", ".#.#.#.#.", "..#####.."]},
	"snoep": {"colour": Color("#C08BFF"), "rows": ["#.......#", "##.###.##", "#########", "##.###.##", "#.......#"]},
	"reep": {"colour": Color("#8A5A3A"), "rows": ["#########", "##.##.###", "#########", "##.##.###", "#########"]},
}
const KIND_ICONS := {"eten": "brood", "drinken": "fles", "spullen": "tas", "sleutel": "sleutel"}
## Colours of the HUD's own icons when an item uses one.
const HUD_ICON_COLOURS := {"heart": Color("#FF5D73"), "bolt": Color("#8BE36B"), "chomp": Color("#FFB547"), "burst": Color("#C08BFF")}

## The quest lists: kind (as in set_quests) and the label of its button.
const QUEST_KINDS := [["verhaal", "VERHAAL"], ["zij", "ZIJMISSIES"]]

## The map: places in a visited neighbourhood and the others, the fog over the
## neighbourhoods not visited yet, and the name of the whole city (the "wijken" entry that
## covers everything; never fogged).
const PLACE_COLOUR := Color("#47D6C2")
const UNKNOWN_PLACE_COLOUR := Color("#5A6090")
## The supermarket chains on the map: the colour of the chain and whether its marker is round
## (the shape of its emblem), and the name in the place panel. Their places are "derrek",
## "derrek_2", ... (tools/build/city/map.gd _supermarket).
const SUPERMARKETS := {
	"derrek": {"colour": Color("#DE1828"), "round": false, "name": "DERREK"},
	"alfred_steyhn": {"colour": Color("#2CA8E4"), "round": true, "name": "ALFRED STEYHN"},
}
## The cash machines in the streets (the markers Geldautomaat_<n> under Straatautomaten,
## scripts/world/things/street_machines.gd) on the map, as places: in the yellow of PINPUNT, also in
## neighbourhoods not visited yet (so you can always find the nearest one to get money).
const CASH_MACHINE_NODE := "Straatautomaten"
const CASH_MACHINE_MARKER := "Geldautomaat"
const CASH_MACHINE_KEY := "pinautomaat_"
const CASH_MACHINE_COLOUR := Color("#F2B705")
const CASH_MACHINE_NAME := "Pinautomaat"
const FOG := Color(20.0 / 255.0, 24.0 / 255.0, 58.0 / 255.0, 0.86)
## How see-through the icon of an item you have not got is in the slot kept for it (the ID card).
const MISSING_ITEM_ALPHA := 0.25
const WHOLE_CITY := "Den Haag"
## Map cells are 4 m (the "wijken" table counts in cells).
const CELL_METRES := 4.0
## Screen pixels (design) within which a click picks a marker.
const MARKER_PICK_RADIUS := 14.0


## A box: a style box with a hard shadow down and to the right and, if set, a coloured strip
## on its left; its children fill it inside the style's content margins. Clickable (the
## `pressed` signal) when its mouse filter is STOP.
class Box extends Container:
	signal pressed

	var style: StyleBox:
		set(value):
			style = value
			update_minimum_size()
			queue_sort()
			queue_redraw()
	var shadow_offset := 0.0:
		set(value):
			shadow_offset = value
			queue_redraw()
	var shadow_colour := Color.BLACK:
		set(value):
			shadow_colour = value
			queue_redraw()
	var strip_colour := Color(0, 0, 0, 0):
		set(value):
			strip_colour = value
			queue_redraw()
	var strip_width := 0.0

	func _init(box_style: StyleBox = null) -> void:
		style = box_style if box_style else StyleBoxEmpty.new()
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			var top_left := Vector2(style.get_margin(SIDE_LEFT), style.get_margin(SIDE_TOP))
			var inner := Rect2(top_left, (size - style.get_minimum_size()).max(Vector2.ZERO))
			for child in get_children():
				if child is Control and not (child as Control).top_level:
					fit_child_in_rect(child, inner)

	func _get_minimum_size() -> Vector2:
		var largest := Vector2.ZERO
		for child in get_children():
			if child is Control and (child as Control).visible and not (child as Control).top_level:
				largest = largest.max((child as Control).get_combined_minimum_size())
		return largest + style.get_minimum_size()

	func _draw() -> void:
		if shadow_offset > 0.0:
			draw_rect(Rect2(Vector2.ONE * shadow_offset, size), shadow_colour)
		draw_style_box(style, Rect2(Vector2.ZERO, size))
		if strip_width > 0.0 and strip_colour.a > 0.0:
			draw_rect(Rect2(Vector2.ZERO, Vector2(strip_width, size.y)), strip_colour)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			pressed.emit()


var _hud: Node
var _player: Node
var _is_open := false
## Shut by the story until a mission opens it (Story "ontgrendelt": ["menu"], GameHud.set_menu_locked):
## then Tab, I, J and M do nothing.
var locked := false
var _current_tab := "inventaris"

var _font_title: Font        # Pixelify Sans, bold
var _font_title_spaced: Font # Pixelify Sans, bold, 1 px between letters
var _font_title_medium: Font # Pixelify Sans, semibold
var _font_pixel: Font        # Silkscreen
var _font_pixel_bold: Font   # Silkscreen bold
var _font_body: Font         # JetBrains Mono
var _font_body_bold: Font    # JetBrains Mono, semibold
var _font_italic: Font       # JetBrains Mono, slanted

var _background: ColorRect
var _root: Control
var _crt_overlay: ColorRect
var _tab_boxes := {}         # tab name -> Box
var _tab_labels := {}        # tab name -> Label
var _pages := {}             # tab name -> Control
var _header_info: Label
var _money_label: Label

# inventory
var _fallback_inventory := {}   # item id -> count, when there is no player
var _fallback_stats := {}       # stat name -> Vector2(value, maximum), when there is no player or HUD
var _category := ""
var _selected_item := ""
var _shown_items: Array[String] = []
var _character_name: Label
var _character_line: Label
var _portrait_holder: Control
var _portrait: PlayerPortrait
var _stat_bars := {}            # stat name -> SegmentBar
var _stat_texts := {}           # stat name -> Label
var _category_boxes: Array[Box] = []
var _category_labels: Array[Label] = []
var _slots: Array[Box] = []
var _slot_icons: Array[PixelIcon] = []
var _slot_counts: Array[Label] = []
var _slots_used_label: Label
var _detail_box: Box
var _detail_icon_box: Box
var _detail_icon: PixelIcon
var _detail_rarity: Label
var _detail_name: Label
var _detail_kind: Label
var _detail_lines_box: Box
var _detail_lines: VBoxContainer
var _detail_text: Label
var _detail_empty: Label
var _detail_buttons: HBoxContainer
var _action_box: Box
var _action_label: Label
var _drop_box: Box
var _drop_label: Label

# quests
var _quest_kind := "verhaal"
var _selected_quest := 0
var _quest_kind_boxes := {}     # kind -> Box
var _quest_kind_labels := {}    # kind -> Label
var _quest_rows: VBoxContainer
var _quest_detail: Box
var _quest_detail_column: VBoxContainer
var _quest_empty: Box
var _quest_content: HBoxContainer

# map
var _map_clip: Control
var _map_picture: TextureRect
var _map_fog: TextureRect
var _map_overlay: Control
var _map_arrow: PlayerArrow
var _map_waiting: Label
var _map_coordinates: Label
var _map_coordinates_box: Box
var _map_north: Box
var _map_scale := 1.0
var _map_offset := Vector2.ZERO
var _places: Array[Dictionary] = []   # {"key", "name", "position": Vector2 world x, z, "wijk"}
var _selected_place := ""
var _visited := {}                    # wijk name -> true
var _place_box: Box
var _place_kind: Label
var _place_name: Label
var _place_wijk: Label
var _place_distance: Label
var _place_state: Label
var _place_marker: Label     # whether the marker is on the chosen place, and how to set it
var _here_wijk: Label
var _here_street: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if get_parent() and get_parent().has_method("quests"):
		_hud = get_parent()
	_load_fonts()
	_background = ColorRect.new()
	_background.name = "Achtergrond"
	_background.color = UiStyle.INK
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_background)
	_root = Control.new()
	_root.name = "Ontwerp"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(column)
	column.add_child(_build_tab_bar())
	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(pages)
	_pages["inventaris"] = _build_inventory_page()
	_pages["quests"] = _build_quest_page()
	_pages["kaart"] = _build_map_page()
	for tab_name: String in TABS:
		pages.add_child(_pages[tab_name])
	_build_crt()
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
func open(tab_name: String = "inventaris") -> void:
	if not TABS.has(tab_name):
		tab_name = "inventaris"
	if not _is_open:
		if locked or get_tree().paused:
			return
		_find_player()
		if _player and _player.has_method("is_dead") and _player.is_dead():
			return
		_is_open = true
		visible = true
		get_tree().paused = true
		UiSounds.play(self, "doe")
		_make_portrait()
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
	if _portrait:
		_portrait.queue_free()
		_portrait = null


func is_open() -> bool:
	return _is_open


## The tab shown (or shown last).
func current_tab() -> String:
	return _current_tab


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = (event as InputEventKey).keycode
	if not _is_open:
		match key:
			KEY_TAB:
				# where you left it (the tab shown last), the inventory the first time
				open(_current_tab if TABS.has(_current_tab) else "inventaris")
			KEY_I:
				open("inventaris")
			KEY_J:
				open("quests")
			KEY_M:
				open("kaart")
			_:
				return
		if _is_open:
			get_viewport().set_input_as_handled()
		return
	match key:
		KEY_TAB, KEY_ESCAPE:
			close()
		KEY_I:
			_open_or_close("inventaris")
		KEY_J:
			_open_or_close("quests")
		KEY_M:
			_open_or_close("kaart")
		KEY_Q:
			_show_tab(TABS[posmod(TABS.find(_current_tab) - 1, TABS.size())])
		KEY_E:
			_show_tab(TABS[posmod(TABS.find(_current_tab) + 1, TABS.size())])
		_:
			match _current_tab:
				"inventaris":
					_inventory_key(key)
				"quests":
					_quest_key(key)
				"kaart":
					_map_key(key)
	# while open no key reaches the game (nor the HUD's pause menu)
	if is_inside_tree():
		get_viewport().set_input_as_handled()


## The key of a tab while on it closes the menu, else goes there.
func _open_or_close(tab_name: String) -> void:
	if _current_tab == tab_name:
		close()
	else:
		_show_tab(tab_name)


## A direction from the arrows or WASD, else Vector2i.ZERO.
static func _direction(key: Key) -> Vector2i:
	match key:
		KEY_LEFT, KEY_A:
			return Vector2i.LEFT
		KEY_RIGHT, KEY_D:
			return Vector2i.RIGHT
		KEY_UP, KEY_W:
			return Vector2i.UP
		KEY_DOWN, KEY_S:
			return Vector2i.DOWN
	return Vector2i.ZERO


static func _is_accept(key: Key) -> bool:
	return key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]


func _inventory_key(key: Key) -> void:
	var direction := _direction(key)
	if direction != Vector2i.ZERO:
		_move_item_selection(direction)
	elif _is_accept(key):
		_use_selected()
	elif key in [KEY_X, KEY_DELETE, KEY_BACKSPACE]:
		_drop_selected()
	elif key >= KEY_1 and key < KEY_1 + CATEGORIES.size():
		_choose_category(CATEGORIES[key - KEY_1][1])


func _quest_key(key: Key) -> void:
	var direction := _direction(key)
	if direction.x != 0:
		var index := posmod(_quest_kind_index() + direction.x, QUEST_KINDS.size())
		_choose_quest_kind(QUEST_KINDS[index][0])
	elif direction.y != 0:
		var count := _quests_of_kind(_quest_kind).size()
		if count > 0:
			var index := clampi(_selected_quest + direction.y, 0, count - 1)
			if index != _selected_quest:
				UiSounds.play(self, "kies")
				_selected_quest = index
				_refresh_quests()
	elif _is_accept(key):
		_track_selected_quest()


## Follows the chosen quest (GameHud.track_quest).
func _track_selected_quest() -> void:
	var quests := _quests_of_kind(_quest_kind)
	if quests.is_empty() or _hud == null or not _hud.has_method("track_quest"):
		return
	var id: String = GameHud.quest_id(quests[_selected_quest])
	if id == _tracked_id():
		return
	if GameHud.is_quest_done(quests[_selected_quest]):
		UiSounds.play(self, "terug")   # done: nothing left to follow
		return
	UiSounds.play(self, "doe")
	_hud.track_quest(id)
	_refresh_quests()


func _tracked_id() -> String:
	return _hud.tracked_quest_id() if _hud and _hud.has_method("tracked_quest_id") else ""


func _map_key(key: Key) -> void:
	var direction := _direction(key)
	if key == KEY_TELEPORT and OS.is_debug_build():
		var place := _place(_selected_place)
		if not place.is_empty():
			teleport_to(place.position)
		return
	if direction != Vector2i.ZERO:
		_move_place_selection(Vector2(direction))
	elif _is_accept(key):
		toggle_marker()


## The marker on the chosen place (GameHud.set_waypoint: on the minimap and as a beam of
## light in the town), or off again when it is there already.
func toggle_marker() -> void:
	var place := _place(_selected_place)
	if place.is_empty() or _hud == null or not _hud.has_method("set_waypoint"):
		return
	if _hud.has_waypoint() and (_hud.waypoint() as Vector2).is_equal_approx(place.position):
		_hud.clear_waypoint()
		UiSounds.play(self, "terug")
	else:
		var chain := supermarket_chain(place.key)
		_hud.set_waypoint(place.position, String(SUPERMARKETS[chain].name) if chain != "" else String(place.name))
		UiSounds.play(self, "doe")
	_fill_place_panel()
	_map_overlay.queue_redraw()


func _marker_on(place: Dictionary) -> bool:
	return _hud != null and _hud.has_method("has_waypoint") and _hud.has_waypoint() \
		and (_hud.waypoint() as Vector2).is_equal_approx(place.position)


# ------------------------------------------------------------------ tabs

func _show_tab(tab_name: String, with_sound := true) -> void:
	if with_sound and tab_name != _current_tab:
		UiSounds.play(self, "kies")
	_current_tab = tab_name
	for name_of_tab: String in TABS:
		var on := name_of_tab == tab_name
		(_pages[name_of_tab] as Control).visible = on
		(_tab_boxes[name_of_tab] as Box).style = _style(UiStyle.ACCENT if on else Color(0, 0, 0, 0), UiStyle.ACCENT, 0, TAB_PADDING_X)
		var tab_label: Label = _tab_labels[name_of_tab]
		tab_label.add_theme_font_override("font", _font_title if on else _font_title_medium)
		tab_label.add_theme_color_override("font_color", UiStyle.INK if on else UiStyle.TEXT)
	_refresh()
	if _is_open and _hud and _hud.has_signal("menu_opened"):
		_hud.menu_opened.emit(tab_name)


## Fills the open tab and the header from the player, the HUD and the scene.
func _refresh() -> void:
	if not _is_open:
		return
	_money_label.text = MoneyText.amount(_money())
	match _current_tab:
		"inventaris":
			_header_info.text = "%d SPULLEN BIJ JE" % _item_total()
			_refresh_inventory()
		"quests":
			_header_info.text = "%d VERHAAL · %d ZIJMISSIES" % [_quests_of_kind("verhaal").size(), _quests_of_kind("zij").size()]
			_refresh_quests()
		"kaart":
			_refresh_map()


# ------------------------------------------------------------------ the player

## The "Speler" node of the current scene (looked up on each opening: it may come later
## than the HUD), and its signals.
func _find_player() -> void:
	var scene := get_tree().current_scene
	var found: Node = scene.get_node_or_null(PLAYER_NODE) if scene else null
	if found != _player:
		_player = found
		if _player:
			for signal_name in ["inventory_changed", "stats_changed"]:
				if _player.has_signal(signal_name) and not _player.is_connected(signal_name, _refresh):
					_player.connect(signal_name, _refresh)
	if _player == null and _fallback_inventory.is_empty():
		_fallback_inventory = Items.START_ITEMS.get(PlayerCharacter.current_id(), {}).duplicate()


func _archetype_id() -> String:
	if _player and "archetype_id" in _player and PlayerCharacter.ARCHETYPES.has(_player.archetype_id):
		return _player.archetype_id
	return PlayerCharacter.current_id()


func _archetype() -> Dictionary:
	return PlayerCharacter.ARCHETYPES[_archetype_id()]


func _level() -> int:
	if _player and "level" in _player:
		return int(_player.level)
	if _hud and "player_level" in _hud:
		return int(_hud.player_level)
	return int(_archetype().get("level", 1))


func _money() -> float:
	if _player and "money" in _player:
		return float(_player.money)
	return float(_archetype().get("start_money", 0))


## A stat as Vector2(value, maximum): from the player, else the HUD, else the archetype
## (hunger and overstimulation start empty, as in the HUD).
func _stat(stat_name: String) -> Vector2:
	if _player and _player.has_method("stat"):
		return _player.stat(stat_name)
	if _fallback_stats.has(stat_name):
		return _fallback_stats[stat_name]
	if _hud and _hud.has_method("get_stat"):
		var from_hud: Vector2 = _hud.get_stat(stat_name)
		if from_hud.y > 0.0:
			return from_hud
	var maximum := float(_archetype().stats.get(stat_name, 100))
	return Vector2(0.0 if stat_name in ["honger", "overprikkeldheid"] else maximum, maximum)


func _inventory() -> Dictionary:
	if _player and "inventory" in _player:
		return _player.inventory
	return _fallback_inventory


## How many kinds of item the player has room for (Items.BASE_SLOTS, more with a rucksack).
func _slot_count() -> int:
	if _player and _player.has_method("inventory_slots"):
		return mini(int(_player.inventory_slots()), GRID_COLUMNS * GRID_ROWS)
	return Items.BASE_SLOTS


## Whether the player wears a coat (Items "worn"): its pockets give more room.
func _has_coat() -> bool:
	if _player == null or not ("inventory" in _player):
		return false
	for item_id: String in _player.inventory:
		if Items.is_worn(item_id):
			return true
	return false


func _item_total() -> int:
	var total := 0
	for item_id: String in _inventory():
		total += int(_inventory()[item_id])
	return total


# ------------------------------------------------------------------ building

func _load_fonts() -> void:
	var fonts := UiStyle.fonts()
	_font_title = fonts.title
	_font_title_medium = fonts.title_medium
	_font_pixel = fonts.pixel
	_font_pixel_bold = fonts.pixel_bold
	_font_body = fonts.body
	var body := UiStyle.font(UiStyle.FONT_BODY)
	_font_body_bold = UiStyle.weighted(body, 600)
	var slanted := UiStyle.weighted(body, 400) as FontVariation
	# FreeType's xy: the top of a glyph leans to the right (a faux italic)
	slanted.variation_transform = Transform2D(Vector2(1.0, 0.2), Vector2(0.0, 1.0), Vector2.ZERO)
	_font_italic = slanted
	_font_title_spaced = UiStyle.spaced(_font_title, 1)


## A flat style: background, a border of `border_width` all round, content margins.
static func _style(background: Color, border: Color, border_width: int, margin_x := 0, margin_y := 0) -> StyleBoxFlat:
	var style := UiStyle.box_style(background, border, border_width)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	return style


func _box(style: StyleBox, shadow := 0.0, clickable := false) -> Box:
	var box := Box.new(style)
	box.shadow_offset = shadow
	if clickable:
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return box


func _vbox(separation: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return column


func _hbox(separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


func _spacer(vertical := true) -> Control:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical:
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


## A page under the tab bar: its margins and, at the bottom, a line of keys.
func _page(page_name: String, keys: String) -> Array:
	var margins := MarginContainer.new()
	margins.name = page_name
	margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margins.add_theme_constant_override("margin_left", PAGE_MARGIN_X)
	margins.add_theme_constant_override("margin_right", PAGE_MARGIN_X)
	margins.add_theme_constant_override("margin_top", PAGE_MARGIN_Y)
	margins.add_theme_constant_override("margin_bottom", 14)
	var column := _vbox(12)
	margins.add_child(column)
	var content := _hbox(24)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	column.add_child(UiStyle.label(keys, _font_pixel, 10, UiStyle.MUTED))
	return [margins, content]


func _build_tab_bar() -> Control:
	var style := StyleBoxFlat.new()
	style.bg_color = UiStyle.PANEL
	style.border_color = UiStyle.BORDER
	style.border_width_bottom = 3
	style.anti_aliasing = false
	style.content_margin_left = PAGE_MARGIN_X
	style.content_margin_right = PAGE_MARGIN_X
	var bar := _box(style)
	bar.name = "Tabs"
	bar.custom_minimum_size = Vector2(0, TAB_BAR_HEIGHT + 3)
	var row := _hbox(4)
	bar.add_child(row)
	var left_key := UiStyle.label("[Q]", _font_pixel, 11, UiStyle.MUTED)
	left_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_key.custom_minimum_size = Vector2(32, 0)
	row.add_child(left_key)
	for tab_name: String in TABS:
		var tab := _box(_style(Color(0, 0, 0, 0), UiStyle.ACCENT, 0, TAB_PADDING_X), 0.0, true)
		var tab_label := UiStyle.label(TAB_TITLES[tab_name], _font_title_medium, 18)
		tab_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tab.add_child(tab_label)
		tab.pressed.connect(func() -> void: _show_tab(tab_name))
		row.add_child(tab)
		_tab_boxes[tab_name] = tab
		_tab_labels[tab_name] = tab_label
	var right_key := UiStyle.label("[E]", _font_pixel, 11, UiStyle.MUTED)
	right_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_key.custom_minimum_size = Vector2(32, 0)
	right_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(right_key)
	row.add_child(_spacer(false))
	_header_info = UiStyle.label("", UiStyle.spaced(_font_pixel, 2), 11, UiStyle.MUTED)
	_header_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_header_info)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(18, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	# the money as in the HUD: a pixel euro sign and euros to the cent
	var coin := PixelIcon.new()
	coin.bitmap = ["...####", "..#....", "######.", ".#.....", "######.", "..#....", "...####"]
	coin.colour = UiStyle.ACCENT
	coin.pixel = 14.0 / 7.0
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	_money_label = UiStyle.label("0", _font_pixel, 13)
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_money_label)
	var gap_after := gap.duplicate() as Control
	row.add_child(gap_after)
	var close_box := _box(_style(UiStyle.INK, UiStyle.BORDER, 2, 10, 6), 0.0, true)
	close_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_box.add_child(UiStyle.label("[ESC] SLUITEN", _font_pixel, 10, UiStyle.MUTED))
	close_box.pressed.connect(close)
	row.add_child(close_box)
	return bar


# ------------------------------------------------------------------ inventory page

func _build_inventory_page() -> Control:
	var parts := _page("Inventaris", "[←↑↓→] KIEZEN   [ENTER] GEBRUIKEN   [X] WEGGOOIEN   [1-5] SOORT   [Q/E] TAB   [TAB] SLUITEN")
	var content: HBoxContainer = parts[1]
	content.add_child(_build_character_column())
	content.add_child(_build_item_grid())
	content.add_child(_build_item_detail())
	return parts[0]


func _build_character_column() -> Control:
	var column := _vbox(14)
	column.custom_minimum_size = Vector2(320, 0)
	var card := _box(_style(UiStyle.PANEL, UiStyle.BORDER, 3, 16, 16), UiStyle.SHADOW_OFFSET)
	column.add_child(card)
	var card_column := _vbox(6)
	card.add_child(card_column)
	_character_name = UiStyle.label("", _font_title, 24)
	card_column.add_child(_character_name)
	_character_line = UiStyle.label("", _font_pixel, 11, UiStyle.ACCENT)
	_character_line.clip_text = true
	_character_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card_column.add_child(_character_line)
	# the figure in 3D on ink (made on opening, see _make_portrait)
	var figure_frame := _box(_style(UiStyle.INK, UiStyle.BORDER, 2))
	figure_frame.custom_minimum_size = Vector2(0, 196)
	_portrait_holder = Control.new()
	_portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_holder.clip_contents = true
	figure_frame.add_child(_portrait_holder)
	var spacing := Control.new()
	spacing.custom_minimum_size = Vector2(0, 6)
	spacing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_column.add_child(spacing)
	card_column.add_child(figure_frame)
	var stats := _box(_style(UiStyle.PANEL, UiStyle.BORDER, 2, 16, 14))
	column.add_child(stats)
	var stats_column := _vbox(9)
	stats.add_child(stats_column)
	stats_column.add_child(UiStyle.label("TOESTAND", UiStyle.spaced(_font_pixel, 2), 11, UiStyle.MUTED))
	for stat_name: String in GameHud.STATS:
		var stat: Dictionary = GameHud.STATS[stat_name]
		var stat_column := _vbox(4)
		var heading := _hbox(8)
		var icon := PixelIcon.new()
		icon.bitmap = GameHud.PIXEL_ICONS[stat.icon]
		icon.colour = stat.colour
		icon.pixel = 2.0
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		heading.add_child(icon)
		var stat_label := UiStyle.label(STAT_LABELS.get(stat_name, stat_name.to_upper()), _font_pixel, 12)
		stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(stat_label)
		var value_text := UiStyle.label("", _font_pixel, 12, SOFT_TEXT)
		heading.add_child(value_text)
		stat_column.add_child(heading)
		var bar := SegmentBar.new()
		bar.segments = STAT_SEGMENTS
		bar.segment_height = 8
		bar.full_colour = stat.colour
		bar.empty_colour = stat.empty
		stat_column.add_child(bar)
		stats_column.add_child(stat_column)
		_stat_bars[stat_name] = bar
		_stat_texts[stat_name] = value_text
	return column


func _build_item_grid() -> Control:
	var column := _vbox(12)
	var buttons := _hbox(6)
	column.add_child(buttons)
	for category: Array in CATEGORIES:
		var button := _box(_style(UiStyle.INK, UiStyle.BORDER, 2, 12, 4), 0.0, true)
		button.custom_minimum_size = Vector2(0, 36)
		var button_label := UiStyle.label(category[0], _font_pixel, 11, UiStyle.MUTED)
		button_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_child(button_label)
		var kind: String = category[1]
		button.pressed.connect(func() -> void: _choose_category(kind))
		buttons.add_child(button)
		_category_boxes.append(button)
		_category_labels.append(button_label)
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", SLOT_GAP)
	grid.add_theme_constant_override("v_separation", SLOT_GAP)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(grid)
	for slot_index in GRID_COLUMNS * GRID_ROWS:
		var slot := _box(_style(EMPTY_SLOT, EMPTY_BORDER, 2), 0.0, true)
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.strip_width = 0.0
		var centre := CenterContainer.new()
		centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := PixelIcon.new()
		icon.pixel = 3.0
		centre.add_child(icon)
		slot.add_child(centre)
		var count := UiStyle.label("", _font_pixel, 10)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.add_theme_constant_override("line_spacing", 0)
		slot.add_child(count)
		slot.style = _style(EMPTY_SLOT, EMPTY_BORDER, 2, 4, 1)
		slot.pressed.connect(func() -> void: _click_slot(slot_index))
		# hovering shows it on the right too (a found bank card: the riddle of its PIN)
		slot.mouse_entered.connect(func() -> void: _click_slot(slot_index))
		grid.add_child(slot)
		_slots.append(slot)
		_slot_icons.append(icon)
		_slot_counts.append(count)
	_slots_used_label = UiStyle.label("", _font_pixel, 10, UiStyle.MUTED)
	column.add_child(_slots_used_label)
	return column


func _build_item_detail() -> Control:
	_detail_box = _box(_style(UiStyle.PANEL, UiStyle.BORDER, 3, 20, 20), UiStyle.SHADOW_OFFSET)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := _vbox(12)
	_detail_box.add_child(column)
	var heading := _hbox(14)
	column.add_child(heading)
	_detail_icon_box = _box(_style(UiStyle.INK, UiStyle.BORDER, 2))
	_detail_icon_box.custom_minimum_size = Vector2(72, 72)
	_detail_icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_icon = PixelIcon.new()
	_detail_icon.pixel = 4.0
	centre.add_child(_detail_icon)
	_detail_icon_box.add_child(centre)
	heading.add_child(_detail_icon_box)
	var names := _vbox(4)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_child(names)
	_detail_rarity = UiStyle.label("", UiStyle.spaced(_font_pixel, 2), 11)
	names.add_child(_detail_rarity)
	_detail_name = UiStyle.label("", _font_title, 22)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(_detail_name)
	_detail_kind = UiStyle.label("", _font_body, 12, UiStyle.MUTED)
	names.add_child(_detail_kind)
	# the effects between two lines
	var lines_style := StyleBoxFlat.new()
	lines_style.bg_color = Color(0, 0, 0, 0)
	lines_style.border_color = UiStyle.BORDER
	lines_style.border_width_top = 2
	lines_style.border_width_bottom = 2
	lines_style.content_margin_top = 10
	lines_style.content_margin_bottom = 10
	lines_style.anti_aliasing = false
	_detail_lines_box = _box(lines_style)
	_detail_lines = _vbox(6)
	_detail_lines_box.add_child(_detail_lines)
	column.add_child(_detail_lines_box)
	_detail_text = UiStyle.label("", _font_italic, 13, SOFT_TEXT)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.add_theme_constant_override("line_spacing", 5)
	column.add_child(_detail_text)
	_detail_empty = UiStyle.label("Je zakken zijn leeg.", _font_italic, 13, UiStyle.MUTED)
	_detail_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail_empty)
	column.add_child(_spacer())
	_detail_buttons = _hbox(8)
	column.add_child(_detail_buttons)
	_action_box = _box(_style(UiStyle.ACCENT, UiStyle.ACCENT, 0, 14), 3.0, true)
	_action_box.custom_minimum_size = Vector2(0, 44)
	_action_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_label = UiStyle.label("", _font_pixel_bold, 12, UiStyle.INK)
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_box.add_child(_action_label)
	_action_box.pressed.connect(_use_selected)
	_detail_buttons.add_child(_action_box)
	_drop_box = _box(_style(UiStyle.PANEL, UiStyle.BORDER, 2, 14), 0.0, true)
	_drop_box.custom_minimum_size = Vector2(0, 44)
	_drop_label = UiStyle.label("WEGGOOIEN", _font_pixel, 12)
	_drop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drop_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_drop_box.add_child(_drop_label)
	_drop_box.pressed.connect(_drop_selected)
	_detail_buttons.add_child(_drop_box)
	return _detail_box


## The chosen figure (PlayerPortrait), whole and turning slowly; made on opening (it
## renders every frame) and when the archetype changed.
func _make_portrait() -> void:
	var archetype_id := _archetype_id()
	if _portrait and _portrait.archetype_id == archetype_id:
		return
	if _portrait:
		_portrait.queue_free()
	_portrait = PlayerPortrait.new()
	_portrait.name = "Figuur"
	_portrait.archetype_id = archetype_id
	_portrait.zoom = 0.0
	_portrait.spin = 22.0
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_holder.add_child(_portrait)


# ------------------------------------------------------------------ inventory

func _refresh_inventory() -> void:
	var archetype := _archetype()
	_character_name.text = archetype.name
	_character_line.text = "LV %d · %s" % [_level(), archetype.subtitle]
	_make_portrait()
	for stat_name: String in _stat_bars:
		var value := _stat(stat_name)
		var maximum := maxf(value.y, 1.0)
		(_stat_bars[stat_name] as SegmentBar).fill = value.x / maximum
		(_stat_texts[stat_name] as Label).text = "%d/%d" % [roundi(value.x), roundi(value.y)]
	for category_index in CATEGORIES.size():
		var on: bool = CATEGORIES[category_index][1] == _category
		_category_boxes[category_index].style = _style(RAISED if on else UiStyle.INK, UiStyle.ACCENT if on else UiStyle.BORDER, 2, 12, 4)
		_category_labels[category_index].add_theme_color_override("font_color", UiStyle.TEXT if on else UiStyle.MUTED)
	_shown_items = _items_in_category(_category)
	if not _shown_items.has(_selected_item):
		_selected_item = _shown_items[0] if not _shown_items.is_empty() else ""
	var inventory := _inventory()
	# what takes no room (the slip of Burgerzaken, the cans and bottles in the bag) gets a slot
	# of its own for as long as it is there, on top of the room (not counted as room)
	var lit_slots := _slot_count() + _shown_items.filter(func(item_id: String) -> bool:
		return int(inventory.get(item_id, 0)) > 0 and not Items.takes_slot(item_id)).size()
	for slot_index in _slots.size():
		var slot := _slots[slot_index]
		var icon := _slot_icons[slot_index]
		var count := _slot_counts[slot_index]
		# the slots beyond the room it has (no coat: only the pockets) are shut
		slot.modulate.a = 1.0 if slot_index < lit_slots else LOCKED_SLOT_ALPHA
		if slot_index >= _shown_items.size():
			slot.style = _style(EMPTY_SLOT, EMPTY_BORDER, 2, 4, 1)
			slot.shadow_offset = 0.0
			icon.bitmap = []
			icon.modulate.a = 1.0
			count.text = ""
			slot.tooltip_text = "" if slot_index < _slot_count() else "Meer ruimte met een jas aan"
			continue
		var item_id := _shown_items[slot_index]
		var rarity_colour := _rarity_colour(item_id)
		var selected := item_id == _selected_item
		slot.style = _style(SELECTED_SLOT if selected else UiStyle.PANEL, Color.WHITE if selected else rarity_colour, 2, 4, 1)
		slot.shadow_offset = 3.0 if selected else 0.0
		slot.shadow_colour = rarity_colour
		_set_item_icon(icon, item_id)
		var amount := int(inventory.get(item_id, 0))
		count.text = str(amount) if amount > 1 else ""
		slot.tooltip_text = _item_name(item_id)
		icon.modulate.a = 1.0
		if amount <= 0:
			# the slot kept for your ID card: empty, the card a shadow in it
			slot.style = _style(EMPTY_SLOT, Color.WHITE if selected else EMPTY_BORDER, 2, 4, 1)
			slot.shadow_offset = 0.0
			icon.modulate.a = MISSING_ITEM_ALPHA
			slot.tooltip_text = _item_name(item_id) + " (kwijt)"
		if item_id == BankCards.ITEM:
			slot.tooltip_text = BankCards.description(_player, _item_name(item_id))
	var used := _items_in_category("").filter(func(item_id: String) -> bool: return int(inventory.get(item_id, 0)) > 0 and Items.takes_slot(item_id)).size()
	_slots_used_label.text = "%d / %d VAKJES" % [used, _slot_count()] + ("  · JAS" if _has_coat() else "")
	_refresh_item_detail()


func _refresh_item_detail() -> void:
	var has_item := _selected_item != ""
	for part: Control in [_detail_icon_box, _detail_rarity, _detail_name, _detail_kind, _detail_lines_box, _detail_text, _detail_buttons]:
		part.visible = has_item
	_detail_empty.visible = not has_item
	if not has_item:
		_detail_box.style = _style(UiStyle.PANEL, UiStyle.BORDER, 3, 20, 20)
		_detail_empty.text = "Je zakken zijn leeg." if _category == "" else "Hier heb je niks van."
		return
	var item := Items.item(_selected_item)
	var rarity: String = item.get("rarity", "gewoon")
	var rarity_colour := _rarity_colour(_selected_item)
	_detail_box.style = _style(UiStyle.PANEL, rarity_colour, 3, 20, 20)
	_detail_icon_box.style = _style(UiStyle.INK, rarity_colour, 2)
	_set_item_icon(_detail_icon, _selected_item)
	_detail_icon.modulate.a = 1.0 if int(_inventory().get(_selected_item, 0)) > 0 else MISSING_ITEM_ALPHA
	_detail_rarity.text = RARITIES.get(rarity, RARITIES.gewoon).label
	_detail_rarity.add_theme_color_override("font_color", rarity_colour)
	_detail_name.text = _item_name(_selected_item)
	_detail_kind.text = KIND_NAMES.get(item.get("kind", "spullen"), "Spullen")
	for line in _detail_lines.get_children():
		line.queue_free()
	var amount := int(_inventory().get(_selected_item, 0))
	_detail_lines.add_child(_detail_line("AANTAL", "%d×" % amount, UiStyle.TEXT))
	var effect: Dictionary = item.get("effect", {})
	if effect.is_empty():
		_detail_lines.add_child(_detail_line("EFFECT", "GEEN", UiStyle.MUTED))
	for stat_name: String in effect:
		var change := float(effect[stat_name])
		var better := change < 0.0 if stat_name in LOWER_IS_BETTER else change > 0.0
		_detail_lines.add_child(_detail_line(STAT_LABELS.get(stat_name, stat_name.to_upper()),
				"VOL" if change >= Items.FULL else "%+d" % roundi(change), GOOD if better else BAD))
	var text: String = item.get("text", "")
	if _selected_item == BankCards.ITEM:
		# every card found: its holder and the riddle of its PIN (BankCards)
		text = BankCards.description(_player, text)
	if _selected_item == "wachtnummer" and _player and _player.has_meta("wachtnummer"):
		text += "\nNummer B %03d." % int(_player.get_meta("wachtnummer"))   # (CityHall.TICKET_META)
	if amount <= 0 and item.has("missing_text"):
		text = String(item.missing_text)   # the slot kept for your ID card, empty
		_detail_rarity.text = "KWIJT"
	_detail_text.text = "“%s”" % text if text != "" else ""
	_detail_text.visible = text != ""
	_action_box.visible = Items.can_use(_selected_item)
	_action_label.text = item.get("action", "GEBRUIKEN")
	var can_drop: bool = item.get("kind", "") != "sleutel"
	_drop_box.mouse_filter = Control.MOUSE_FILTER_STOP if can_drop else Control.MOUSE_FILTER_IGNORE
	_drop_label.add_theme_color_override("font_color", UiStyle.TEXT if can_drop else EMPTY_BORDER)
	_drop_box.size_flags_horizontal = Control.SIZE_FILL if _action_box.visible else Control.SIZE_EXPAND_FILL


func _detail_line(key: String, value: String, colour: Color) -> Control:
	var row := _hbox(8)
	var key_label := UiStyle.label(key, _font_pixel, 12, SOFT_TEXT)
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_label)
	row.add_child(UiStyle.label(value, _font_body_bold, 13, colour))
	return row


## The item ids in the inventory of this kind ("" = all), by kind (KIND_ORDER), then
## rarity (rare first), then name; at most the size of the grid.
func _items_in_category(kind: String) -> Array[String]:
	var inventory := _inventory()
	var found: Array[String] = []
	for item_id: String in inventory:
		if int(inventory[item_id]) <= 0:
			continue
		if kind == "" or Items.item(item_id).get("kind", "spullen") == kind:
			found.append(item_id)
	var always := Items.ALWAYS_SHOWN
	var missing: bool = int(inventory.get(always, 0)) <= 0 and (kind == "" or kind == Items.item(always).get("kind", ""))
	var rarity_order := RARITIES.keys()
	found.sort_custom(func(first: String, second: String) -> bool:
		var first_item := Items.item(first)
		var second_item := Items.item(second)
		var first_kind := KIND_ORDER.find(first_item.get("kind", "spullen"))
		var second_kind := KIND_ORDER.find(second_item.get("kind", "spullen"))
		if first_kind != second_kind:
			return first_kind < second_kind
		var first_rarity := rarity_order.find(first_item.get("rarity", "gewoon"))
		var second_rarity := rarity_order.find(second_item.get("rarity", "gewoon"))
		if first_rarity != second_rarity:
			return first_rarity > second_rarity
		return _item_name(first) < _item_name(second))
	# the slot of your ID card first, empty (dimmed) while you have not got it
	if missing:
		found.push_front(always)
	if found.size() > GRID_COLUMNS * GRID_ROWS:
		found.resize(GRID_COLUMNS * GRID_ROWS)
	return found


func _item_name(item_id: String) -> String:
	return Items.item(item_id).get("name", item_id.capitalize())


func _rarity_colour(item_id: String) -> Color:
	var rarity: String = Items.item(item_id).get("rarity", "gewoon")
	return RARITIES.get(rarity, RARITIES.gewoon).colour


## The icon of an item: its own (ITEM_ICONS or the HUD's PIXEL_ICONS), else that of its kind.
func _set_item_icon(icon: PixelIcon, item_id: String) -> void:
	var item := Items.item(item_id)
	var icon_name: String = item.get("icon", "")
	if icon_name == "" or not (ITEM_ICONS.has(icon_name) or GameHud.PIXEL_ICONS.has(icon_name)):
		icon_name = KIND_ICONS.get(item.get("kind", "spullen"), "tas")
	if ITEM_ICONS.has(icon_name):
		icon.bitmap = ITEM_ICONS[icon_name].rows
		icon.colour = ITEM_ICONS[icon_name].colour
	else:
		icon.bitmap = GameHud.PIXEL_ICONS[icon_name]
		icon.colour = HUD_ICON_COLOURS.get(icon_name, UiStyle.TEXT)


func _choose_category(kind: String) -> void:
	if kind == _category:
		return
	UiSounds.play(self, "kies")
	_category = kind
	_selected_item = ""
	_refresh_inventory()


func _click_slot(slot_index: int) -> void:
	if slot_index >= _shown_items.size():
		return
	if _shown_items[slot_index] != _selected_item:
		UiSounds.play(self, "kies")
		_selected_item = _shown_items[slot_index]
		_refresh_inventory()


func _move_item_selection(direction: Vector2i) -> void:
	if _shown_items.is_empty():
		return
	var index := maxi(_shown_items.find(_selected_item), 0)
	var target := index + direction.x + direction.y * GRID_COLUMNS
	if target < 0 or target >= _shown_items.size():
		# sideways past the end of a row: stay; up or down off the grid: the nearest item
		if direction.y == 0:
			return
		target = clampi(target, 0, _shown_items.size() - 1)
	if target != index:
		UiSounds.play(self, "kies")
		_selected_item = _shown_items[target]
		_refresh_inventory()


## Uses the chosen item (eats, drinks...): through the player's use_item, or without a
## player on the menu's own copy of the stats.
func _use_selected() -> void:
	if _selected_item == "" or not Items.can_use(_selected_item):
		UiSounds.play(self, "terug")
		return
	var used := false
	if _player and _player.has_method("use_item"):
		used = _player.use_item(_selected_item)
	else:
		used = _use_without_player(_selected_item)
	UiSounds.play(self, "doe" if used else "terug")
	_refresh()


func _use_without_player(item_id: String) -> bool:
	var amount := int(_fallback_inventory.get(item_id, 0))
	if amount <= 0:
		return false
	_take_one(_fallback_inventory, item_id)
	var effect: Dictionary = Items.item(item_id).get("effect", {})
	for stat_name: String in effect:
		var value := _stat(stat_name)
		_fallback_stats[stat_name] = Vector2(clampf(value.x + float(effect[stat_name]), 0.0, value.y), value.y)
	return true


func _drop_selected() -> void:
	if _selected_item == "" or Items.item(_selected_item).get("kind", "") == "sleutel":
		UiSounds.play(self, "terug")
		return
	if _player and _player.has_method("drop_item"):
		_player.drop_item(_selected_item)
	else:
		_take_one(_fallback_inventory, _selected_item)
	UiSounds.play(self, "terug")
	_refresh()


static func _take_one(inventory: Dictionary, item_id: String) -> void:
	var left := int(inventory.get(item_id, 0)) - 1
	if left > 0:
		inventory[item_id] = left
	else:
		inventory.erase(item_id)


# ------------------------------------------------------------------ quest page

func _build_quest_page() -> Control:
	var parts := _page("Quests", "[↑↓] KIEZEN   [ENTER] VOLGEN   [←→] VERHAAL / ZIJMISSIES   [Q/E] TAB   [TAB] SLUITEN")
	var content: HBoxContainer = parts[1]
	_quest_content = content
	var list_column := _vbox(12)
	list_column.custom_minimum_size = Vector2(400, 0)
	content.add_child(list_column)
	var kind_buttons := _hbox(6)
	list_column.add_child(kind_buttons)
	for kind_entry: Array in QUEST_KINDS:
		var kind: String = kind_entry[0]
		var button := _box(_style(UiStyle.INK, UiStyle.BORDER, 2, 8, 4), 0.0, true)
		button.custom_minimum_size = Vector2(0, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button_label := UiStyle.label(kind_entry[1], _font_pixel, 11, UiStyle.MUTED)
		button_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_child(button_label)
		button.pressed.connect(func() -> void: _choose_quest_kind(kind))
		kind_buttons.add_child(button)
		_quest_kind_boxes[kind] = button
		_quest_kind_labels[kind] = button_label
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	list_column.add_child(scroll)
	_quest_rows = _vbox(6)
	_quest_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_quest_rows)
	_quest_detail = _box(_style(UiStyle.PANEL, UiStyle.ACCENT, 3, 28, 24), 6.0)
	_quest_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_detail_column = _vbox(16)
	_quest_detail.add_child(_quest_detail_column)
	content.add_child(_quest_detail)
	# no quests at all: one panel in the middle instead of the list and the detail
	_quest_empty = _box(_style(UiStyle.PANEL, UiStyle.BORDER, 3, 40, 32), UiStyle.SHADOW_OFFSET)
	_quest_empty.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	_quest_empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var empty_column := _vbox(10)
	var empty_heading := UiStyle.label("— GEEN OPDRACHTEN —", UiStyle.spaced(_font_pixel, 3), 12, UiStyle.ACCENT)
	empty_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_column.add_child(empty_heading)
	var empty_text := UiStyle.label("Nog geen opdrachten. Zwerf wat rond.", _font_italic, 14, SOFT_TEXT)
	empty_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_column.add_child(empty_text)
	_quest_empty.add_child(empty_column)
	content.add_child(_quest_empty)
	return parts[0]


func _quest_colour(kind: String) -> Color:
	return UiStyle.ACCENT if kind == "verhaal" else UiStyle.SIDE_ACCENT


func _all_quests() -> Array:
	if _hud and _hud.has_method("quests"):
		return _hud.quests()
	return []


func _quests_of_kind(kind: String) -> Array:
	var found := []
	for quest: Dictionary in _all_quests():
		if str(quest.get("kind", "verhaal")) == kind:
			found.append(quest)
	return found


func _quest_kind_index() -> int:
	for kind_index in QUEST_KINDS.size():
		if QUEST_KINDS[kind_index][0] == _quest_kind:
			return kind_index
	return 0


func _choose_quest_kind(kind: String) -> void:
	if kind == _quest_kind:
		return
	UiSounds.play(self, "kies")
	_quest_kind = kind
	_selected_quest = 0
	_refresh_quests()


func _refresh_quests() -> void:
	var has_any := not _all_quests().is_empty()
	_quest_empty.visible = not has_any
	(_quest_rows.get_parent().get_parent() as Control).visible = has_any
	_quest_detail.visible = has_any
	if not has_any:
		return
	for kind_entry: Array in QUEST_KINDS:
		var kind: String = kind_entry[0]
		var on := kind == _quest_kind
		(_quest_kind_boxes[kind] as Box).style = _style(RAISED if on else UiStyle.INK, _quest_colour(kind) if on else UiStyle.BORDER, 2, 8, 4)
		(_quest_kind_labels[kind] as Label).add_theme_color_override("font_color", UiStyle.TEXT if on else UiStyle.MUTED)
	for row in _quest_rows.get_children():
		row.queue_free()
	var quests := _quests_of_kind(_quest_kind)
	_selected_quest = clampi(_selected_quest, 0, maxi(quests.size() - 1, 0))
	if quests.is_empty():
		var nothing := UiStyle.label("Geen zijmissies op dit moment." if _quest_kind == "zij" else "Geen verhaalopdracht op dit moment.", _font_italic, 13, UiStyle.MUTED)
		_quest_rows.add_child(nothing)
	for quest_index in quests.size():
		_quest_rows.add_child(_quest_row(quests[quest_index], quest_index))
	_fill_quest_detail(quests[_selected_quest] if not quests.is_empty() else {})


func _quest_row(quest: Dictionary, quest_index: int) -> Control:
	var colour := _quest_colour(_quest_kind)
	var selected := quest_index == _selected_quest
	var row := _box(_style(RAISED if selected else UiStyle.PANEL, Color.WHITE if selected else UiStyle.BORDER, 2, 14, 10), 4.0 if selected else 0.0, true)
	row.style.content_margin_left = 6 + 14
	row.strip_width = 6.0
	row.strip_colour = colour
	row.custom_minimum_size = Vector2(0, 56)
	var line := _hbox(12)
	row.add_child(line)
	var texts := _vbox(3)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(texts)
	texts.add_child(UiStyle.label(_quest_tag(quest), UiStyle.spaced(_font_pixel, 2), 10, colour))
	var steps: Array = quest.get("steps", [])
	var done := not steps.is_empty() and _steps_done(steps) == steps.size()
	var title := UiStyle.label(str(quest.get("title", "")), _font_title_medium, 17, UiStyle.MUTED if done else UiStyle.TEXT)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(title)
	var followed := GameHud.quest_id(quest) == _tracked_id()
	var status := UiStyle.label(("◆ VOLGT  " if followed else "") + _quest_status(quest), _font_pixel, 10, UiStyle.ACCENT if followed else UiStyle.MUTED)
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(status)
	row.pressed.connect(func() -> void:
		if quest_index != _selected_quest:
			UiSounds.play(self, "kies")
			_selected_quest = quest_index
			_refresh_quests.call_deferred())
	return row


func _quest_tag(quest: Dictionary) -> String:
	var main := str(quest.get("kind", "verhaal")) == "verhaal"
	return ("◆ " if main else "! ") + str(quest.get("label", "VERHAAL" if main else "ZIJMISSIE"))


## Right on a quest's row: the steps done ("2/3"), else its distance.
func _quest_status(quest: Dictionary) -> String:
	var steps: Array = quest.get("steps", [])
	if not steps.is_empty():
		var done := _steps_done(steps)
		return "KLAAR" if done == steps.size() else "%d/%d" % [done, steps.size()]
	return str(quest.get("distance", ""))


static func _steps_done(steps: Array) -> int:
	var done := 0
	for step: Dictionary in steps:
		if step.get("done", false):
			done += 1
	return done


## The chosen quest: its tag, title, distance (and giver, if any), description (if any),
## steps with boxes and rewards (if any: "rewards" = an Array of texts).
func _fill_quest_detail(quest: Dictionary) -> void:
	for child in _quest_detail_column.get_children():
		child.queue_free()
	var colour := _quest_colour(_quest_kind)
	_quest_detail.style = _style(UiStyle.PANEL, colour, 3, 28, 24)
	if quest.is_empty():
		_quest_detail_column.add_child(UiStyle.label("Kies een opdracht.", _font_italic, 14, UiStyle.MUTED))
		return
	var heading := _hbox(16)
	_quest_detail_column.add_child(heading)
	var names := _vbox(6)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(names)
	names.add_child(UiStyle.label(_quest_tag(quest), UiStyle.spaced(_font_pixel, 3), 11, colour))
	var title := UiStyle.label(str(quest.get("title", "")), _font_title_spaced, 32)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(title)
	var giver := str(quest.get("giver", ""))
	if giver != "":
		names.add_child(UiStyle.label("Van %s" % giver, _font_body, 12, UiStyle.MUTED))
	var distance := str(quest.get("distance", ""))
	if distance != "":
		var chip := _box(_style(Color(0, 0, 0, 0), UiStyle.BORDER, 2, 8, 4))
		chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		chip.add_child(UiStyle.label(distance, _font_pixel, 11))
		heading.add_child(chip)
	var description := str(quest.get("description", ""))
	if description != "":
		var text := UiStyle.label(description, _font_body, 14, SOFT_TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_constant_override("line_spacing", 6)
		_quest_detail_column.add_child(text)
	var steps: Array = quest.get("steps", [])
	if not steps.is_empty():
		var goals := _vbox(8)
		goals.add_child(UiStyle.label("DOELEN", UiStyle.spaced(_font_pixel, 2), 11, UiStyle.MUTED))
		for step: Dictionary in steps:
			var done: bool = step.get("done", false)
			var locked: bool = step.get("locked", false) and not done
			var step_colour := UiStyle.MUTED if done else UiStyle.TEXT
			var row := _hbox(10)
			var check := Panel.new()
			check.custom_minimum_size = Vector2(12, 12)
			check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			check.mouse_filter = Control.MOUSE_FILTER_IGNORE
			check.add_theme_stylebox_override("panel", UiStyle.box_style(step_colour if done else Color(0, 0, 0, 0), step_colour, 2))
			row.add_child(check)
			var step_text := UiStyle.label(str(step.get("text", "")) + ("  (eerst de stap hiervoor)" if locked else ""), _font_body, 14, step_colour)
			step_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			step_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(step_text)
			if step.has("progress"):
				row.add_child(UiStyle.label(str(step.progress), _font_pixel, 11, step_colour))
			if int(step.get("xp", 0)) > 0:
				row.add_child(UiStyle.label("+%d XP" % int(step.xp), _font_pixel, 11, step_colour if done else XP_TEXT_COLOUR))
			# a step that cannot be done yet: see-through
			if locked:
				row.modulate.a = GameHud.LOCKED_STEP_OPACITY
			goals.add_child(row)
		_quest_detail_column.add_child(goals)
	var followed := GameHud.quest_id(quest) == _tracked_id()
	var finished := GameHud.is_quest_done(quest)
	var follow := _box(_style(RAISED if followed else UiStyle.INK, colour if followed else UiStyle.BORDER, 2, 12, 6), 0.0, not followed and not finished)
	follow.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var follow_text := "◆ JE VOLGT DEZE OPDRACHT" if followed else ("AFGEROND" if finished else "[ENTER] VOLGEN")
	follow.add_child(UiStyle.label(follow_text, _font_pixel, 11, colour if followed else (UiStyle.MUTED if finished else UiStyle.TEXT)))
	if not followed and not finished:
		follow.pressed.connect(_track_selected_quest)
	_quest_detail_column.add_child(follow)
	_quest_detail_column.add_child(_spacer())
	var rewards: Array = quest.get("rewards", [])
	if not rewards.is_empty():
		var footer_style := StyleBoxFlat.new()
		footer_style.bg_color = Color(0, 0, 0, 0)
		footer_style.border_color = UiStyle.BORDER
		footer_style.border_width_top = 2
		footer_style.content_margin_top = 16
		footer_style.anti_aliasing = false
		var footer := _box(footer_style)
		var footer_column := _vbox(8)
		footer.add_child(footer_column)
		footer_column.add_child(UiStyle.label("BELONINGEN", UiStyle.spaced(_font_pixel, 2), 11, UiStyle.MUTED))
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 8)
		chips.add_theme_constant_override("v_separation", 8)
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for reward in rewards:
			var chip := _box(_style(UiStyle.INK, colour, 2, 10, 6))
			var chip_row := _hbox(6)
			var square := ColorRect.new()
			square.color = colour
			square.custom_minimum_size = Vector2(8, 8)
			square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			square.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip_row.add_child(square)
			chip_row.add_child(UiStyle.label(str(reward).to_upper(), _font_pixel, 11))
			chip.add_child(chip_row)
			chips.add_child(chip)
		footer_column.add_child(chips)
		_quest_detail_column.add_child(footer)


# ------------------------------------------------------------------ map page

func _build_map_page() -> Control:
	var parts := _page("Kaart", "[←↑↓→] PLEK KIEZEN   [ENTER] MARKER   [KLIK] KIEZEN   [RECHTSKLIK] MARKER   [Q/E] TAB   [TAB] SLUITEN")
	var content: HBoxContainer = parts[1]
	var frame := _box(_style(UiStyle.INK, UiStyle.BORDER, 3), 6.0)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 3.0
	content.add_child(frame)
	_map_clip = Control.new()
	_map_clip.clip_contents = true
	_map_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_map_clip)
	_map_picture = TextureRect.new()
	_map_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_map_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_clip.add_child(_map_picture)
	_map_fog = TextureRect.new()
	_map_fog.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_fog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_fog.stretch_mode = TextureRect.STRETCH_SCALE
	_map_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_clip.add_child(_map_fog)
	_map_overlay = Control.new()
	_map_overlay.name = "Plekken"
	_map_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_overlay.draw.connect(_draw_map_overlay)
	_map_overlay.gui_input.connect(_on_map_input)
	_map_clip.add_child(_map_overlay)
	_map_arrow = PlayerArrow.new()
	_map_arrow.scale = Vector2(0.8, 0.8)
	_map_clip.add_child(_map_arrow)
	_map_waiting = UiStyle.label("DE KAART WORDT NOG GETEKEND…", _font_pixel, 12, UiStyle.MUTED)
	_map_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_map_clip.add_child(_map_waiting)
	_map_coordinates_box = _box(_style(UiStyle.TRANSLUCENT_INK, UiStyle.TRANSLUCENT_INK, 0, 8, 4))
	_map_coordinates = UiStyle.label("", _font_pixel, 11)
	_map_coordinates_box.add_child(_map_coordinates)
	_map_clip.add_child(_map_coordinates_box)
	_map_north = _box(_style(UiStyle.TRANSLUCENT_INK, UiStyle.BORDER, 2))
	_map_north.custom_minimum_size = Vector2(36, 36)
	var north := UiStyle.label("N", _font_pixel_bold, 14)
	north.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	north.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_map_north.add_child(north)
	_map_clip.add_child(_map_north)
	_map_clip.resized.connect(_layout_map)
	content.add_child(_build_map_side())
	return parts[0]


func _build_map_side() -> Control:
	var column := _vbox(14)
	column.custom_minimum_size = Vector2(296, 0)
	_place_box = _box(_style(UiStyle.PANEL, PLACE_COLOUR, 3, 18, 18), UiStyle.SHADOW_OFFSET)
	column.add_child(_place_box)
	var place_column := _vbox(10)
	_place_box.add_child(place_column)
	_place_kind = UiStyle.label("", UiStyle.spaced(_font_pixel, 2), 11, PLACE_COLOUR)
	place_column.add_child(_place_kind)
	_place_name = UiStyle.label("", _font_title, 22)
	_place_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place_column.add_child(_place_name)
	_place_wijk = UiStyle.label("", _font_body, 13, SOFT_TEXT)
	_place_wijk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place_column.add_child(_place_wijk)
	var chips := _hbox(8)
	place_column.add_child(chips)
	for chip_index in 2:
		var chip := _box(_style(Color(0, 0, 0, 0), UiStyle.BORDER, 1, 6, 3))
		var chip_label := UiStyle.label("", _font_pixel, 11, UiStyle.MUTED)
		chip.add_child(chip_label)
		chips.add_child(chip)
		if chip_index == 0:
			_place_distance = chip_label
		else:
			_place_state = chip_label
	_place_marker = UiStyle.label("", _font_pixel, 11, UiStyle.TEXT)
	place_column.add_child(_place_marker)
	var here := _box(_style(UiStyle.PANEL, UiStyle.BORDER, 2, 16, 14))
	column.add_child(here)
	var here_column := _vbox(6)
	here.add_child(here_column)
	here_column.add_child(UiStyle.label("JE BENT HIER", UiStyle.spaced(_font_pixel, 2), 11, UiStyle.MUTED))
	_here_wijk = UiStyle.label("", _font_pixel, 12, UiStyle.SIDE_ACCENT)
	here_column.add_child(_here_wijk)
	_here_street = UiStyle.label("", _font_body, 13)
	_here_street.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	here_column.add_child(_here_street)
	var legend := _box(_style(UiStyle.PANEL, UiStyle.BORDER, 2, 16, 14))
	column.add_child(legend)
	var legend_column := _vbox(10)
	legend.add_child(legend_column)
	legend_column.add_child(UiStyle.label("LEGENDA", UiStyle.spaced(_font_pixel, 2), 11, UiStyle.MUTED))
	var legend_grid := GridContainer.new()
	legend_grid.columns = 2
	legend_grid.add_theme_constant_override("h_separation", 12)
	legend_grid.add_theme_constant_override("v_separation", 8)
	legend_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend_column.add_child(legend_grid)
	legend_grid.add_child(_legend_entry(_legend_square(PLACE_COLOUR, PLACE_COLOUR), "Plek"))
	legend_grid.add_child(_legend_entry(_legend_square(UNKNOWN_PLACE_COLOUR, UNKNOWN_PLACE_COLOUR), "Nog onbekend"))
	for chain: String in SUPERMARKETS:
		var marker := _legend_square(SUPERMARKETS[chain].colour, Color.WHITE)
		if SUPERMARKETS[chain].round:
			var round_style := UiStyle.box_style(SUPERMARKETS[chain].colour, Color.WHITE, 1) as StyleBoxFlat
			if round_style:
				round_style = round_style.duplicate()
				round_style.set_corner_radius_all(5)
				marker.add_theme_stylebox_override("panel", round_style)
		legend_grid.add_child(_legend_entry(marker, String(SUPERMARKETS[chain].name).capitalize()))
	legend_grid.add_child(_legend_entry(_legend_square(CASH_MACHINE_COLOUR, UiStyle.INK), CASH_MACHINE_NAME))
	legend_grid.add_child(_legend_entry(_legend_square(GameHud.WAYPOINT_COLOUR, Color.WHITE), "Jouw marker"))
	legend_grid.add_child(_legend_entry(_legend_square(Color(FOG, 1.0), UiStyle.BORDER), "Onontdekte wijk"))
	var arrow_holder := Control.new()
	arrow_holder.custom_minimum_size = Vector2(12, 12)
	arrow_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arrow := PlayerArrow.new()
	arrow.scale = Vector2(0.5, 0.5)
	arrow.position = Vector2(6, 6)
	arrow_holder.add_child(arrow)
	legend_grid.add_child(_legend_entry(arrow_holder, "Jij"))
	column.add_child(_spacer())
	return column


func _legend_square(colour: Color, border: Color) -> Control:
	var square := Panel.new()
	square.custom_minimum_size = Vector2(10, 10)
	square.mouse_filter = Control.MOUSE_FILTER_IGNORE
	square.add_theme_stylebox_override("panel", UiStyle.box_style(colour, border, 1))
	return square


func _legend_entry(marker: Control, text: String) -> Control:
	var row := _hbox(8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(marker)
	row.add_child(UiStyle.label(text, _font_body, 12))
	return row


# ------------------------------------------------------------------ map

## The scene the HUD belongs to (its metadata: "places", "wijken", "straten").
func _world() -> Node:
	if _hud:
		return _hud.owner if _hud.owner else _hud.get_parent()
	return get_tree().current_scene


## Where the player is (world x, z) and which way it looks (x, z): the player node, else
## the point the camera looks at.
func _player_position() -> Vector2:
	if _player is Node3D:
		var position_3d := (_player as Node3D).global_position
		return Vector2(position_3d.x, position_3d.z)
	var camera := get_viewport().get_camera_3d()
	if camera:
		var focus := Iso.ground_focus(camera)
		return Vector2(focus.x, focus.z)
	return Vector2.ZERO


func _player_heading() -> Vector2:
	if _player is Node3D:
		var forward := (_player as Node3D).global_basis.z
		return Vector2(forward.x, forward.z)
	var camera := get_viewport().get_camera_3d()
	if camera:
		var forward := -camera.global_basis.z
		return Vector2(forward.x, forward.z)
	return Vector2(0.0, -1.0)


## The neighbourhood at world x, z (the first "wijken" entry it lies in, as the HUD does).
func _wijk_at(world_position: Vector2) -> String:
	var world := _world()
	if world == null:
		return WHOLE_CITY
	var cell := world_position / CELL_METRES
	for area: Array in world.get_meta("wijken", []):
		if cell.x >= area[1] and cell.y >= area[2] and cell.x < area[3] + 1 and cell.y < area[4] + 1:
			return area[0]
	return WHOLE_CITY


func _refresh_map() -> void:
	var world := _world()
	_visited.clear()
	if _hud and _hud.has_method("visited_areas"):
		for wijk: String in _hud.visited_areas():
			_visited[wijk] = true
	var player_at := _player_position()
	var player_wijk := _wijk_at(player_at)
	_visited[player_wijk] = true
	_visited[WHOLE_CITY] = true
	_places.clear()
	if world:
		var places: Dictionary = world.get_meta("places", {})
		for place_key: String in places:
			if place_key.begins_with("verkeerslichten"):
				continue   # a test spot of the builder, not a place
			var place_position: Vector2 = places[place_key]
			if _shrouded(place_position):
				continue   # not open yet (the story's shroud)
			_places.append({"key": place_key, "name": GameHud._place_name(place_key),
					"position": place_position, "wijk": _wijk_at(place_position)})
		var machines := world.get_node_or_null(CASH_MACHINE_NODE)
		if machines:
			var number := 0
			for marker in machines.get_children():
				if not (marker is Node3D and String(marker.name).begins_with(CASH_MACHINE_MARKER)):
					continue
				number += 1
				var at := (marker as Node3D).global_position
				var machine_position := Vector2(at.x, at.z)
				if _shrouded(machine_position):
					continue
				_places.append({"key": CASH_MACHINE_KEY + str(number), "name": CASH_MACHINE_NAME,
						"position": machine_position, "wijk": _wijk_at(machine_position)})
	if _selected_place == "" or not _places.any(func(place: Dictionary) -> bool: return place.key == _selected_place):
		_selected_place = _nearest_place(player_at)
	var area_names := {}
	if world:
		for area: Array in world.get_meta("wijken", []):
			if area[0] != WHOLE_CITY:
				area_names[area[0]] = true
	var visited_count := 0
	for wijk: String in area_names:
		if _visited.has(wijk):
			visited_count += 1
	_header_info.text = "DEN HAAG · %d / %d WIJKEN ONTDEKT" % [visited_count, area_names.size()]
	var texture := _map_texture()
	_map_picture.texture = texture
	_map_fog.texture = _fog_texture(texture)
	_map_coordinates.text = "X %04d · Y %04d" % [roundi(player_at.x), roundi(player_at.y)]
	_here_wijk.text = player_wijk.to_upper()
	var street := ""
	if world:
		street = GameHud._street_at(world, player_at / CELL_METRES)
	_here_street.text = street if street != "" else "Geen straat"
	_here_street.add_theme_color_override("font_color", UiStyle.TEXT if street != "" else UiStyle.MUTED)
	_layout_map()
	_fill_place_panel()


func _map_texture() -> Texture2D:
	if _hud and _hud.has_method("minimap_texture"):
		return _hud.minimap_texture()
	return null


func _map_origin() -> Vector2:
	if _hud and _hud.has_method("minimap_origin"):
		return _hud.minimap_origin()
	return Vector2.ZERO


func _metres_per_pixel() -> float:
	if _hud and _hud.has_method("minimap_metres_per_pixel"):
		return maxf(_hud.minimap_metres_per_pixel(), 0.01)
	return CELL_METRES


## A picture the size of the map with the fog over the neighbourhoods not visited yet:
## the "wijken" painted last to first (the first one a cell lies in wins, as in the HUD).
func _fog_texture(map_texture: Texture2D) -> Texture2D:
	var world := _world()
	if map_texture == null or world == null:
		return null
	var pixels := Vector2i(map_texture.get_size())
	var image := Image.create(pixels.x, pixels.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var areas: Array = world.get_meta("wijken", [])
	var origin := _map_origin()
	var metres_per_pixel := _metres_per_pixel()
	for area_index in range(areas.size() - 1, -1, -1):
		var area: Array = areas[area_index]
		var from_world := Vector2(area[1], area[2]) * CELL_METRES
		var to_world := Vector2(float(area[3]) + 1.0, float(area[4]) + 1.0) * CELL_METRES
		var from_pixel := ((from_world - origin) / metres_per_pixel).round()
		var to_pixel := ((to_world - origin) / metres_per_pixel).round()
		var rect := Rect2i(Vector2i(from_pixel), Vector2i(to_pixel - from_pixel)).intersection(Rect2i(Vector2i.ZERO, pixels))
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		image.fill_rect(rect, Color(0, 0, 0, 0) if _visited.has(area[0]) else FOG)
	# what the story has not opened yet: not on the map at all (GameHud.shroud_image)
	var shroud: Image = _hud.shroud_image() if _hud and _hud.has_method("shroud_image") else null
	if shroud and Vector2i(shroud.get_size()) == pixels:
		image.blend_rect(shroud, Rect2i(Vector2i.ZERO, pixels), Vector2i.ZERO)
	return ImageTexture.create_from_image(image)


## Fits the map picture into its frame (as large as fits, centred) and places the markers,
## the arrow, the coordinates and the north sign.
func _layout_map() -> void:
	var area := _map_clip.size
	_map_overlay.position = Vector2.ZERO
	_map_overlay.size = area
	_map_waiting.position = Vector2.ZERO
	_map_waiting.size = area
	_map_north.position = Vector2(area.x - 12.0 - 36.0, 10.0)
	_map_north.size = Vector2(36, 36)
	_map_coordinates_box.reset_size()
	_map_coordinates_box.position = Vector2(12.0, area.y - 10.0 - _map_coordinates_box.size.y)
	var texture := _map_picture.texture
	_map_waiting.visible = texture == null
	_map_arrow.visible = texture != null
	if texture == null:
		_map_overlay.queue_redraw()
		return
	var texture_size := texture.get_size()
	_map_scale = minf(area.x / texture_size.x, area.y / texture_size.y)
	_map_offset = ((area - texture_size * _map_scale) * 0.5).floor()
	for picture: TextureRect in [_map_picture, _map_fog]:
		picture.position = _map_offset
		picture.size = texture_size * _map_scale
	_map_arrow.position = _world_to_map(_player_position())
	var heading := _player_heading()
	if heading.length_squared() > 0.0001:
		_map_arrow.rotation = atan2(heading.x, -heading.y)
	_map_overlay.queue_redraw()


func _world_to_map(world_position: Vector2) -> Vector2:
	return _map_offset + (world_position - _map_origin()) / _metres_per_pixel() * _map_scale


## The spot of the town (world x, z) under `map_point` (a point of the map overlay).
func _map_to_world(map_point: Vector2) -> Vector2:
	return _map_origin() + (map_point - _map_offset) / _map_scale * _metres_per_pixel()


## Debug (debug builds: T on the chosen place, Shift+click anywhere on the map): the player to
## `spot` (world x, z), on the nearest walkable cell there (not into a building or the water),
## the menu closed. Not inside a building.
func teleport_to(spot: Vector2) -> void:
	var interiors := get_tree().get_first_node_in_group("binnenruimtes")
	if _player == null or not _player.has_method("teleport") or (interiors and interiors.has_method("is_inside") and interiors.is_inside()):
		return
	var at := Vector3(spot.x, _player.global_position.y + 2.0, spot.y)
	var world := _world()
	var walkers: Node = world.get_node_or_null("Voetgangers") if world else null
	if walkers and walkers.has_method("nearest_walkable"):
		var cell: Vector3i = walkers.nearest_walkable(walkers.cell_of(Vector3(spot.x, 0.0, spot.y)))
		var middle: Vector3 = walkers.cell_middle(cell)
		at = Vector3(middle.x, middle.y + 2.0, middle.z)
	_player.teleport(at, _player.rotation.y)
	print("debug: naar %.0f, %.0f" % [at.x, at.z])
	UiSounds.play(self, "doe")
	close()


## The markers of the places (the chosen one larger, ringed white, on top) and the names of
## the visited neighbourhoods.
func _draw_map_overlay() -> void:
	if _map_picture.texture == null:
		return
	var world := _world()
	if world:
		for area: Array in world.get_meta("wijken", []):
			if area[0] == WHOLE_CITY or not _visited.has(area[0]):
				continue
			var centre_world := Vector2(float(area[1] + area[3]) + 1.0, float(area[2] + area[4]) + 1.0) * 0.5 * CELL_METRES
			if _shrouded(centre_world):
				continue
			var text := str(area[0]).to_upper()
			var text_width := _font_pixel.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			var at := _world_to_map(centre_world) - Vector2(text_width * 0.5, -4.0)
			_map_overlay.draw_string(_font_pixel, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyle.INK)
			_map_overlay.draw_string(_font_pixel, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(UiStyle.TEXT, 0.55))
	var chosen: Dictionary = {}
	for place: Dictionary in _places:
		if place.key == _selected_place:
			chosen = place
			continue
		if _shrouded(place.position):
			continue   # not open yet: not on the map
		var at := _world_to_map(place.position).round()
		if supermarket_chain(place.key) != "":
			_draw_supermarket(at, supermarket_chain(place.key), false)
			continue
		if is_cash_machine(place.key):
			_draw_cash_machine(at, false)
			continue
		_map_overlay.draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), UiStyle.INK)
		_map_overlay.draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), _place_colour(place))
	if not chosen.is_empty():
		var at := _world_to_map(chosen.position).round()
		if supermarket_chain(chosen.key) != "":
			_draw_supermarket(at, supermarket_chain(chosen.key), true)
		elif is_cash_machine(chosen.key):
			_draw_cash_machine(at, true)
		else:
			_map_overlay.draw_rect(Rect2(at - Vector2(11, 11), Vector2(22, 22)), Color.WHITE)
			_map_overlay.draw_rect(Rect2(at - Vector2(8, 8), Vector2(16, 16)), UiStyle.INK)
			_map_overlay.draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), _place_colour(chosen))
	# the places a mission marked for good (Story "markeringen"): a ring round them
	for at_world: Vector2 in _story_markers():
		var ring_at := _world_to_map(at_world).round()
		_map_overlay.draw_arc(ring_at, 11.0, 0.0, TAU, 20, UiStyle.INK, 4.0)
		_map_overlay.draw_arc(ring_at, 11.0, 0.0, TAU, 20, UiStyle.ACCENT, 2.0)
	# the marker set on the map, a pink diamond
	if _hud and _hud.has_method("has_waypoint") and _hud.has_waypoint():
		QuestMarks.draw_mark(_map_overlay, _world_to_map(_hud.waypoint()).round(), 9.0, 1.0, GameHud.WAYPOINT_COLOUR)
	# where the followed quest sends you, over everything
	if _hud and _hud.has_method("quest_targets"):
		for target: Vector2 in _hud.quest_targets():
			if _shrouded(target):
				continue
			QuestMarks.draw_mark(_map_overlay, _world_to_map(target).round(), 8.0)


## Whether the world point is still under the story's shroud (GameHud.is_shrouded).
func _shrouded(world_point: Vector2) -> bool:
	return _hud != null and _hud.has_method("is_shrouded") and _hud.is_shrouded(world_point)


## The places the missions marked for good (Story.markers), world x, z.
func _story_markers() -> Array:
	var story := get_tree().get_first_node_in_group("verhaal")
	return story.markers().values() if story and story.has_method("markers") else []


## The chain of a supermarket place ("derrek_3" -> "derrek"), "" for any other place.
static func supermarket_chain(place_key: String) -> String:
	var words := place_key.split("_", false)
	if words.size() > 1 and words[-1].is_valid_int():
		words.resize(words.size() - 1)
	var chain := "_".join(words)
	return chain if SUPERMARKETS.has(chain) else ""


## Whether a place of the map is a cash machine ("pinautomaat_3").
static func is_cash_machine(place_key: String) -> bool:
	return place_key.begins_with(CASH_MACHINE_KEY)


## The marker of a cash machine at `at`: a small upright yellow block (the machine) with a
## dark screen; `chosen`: larger, ringed white.
func _draw_cash_machine(at: Vector2, chosen: bool) -> void:
	var half := Vector2(4.0, 5.0) * (1.5 if chosen else 1.0)
	if chosen:
		_map_overlay.draw_rect(Rect2(at - half - Vector2.ONE * 4.0, (half + Vector2.ONE * 4.0) * 2.0), Color.WHITE)
	_map_overlay.draw_rect(Rect2(at - half - Vector2.ONE * 2.0, (half + Vector2.ONE * 2.0) * 2.0), UiStyle.INK)
	_map_overlay.draw_rect(Rect2(at - half, half * 2.0), CASH_MACHINE_COLOUR)
	var screen := Vector2(half.x * 0.6, half.y * 0.35)
	_map_overlay.draw_rect(Rect2(at - Vector2(screen.x, half.y * 0.7), screen * 2.0), UiStyle.INK)


## The marker of a supermarket at `at`: a square (DERREK) or a disc (ALFRED STEYHN) in the
## chain's colour with a white rim and a white dot; `chosen`: larger, ringed white.
func _draw_supermarket(at: Vector2, chain: String, chosen: bool) -> void:
	var colour: Color = SUPERMARKETS[chain].colour
	var size := 8.0 if chosen else 5.5
	if SUPERMARKETS[chain].round:
		if chosen:
			_map_overlay.draw_circle(at, size + 4.0, Color.WHITE)
		_map_overlay.draw_circle(at, size + 2.0, UiStyle.INK)
		_map_overlay.draw_circle(at, size + 1.0, Color.WHITE)
		_map_overlay.draw_circle(at, size, colour)
	else:
		if chosen:
			_map_overlay.draw_rect(Rect2(at - Vector2.ONE * (size + 4.0), Vector2.ONE * (size + 4.0) * 2.0), Color.WHITE)
		_map_overlay.draw_rect(Rect2(at - Vector2.ONE * (size + 2.0), Vector2.ONE * (size + 2.0) * 2.0), UiStyle.INK)
		_map_overlay.draw_rect(Rect2(at - Vector2.ONE * (size + 1.0), Vector2.ONE * (size + 1.0) * 2.0), Color.WHITE)
		_map_overlay.draw_rect(Rect2(at - Vector2.ONE * size, Vector2.ONE * size * 2.0), colour)
	_map_overlay.draw_rect(Rect2(at - Vector2(1.5, 1.5), Vector2(3, 3)), Color.WHITE)


func _place_colour(place: Dictionary) -> Color:
	return PLACE_COLOUR if _visited.has(place.wijk) else UNKNOWN_PLACE_COLOUR


func _place(place_key: String) -> Dictionary:
	for place: Dictionary in _places:
		if place.key == place_key:
			return place
	return {}


func _nearest_place(world_position: Vector2) -> String:
	var nearest := ""
	var nearest_distance := INF
	for place: Dictionary in _places:
		var distance := (place.position as Vector2).distance_to(world_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = place.key
	return nearest


func _fill_place_panel() -> void:
	var place := _place(_selected_place)
	_place_box.visible = not place.is_empty()
	if place.is_empty():
		return
	var known := _visited.has(place.wijk)
	var colour := PLACE_COLOUR if known else UNKNOWN_PLACE_COLOUR
	var chain := supermarket_chain(place.key)
	if chain != "":
		colour = SUPERMARKETS[chain].colour
	var cash_machine := is_cash_machine(place.key)
	if cash_machine:
		colour = CASH_MACHINE_COLOUR
	_place_box.style = _style(UiStyle.PANEL, colour, 3, 18, 18)
	_place_kind.text = "◆ SUPERMARKT" if chain != "" else ("◆ PINAUTOMAAT" if cash_machine else ("◆ PLEK" if known else "? NOG ONBEKEND"))
	_place_kind.add_theme_color_override("font_color", colour)
	_place_name.text = String(SUPERMARKETS[chain].name) if chain != "" else place.name
	_place_wijk.text = "In %s" % place.wijk if place.wijk != WHOLE_CITY else "In Den Haag"
	var distance := (place.position as Vector2).distance_to(_player_position())
	_place_distance.text = "%d M" % roundi(distance)
	_place_state.text = "BEZOCHTE WIJK" if known else "ONONTDEKTE WIJK"
	var marked := _marker_on(place)
	_place_marker.text = "◆ MARKER STAAT HIER   [ENTER] WEG" if marked else "[ENTER] MARKER ZETTEN"
	_place_marker.add_theme_color_override("font_color", GameHud.WAYPOINT_COLOUR if marked else UiStyle.TEXT)


func _choose_place(place_key: String) -> void:
	if place_key == "" or place_key == _selected_place:
		return
	UiSounds.play(self, "kies")
	_selected_place = place_key
	_fill_place_panel()
	_map_overlay.queue_redraw()


func _on_map_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var button := (event as InputEventMouseButton).button_index
	if button != MOUSE_BUTTON_LEFT and button != MOUSE_BUTTON_RIGHT:
		return
	var nearest := ""
	var nearest_distance := MARKER_PICK_RADIUS
	for place: Dictionary in _places:
		var distance := _world_to_map(place.position).distance_to((event as InputEventMouseButton).position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = place.key
	# debug: Shift+click puts the player there, anywhere on the map
	if button == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).shift_pressed and OS.is_debug_build():
		_map_overlay.accept_event()
		teleport_to(_map_to_world((event as InputEventMouseButton).position))
		return
	_choose_place(nearest)
	if button == MOUSE_BUTTON_RIGHT and nearest != "":
		toggle_marker()
	_map_overlay.accept_event()


## The nearest place in this direction (on screen) from the chosen one, within 60 degrees
## of it, the straightest preferred.
func _move_place_selection(direction: Vector2) -> void:
	var current := _place(_selected_place)
	if current.is_empty():
		_choose_place(_nearest_place(_player_position()))
		return
	var from := _world_to_map(current.position)
	var best := ""
	var best_score := INF
	for place: Dictionary in _places:
		if place.key == current.key:
			continue
		var offset := _world_to_map(place.position) - from
		var distance := offset.length()
		if distance < 0.5:
			continue
		var straightness := offset.dot(direction) / distance
		if straightness < 0.5:
			continue
		var score := distance * (2.0 - straightness)
		if score < best_score:
			best_score = score
			best = place.key
	_choose_place(best)


# ------------------------------------------------------------------ CRT and layout

## A slight bend over the menu, with the HUD's settings (the menu bends as little as the
## HUD itself does).
func _build_crt() -> void:
	var curvature := 0.02
	var corner := 0.035
	if _hud and "crt_ui_curvature" in _hud:
		curvature = minf(_hud.crt_ui_curvature, _hud.crt_curvature)
		corner = _hud.crt_corner if curvature > 0.0 else 0.0
	_crt_overlay = UiStyle.make_crt_overlay(curvature, corner, DESIGN_SIZE)
	add_child(_crt_overlay)
	_crt_overlay.resized.connect(func() -> void:
		(_crt_overlay.material as ShaderMaterial).set_shader_parameter("screen_size", _crt_overlay.size))


## Scales the design to the window (the smaller of the two ratios); the layout fills the
## window at that scale.
func _fit_to_window() -> void:
	var window := get_viewport().get_visible_rect().size
	var factor := minf(window.x / DESIGN_SIZE.x, window.y / DESIGN_SIZE.y)
	if factor <= 0.0:
		return
	_root.scale = Vector2(factor, factor)
	_root.size = window / factor
