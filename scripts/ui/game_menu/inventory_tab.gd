extends Control
## The INVENTARIS tab of the game menu (the node "Inventaris"; behaviour,
## docs/CODE_LAGEN.md): it keeps the category and the item that are chosen, takes the keys
## of the tab (arrows / WASD choose, Enter uses, X drops, 1-5 the category) and the clicks
## of its picture, asks inventory_tab_rules.gd what the grid and the panel of the chosen
## item show of the player (menu_player.gd), and hands that to inventory_tab_view.gd.
## Made by scripts/ui/game_menu.gd, which refreshes it and passes the keys on.
##   const InventoryTab = preload("res://scripts/ui/game_menu/inventory_tab.gd")

const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const Items = preload("res://scripts/player/items.gd")
const BankCards = preload("res://scripts/player/bank_cards.gd")
const StatLook = preload("res://scripts/ui/hud/stat_look.gd")
const StatRules = preload("res://scripts/ui/hud/stat_rules.gd")
const ItemLook = preload("res://scripts/ui/game_menu/item_look.gd")
const MenuRules = preload("res://scripts/ui/game_menu/menu_rules.gd")
const MenuPlayer = preload("res://scripts/ui/game_menu/menu_player.gd")
const InventoryTabRules = preload("res://scripts/ui/game_menu/inventory_tab_rules.gd")
const InventoryTabLayout = preload("res://scripts/ui/game_menu/inventory_tab_layout.gd")
const InventoryTabView = preload("res://scripts/ui/game_menu/inventory_tab_view.gd")

## An item was used or thrown away: the whole menu shows itself anew (the money, the header).
signal changed

## Its picture.
var view: InventoryTabView
## The player whose things these are (the menu sets it).
var player: MenuPlayer

var _category := ""
var _selected_item := ""
var _shown_items: Array[String] = []


func _init() -> void:
	name = "Inventaris"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player = MenuPlayer.new()
	view = InventoryTabView.new()
	add_child(view)
	for stat_name: String in StatLook.STATS:
		view.add_stat(stat_name, InventoryTabRules.stat_label(stat_name))
	for category: Array in InventoryTabRules.CATEGORIES:
		view.add_category(category[0])
	view.category_pressed.connect(func(index: int) -> void: choose_category(InventoryTabRules.CATEGORIES[index][1]))
	view.slot_pressed.connect(choose_slot)
	view.use_pressed.connect(use_selected)
	view.drop_pressed.connect(drop_selected)


## Shows the character, its stats, the grid and the chosen item as they are now.
func refresh() -> void:
	var archetype := player.archetype()
	view.show_character(archetype.name, InventoryTabRules.character_line(player.level(), archetype.subtitle))
	show_figure()
	for stat_name: String in StatLook.STATS:
		var value := player.stat(stat_name)
		view.show_stat(stat_name, InventoryTabRules.bar_fill(value), StatRules.value_text(value))
	view.show_category(InventoryTabRules.category_index(_category))
	_shown_items = items_in_category(_category)
	if not _shown_items.has(_selected_item):
		_selected_item = _shown_items[0] if not _shown_items.is_empty() else ""
	_show_slots()
	_show_selected_item()


## The line of the tab bar while this tab is open.
func header_text() -> String:
	return InventoryTabRules.header_text(InventoryTabRules.item_total(player.inventory()))


## The figure of the player's archetype (while the menu is open: it renders every frame).
func show_figure() -> void:
	view.show_figure(player.archetype_id())


func hide_figure() -> void:
	view.hide_figure()


## A key while this tab is open: the arrows, Enter, the drop keys and 1-5.
func handle_key(key: Key) -> void:
	var direction := MenuRules.direction(key)
	if direction != Vector2i.ZERO:
		move_selection(direction)
	elif MenuRules.is_accept(key):
		use_selected()
	elif InventoryTabRules.is_drop_key(key):
		drop_selected()
	elif InventoryTabRules.category_for_key(key) != -1:
		choose_category(InventoryTabRules.CATEGORIES[InventoryTabRules.category_for_key(key)][1])


