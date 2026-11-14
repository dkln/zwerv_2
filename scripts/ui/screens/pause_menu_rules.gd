extends RefCounted
## The logic of the pause menu (the rules layer of scripts/ui/screens/pause_menu.gd, which
## is the behaviour; pause_menu_layout.gd has the sizes, pause_menu_view.gd builds and
## shows it): the items of the menu and what each does, which item the arrow goes to, and
## how the settings read. Plain functions, without nodes or the settings file (the
## behaviour reads the settings and hands the values in).
##   const PauseMenuRules = preload("res://scripts/ui/screens/pause_menu_rules.gd")

## The items of the menu: what it says and what it does (the behaviour's _do).
const ITEMS := [["VERDER SPELEN", "resume"], ["INSTELLINGEN", "settings"], ["HOOFDMENU", "menu"], ["AFSLUITEN", "quit"]]
## The last entry of the settings: back to the menu itself.
const BACK_LABEL := "TERUG"


## The index of the item of ITEMS that does `action` ("resume", "settings", ...); -1: none.
static func item_index(action: String) -> int:
	for index in ITEMS.size():
		if ITEMS[index][1] == action:
			return index
	return -1


## What the items of the menu say, top to bottom.
static func item_labels() -> Array[String]:
	var labels: Array[String] = []
	for item: Array in ITEMS:
		labels.append(String(item[0]))
	return labels


## What the items of the menu do ("resume", "settings", ...), top to bottom.
static func item_actions() -> Array[String]:
	var actions: Array[String] = []
	for item: Array in ITEMS:
		actions.append(String(item[1]))
	return actions


## The item `step` (1: down, -1: up) from `index` of `count`, round at the ends.
static func next_index(index: int, step: int, count: int) -> int:
	return posmod(index + step, count) if count > 0 else 0


## Whether choosing `action` sounds by itself: going on does not (it sounds as the menu closing).
static func action_sounds(action: String) -> bool:
	return action != "resume"


## How the anti-aliasing setting reads, `value` its name (GraphicsSettings.anti_aliasing).
static func anti_aliasing_label(value: String) -> String:
	return "ANTI-ALIASING: %s" % value


## How the render scale setting reads, `value` its text (GraphicsSettings.render_scale_text).
static func render_scale_label(value: String) -> String:
	return "RENDERSCHAAL: %s" % value


## How the CRT setting reads when the look is on or off.
static func crt_label(on: bool) -> String:
	return "CRT-BEELD: %s" % ("AAN" if on else "UIT")
