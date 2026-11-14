extends RefCounted
## The rules of the INVENTARIS tab of the game menu (logic; docs/CODE_LAGEN.md): which
## items the grid shows and in which order, which icon an item gets, what stands in a slot
## and in the panel of the chosen item, how the arrows move through the grid, what room the
## player has, and what using or dropping does to a plain inventory. The behaviour is
## inventory_tab.gd, the picture inventory_tab_view.gd.
##   const InventoryTabRules = preload("res://scripts/ui/game_menu/inventory_tab_rules.gd")

const Items = preload("res://scripts/player/items.gd")

## The rarities of Items.ITEMS, common first: what they are called.
const RARITY_LABELS := {"gewoon": "GEWOON", "bijzonder": "BIJZONDER", "zeldzaam": "ZELDZAAM", "episch": "EPISCH", "legendarisch": "LEGENDARISCH"}
const DEFAULT_RARITY := "gewoon"
## In place of the rarity of an item you have not got (the slot kept for your ID card).
const MISSING_LABEL := "KWIJT"
## The kinds of Items.ITEMS as shown under an item's name, and their order in the grid.
const KIND_NAMES := {"eten": "Eten", "drinken": "Drinken", "spullen": "Spullen", "sleutel": "Sleutelvoorwerp · niet weg te gooien"}
const KIND_ORDER := ["eten", "drinken", "spullen", "sleutel"]
const DEFAULT_KIND := "spullen"
## The kind that cannot be thrown away.
const KEY_KIND := "sleutel"
## The icon of an item without one of its own, by its kind.
const KIND_ICONS := {"eten": "brood", "drinken": "fles", "spullen": "tas", "sleutel": "sleutel"}
const DEFAULT_ICON := "tas"
## The category buttons over the grid: label and kind ("" = all).
const CATEGORIES := [["ALLES", ""], ["ETEN", "eten"], ["DRINKEN", "drinken"], ["SPULLEN", "spullen"], ["SLEUTEL", "sleutel"]]
## How the stats are called in the menu, and the stats where less is better (a negative
## effect is good news).
const STAT_LABELS := {"gezondheid": "LEVEN", "uithoudingsvermogen": "STAMINA", "honger": "HONGER", "overprikkeldheid": "PRIKKELS"}
const LOWER_IS_BETTER := ["overprikkeldheid"]
## The stats that start empty (as in the HUD); the others start full.
const STARTS_EMPTY := ["honger", "overprikkeldheid"]
## The keys that throw the chosen item away.
const DROP_KEYS := [KEY_X, KEY_DELETE, KEY_BACKSPACE]
const DEFAULT_ACTION := "GEBRUIKEN"
## The item whose text gets the number of the slip of Burgerzaken.
const TICKET_ITEM := "wachtnummer"


## The name an item is shown by.
static func item_name(item_id: String) -> String:
	return Items.item(item_id).get("name", item_id.capitalize())


static func kind_of(item_id: String) -> String:
	return Items.item(item_id).get("kind", DEFAULT_KIND)


static func rarity_of(item_id: String) -> String:
	var rarity: String = Items.item(item_id).get("rarity", DEFAULT_RARITY)
	return rarity if RARITY_LABELS.has(rarity) else DEFAULT_RARITY


## How a stat is called in the menu ("LEVEN"); its own name in capitals when it has none.
static func stat_label(stat_name: String) -> String:
	return STAT_LABELS.get(stat_name, stat_name.to_upper())


## The stat an archetype starts with when nobody keeps it: empty for hunger and
## overstimulation, else full; Vector2(value, maximum).
static func starting_stat(stat_name: String, maximum: float) -> Vector2:
	return Vector2(0.0 if stat_name in STARTS_EMPTY else maximum, maximum)


## The share (0..1) of a stat's bar that is full (a maximum under 1 counts as 1).
static func bar_fill(stat: Vector2) -> float:
	return stat.x / maxf(stat.y, 1.0)


## A stat after an effect of `change` points, within 0..its maximum.
static func stat_after(stat: Vector2, change: float) -> Vector2:
	return Vector2(clampf(stat.x + change, 0.0, stat.y), stat.y)