## Shows only the items of this kind ("" = all).
func choose_category(kind: String) -> void:
	if kind == _category:
		return
	UiSounds.play(self, "kies")
	_category = kind
	_selected_item = ""
	refresh()


## Chooses the item in this slot (a click, or the mouse over it); nothing on an empty slot.
func choose_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _shown_items.size():
		return
	if _shown_items[slot_index] != _selected_item:
		UiSounds.play(self, "kies")
		_selected_item = _shown_items[slot_index]
		refresh()


## Chooses this item without a sound (it is shown at the next refresh if it is in the grid).
func select_item(item_id: String) -> void:
	_selected_item = item_id


## The next item in this direction (the arrows).
func move_selection(direction: Vector2i) -> void:
	var index := maxi(_shown_items.find(_selected_item), 0)
	var target := InventoryTabRules.moved_selection(index, InventoryTabLayout.slot_step(direction), direction.y == 0, _shown_items.size())
	if target != -1 and target != index:
		UiSounds.play(self, "kies")
		_selected_item = _shown_items[target]
		refresh()


## Uses the chosen item (eats, drinks...).
func use_selected() -> void:
	if _selected_item == "" or not Items.can_use(_selected_item):
		UiSounds.play(self, "terug")
		return
	var used := player.use_item(_selected_item)
	UiSounds.play(self, "doe" if used else "terug")
	changed.emit()


## Throws one of the chosen item away, but never a key item.
func drop_selected() -> void:
	if not InventoryTabRules.can_drop(_selected_item):
		UiSounds.play(self, "terug")
		return
	player.drop_item(_selected_item)
	UiSounds.play(self, "terug")
	changed.emit()


## The kind of item shown ("" = all).
func category() -> String:
	return _category


func selected_item() -> String:
	return _selected_item


## The items in the grid, slot by slot.
func shown_items() -> Array[String]:
	return _shown_items


## The items of the player of this kind ("" = all), in the order of the grid.
func items_in_category(kind: String) -> Array[String]:
	return InventoryTabRules.items_in_category(player.inventory(), kind, InventoryTabLayout.slot_count())


## How many kinds of item the player has room for.
func slot_count() -> int:
	return player.slot_count(InventoryTabLayout.slot_count())


## The names of the icons there are: the items' own and the HUD's.
static func known_icons() -> Array:
	return ItemLook.ITEM_ICONS.keys() + StatLook.PIXEL_ICONS.keys()


func _show_slots() -> void:
	var inventory := player.inventory()
	var room := slot_count()
	var lit_slots := InventoryTabRules.lit_slots(room, _shown_items, inventory)
	var icons := known_icons()
	for slot_index in InventoryTabLayout.slot_count():
		var lit := slot_index < lit_slots
		if slot_index >= _shown_items.size():
			view.show_empty_slot(slot_index, lit, InventoryTabRules.empty_slot_tooltip(slot_index, room))
			continue
		var item_id := _shown_items[slot_index]
		var slot := InventoryTabRules.slot(item_id, InventoryTabRules.amount_of(inventory, item_id), item_id == _selected_item, icons)
		if item_id == BankCards.ITEM:
			slot.tooltip = BankCards.description(player.node, InventoryTabRules.item_name(item_id))
		view.show_slot(slot_index, slot, lit)
	view.show_slots_used(InventoryTabRules.slots_text(
			InventoryTabRules.used_slots(inventory, InventoryTabLayout.slot_count()), room, player.has_coat()))


func _show_selected_item() -> void:
	if _selected_item == "":
		view.show_no_item(InventoryTabRules.empty_text(_category))
		return
	var text: String = Items.item(_selected_item).get("text", "")
	if _selected_item == BankCards.ITEM:
		# every card found: its holder and the riddle of its PIN (BankCards)
		text = BankCards.description(player.node, text)
	view.show_item(InventoryTabRules.detail(_selected_item, InventoryTabRules.amount_of(player.inventory(), _selected_item),
			text, player.ticket_number(), known_icons()))
