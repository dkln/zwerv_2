extends RefCounted
## Unit tests of money and things (scripts/player/player_controller.gd, scripts/player/items.gd,
## scripts/ui/hud.gd, scripts/world/loose_change.gd): amounts written as the Dutch write them,
## buying (not without the money, not with full pockets), what is earned, and the items each
## character starts with.

const Items = preload("res://scripts/player/items.gd")
const LooseChange = preload("res://scripts/world/loose_change.gd")


## Amounts are written the Dutch way (euro sign, comma), also for a loose coin.
func test_money_as_the_dutch_write_it(test) -> void:
	var cases := {0.0: "0,00", 0.1: "0,10", 0.5: "0,50", 12.0: "12,00", 1284.5: "1.284,50",
		1234567.0: "1.234.567,00", -3.5: "-3,50", 2.005: "2,01"}
	for euros: float in cases:
		test.check(GameHud.money_text(euros) == cases[euros], "%s: %s (verwacht %s)" % [euros, GameHud.money_text(euros), cases[euros]])
	test.check(LooseChange._euros(0.5) == "€ 0,50", "een munt: € 0,50 (%s)" % LooseChange._euros(0.5))


## Buying: nothing without the money; with it the price goes off and the item comes in,
## a second one into the same slot.
func test_buying(test) -> void:
	var player := PlayerController.new()
	test.check(player.buy("kroket", 2.5) == "geld", "zonder geld: niets")
	player.add_money(5.0)
	test.check(player.buy("kroket", 2.5) == "ok", "met geld: gekocht")
	test.check(is_equal_approx(player.money, 2.5) and int(player.inventory.get("kroket", 0)) == 1, "geld eraf, kroket erbij")
	test.check(player.buy("kroket", 2.5) == "ok" and int(player.inventory.kroket) == 2, "nog een: in hetzelfde vak")
	player.free()


## With full pockets nothing is bought or paid, except more of what is already carried;
## a backpack gives more slots.
func test_full_pockets(test) -> void:
	var player := PlayerController.new()
	player.add_money(100.0)
	var kinds: Array = Items.ITEMS.keys()
	for index in player.inventory_slots():
		player.inventory[kinds[index]] = 1
	var other: String = kinds[player.inventory_slots()]
	test.check(player.buy(other, 1.0) == "vol", "zakken vol: niet gekocht")
	test.check(is_equal_approx(player.money, 100.0), "en niet betaald")
	test.check(player.add_item(kinds[0]), "van wat het al heeft past er nog bij")
	player.has_backpack = true
	test.check(player.inventory_slots() == Items.BASE_SLOTS + Items.BACKPACK_SLOTS, "met een rugzak meer vakken")
	test.check(player.buy(other, 1.0) == "ok", "en dan past het wel")
	player.free()


## Money never goes below nothing, and money_earned only counts what came in.
func test_what_is_earned(test) -> void:
	var player := PlayerController.new()
	player.add_money(3.0)
	player.add_money(-10.0)
	test.check(player.money == 0.0, "nooit minder dan niets (%s)" % player.money)
	test.check(player.money_earned == 3.0, "verdiend telt alleen wat erbij kwam (%s)" % player.money_earned)
	player.free()


## Every item of Items.ITEMS has all its fields; an unknown id gives an empty item.
func test_every_item_is_complete(test) -> void:
	for item_id: String in Items.ITEMS:
		var item: Dictionary = Items.item(item_id)
		for key in ["name", "kind", "rarity", "icon"]:
			test.check(item.has(key), "%s heeft %s" % [item_id, key])
	test.check(Items.item("bestaat_niet").is_empty(), "een onbekend item: leeg")


## What each character starts with are existing items that fit in the pockets.
func test_start_items_exist_and_fit(test) -> void:
	for character: String in Items.START_ITEMS:
		var start: Dictionary = Items.START_ITEMS[character]
		test.check(start.size() <= Items.BASE_SLOTS, "%s past in de zakken (%d vakken)" % [character, start.size()])
		for item_id: String in start:
			test.check(Items.ITEMS.has(item_id), "%s begint met %s, een bestaand item" % [character, item_id])