## The item ids in `inventory` (item id -> count) of this kind ("" = all), by kind
## (KIND_ORDER), then rarity (rare first), then name; first the slot always kept
## (Items.ALWAYS_SHOWN, your ID card) while you have not got it; at most `most`.
static func items_in_category(inventory: Dictionary, kind: String, most: int) -> Array[String]:
	var found: Array[String] = []
	for item_id: String in inventory:
		if int(inventory[item_id]) <= 0:
			continue
		if kind == "" or kind_of(item_id) == kind:
			found.append(item_id)
	var always := Items.ALWAYS_SHOWN
	var missing: bool = int(inventory.get(always, 0)) <= 0 and (kind == "" or kind == Items.item(always).get("kind", ""))
	found.sort_custom(comes_before)
	if missing:
		found.push_front(always)
	if found.size() > most:
		found.resize(most)
	return found


## Whether the item `first` stands before `second` in the grid.
static func comes_before(first: String, second: String) -> bool:
	var first_kind := KIND_ORDER.find(kind_of(first))
	var second_kind := KIND_ORDER.find(kind_of(second))
	if first_kind != second_kind:
		return first_kind < second_kind
	var rarity_order := RARITY_LABELS.keys()
	var first_rarity := rarity_order.find(Items.item(first).get("rarity", DEFAULT_RARITY))
	var second_rarity := rarity_order.find(Items.item(second).get("rarity", DEFAULT_RARITY))
	if first_rarity != second_rarity:
		return first_rarity > second_rarity
	return item_name(first) < item_name(second)


## The name of the icon of an item: its own when it is among `known_icons`, else that of
## its kind.
static func icon_name(item_id: String, known_icons: Array) -> String:
	var item := Items.item(item_id)
	var own: String = item.get("icon", "")
	if own == "" or not known_icons.has(own):
		return KIND_ICONS.get(item.get("kind", DEFAULT_KIND), DEFAULT_ICON)
	return own


## The index in CATEGORIES a number key (1-5) chooses; -1 for any other key.
static func category_for_key(key: Key) -> int:
	return key - KEY_1 if key >= KEY_1 and key < KEY_1 + CATEGORIES.size() else -1


## The index in CATEGORIES of a kind ("" = all); -1 when it is no category.
static func category_index(kind: String) -> int:
	for index in CATEGORIES.size():
		if CATEGORIES[index][1] == kind:
			return index
	return -1


static func is_drop_key(key: Key) -> bool:
	return key in DROP_KEYS


## The slot chosen after a step of `step` slots (InventoryTabLayout.slot_step) from `index`
## among `count` items: sideways past the end it stays (`sideways`), up or down off the
## grid it goes to the nearest item. -1 without items.
static func moved_selection(index: int, step: int, sideways: bool, count: int) -> int:
	if count <= 0:
		return -1
	var from := maxi(index, 0)
	var target := from + step
	if target < 0 or target >= count:
		if sideways:
			return from
		target = clampi(target, 0, count - 1)
	return target


## How many of an item `inventory` holds.
static func amount_of(inventory: Dictionary, item_id: String) -> int:
	return int(inventory.get(item_id, 0))


## How many things there are in all.
static func item_total(inventory: Dictionary) -> int:
	var total := 0
	for item_id: String in inventory:
		total += int(inventory[item_id])
	return total


## One of an item less in `inventory`; the last one takes the item out of it.
static func take_one(inventory: Dictionary, item_id: String) -> void:
	var left := int(inventory.get(item_id, 0)) - 1
	if left > 0:
		inventory[item_id] = left
	else:
		inventory.erase(item_id)


## Whether an item can be thrown away (a key item never).
static func can_drop(item_id: String) -> bool:
	return item_id != "" and Items.item(item_id).get("kind", "") != KEY_KIND


## How many slots are lit: the `room` the player has and, on top, one for each of
## `shown_items` that takes no room (the slip of Burgerzaken, the cans and bottles in the
## bag) for as long as it is there.
static func lit_slots(room: int, shown_items: Array, inventory: Dictionary) -> int:
	var extra := 0
	for item_id: String in shown_items:
		if amount_of(inventory, item_id) > 0 and not Items.takes_slot(item_id):
			extra += 1
	return room + extra


## How many slots of the room are taken: the kinds of item in the grid (at most `most`)
## that are there and take a slot.
static func used_slots(inventory: Dictionary, most: int) -> int:
	var used := 0
	for item_id: String in items_in_category(inventory, "", most):
		if amount_of(inventory, item_id) > 0 and Items.takes_slot(item_id):
			used += 1
	return used


