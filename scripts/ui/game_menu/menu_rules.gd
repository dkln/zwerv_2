extends RefCounted
## The rules of the game menu as a whole (logic; docs/CODE_LAGEN.md): its tabs and their
## order, which key opens which tab, what the arrows and Enter mean on every tab, and how
## much its picture bends with the HUD. The behaviour is scripts/ui/game_menu.gd; the tabs
## have rules of their own (inventory_tab_rules.gd, quest_tab_rules.gd, map_tab_rules.gd).
##   const MenuRules = preload("res://scripts/ui/game_menu/menu_rules.gd")

const TABS := ["inventaris", "quests", "kaart"]
const TAB_TITLES := {"inventaris": "INVENTARIS", "quests": "QUESTS", "kaart": "KAART"}
## The tab the menu opens on the first time, and for a name that is no tab.
const FIRST_TAB := "inventaris"
## The key of each tab: opens the menu there, goes there, or closes the menu when on it.
const TAB_KEYS := {KEY_I: "inventaris", KEY_J: "quests", KEY_M: "kaart"}
const CLOSE_KEYS := [KEY_TAB, KEY_ESCAPE]
const ACCEPT_KEYS := [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
## How much the menu bends without a HUD to take it from (the HUD's own defaults).
const CURVATURE := 0.02
const CORNER := 0.035


## `tab_name` if it is a tab, else the first tab.
static func valid_tab(tab_name: String) -> String:
	return tab_name if TABS.has(tab_name) else FIRST_TAB


## The tab a key stands for (I, J, M); "" for any other key.
static func tab_for_key(key: Key) -> String:
	return TAB_KEYS.get(key, "")


## The tab `step` places on from `tab_name` (Q: -1, E: +1), round the ends.
static func neighbour_tab(tab_name: String, step: int) -> String:
	return TABS[posmod(TABS.find(tab_name) + step, TABS.size())]


## Which way Q (back) or E (on) goes through the tabs; 0 for any other key.
static func tab_step(key: Key) -> int:
	match key:
		KEY_Q:
			return -1
		KEY_E:
			return 1
	return 0


## Whether the key closes the open menu (Tab, Escape).
static func is_close_key(key: Key) -> bool:
	return key in CLOSE_KEYS


## A direction from the arrows or WASD, else Vector2i.ZERO.
static func direction(key: Key) -> Vector2i:
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


## Whether the key chooses (Enter, Space).
static func is_accept(key: Key) -> bool:
	return key in ACCEPT_KEYS


## How the menu bends, as Vector2(curvature, corner): as little as the HUD itself does
## (`ui_curvature`, at most the `curvature` of the world; no rounded corners when flat).
static func bend(ui_curvature: float, curvature: float, corner: float) -> Vector2:
	var bent := minf(ui_curvature, curvature)
	return Vector2(bent, corner if bent > 0.0 else 0.0)
