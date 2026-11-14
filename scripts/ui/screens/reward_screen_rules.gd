extends RefCounted
## The logic of the reward screen (the rules layer of scripts/ui/reward_screen.gd, which is
## the behaviour; reward_screen_layout.gd has the sizes, reward_screen_view.gd builds and
## shows it): the pages of a reward, what a page says (the heading, the name, the rarity,
## the chips, the line at the bottom) and from when a key goes on. Plain functions, without
## nodes or the items of the game (the behaviour hands the item of a page in).
## A reward: {"heading", "title", "xp": int, "items": [{"item": id, "count": int}]}.
##   const RewardScreenRules = preload("res://scripts/ui/screens/reward_screen_rules.gd")

## Seconds before a key goes on (a key still held from the game does not skip it).
const KEYS_AFTER := 0.35
const RARITY_LABELS := {"gewoon": "GEWOON", "bijzonder": "BIJZONDER", "zeldzaam": "ZELDZAAM",
	"episch": "EPISCH", "legendarisch": "LEGENDARISCH"}
## What a page is called when its reward has no heading.
const DEFAULT_HEADING := "BELONING"
## A page with only experience: what it is called and what it says.
const XP_NAME := "ERVARING"
const XP_TEXT := "Je bent weer wat wijzer geworden op straat."
## The kinds of chips under an item: how many of it, and the experience that came with it.
const CHIP_COUNT := "count"
const CHIP_XP := "xp"


## The pages of `reward`: one for each item (the XP on the first), or one with only the XP.
## Per page: {"heading", "title", "xp", "item", "count"}.
static func pages_of(reward: Dictionary) -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	var xp := int(reward.get("xp", 0))
	for entry: Dictionary in reward.get("items", []):
		var item_id := String(entry.get("item", ""))
		if item_id == "":
			continue
		pages.append({"heading": String(reward.get("heading", DEFAULT_HEADING)), "title": String(reward.get("title", "")),
			"xp": xp if pages.is_empty() else 0, "item": item_id, "count": int(entry.get("count", 1))})
	if pages.is_empty() and xp > 0:
		pages.append({"heading": String(reward.get("heading", DEFAULT_HEADING)), "title": String(reward.get("title", "")),
			"xp": xp, "item": "", "count": 0})
	return pages


## Whether a key goes on yet, `since` seconds after the page came up.
static func keys_work(since: float) -> bool:
	return since >= KEYS_AFTER


## The line at the bottom of page `page_index` of `page_count`: OK on the last, else on to
## the next with where you are ("[ENTER] VERDER  1 / 3").
static func footer_text(page_index: int, page_count: int) -> String:
	return "[ENTER] OK" if page_index == page_count - 1 else "[ENTER] VERDER  %d / %d" % [page_index + 1, page_count]


## How experience reads ("+50 XP").
static func xp_text(xp: int) -> String:
	return "+%d XP" % xp


## How the rarity of `item` (Items: its "rarity") reads; an unknown one reads as common.
static func rarity_label(item: Dictionary) -> String:
	return String(RARITY_LABELS.get(String(item.get("rarity", "gewoon")), "GEWOON"))


## The chips under the item of `page`, left to right: [text, kind] each (CHIP_COUNT when
## there is more than one of it, CHIP_XP for the experience that came with it).
static func chips(page: Dictionary) -> Array:
	var made: Array = []
	if String(page.item) == "":
		return made
	if int(page.count) > 1:
		made.append(["%d x" % int(page.count), CHIP_COUNT])
	if int(page.xp) > 0:
		made.append([xp_text(int(page.xp)), CHIP_XP])
	return made


## What `page` (of pages_of) says, `item` the item it is about (Items.item; {} for a page
## with only experience): {"heading", "title", "name", "rarity", "text", "big_xp", "chips"}.
static func page_texts(page: Dictionary, item: Dictionary) -> Dictionary:
	var item_id := String(page.item)
	var texts := {"heading": "◆ " + String(page.heading), "title": String(page.title), "chips": chips(page)}
	if item_id != "":
		texts["name"] = String(item.get("name", item_id)).to_upper()
		texts["rarity"] = rarity_label(item)
		texts["text"] = String(item.get("text", ""))
		texts["big_xp"] = ""
	else:
		texts["name"] = XP_NAME
		texts["rarity"] = ""
		texts["text"] = XP_TEXT
		texts["big_xp"] = xp_text(int(page.xp))
	return texts