## Under the grid: "4 / 6 VAKJES", with the coat when one is worn.
static func slots_text(used: int, room: int, has_coat: bool) -> String:
	return "%d / %d VAKJES" % [used, room] + ("  · JAS" if has_coat else "")


## The line in the tab bar: "7 SPULLEN BIJ JE".
static func header_text(total: int) -> String:
	return "%d SPULLEN BIJ JE" % total


## Under the character's name: "LV 3 · De schilder".
static func character_line(level: int, subtitle: String) -> String:
	return "LV %d · %s" % [level, subtitle]


## What an empty slot says when hovered: nothing within the `room`, else how to get more.
static func empty_slot_tooltip(slot_index: int, room: int) -> String:
	return "" if slot_index < room else "Meer ruimte met een jas aan"


## A slot with an item in it: {"icon": the name of its icon, "rarity", "count": the number
## bottom right ("" for one or none), "tooltip", "selected", "missing": the slot kept for
## an item you have not got}.
static func slot(item_id: String, amount: int, selected: bool, known_icons: Array) -> Dictionary:
	var missing := amount <= 0
	return {
		"icon": icon_name(item_id, known_icons),
		"rarity": rarity_of(item_id),
		"count": str(amount) if amount > 1 else "",
		"tooltip": item_name(item_id) + (" (kwijt)" if missing else ""),
		"selected": selected,
		"missing": missing,
	}


## The lines between the rules of the panel of the chosen item: how many there are and what
## it does to each stat. Each {"key", "value", "tone": "plain", "muted", "good" or "bad"}.
static func effect_lines(item_id: String, amount: int) -> Array:
	var lines := [{"key": "AANTAL", "value": "%d×" % amount, "tone": "plain"}]
	var effect: Dictionary = Items.item(item_id).get("effect", {})
	if effect.is_empty():
		lines.append({"key": "EFFECT", "value": "GEEN", "tone": "muted"})
	for stat_name: String in effect:
		var change := float(effect[stat_name])
		var better := change < 0.0 if stat_name in LOWER_IS_BETTER else change > 0.0
		lines.append({"key": stat_label(stat_name), "value": "VOL" if change >= Items.FULL else "%+d" % roundi(change),
				"tone": "good" if better else "bad"})
	return lines


## The text under the lines: `text` (the item's own, or what the bank cards make of it),
## with the number of the slip (`ticket_number`, -1 none) for the slip, or the item's
## "missing_text" when you have not got it; in quotes, "" when there is none.
static func detail_text(item_id: String, amount: int, text: String, ticket_number: int) -> String:
	var item := Items.item(item_id)
	if item_id == TICKET_ITEM and ticket_number >= 0:
		text += "\nNummer B %03d." % ticket_number
	if amount <= 0 and item.has("missing_text"):
		text = String(item.missing_text)
	return "“%s”" % text if text != "" else ""


## The panel of the chosen item: {"icon", "rarity", "rarity_text", "name", "kind_text",
## "lines" (effect_lines), "text" (detail_text), "can_use", "action": the text on the use
## button, "can_drop", "missing"}.
static func detail(item_id: String, amount: int, text: String, ticket_number: int, known_icons: Array) -> Dictionary:
	var item := Items.item(item_id)
	var missing := amount <= 0
	return {
		"icon": icon_name(item_id, known_icons),
		"rarity": rarity_of(item_id),
		"rarity_text": MISSING_LABEL if missing and item.has("missing_text") else RARITY_LABELS[rarity_of(item_id)],
		"name": item_name(item_id),
		"kind_text": KIND_NAMES.get(item.get("kind", DEFAULT_KIND), "Spullen"),
		"lines": effect_lines(item_id, amount),
		"text": detail_text(item_id, amount, text, ticket_number),
		"can_use": Items.can_use(item_id),
		"action": item.get("action", DEFAULT_ACTION),
		"can_drop": item.get("kind", "") != KEY_KIND,
		"missing": missing,
	}


## What the panel says when no item is chosen: nothing at all, or none of this kind.
static func empty_text(category: String) -> String:
	return "Je zakken zijn leeg." if category == "" else "Hier heb je niks van."
